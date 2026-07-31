# Keepworth

App iOS de finanzas personales. **Local-only**: ningún dato de usuario sale del dispositivo salvo hacia el iCloud privado del propio usuario. No hay servidor propio ni cuentas de usuario.

iOS 26+ · iPhone y iPad · SwiftUI · GRDB · Tuist

> **Si es tu primera sesión en este proyecto, lee `ESTADO.md` antes de tocar nada.** Contiene el plan completo, las decisiones tomadas y por qué, en qué fase estamos y qué hay pendiente de verificar. Este archivo impone las reglas; `ESTADO.md` explica el contexto.

---

## Reglas duras

Estas reglas no se negocian por conveniencia. Si una tarea parece exigir romper una, es la tarea la que está mal planteada: pregunta antes de proceder.

### Ley de dependencias

| Módulo | Puede importar |
|---|---|
| `KeepworthDomain` | nada (ni GRDB, ni SwiftUI, ni CloudKit, ni UIKit) |
| `KeepworthPersistence` | `Domain` + GRDB |
| `KeepworthSync` | `Domain` + `Persistence` + CloudKit |
| `KeepworthDesignSystem` | SwiftUI únicamente |
| `Feature*` | `Domain` + `DesignSystem` |
| `KeepworthAppCore` | todos |

**Ninguna feature importa `KeepworthPersistence`, `KeepworthSync`, `GRDB` ni `CloudKit`.** Las features dependen de protocolos declarados en `Domain`; `KeepworthAppCore` es el único lugar donde se instancian implementaciones concretas.

Un `import GRDB` dentro de `Modules/Features/` es un error de arquitectura, no un atajo.

### Dinero

- El dinero se representa con `Money`, que envuelve `Int64` de unidades menores y un `CurrencyCode`.
- **Un `Double` o un `Float` en el dominio monetario es un bug.** Sin excepciones, tampoco "solo para mostrar".
- Aritmética entre divisas distintas sin tipo de cambio explícito debe fallar, no aproximar.

### Contabilidad

El modelo es de **partida doble**. Todo movimiento es un `Entry` con al menos dos `EntryLine` cuya suma en divisa base es **exactamente cero**.

Las categorías no son una tabla aparte: son `Account` de tipo `.expense` o `.income`. Un gasto es una transferencia de una cuenta de activo a una cuenta de gasto. La UI dice "categoría"; el ledger dice "cuenta".

### Persistencia

- Los identificadores son UUID. **Nunca autoincrementales**: romperían el sync con CloudKit.
- Toda tabla lleva `created_at`, `updated_at` y `deleted_at`.
- **Nada se borra físicamente.** Borrar es marcar `deleted_at`; las consultas filtran filas vivas.
- Cada cambio de esquema es una migración nueva y versionada. Nunca se edita una migración ya publicada.

### Diseño

- **Cero colores literales fuera de `KeepworthDesignSystem`.** Solo los seis tokens semánticos: `bg`, `surface`, `ink`, `inkSoft`, `hairline`, `accent`.
- El acento verde aparece únicamente en elementos interactivos y en dinero que entra. **Los gastos van en `ink`, nunca en rojo** — la app no regaña al usuario.
- Sin tarjetas ni sombras: la jerarquía se construye con espacio en blanco y hairlines de 0,5 pt.
- Los importes usan SF Mono con `.monospacedDigit()`.
- Una acción primaria por pantalla; el resto vive en gestos nativos.

### Textos

Todo texto visible vive en un String Catalog, en inglés y español. Un literal de cadena en una vista es un bug de localización.

### Dependencias externas

Solo GRDB está aprobada. Cualquier otra librería se propone al usuario con alternativas antes de instalarla, nunca se añade por iniciativa propia.

---

## Comandos

```bash
tuist install     # resuelve dependencias externas
tuist generate    # regenera el .xcodeproj (no está en git)
tuist build

xcodebuild test \
  -workspace Keepworth.xcworkspace \
  -scheme Keepworth \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

El `.xcodeproj` y el `.xcworkspace` son artefactos generados: no se editan a mano ni se versionan. Para añadir un módulo o cambiar dependencias se edita `Project.swift`.

---

## Estructura

```
Apps/Keepworth/            app target
Modules/Core/              Domain, Persistence, Sync, DesignSystem
Modules/KeepworthAppCore/  composition root: DI y navegación raíz
```

Aún no existen, y sus targets se declararán en `Project.swift` cuando toque:

```
Modules/Features/          una carpeta por feature (Fase 4)
Apps/KeepworthWidgets/     widget extension (Fase 7)
```

Cada módulo tiene `Sources/` y `Tests/`. Los módulos Core llevan su propio `CLAUDE.md` con el contrato de la capa: léelo antes de tocarlos.

## Tests

Swift Testing (`import Testing`, `@Test`, `#expect`), no XCTest.

`KeepworthDomain` es la capa donde se demuestran los invariantes contables: merece cobertura alta. Las features se testean con dobles en memoria de los protocolos de `Domain`, nunca contra una base de datos real.
