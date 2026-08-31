# Keepworth

App iOS de finanzas personales. **Local-only**: ningún dato de usuario sale del dispositivo salvo hacia el iCloud privado del propio usuario. No hay servidor propio ni cuentas de usuario.

iOS 26+ · iPhone y iPad · SwiftUI · GRDB · Tuist

Este archivo impone las reglas que valen en cualquier archivo del repositorio. Las de una capa concreta viven en el `CLAUDE.md` de su módulo, que se carga solo al trabajar allí. `ESTADO.md` no se lee entero: se consulta por secciones —§3 entorno y trampas de verificación, §6 modelo de datos, §6 bis decisiones del dominio, §7 design system, §8 navegación, §9 fases, §11 puntos abiertos—.

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
| `Feature*` | `Domain` + `DesignSystem` (+ `FeatureSupport`) |
| `KeepworthAppCore` | todos |

**Ninguna feature importa `KeepworthPersistence`, `KeepworthSync`, `GRDB` ni `CloudKit`.** Las features dependen de protocolos declarados en `Domain`; `KeepworthAppCore` es el único lugar donde se instancian implementaciones concretas.

`FeatureSupport` está en la capa de features y tiene sus mismos derechos: guarda lo que dos pantallas dibujan igual, y no puede importar nada que una feature no pueda.

Un `import GRDB` dentro de `Modules/Features/` es un error de arquitectura, no un atajo. Si una feature necesita algo que no está en los protocolos de `Domain`, **se amplía el protocolo**.

Excepciones, y solo estas tres: `Apps/KeepworthWidgets` depende de `Persistence` porque lee la base de datos del App Group; `KeepworthDesignSystemTests` importa UIKit porque es la única API que admite no haber encontrado un color del catálogo; y los targets de test de las features **repiten** los dobles en memoria de `Domain`, porque un target de test no exporta nada y la alternativa sería enviar dobles dentro de un módulo de producción. La tabla limita lo que importa cada **módulo**, no sus tests.

**Un archivo bajo `Modules/` sin target declarado en `Project.swift` esquiva toda la validación**: no lo ve `tuist generate`, ni el build, ni el CI. El target y el primer `.swift` del módulo van en el mismo commit.

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

Los siete invariantes con sus tests están en `Modules/Core/KeepworthDomain/CLAUDE.md`.

### Persistencia

UUID como clave primaria —nunca autoincremental, rompería el sync—, `created_at`/`updated_at`/`deleted_at` en toda tabla, soft delete siempre, migraciones publicadas inmutables, y las líneas se leen por la vista `live_entry_line` y nunca por `entry_line`.

Las seis reglas de esquema, con su porqué y sus trampas, están en `Modules/Core/KeepworthPersistence/CLAUDE.md`.

### Diseño

Siete tokens semánticos y ni un color literal fuera de `KeepworthDesignSystem`. El color de un importe marca **dirección, nunca juicio**: `accent` cuando el dinero entra, `expense` cuando sale o se debe, `ink` en todo lo demás. Lleva signo todo importe negativo o con dirección.

La paleta con sus hex, la regla completa del color y del signo, y el acabado —sin tarjetas ni sombras— están en `Modules/Core/KeepworthDesignSystem/CLAUDE.md`.

### Textos

Todo texto visible vive en un String Catalog, en inglés y español. Un literal de cadena en una vista es un bug de localización.

**Siempre con `bundle: .module`.** Dentro de un framework, `String(localized:)` y `Text(_:)` miran en el bundle principal, así que sin él las cadenas se pintan como su propia clave **sin dar ningún error**.

### Idioma del código

**Todo lo que va dentro de un archivo de código está en inglés**: identificadores, comentarios, mensajes de error de desarrollador y nombres de test. Sin excepciones por tipo de archivo — Swift, `Project.swift`, `Tuist/Package.swift`, workflows de CI, entitlements y scripts de hook incluidos.

La documentación (`CLAUDE.md`, `ESTADO.md`) y la conversación van en español. La frontera es el archivo: si el compilador, `xcodebuild` o la shell lo leen, está en inglés.

Dos excepciones, y solo dos:

- **Texto visible para el usuario** mientras no exista localización: hoy es `NSFaceIDUsageDescription` en `Project.swift`, y se mueve al String Catalog en cuanto haya uno.
- **Datos de prueba que simulan lo que teclearía el usuario**: una cuenta llamada `"Nómina"` en un test es un dato, no código. Traducirla no mejora nada y le quita realismo al caso.

### Dependencias externas

Solo GRDB está aprobada. Cualquier otra librería se propone al usuario con alternativas antes de instalarla, nunca se añade por iniciativa propia.

### Git

Nada de lo que quede en el repositorio lleva atribución de IA: sin `Co-Authored-By: Claude`, sin `🤖 Generated with Claude Code`, sin menciones a Claude, Anthropic o Claude Code en mensajes de commit, cuerpos de PR, issues ni comentarios. El autor es el usuario y el mensaje describe el cambio y su porqué, nada más.

El CI dispara en `pull_request` y en `push` a `main`: **empujar una rama sin abrir PR no ejecuta nada.**

Las PR se cierran con **commit de merge** y la rama se conserva. Ni squash, ni `--delete-branch`: cada fase queda como una unidad navegable en el historial.

#### PR apiladas: se mergean de arriba abajo

