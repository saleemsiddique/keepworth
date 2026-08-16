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

### Persistencia

- Los identificadores son UUID. **Nunca autoincrementales**: romperían el sync con CloudKit.
- Toda tabla lleva `created_at`, `updated_at` y `deleted_at`.
- **Nada se borra físicamente.** Borrar es marcar `deleted_at`; las consultas filtran filas vivas.
- Una línea solo cuenta si **ni ella ni su asiento** están borrados. Las consultas van contra la vista `live_entry_line`, nunca contra `entry_line` directamente: filtrar solo por la línea es el error silencioso más probable del esquema.
- Cada cambio de esquema es una migración nueva y versionada. Nunca se edita una migración ya publicada.

### Diseño

- **Cero colores literales fuera de `KeepworthDesignSystem`.** Solo los siete tokens semánticos: `bg`, `surface`, `ink`, `inkSoft`, `hairline`, `accent`, `expense`.
- **El color de un importe marca dirección, nunca juicio**: `accent` cuando el dinero **entra**, `expense` cuando **sale o se debe** —un gasto, un saldo negativo, el total gastado de un periodo—, e `ink` en **todo lo demás**, incluidos los saldos positivos y las cifras derivadas como lo ahorrado. El verde aparece además en los elementos interactivos.
- `expense` está construido para espejar a `accent`, no para alarmar: profundo y desaturado en claro, brillante en oscuro, igual que el verde. Ninguno de los dos grita más que el otro.
- **Lleva signo todo importe que sea negativo o que tenga dirección**; un saldo positivo no lleva ninguno. El signo se pone aunque el color ya diga lo mismo: la redundancia es deliberada, porque la cifra tiene que leerse igual en escala de grises, con daltonismo o copiada a un sitio sin color.
- Sin tarjetas ni sombras: la jerarquía se construye con espacio en blanco y hairlines de 0,5 pt.
- Los importes usan SF Mono con `.monospacedDigit()`.
- Una acción primaria por pantalla; el resto vive en gestos nativos.

### Textos

Todo texto visible vive en un String Catalog, en inglés y español. Un literal de cadena en una vista es un bug de localización.

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

Mergearlas en el orden natural, de abajo arriba, **no funciona en este repositorio**: GitHub solo reapunta la base de una PR apilada a `main` cuando se **borra** la rama anterior, y aquí las ramas se conservan. Cada PR se mergea entonces en su base y no en `main`, así que solo llega la primera y el resto se queda en las ramas intermedias sin que nada avise.

Pasó con las cuatro PR de la Fase 4 (#8 a #11) y se resolvió con una PR de integración desde la rama que ya las contenía a todas. Antes de darlas por hechas:

```bash
git fetch origin
git log --oneline origin/main -5          # ¿está lo que crees que está?
git diff --stat origin/main origin/<rama-de-arriba>   # tiene que salir vacío
```

### Cambiar una decisión

Cambiar una regla no es editar el sitio donde la encontraste. Una decisión de este proyecto vive en varios archivos a la vez, y dejar uno atrás no rompe nada — solo hace que la documentación mienta, que es peor que no tenerla.

Cuando cambie una regla, recorre los cinco:

1. **`CLAUDE.md`** (este archivo) — el enunciado corto de la regla.
2. **`ESTADO.md`** — el enunciado largo, con el **porqué** y con qué sustituye. Una regla que cambia sin dejar rastro de por qué cambió se revierte sola en tres meses.
3. **El `CLAUDE.md` del módulo** afectado.
4. **`.claude/agents/architecture-reviewer.md`** — el que más se olvida. Si sus reglas se quedan viejas, **denuncia como violación justo lo que se acaba de decidir**. Ya pasó al añadir el token `expense`.
5. **Las maquetas y ejemplos** de `ESTADO.md` §6 y §8, y las galerías del design system. Son la referencia visual, y siguen enseñando lo viejo aunque el texto de al lado diga otra cosa.

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

**El esquema es `Keepworth-Workspace`, no `Keepworth`.** Tuist autogenera un esquema por target: el de `Keepworth` es el de la app y su acción de test está vacía, así que ejecuta cero tests sin avisar de ello. `Keepworth-Workspace` es el único que agrupa los ocho targets de test.

El `.xcodeproj` y el `.xcworkspace` son artefactos generados: no se editan a mano ni se versionan. Para añadir un módulo o cambiar dependencias se edita `Project.swift`.

**`tuist generate` no es opcional al crear o renombrar archivos.** La lista de archivos queda fijada en el `.xcodeproj`, así que un archivo nuevo no se compila y uno renombrado da `Build input file cannot be found`. El hook solo se dispara al tocar `Project.swift`; en los demás casos lo lanzas tú.

Los diagnósticos de SourceKit en el editor se quedan atrás hasta esa regeneración: `Cannot find 'X' in scope` sobre código recién escrito suele ser eso y no un error real. **Manda `tuist xcodebuild build`**, no el subrayado rojo.

`Tuist/Package.resolved` cambia su `originHash` al regenerar sin que se mueva ningún pin. Es ruido: fuera del commit salvo que cambie una versión de verdad.

### Antes de dar una fase por terminada

Además de build, tests y lint, dos comprobaciones que ninguna herramienta hace sola:

```bash
# cero colores literales fuera del design system
grep -rn -E 'Color\(red:|\.foregroundColor|Color\.(gray|black|white|red|blue|green|primary|secondary)|Divider\(\)|\.shadow\(' \
  --include='*.swift' Modules Apps | grep -v 'Sources/Tokens/Colors.swift'
```

Y pasar el agente `architecture-reviewer` sobre el diff. Encuentra cosas que el compilador no puede: duplicación real, una regla escrita en dos sitios con distinta letra, un test que no prueba lo que dice probar.

Los recuentos de tests se dicen en **casos ejecutados y por módulo**, nunca en atributos `@Test` del repositorio entero: los tests parametrizados hacen que las dos cifras no se parezcan.

---

## Estructura

```
Apps/Keepworth/            app target
Modules/Core/              Domain, Persistence, Sync, DesignSystem
Modules/Features/          una carpeta por pantalla, más FeatureSupport
Modules/KeepworthAppCore/  composition root: DI y navegación raíz
```

Aún no existe, y su target se declarará en `Project.swift` cuando toque:

```
Apps/KeepworthWidgets/     widget extension (Fase 7)
```

Cada módulo tiene `Sources/` y `Tests/`. `KeepworthDesignSystem` lleva además `Resources/` con el catálogo de tokens, y es el único: los recursos se declaran con `resourceGlobs:` en `Project.swift`, que por defecto está vacío porque un glob que no casa con nada hace fallar la generación.

Los módulos Core llevan su propio `CLAUDE.md` con el contrato de la capa: léelo antes de tocarlos.

## Tests

Swift Testing (`import Testing`, `@Test`, `#expect`), no XCTest.

`KeepworthDomain` es la capa donde se demuestran los invariantes contables: merece cobertura alta. Las features se testean con dobles en memoria de los protocolos de `Domain`, nunca contra una base de datos real.
