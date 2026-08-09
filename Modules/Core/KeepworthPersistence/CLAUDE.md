# KeepworthPersistence

Implementa los protocolos de repositorio de `KeepworthDomain` sobre SQLite con GRDB.

## Contrato

**Importa**: `KeepworthDomain` y `GRDB`. Nada más.

**Expone**: implementaciones concretas de `AccountRepository` y `EntryRepository`, la configuración de la base de datos y el registro de migraciones. **No expone tipos de GRDB en su API pública**: quien la usa recibe entidades de `Domain`, nunca `Record` ni `Row`.

## Base de datos

- Vive en el contenedor del **App Group**, no en Documents. El widget necesita leerla.
- `DatabasePool`, no `DatabaseQueue`: hay lecturas concurrentes desde el widget.
- Protección de fichero: `.completeUntilFirstUserAuthentication`. **No usar `.complete`**: impediría al widget leer con el dispositivo bloqueado.

## Reglas de esquema

1. **UUID como clave primaria, nunca autoincremental.** Un `INTEGER PRIMARY KEY AUTOINCREMENT` rompe el sync con CloudKit de forma irreparable.
2. Toda tabla lleva `created_at`, `updated_at` y `deleted_at`.
3. **Soft delete siempre**: borrar es escribir `deleted_at`. Las consultas filtran `deleted_at IS NULL`. Un `DELETE FROM` en código de producción es un bug: sin tombstone, el registro reaparece en el siguiente sync.
4. **Las líneas se consultan por la vista `live_entry_line`, nunca por `entry_line`.** Una línea solo cuenta si ni ella ni su asiento están borrados; filtrar solo por la línea deja vivas las líneas de asientos borrados y descuadra saldos e informes sin dar ningún síntoma.
5. `PRAGMA foreign_keys = ON`. No es el valor por defecto de SQLite.
6. Cada cambio de esquema es una **migración nueva y versionada**. Una migración ya publicada no se edita jamás, ni para corregir un typo.

## Observación

La UI se refresca con `ValueObservation`. Los repositorios exponen secuencias de valores de `Domain`, no de records de GRDB.

## Records

Los records son tipos **aparte** de las entidades de `Domain`, y no por gusto: `Domain` no puede importar GRDB, así que no puede conformar `FetchableRecord`.

Esa separación es lo que obliga a que **toda lectura pase por el inicializador que valida**. Decodificar directamente en la entidad dejaría entrar una fila que el dominio considera imposible —una categoría dentro de un banco— y el resto del código se fía de que no existe. Hay un test que lo demuestra saltándose el `CHECK` del esquema.

## Escritura

- **`created_at` y `deleted_at` no se reescriben nunca en un `save`.** Se leen de la fila existente con `StoredTimestamps`. Limpiar un tombstone al guardar resucita la fila en el siguiente sync.
- **Guardar un asiento entierra las líneas que ya no tiene.** Si no, editar un movimiento de tres líneas a dos deja viva la tercera bajo un asiento vivo: `live_entry_line` la sigue devolviendo y el asiento almacenado deja de sumar cero, sin ningún síntoma.
- El reloj se inyecta (`now:`) para que los tests fijen las marcas de tiempo.

## Tests

Contra base de datos **en memoria**, nunca contra un fichero real.

Casos que siempre deben existir: cada migración aplica sobre base vacía y sobre base con datos; el borrado marca `deleted_at` y la fila desaparece de las consultas; los saldos derivados coinciden con la suma de líneas.
