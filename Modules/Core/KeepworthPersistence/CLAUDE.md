# KeepworthPersistence

Implementa los protocolos de repositorio de `KeepworthDomain` sobre SQLite con GRDB.

## Contrato

**Importa**: `KeepworthDomain` y `GRDB`. Nada más.

**Expone**: `AppDatabase` con la configuración de la base de datos y el registro de migraciones, y las cuatro implementaciones de repositorio: `SQLiteInstitutionRepository`, `SQLiteAccountRepository`, `SQLiteEntryRepository` y `SQLiteSettingsRepository`. **No expone tipos de GRDB en su API pública**: quien la usa recibe entidades de `Domain`, nunca `Record`, `Row` ni `DatabaseWriter`.

## Base de datos

- Vive en el contenedor del **App Group**, no en Documents. El widget necesita leerla.
- `DatabasePool`, no `DatabaseQueue`: hay lecturas concurrentes desde el widget. Vale para la base de datos real; la de tests y previews (`AppDatabase.inMemory()`) es un `DatabaseQueue`, que sin fichero es lo único que tiene sentido.
- Protección de fichero: `.completeUntilFirstUserAuthentication`. **No usar `.complete`**: impediría al widget leer con el dispositivo bloqueado.

## Reglas de esquema

1. **UUID como clave primaria, nunca autoincremental.** Un `INTEGER PRIMARY KEY AUTOINCREMENT` rompe el sync con CloudKit de forma irreparable.
2. Toda tabla lleva `created_at`, `updated_at` y `deleted_at`.
3. **Soft delete siempre**: borrar es escribir `deleted_at`. Las consultas filtran `deleted_at IS NULL`. Un `DELETE FROM` en código de producción es un bug: sin tombstone, el registro reaparece en el siguiente sync.

   Hoy **no existe ninguna operación de borrado en esta capa**. `AccountRepository.archive` es lo único que hay, y el único `deleted_at` que se escribe es el que entierra las líneas que un asiento reguardado ya no tiene. El borrado llega en la Fase 4, con la pantalla que lo pide y con su regla —sin movimientos se borra, con movimientos se archiva—. La regla de arriba es la que tendrá que cumplir cuando exista.
4. **Las líneas se consultan por la vista `live_entry_line`, nunca por `entry_line`.** Una línea solo cuenta si ni ella ni su asiento están borrados; filtrar solo por la línea deja vivas las líneas de asientos borrados y descuadra saldos e informes sin dar ningún síntoma.
5. `PRAGMA foreign_keys = ON`. No es el valor por defecto de SQLite.
6. Cada cambio de esquema es una **migración nueva y versionada**. Una migración ya publicada no se edita jamás, ni para corregir un typo.

## Observación

`SQLiteLedgerChanges` implementa el protocolo `LedgerChanges` de `Domain` con un `DatabaseRegionObservation` sobre **la base entera**, no sobre una lista de tablas. La señal no lleva detalle, así que estrechar la región no compraría nada y añadiría una forma de equivocarse: olvidar una tabla es una pantalla que deja de actualizarse sin síntoma.

Se valoró observar cada consulta con `ValueObservation` —lo que este documento prometía antes— y se descartó en la Fase 4: obligaba a una variante observada de cada consulta y a que el doble en memoria emitiera con la misma semántica en todas ellas, para ahorrar unas lecturas pequeñas contra SQLite local.

El `Database` que entrega `onChange` se descarta a propósito: leerlo ahí correría en la cola del escritor y convertiría un aviso en una consulta.

**Una sola observación para toda la app, repartida entre todos los oyentes.** `DatabaseRegionObservation.start` **bloquea el hilo que lo llama** hasta conseguir acceso de escritura, así que arrancar una por pantalla congelaría el hilo principal mientras hubiera una importación en curso. `SQLiteLedgerChanges` arranca en su `init` y `changes()` solo añade un oyente.

Dos consecuencias que hay que respetar al usarlo:

- **Se construye una vez, en `KeepworthAppCore`, y fuera del actor principal.** Es la llamada que puede esperar al escritor.
- **El stream mantiene viva la observación**, con una captura fuerte deliberada. Sin ella, `SQLiteLedgerChanges(...).changes()` sobre un valor que nadie más retiene devuelve un stream que no dispara nunca, porque el `deinit` cancela al salir. Costó tres tests en rojo descubrirlo, y en producción habría sido una pantalla que deja de refrescarse sin ningún síntoma.

Los streams llevan `bufferingPolicy: .bufferingNewest(1)`: dos señales dicen lo mismo que una, así que importar veinte movimientos con la pantalla suspendida cuesta una recarga al volver, no veinte.

## Records

Los records son tipos **aparte** de las entidades de `Domain`, y no por gusto: `Domain` no puede importar GRDB, así que no puede conformar `FetchableRecord`.

Esa separación es lo que obliga a que **toda lectura pase por el inicializador que valida**. Decodificar directamente en la entidad dejaría entrar una fila que el dominio considera imposible —una categoría dentro de un banco— y el resto del código se fía de que no existe. Hay un test que lo demuestra saltándose el `CHECK` del esquema.

## Lectura de asientos

`entries(matching:)` va en **dos consultas**, no una por asiento: primero qué movimientos casan con el filtro, después todas las líneas de esos movimientos de golpe.

Toda lectura pasa por `Entry.init`, así que un asiento cuyas líneas almacenadas ya no suman cero **falla al leerse** en vez de pintarse en pantalla. Hay test. Por eso `toDomain(lines:)` recibe **todas** las líneas del asiento aunque el filtro solo casara con una: un subconjunto nunca cuadra.

El desempate del orden es `created_at`. `occurred_on` no tiene hora, así que varios movimientos del mismo día volverían en el orden que SQLite quisiera y la lista se reordenaría sola entre arranques.

## Escritura

- **`created_at` y `deleted_at` no se reescriben nunca en un `save`.** Se leen de la fila existente con `StoredTimestamps`. Limpiar un tombstone al guardar resucita la fila en el siguiente sync.
- **Guardar un asiento entierra las líneas que ya no tiene.** Si no, editar un movimiento de tres líneas a dos deja viva la tercera bajo un asiento vivo: `live_entry_line` la sigue devolviendo y el asiento almacenado deja de sumar cero, sin ningún síntoma.
- El reloj se inyecta (`now:`) para que los tests fijen las marcas de tiempo.

## Tests

Contra base de datos **en memoria**, nunca contra un fichero real.

Casos que siempre deben existir: cada migración aplica sobre base vacía y sobre base con datos; los saldos derivados coinciden con la suma de líneas; reguardar un asiento con menos líneas entierra las sobrantes; un `save` no reescribe `created_at` ni limpia un tombstone.

El test de que una fila con `deleted_at` desaparece de las consultas existe, pero hoy escribe el `UPDATE` a mano porque **no hay API de borrado que llamar**. Cuando la Fase 4 la traiga, ese test pasa a ejercitarla y se convierte en criterio permanente.

El helper `StoredLedger` monta un libro sembrado sobre los cuatro repositorios reales. Se llama así frente al `Ledger` de `KeepworthDomain`, que ve lo mismo a través de dobles en memoria; ninguno de los dos toca un fichero.
