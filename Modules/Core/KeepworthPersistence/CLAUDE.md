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
4. Cada cambio de esquema es una **migración nueva y versionada**. Una migración ya publicada no se edita jamás, ni para corregir un typo.

## Observación

La UI se refresca con `ValueObservation`. Los repositorios exponen secuencias de valores de `Domain`, no de records de GRDB.

## Tests

Contra base de datos **en memoria**, nunca contra un fichero real.

Casos que siempre deben existir: cada migración aplica sobre base vacía y sobre base con datos; el borrado marca `deleted_at` y la fila desaparece de las consultas; los saldos derivados coinciden con la suma de líneas.
