# KeepworthSync

Sincroniza la base de datos local con la **CloudKit private database** del usuario mediante `CKSyncEngine`, a nivel de registro.

No existe servidor propio en ningún punto de este flujo: los datos van del dispositivo al iCloud del propio usuario y vuelven.

## Contrato

**Importa**: `KeepworthDomain`, `KeepworthPersistence` y `CloudKit`.

**Expone**: el arranque y el estado del motor de sync. Nada de la app fuera de `KeepworthAppCore` lo usa directamente.

## Por qué el esquema ya está preparado

Estas tres decisiones se tomaron al diseñar el modelo de datos y están implementadas en la migración `v1` (Fase 2), precisamente para que este módulo sea posible sin migrar datos de usuario:

- **UUID como identificador**: el `recordName` de CloudKit se deriva de él.
- **`updated_at` en toda fila**: es el criterio de resolución de conflictos.
- **Soft delete**: sin tombstone, un registro borrado en un dispositivo reaparece desde otro.

Se sincronizan `institution`, `account`, `entry`, `entry_line` y `app_setting`.

Los *system fields* de cada `CKRecord` se conservan en una tabla `sync_metadata` aparte, no en columnas de las tablas de datos: perderlos hace que el servidor rechace la escritura o duplique el registro, y mezclarlos con el modelo cargaría al dominio con detalles de transporte.

## Reglas

1. La resolución de conflictos es **a nivel de registro por `updated_at`**, no a nivel de campo.
2. El sync es **offline-first**: los cambios se aplican siempre en local primero y se encolan para subir. La UI nunca espera a la red.
3. Un fallo de red **no es un error de usuario**: se reintenta, no se muestra una alerta.
4. Un `Entry` y sus `EntryLine` deben subirse y aplicarse **juntos**. Un asiento a medio sincronizar es un asiento descuadrado, que viola el invariante central del dominio.

## Tests

La lógica de mapeo entidad ↔ `CKRecord` y la resolución de conflictos se testean sin red, con dobles.

La verificación real es manual y con dos simuladores compartiendo cuenta de iCloud: un cambio en uno aparece en el otro, y editar el mismo movimiento en ambos resuelve sin duplicar ni perder datos.
