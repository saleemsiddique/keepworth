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
- **El valor de una línea en divisa base se guarda, no se calcula.** Es el importe que realmente se movió, no el resultado de multiplicar por un tipo de cambio. Multiplicar descuadra los asientos y hace inalcanzable el invariante de suma cero.

### Contabilidad

El modelo es de **partida doble**. Todo movimiento es un `Entry` con al menos dos `EntryLine` cuya suma en divisa base es **exactamente cero**.

Cada `Account` tiene un `AccountKind` que determina todo su comportamiento:

| `kind` | Qué es para el usuario | ¿Patrimonio? | ¿Banco? |
|---|---|---|---|
| `.asset` | Cuentas, efectivo, carteras | Suma | Opcional |
| `.liability` | Tarjetas de crédito, préstamos | Resta | Opcional |
| `.expense` | Categorías de gasto | **Nunca** | Nunca |
| `.income` | Categorías de ingreso | **Nunca** | Nunca |
| `.equity` | Saldo inicial (interna, oculta) | Nunca | Nunca |

**El patrimonio neto es exclusivamente `.asset` + `.liability`.** Que una categoría sume al patrimonio es el bug más grave posible en esta app: significa que el usuario cree tener dinero que no tiene.

Las categorías no son una tabla aparte: son `Account` de tipo `.expense` o `.income`, y **no existe un tipo `Category`**. Eso es fontanería que hace que gasto, ingreso y traspaso sean la misma operación; la UI nunca las mezcla con las cuentas.

Los bancos sí son entidad propia (`Institution`): agrupan cuentas y dan un total por entidad, pero no guardan dinero ni reciben movimientos. Una cuenta `.expense`, `.income` o `.equity` **nunca** pertenece a un banco.

### Persistencia

- Los identificadores son UUID. **Nunca autoincrementales**: romperían el sync con CloudKit.
- Toda tabla lleva `created_at`, `updated_at` y `deleted_at`.
- **Nada se borra físicamente.** Borrar es marcar `deleted_at`; las consultas filtran filas vivas.
- Una línea solo cuenta si **ni ella ni su asiento** están borrados. Las consultas van contra la vista `live_entry_line`, nunca contra `entry_line` directamente: filtrar solo por la línea es el error silencioso más probable del esquema.
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

### Git

Nada de lo que quede en el repositorio lleva atribución de IA: sin `Co-Authored-By: Claude`, sin `🤖 Generated with Claude Code`, sin menciones a Claude, Anthropic o Claude Code en mensajes de commit, cuerpos de PR, issues ni comentarios. El autor es el usuario y el mensaje describe el cambio y su porqué, nada más.

El CI dispara en `pull_request` y en `push` a `main`: **empujar una rama sin abrir PR no ejecuta nada.**

---

## Comandos

**Solo funcionan en el Mac.** Tuist y `swift-format` no existen en Windows, así que desde ahí no se puede compilar, testear ni formatear, y los dos hooks quedan inertes. El detalle está en `ESTADO.md` §3.

```bash
tuist install            # resuelve dependencias externas
tuist generate --no-open # regenera el .xcodeproj (no está en git)

tuist xcodebuild build \
  -workspace Keepworth.xcworkspace \
  -scheme Keepworth-Workspace \
  -destination 'platform=iOS Simulator,name=iPhone 17'

xcodebuild test \
  -workspace Keepworth.xcworkspace \
  -scheme Keepworth-Workspace \
  -destination 'platform=iOS Simulator,name=iPhone 17' | xcbeautify

xcrun swift-format lint --configuration .swift-format --recursive --strict Modules Apps
```

**El esquema es `Keepworth-Workspace`, no `Keepworth`.** Tuist autogenera un esquema por target: el de `Keepworth` es el de la app y su acción de test está vacía, así que ejecuta cero tests sin avisar de ello. `Keepworth-Workspace` es el único que agrupa los cinco targets de test.

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