Una fase larga se parte en varias PR, cada una con la anterior como base. **Se mergean empezando por la de arriba** —la última— y bajando, de modo que la de más abajo acaba conteniendo a todas y una sola PR la lleva a `main`.

De abajo arriba **no funciona aquí**: GitHub solo reapunta la base de una PR apilada a `main` cuando se **borra** la rama anterior, y estas se conservan. Cada PR se mergea entonces en su base, así que solo llega la primera y el resto se queda en ramas intermedias sin que nada avise. Pasó con las PR #8 a #11 de la Fase 4. Antes de darlas por hechas:

```bash
git fetch origin
git log --oneline origin/main -5          # ¿está lo que crees que está?
git diff --stat origin/main origin/<rama-de-arriba>   # tiene que salir vacío
```

### Cambiar una decisión

Una regla vive en **un solo sitio autoritativo**: este archivo si es transversal, el `CLAUDE.md` de su módulo si es de una capa. Quien la cita, la enlaza en vez de repetirla. Cuando cambie, recorre los cuatro sitios donde deja rastro:

1. **El `CLAUDE.md` dueño** — el enunciado de la regla.
2. **`ESTADO.md`** — el porqué y a qué sustituye. Una regla que cambia sin dejar rastro de por qué cambió se revierte sola en tres meses.
3. **`.claude/agents/architecture-reviewer.md`** — el que más se olvida. Copia las reglas a propósito, para poder auditar sin depender de nada; si se quedan viejas, **denuncia como violación justo lo que se acaba de decidir**. Ya pasó al añadir el token `expense`.
4. **Las maquetas y ejemplos** de `ESTADO.md` §6 y §8, y las galerías del design system. Son la referencia visual, y siguen enseñando lo viejo aunque el texto de al lado diga otra cosa.

Dos hábitos que salen de haberlo hecho mal:

- **Enuncia el criterio, no una lista de ejemplos.** «`ink` para un saldo positivo o un total» dejó fuera el saldo negativo, y el código y la documentación acabaron discrepando sin que nadie lo viera. «`ink` para todo lo que no entra ni sale» no deja huecos.
- **Cuando dos documentos digan lo mismo, que lo digan con las mismas palabras.** Si uno matiza y otro no, el matiz se pierde en la siguiente lectura.

---

## Comandos

**Solo funcionan en el Mac.** Tuist y `swift-format` no existen en Windows, así que desde ahí no se puede compilar, testear ni formatear, y los dos hooks quedan inertes. El detalle está en `ESTADO.md` §3.

Los binarios vienen de `mise`, y los hooks corren en un shell no interactivo. Si un comando «no existe», es el `PATH`:

```bash
export PATH="$HOME/.local/share/mise/shims:$PATH"
```

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

**El esquema es `Keepworth-Workspace`, no `Keepworth`.** Tuist autogenera un esquema por target: el de `Keepworth` es el de la app y su acción de test está vacía, así que ejecuta cero tests sin avisar de ello. `Keepworth-Workspace` es el único que agrupa los diez targets de test.

**`tuist generate` no es opcional al crear o renombrar archivos.** La lista de archivos queda fijada en el `.xcodeproj`, así que un archivo nuevo no se compila y uno renombrado da `Build input file cannot be found`. El hook solo se dispara al tocar `Project.swift`; en los demás casos lo lanzas tú.

El `.xcodeproj` y el `.xcworkspace` son artefactos generados: no se editan a mano ni se versionan. Para añadir un módulo o cambiar dependencias se edita `Project.swift`.

Cuando algo falle de forma rara —SourceKit subrayando código correcto, todos los bundles de test cayendo a la vez—, mira `ESTADO.md` §3 § «Trampas de verificación» antes de tocar Swift: suele ser el entorno.

### Antes de dar una fase por terminada

Además de build, tests y lint, una comprobación que ninguna herramienta hace sola:

```bash
# cero colores literales fuera del design system
grep -rn -E 'Color\(red:|\.foregroundColor|Color\.(gray|black|white|red|blue|green|primary|secondary)|Divider\(\)|\.shadow\(' \
  --include='*.swift' Modules Apps | grep -v 'Sources/Tokens/Colors.swift'
```

Los recuentos de tests se dicen en **casos ejecutados y por módulo**, nunca en atributos `@Test` del repositorio entero: los tests parametrizados hacen que las dos cifras no se parezcan.

Queda además el agente `architecture-reviewer`, que encuentra lo que el compilador no puede. **Se lanza solo si el usuario lo pide.**

---

## Estructura

```
Apps/Keepworth/            app target
Modules/Core/              Domain, Persistence, Sync, DesignSystem
Modules/Features/          una carpeta por pantalla, más FeatureSupport
Modules/KeepworthAppCore/  composition root: DI y navegación raíz
Apps/KeepworthWidgets/     widget extension — no existe aún (Fase 7)
```

Cada módulo tiene `Sources/` y `Tests/`, y los que llevan `Resources/` lo declaran con `resourceGlobs:` en `Project.swift`. **Cada capa lleva su propio `CLAUDE.md` con su contrato**, incluida `Modules/Features/`: se cargan al leer un archivo de la carpeta, así que la regla de una capa no ocupa contexto mientras trabajas en otra.

## Tests

Swift Testing (`import Testing`, `@Test`, `#expect`), no XCTest.

`KeepworthDomain` es la capa donde se demuestran los invariantes contables: merece cobertura alta. Las features se testean con dobles en memoria de los protocolos de `Domain`, nunca contra una base de datos real.
