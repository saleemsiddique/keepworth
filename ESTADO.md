# Keepworth — Estado del proyecto y plan completo

> Documento de traspaso. Si abres una sesión de Claude Code en el Mac y no tienes contexto previo, **este archivo es el punto de partida**. Contiene el plan íntegro, las decisiones tomadas y por qué, lo que ya existe, lo que está sin verificar y los pasos siguientes.
>
> Las reglas de trabajo del día a día están en `CLAUDE.md` (raíz) y en el `CLAUDE.md` de cada módulo. Este documento explica el **porqué**; los `CLAUDE.md` imponen el **qué**.

Última actualización: 2026-08-04 — **Fase 0 verificada en el Mac**: proyecto generado, build y tests en verde, bundle ID definitivo fijado, hooks y agente revisor comprobados.

---

## 1. Qué es Keepworth

App iOS de **gestión de finanzas personales**, exclusiva para iOS.

**Local-only**: ningún dato de usuario sale del dispositivo salvo hacia el iCloud privado del propio usuario. No hay servidor propio, no hay cuentas de usuario, no hay registro. Más adelante existirá un backend, pero exclusivamente para datos **no personales** (tipos de cambio, históricos de APIs externas). Ese backend nunca recibirá información financiera de nadie.

Gratuita por ahora. Construida asumiendo escala real (millones de usuarios) y con la codebase optimizada para que agentes de IA escriban la mayor parte del código: módulos pequeños, capas con dependencias verificadas por herramienta, y tests como especificación ejecutable.

**Estética**: minimalista, inspirada en una terminal. La referencia visual completa está en un artefacto publicado:
https://claude.ai/code/artifact/fc6c746d-92e4-408e-bc33-32786328d709

(El artefacto usa el nombre provisional "WalletOS". El nombre definitivo es **Keepworth**.)

---

## 2. Estado actual

### Lo que existe

La **Fase 0 está verificada** (2026-08-04). Se había redactado desde una máquina Windows sin Xcode ni Tuist, así que hasta esa fecha ni una línea había sido compilada. Ya lo está: el proyecto genera, compila, los cinco tests placeholder pasan y el lint de formato sale limpio. Lo que falló y se corrigió está en la sección 3.

```
CLAUDE.md                                    reglas duras del proyecto
ESTADO.md                                    este archivo
Project.swift                                manifiesto de Tuist
Tuist/Package.swift                          dependencias externas (solo GRDB)
mise.toml                                    versiones de tuist y xcbeautify
.swift-format                                configuración de formato
.gitignore                                   con sección Tuist añadida

.claude/settings.json                        hooks
.claude/hooks/format-swift.sh                formatea Swift tras cada edición
.claude/hooks/regenerate-tuist.sh            regenera el proyecto al tocar Project.swift
.claude/agents/architecture-reviewer.md      agente auditor (model: opus)

.github/workflows/ci.yml                     build + test + lint en runner macOS

Apps/Keepworth/Sources/KeepworthApp.swift    @main
Apps/Keepworth/Keepworth.entitlements        App Group + CloudKit

Modules/Core/KeepworthDomain/                CLAUDE.md + placeholder + test
Modules/Core/KeepworthPersistence/           CLAUDE.md + placeholder + test
Modules/Core/KeepworthSync/                  CLAUDE.md + placeholder + test
Modules/Core/KeepworthDesignSystem/          CLAUDE.md + placeholder + test
Modules/KeepworthAppCore/                    CLAUDE.md + RootView + test
```

Los archivos `*Module.swift` de cada módulo Core son **andamiaje deliberado**: existen solo para que el target enlace y sea testeable desde la Fase 0. Se eliminan cuando el módulo tenga contenido real.

### Lo que no existe todavía

- `Modules/Features/` — se crea en la Fase 4.
- `Apps/KeepworthWidgets/` — se crea en la Fase 7. Se dejó fuera a propósito: declararlo ahora obligaría a escribir un `WidgetBundle` placeholder inservible.
- Skills en `.claude/skills/` — se extraen en la Fase 3.5, con ejemplos reales del repo. Escribirlas antes sería codificar procedimientos imaginados.

---

## 3. Arranque en el Mac

```bash
# 1. Herramientas
brew install mise
mise install                 # instala tuist y xcbeautify según mise.toml

# 2. Proyecto
tuist install                # resuelve GRDB
tuist generate --no-open     # genera Keepworth.xcworkspace

tuist xcodebuild build \
  -workspace Keepworth.xcworkspace \
  -scheme Keepworth-Workspace \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# 3. Tests
xcodebuild test \
  -workspace Keepworth.xcworkspace \
  -scheme Keepworth-Workspace \
  -destination 'platform=iOS Simulator,name=iPhone 17' | xcbeautify
```

`mise` necesita estar en el `PATH` del shell **no interactivo**, porque es el que ejecutan los hooks. Se resuelve con los shims, no con `mise activate`:

```bash
echo 'export PATH="$HOME/.local/share/mise/shims:$PATH"' >> ~/.zshrc
```

El `.xcodeproj` y el `.xcworkspace` son artefactos generados: no se editan a mano ni se versionan. Para añadir un módulo o cambiar dependencias se edita `Project.swift`.

### Qué se encontró al verificar (2026-08-04)

Resuelto todo salvo lo que se indica:

1. **Bundle ID fijado**: `com.saleemsiddique.keepworth`, con `group.com.saleemsiddique.keepworth` y `iCloud.com.saleemsiddique.keepworth`. **Pendiente y a cargo del usuario**: registrar los tres identificadores en el portal de Apple Developer. No bloquea el simulador; sí hace falta para dispositivo físico y para activar CloudKit en la Fase 9.

2. **El comando de test documentado no ejecutaba ni un test.** Tuist autogenera un esquema por target, y el del target `Keepworth` es el de la app: su `<Testables>` está vacío porque los cinco targets de test dependen de los frameworks, no de la app. El esquema correcto es **`Keepworth-Workspace`**. Estaba mal en `CLAUDE.md`, en este archivo y en el CI.

3. **`RootViewTests.swift` no compilaba.** En modo de lenguaje Swift 6, conformar a `View` aísla el inicializador al actor principal, así que el test necesita `@MainActor`. Aplica a cualquier test que construya una vista de aquí en adelante.

4. **`tuist build` está deprecado** en favor de `tuist xcodebuild build`. Documentado ya con la forma nueva.

5. **CI reescrito**: `runs-on: macos-26` (el proyecto apunta a iOS 26 y necesita ese SDK) y selección de Xcode con `maxim-lobanov/setup-xcode` en vez de `xcode-select -s /Applications/Xcode_26.app`, cuya ruta depende de la imagen del runner.

6. **`SWIFT_STRICT_CONCURRENCY: complete` eliminado de `Project.swift`**: el modo de lenguaje Swift 6 ya lo implica. **No es una relajación del ajuste**, es quitar una redundancia; `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` sigue puesto y el build sale limpio sin un solo warning.

7. **GRDB resuelve a 7.11.1** con el `from: "7.0.0"` existente. `Tuist/Package.resolved` se versiona para que el CI resuelva exactamente la misma versión que el Mac.

8. **Simulador**: `iPhone 17` existe en la instalación local (runtimes iOS 26.4 y 26.5). El `-destination` documentado es correcto.

9. **`.gitignore`**: confirmado antes del primer commit. `*.xcodeproj` y `*.xcworkspace` fuera de git es lo correcto con Tuist.

### Entorno de IA: verificado

- **Hook de formato**: se escribió un `.swift` con indentación de 6 y 8 espacios y quedó a 4 sin intervención.
- **Hook de regeneración**: el script es correcto y ejecuta `tuist install` + `tuist generate` al tocar `Project.swift`. Depende de que `tuist` esté en el `PATH` del shell no interactivo; sin los shims el hook avisa y sale sin hacer nada. El `mtime` del `.xcodeproj` **no** sirve como comprobación: la generación de Tuist es idempotente y no reescribe si el contenido no cambia.
- **Agente `architecture-reviewer`**: detectó un `import GRDB` en un archivo bajo `Modules/Features/`, y además el `DatabaseQueue` filtrado en la API pública. Hallazgo suyo que conviene retener: **un archivo bajo `Modules/Features/` sin target declarado en `Project.swift` esquiva la validación entera** — ni `tuist generate` ni el build lo ven. En la Fase 4, el target y sus `dependencies` se declaran en el mismo commit que el primer `.swift` de la feature.

---

## 4. Decisiones fijadas

Todas se cerraron con el usuario el 2026-07-31. No se revisan sin hablarlo.

| Área | Decisión | Por qué |
|---|---|---|
| Plataforma | iOS 26+, iPhone + iPad | Cero código de compatibilidad; menos superficie de bug y codebase más limpia para trabajo con IA |
| Nombre | Keepworth | Marca propia y registrable; evoca patrimonio, que es la pantalla principal |
| Proyecto | Tuist | Sin conflictos de `pbxproj` y los agentes pueden crear módulos sin abrir Xcode |
| Arquitectura | Clean Architecture estricta por capas | Máxima disciplina; las capas son verificables por herramienta |
| Persistencia | GRDB + partida doble | Control total sobre SQL y contabilidad que siempre cuadra |
| Divisas | Esquema multi-divisa desde el día 1, UI monodivisa en v1 | Coste casi cero ahora; añadirlo después no requiere migrar datos ni reescribir consultas. Monodivisa no es "solo euros": el usuario elige la suya al empezar y todas sus cuentas la comparten |
| Conversión | El valor en divisa base se **guarda**, no se calcula con un tipo de cambio | Demostrado con datos reales: multiplicar por un tipo descuadra los asientos y el invariante de suma cero se vuelve inalcanzable |
| Agrupación | Las cuentas se agrupan por **banco**, en tabla propia | Con seis o siete cuentas la lista plana deja de servir, y da el total por entidad. Un banco no guarda dinero: meterlo en `account` obligaría a inventar una cuenta que no es una cuenta |
| Orden de cuentas | Automático por saldo | El orden manual es justo lo que dos dispositivos cambian a la vez y acaba dando guerra con iCloud |
| Programados | Plantillas aparte; no tocan el patrimonio hasta su fecha | Un movimiento que aún no ha ocurrido es una previsión, no contabilidad |
| Movimientos con fecha futura | Un asiento cuenta en el patrimonio **solo si `occurred_on <= hoy`** | El usuario puede fechar un movimiento en el futuro aunque no sea una plantilla. Hasta que llega el día, el dinero sigue donde estaba |
| Dinero en tránsito | Sin cuenta puente: el traspaso se aplica entero según su fecha | Un traspaso entre bancos tarda días, pero modelarlo obligaría a un paso más en cada traspaso. Se resuelve con la fecha, que ya decide si el movimiento cuenta o no |
| Saldo inicial | La pantalla de crear cuenta lo pide **siempre** | Si no, el patrimonio está mal desde el primer minuto y el usuario no sabe por qué |
| Informe mensual | **Pantalla propia**, a un toque desde Resumen | Necesita cabecera con navegación entre periodos, y así Resumen conserva una sola cifra protagonista. No es una tercera tab: la regla de crecimiento se respeta |
| Periodo del informe | **Mes natural** por defecto, con **rango de fechas libre** a un toque | Se valoró un ciclo configurable ("mi mes empieza el 25") y se descartó: el día de cobro oscila —29 de julio, 27 de agosto—, así que un corte fijo encima de esa fecha mete dos nóminas en un periodo y ninguna en otro. Un ajuste permanente que todos ven y casi nadie necesita, para un desajuste que ocurre dos o tres veces al año. El rango libre lo resuelve donde ocurre y además sirve para unas vacaciones o un trimestre |
| Sync | CKSyncEngine a nivel de registro | Multi-dispositivo real con resolución de conflictos, sin servidor propio |
| Protección | Data Protection de iOS + Face ID al abrir | Cifrado por hardware sin dependencias ni riesgo de perder claves; el modelo de amenaza real es "alguien coge tu iPhone" |
| Dependencias | Solo GRDB aprobada | Cualquier otra se propone al usuario con alternativas; nunca se añade por iniciativa propia |
| Tests | Swift Testing + GitHub Actions | Es la única garantía objetiva de que el código generado funciona |
| Idiomas | Inglés y español desde v1 | Retrofitear traducciones sobre textos incrustados es carísimo |
| Telemetría | Solo informes anónimos de Apple | Un SDK de terceros contradiría el "local only" |
| Estética | Dirección "Ledger", acento verde fósforo, temas claro y oscuro | Definida en el artefacto de referencia |
| Alcance v1 | Bancos, cuentas, movimientos, categorías, import/export CSV | Mínimo que resulta genuinamente usable |
| Modelo de agentes | `model: opus` en `.claude/agents/` | Un falso negativo del revisor deja pasar justo el error que existe para atrapar |

### Qué significa "AI-First" aquí

El usuario lo definió como **codebase optimizada para agentes de IA**: módulos pequeños, contratos explícitos, `CLAUDE.md` por módulo, tests como especificación, convenciones estrictas.

**No** significa features de IA en el producto. Nada de categorización automática, entrada por lenguaje natural ni App Intents. Si surge la idea, es una conversación nueva, no una extensión de lo acordado.

---

## 5. Arquitectura

```
Apps/Keepworth/            app target
Modules/Core/              Domain, Persistence, Sync, DesignSystem
Modules/Features/          una carpeta por feature (Fase 4)
Modules/KeepworthAppCore/  composition root: DI y navegación raíz
Apps/KeepworthWidgets/     widget extension (Fase 7)
```

### Ley de dependencias

Se declara en `Project.swift` y Tuist la valida al generar.

| Módulo | Puede importar |
|---|---|
| `KeepworthDomain` | nada (ni GRDB, ni SwiftUI, ni CloudKit, ni UIKit) |
| `KeepworthPersistence` | `Domain` + GRDB |
| `KeepworthSync` | `Domain` + `Persistence` + CloudKit |
| `KeepworthDesignSystem` | SwiftUI únicamente |
| `Feature*` | `Domain` + `DesignSystem` |
| `KeepworthAppCore` | todos |

**La regla crítica: ninguna feature importa `Persistence`, `Sync` ni GRDB.** Las features hablan con protocolos declarados en `Domain`; `AppCore` es el único lugar donde se instancian implementaciones concretas.

Esto es lo que permite testear cada feature con dobles en memoria, y lo que impide que un agente acople una pantalla a la base de datos sin que nadie lo note. Es una violación que **no rompe el build**: solo pudre el diseño en silencio. Por eso existe el agente `architecture-reviewer`.

Excepción única y documentada: el widget sí depende de `Persistence`, porque lee la base de datos compartida por App Group.

Si una feature necesita algo que no está en los protocolos de `Domain`, la solución es **ampliar el protocolo**, no importar `Persistence`.

---

## 6. Modelo de datos

Contabilidad por **partida doble**: todo movimiento **sale de un sitio y entra en otro**, y las dos patas suman cero. Un gasto no es un número negativo suelto.

Cada "sitio" es una fila de `account`, y su `kind` determina cómo se comporta:

| `kind` | Qué es para el usuario | ¿Patrimonio? | ¿Banco? |
|---|---|---|---|
| `asset` | Cuentas bancarias, efectivo, carteras | Suma | Opcional |
| `liability` | Tarjetas de crédito, préstamos | Resta | Opcional |
| `expense` | Categorías de gasto | **Nunca** | Nunca |
| `income` | Categorías de ingreso | **Nunca** | Nunca |
| `equity` | Saldo inicial (interna, oculta) | Nunca | Nunca |

**El patrimonio neto es exclusivamente `asset` + `liability`.** Las categorías no lo tocan jamás: el patrimonio baja porque baja el saldo de una cuenta real, no porque exista una categoría. El "saldo" de una cuenta `expense` no es un saldo, es **cuánto ha pasado por ahí**.

Que las categorías compartan tabla con las cuentas es fontanería, no un concepto de producto: hace que gasto, ingreso y traspaso sean **la misma operación** y elimina una tabla redundante. La UI nunca las mezcla — Resumen muestra cuentas agrupadas por banco, y el editor muestra un selector de cuenta y otro de categoría.

**Los bancos son tabla propia.** Un banco no guarda dinero ni recibe movimientos: solo agrupa cuentas y da un total por entidad. Meterlo en `account` obligaría a inventar una cuenta que no es una cuenta.

### Tablas

```sql
institution(                        -- BBVA, Trade Republic, MyInvestor
  id TEXT PRIMARY KEY,              -- UUID, nunca autoincremental (requisito de sync)
  name TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT                   -- soft delete: tombstones obligatorios para sync
)

account(
  id TEXT PRIMARY KEY,
  institution_id TEXT REFERENCES institution(id),  -- NULL en efectivo y en toda categoría
  name TEXT NOT NULL,
  kind TEXT NOT NULL,               -- asset | liability | income | expense | equity
  currency_code TEXT NOT NULL,      -- ISO 4217
  symbol_name TEXT,                 -- SF Symbol
  is_system INTEGER NOT NULL DEFAULT 0,   -- 1 solo en «Saldo inicial»: ni se borra ni se renombra
  is_archived INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  CHECK (kind IN ('asset','liability','income','expense','equity')),
  CHECK (institution_id IS NULL OR kind IN ('asset','liability'))
)

entry(
  id TEXT PRIMARY KEY,
  occurred_on TEXT NOT NULL,        -- fecha sin hora
  payee TEXT,                       -- "Mercadona"
  note TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
)

entry_line(
  id TEXT PRIMARY KEY,
  entry_id TEXT NOT NULL REFERENCES entry(id),
  account_id TEXT NOT NULL REFERENCES account(id),
  amount_minor INTEGER NOT NULL,        -- lo que se movió, en la divisa de la cuenta
  currency_code TEXT NOT NULL,          -- la divisa de esa cuenta
  base_amount_minor INTEGER NOT NULL,   -- lo que valió en divisa base. En v1 == amount_minor
  sort_order INTEGER NOT NULL DEFAULT 0,  -- con 3+ líneas, cuál es el origen deja de deducirse
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
)

app_setting(                        -- preferencias sincronizables
  key TEXT PRIMARY KEY,             -- base_currency_code, ...
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
```

Una línea solo cuenta si **ni ella ni su asiento** están borrados. Olvidar la segunda condición es el error silencioso más probable del esquema, así que se resuelve una vez en una vista y las consultas van siempre contra ella:

```sql
CREATE VIEW live_entry_line AS
SELECT entry_line.*, entry.occurred_on
FROM entry_line
JOIN entry ON entry.id = entry_line.entry_id
WHERE entry_line.deleted_at IS NULL AND entry.deleted_at IS NULL;
```

Índices parciales, porque la app solo consulta filas vivas: `entry_line(entry_id)`, `entry_line(account_id)`, `entry(occurred_on)`, `account(kind)`, `account(institution_id)`, todos con `WHERE deleted_at IS NULL`.

### Cómo se ve cada movimiento

```
GASTO — Mercadona, 42,30 €              TRASPASO entre tus cuentas
   BBVA · Nómina        −42,30             BBVA · Nómina       −500,00
   Supermercado         +42,30             TR · Remunerada     +500,00
   → el patrimonio baja 42,30              → el patrimonio no se mueve

INGRESO — Nómina                        PAGO CON TARJETA DE CRÉDITO
   BBVA · Nómina     +2.100,00             Visa                 −60,00
   Nómina            −2.100,00             Transporte           +60,00
   → el patrimonio sube 2.100              → la deuda crece; el patrimonio baja 60
```

Siempre la misma estructura. Lo único que cambia es el `kind` de las cuentas de cada lado.

### Invariantes

Garantizados en `KeepworthDomain` y cubiertos por tests:

1. La suma de `base_amount_minor` de un asiento es **exactamente cero**. Siempre, con una divisa o con cinco.
2. Todo asiento tiene **al menos dos líneas**.
3. Los importes son `Int64` en unidades menores. **Un `Double` en el dominio monetario es un bug**, incluso "solo para mostrar".
4. **Ninguna fila se borra físicamente**: se marca `deleted_at`. Sin tombstone, el registro reaparece en el siguiente sync.
5. Una cuenta `expense`, `income` o `equity` **nunca** tiene `institution_id`.
6. `base_amount_minor` está en la divisa base **de todas** las líneas del asiento. En v1 es igual a `amount_minor`.

### Por qué el valor en divisa base se guarda y no se calcula

Es la corrección de diseño más importante de esta sesión, y se demostró ejecutando el esquema con datos reales.

El diseño anterior guardaba un tipo de cambio por línea y multiplicaba. Con un tipo de 1 USD = 0,923456 €, una compra de 123,45 USD deja **1,06 céntimos de descuadre** que ningún redondeo elimina, y arrastra el patrimonio neto a un número no entero de céntimos. El invariante de suma cero se vuelve inalcanzable.

El diseño actual guarda `base_amount_minor` como **dato**, no como cálculo: son los euros que realmente salieron de tu cuenta, y tu banco te los cobró exactos. No hay nada que redondear.

```
COMPRA DE 0,5 BTC                       VENTA POR 35.000 €
   BBVA        −30.000,00 €                Cartera BTC   −0,5 BTC   base −30.000,00
   Cartera BTC     +0,5 BTC                BBVA        +35.000,00   base +35.000,00
   base: −30.000 / +30.000  = 0            Ganancias                base  −5.000,00
                                           suma en base = 0
```

Al vender algo revalorizado hace falta una **tercera línea** con la diferencia, y cae sola en una categoría de ingreso: son tus ganancias, que es justo lo que quieres ver.

Consecuencia práctica: **las consultas usan `base_amount_minor` desde el día uno**. Patrimonio, saldos e informes quedan escritos de la forma definitiva, así que activar multi-divisa no migrará datos ni reescribirá consultas — solo faltará la pantalla para elegir divisa por cuenta.

### Derivaciones

Son consultas, no columnas almacenadas:

- **Saldo de cuenta** = suma de `amount_minor` de sus líneas vivas, en la divisa de la cuenta.
- **Total de un banco** = suma de `base_amount_minor` de las líneas de sus cuentas.
- **Patrimonio neto** = suma de `base_amount_minor` de las líneas de cuentas `asset` y `liability` con `occurred_on <= hoy`. Nada más entra aquí. El filtro de fecha no es opcional: sin él, un movimiento fechado en el futuro descuadra el patrimonio de hoy.
- **Informe de un periodo** = líneas vivas entre dos fechas, agrupadas por cuenta y separando `expense` de `income`. El caso de uso recibe un rango arbitrario; que la pantalla abra en el mes en curso es una decisión de la UI, no del dominio.

El informe mensual y el patrimonio son dos vistas de los mismos datos, así que **no pueden contradecirse**: si en enero ingresaste 2.100 y gastaste 877,30, tu patrimonio subió 1.222,70 exactos. Esa garantía es la razón de ser de la partida doble, y una lista plana de movimientos no la da.

Los traspasos no aparecen en el informe sin necesidad de excluirlos: sus dos patas son cuentas de dinero, y el informe solo mira `expense` e `income`.

El saldo inicial de una cuenta tampoco contamina el informe: su contrapartida es `equity`, no `income`.

### Reglas de esquema

- La base de datos vive en el contenedor del **App Group**, no en Documents: el widget necesita leerla.
- `DatabasePool`, no `DatabaseQueue`: hay lecturas concurrentes desde el widget.
- Protección de fichero **`.completeUntilFirstUserAuthentication`**. No usar `.complete`: impediría al widget leer con el dispositivo bloqueado.
- `PRAGMA foreign_keys = ON`. No es el valor por defecto de SQLite.
- Cada cambio de esquema es una migración nueva y versionada. **Una migración publicada no se edita jamás**, ni para corregir un typo.

### Reglas de borrado

- **Categoría o cuenta sin movimientos**: se borra.
- **Categoría o cuenta con movimientos**: solo se **archiva**. Desaparece del editor pero sigue en el histórico. Borrarla dejaría movimientos huérfanos.
- **Banco con cuentas vivas**: no se borra. Primero se archivan o se mueven sus cuentas.
- La cuenta `is_system` («Saldo inicial») no se borra ni se renombra: es lo que hace que los números cuadren.

### Semilla del primer arranque

Una cuenta de dinero: **Efectivo** (sin banco).

Categorías de gasto: **Supermercado, Restaurantes, Transporte, Vivienda, Suministros, Salud, Ocio, Compras, Suscripciones**.

Categorías de ingreso: **Nómina, Intereses, Otros ingresos**.

Y la cuenta interna **Saldo inicial** (`equity`, `is_system = 1`, oculta de toda lista).

Deliberadamente **no** hay categoría "Otros" en gastos: el cajón de sastre se traga justo lo que querías entender, y quien la quiera se la crea en diez segundos.

Las categorías se crean con el nombre en el idioma del sistema y **son del usuario desde ese momento**: si luego cambia el idioma del dispositivo, no se retraducen. La alternativa —marcarlas como "del sistema" y traducirlas al vuelo— obliga a arrastrar un caso especial por todo el código y se rompe igual en cuanto el usuario renombra una.

### Preparado para lo que viene

Decisiones ya tomadas que **no** se implementan ahora, anotadas para que nadie las reinvente:

- **Multi-divisa**: el esquema y las consultas ya lo soportan. Lo que falta es de UI: elegir divisa al crear una cuenta, y pedir el importe en las dos divisas al registrar un movimiento entre ellas. Cero migración de datos.
- **Movimientos programados**: tabla de plantillas aparte. Un movimiento programado **no toca el patrimonio hasta que llega su fecha**; hasta entonces es una previsión, no contabilidad.
- **Metadatos de CloudKit**: `CKSyncEngine` necesita conservar los *system fields* de cada `CKRecord`. Irán en una tabla `sync_metadata` aparte, no en columnas de las tablas de datos, para que el modelo de dominio no cargue con detalles de transporte.
- **Carteras de inversión**: en v1 son cuentas `asset` cuyo valor actualiza el usuario a mano, con la subida o bajada registrada contra una categoría de ingreso. La valoración automática necesita el backend.

---

## 7. Design System

Los seis tokens, definidos como Color Sets con variante clara y oscura. **Ninguna feature usa un color literal ni un color del sistema.**

| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| `bg` | `#F7F7F5` | `#000000` | Fondo. Negro OLED puro en oscuro |
| `surface` | `#FFFFFF` | `#0D0D0C` | Solo sheets |
| `ink` | `#141413` | `#F2F2EF` | Texto principal |
| `inkSoft` | `#6E6E69` | `#8A8A85` | Texto secundario y metadatos |
| `hairline` | `#E2E2DC` | `#232322` | Separadores de 0,5 pt |
| `accent` | `#1E9E5A` | `#30D158` | Fósforo |

**Regla del acento**: el verde aparece únicamente en elementos interactivos y en dinero que **entra**. Los gastos van en `ink`. **Nunca rojo** — la app no regaña al usuario.

### Tipografía

Dos voces, ambas del sistema. Cero assets, cero licencias, cero peso.

- **Importes**: SF Mono semibold con `.monospacedDigit()`, para que los dígitos no bailen al actualizarse.
- **Títulos y texto**: SF Pro.
- **Metadatos y etiquetas**: SF Pro 11–13 pt, mayúsculas, tracking amplio.

### Contrato de cada pantalla

1. **Una acción primaria por pantalla.** El resto vive en gestos nativos: swipe, long-press, tirar para cerrar.
2. **El número es el protagonista**: cada pantalla se resume en una cifra grande arriba.
3. **Espacio en vez de cajas**: sin tarjetas ni sombras. La jerarquía se construye con espacio en blanco y hairlines de 0,5 pt.
4. **Color = significado**, nunca decoración.
5. **Estados vacíos de una línea**: "Sin movimientos. Añade el primero." Sin ilustraciones.

### Acabado

`contentTransition(.numericText())` en las cifras grandes · SF Symbols en peso `.light`, monocromos y pequeños · un único haptic ligero al guardar · tap en el patrimonio lo oculta con `redacted`.

### Componentes a construir

`LedgerRow`, `HeadlineAmount`, `SectionCaption`, `Hairline`, `PrimaryAction`, `EmptyStateLine`, `LedgerTabBar`.

Cada uno con previews en **ambos temas**. Si un componente nuevo no aparece en la galería de previews, no está terminado.

---

## 8. Navegación

Dos destinos en la barra inferior con el botón de añadir en el **centro exacto**, y Ajustes como icono en la toolbar superior.

```
┌─────────────────────┐
│                   ⚙ │
│ PATRIMONIO          │
│ 24.560,80 €         │
│ ▲ +1,2 % este mes   │
│ ─────────────────── │
│ BBVA      20.500,00 │
│   Nómina   1.200,00 │
│   Remuner 19.300,00 │
│ TRADE R.   4.060,80 │
│   Remuner  1.060,80 │
│   Cartera  3.000,00 │
│ ─────────────────── │
│ ESTE MES            │
│ Gastado     937,30  │
│ Ahorrado  1.162,70 ›│
│ ─────────────────── │
│ RECIENTE            │
│ Mercadona   −42,30  │
├─────────────────────┤
│ Resumen  ⊕  Movim.  │
└─────────────────────┘
```

Al tocar el bloque «Este mes» se empuja el informe, que es una pantalla de detalle y no un destino de la barra:

```
┌─────────────────────┐
│ ‹ Enero 2026 ›    ≡ │
│ ─────────────────── │
│ INGRESOS  2.100,00  │
│   Nómina  2.100,00  │
│ ─────────────────── │
│ GASTOS      937,30  │
│   Vivienda  800,00  │
│   Transporte 60,00  │
│   Supermerc. 42,30  │
│   Restaur.   35,00  │
│ ─────────────────── │
│ AHORRADO  1.162,70  │
└─────────────────────┘
```

El informe y el patrimonio no pueden contradecirse: lo ahorrado en el periodo es exactamente lo que varió el patrimonio en él.

Abre en el mes en curso y las flechas van al anterior y al siguiente. El icono `≡` abre un selector de dos fechas para cualquier rango: el tramo entre dos nóminas que cayeron raras, unas vacaciones, un trimestre. Con un rango libre el título es el rango; con un mes natural, el nombre del mes.

Esto sustituye a un ciclo configurable tipo "mi mes empieza el 25", que se valoró y se descartó por lo explicado en la sección 4.

- **Resumen** — patrimonio neto grande, cuentas agrupadas por banco con el total de cada entidad, movimientos recientes. Las cuentas sin banco (efectivo) van sueltas al final. Bancos ordenados por total y cuentas por saldo, sin orden manual.
- **⊕** — abre el editor de movimiento como sheet con detents. Único elemento con color de acento en la barra.
- **Movimientos** — lista completa, buscable y filtrable por cuenta, categoría y fecha.
- **⚙ Ajustes** — categorías, gestión de cuentas, import/export, apariencia, privacidad, iCloud.

### Regla de crecimiento

Existe para no reorganizar la navegación en v2:

| Funcionalidad futura | Dónde vive |
|---|---|
| Presupuestos | sección del scroll de Resumen |
| Metas de ahorro | sección del scroll de Resumen |
| Filtrar y buscar | filtros aplicados en Movimientos |
| Programados | filtro "programadas" en Movimientos, alimentado por la tabla de plantillas |
| Categorías y bancos | Ajustes |
| Informe mensual | pantalla de detalle empujada desde Resumen |

**Nunca se añade una tercera tab.** Si algo no encuentra sitio bajo esta regla, se discute con el usuario antes de tocar la navegación.

---

## 9. Fases

Cada fase termina compilando, con sus tests en verde y en CI. No se empieza una fase con la anterior a medias.

### Fase 0 — Bootstrap del proyecto y del entorno de IA — **verificada (2026-08-04)**

*Proyecto*: Tuist, `Project.swift` con targets y ley de dependencias, bundle ID, App Group, entitlements de CloudKit, workflow de CI, un test trivial por módulo.

*Entorno de IA*: `CLAUDE.md` raíz y por módulo Core, hook de formato Swift, hook de regeneración de Tuist, agente `architecture-reviewer`.

Proyecto generado, build en verde, los cinco tests placeholder pasando, lint limpio y los tres criterios del entorno de IA comprobados. Lo que falló durante la verificación y cómo se corrigió está en la sección 3.

### Fase 1 — Dominio

`Money`, `CurrencyCode`, `Institution`, `Account`, `AccountKind`, `Entry`, `EntryLine` y las reglas de balance. Protocolos `InstitutionRepository`, `AccountRepository` y `EntryRepository`. Casos de uso: `RecordExpense`, `RecordIncome`, `TransferBetweenAccounts`, `CalculateNetWorth`, `CalculateAccountBalance`, `CalculateInstitutionTotal`, `SummarizePeriod`.

Cero dependencias externas, cobertura alta: es la capa donde los invariantes contables se demuestran. Aquí un bug es dinero mal contado.

Eliminar `DomainModule.swift` al empezar.

### Fase 2 — Persistencia

Conexión GRDB con `DatabasePool` en el App Group y la protección de fichero indicada arriba. Migraciones versionadas desde el inicio. Records GRDB e implementación de los repositorios, **sin exponer tipos de GRDB en la API pública**. Semilla del primer arranque tal como está definida en la sección 6. Tests contra base de datos en memoria.

### Fase 3 — Design System

Tokens, tipografía, componentes y una galería de previews que sirva de referencia visual y de verificación rápida en ambos temas.

### Fase 3.5 — Extracción de skills

**Punto de parada deliberado.** Con dominio, persistencia y design system construidos, los patrones que se repiten son observables en lugar de imaginados. Se extraen las skills citando archivos reales del repo:

- declarar un módulo nuevo en `Project.swift`
- añadir una migración GRDB
- crear una feature con su modelo observable y sus previews
- añadir un componente al design system

Y se endurece el `CLAUDE.md` raíz con lo que haya fallado en las fases 1 a 3.

### Fase 4 — Resumen y Movimientos

`FeatureSummary` y `FeatureTransactions` con SwiftUI y `@Observable`, más la pantalla de informe que se empuja desde Resumen. Barra inferior con ⊕ centrado y Ajustes en toolbar. Observación reactiva con `ValueObservation` de GRDB para que la UI se refresque sola. **Localización EN/ES desde la primera cadena**, sin textos incrustados.

### Fase 5 — Editor de movimiento

Sheet con detents. Teclado numérico, selección de cuenta y categoría, fecha y beneficiario. Traduce la entrada simple del usuario en un asiento equilibrado de dos líneas. Es la pantalla de mayor uso de toda la app: merece pulido específico.

### Fase 6 — Import / Export CSV

Export completo y import desde CSV con mapeo de columnas y previsualización antes de confirmar. En una app local-only es la garantía de que los datos son del usuario y son portables.

### Fase 7 — Privacidad y widget

Face ID al abrir, ocultación del contenido en el selector de apps, tap para redactar el patrimonio. Widget de pantalla de inicio leyendo la base de datos compartida por App Group. Aquí se declara el target `KeepworthWidgets` en `Project.swift`.

### Fase 8 — iPad

Adaptación de layout de las pantallas existentes. Se hace **después** de que el iPhone esté cerrado, para no revisar dos veces cada diseño.

### Fase 9 — Sync con iCloud

`CKSyncEngine` con mapeo `Entry`/`EntryLine`/`Account` ↔ `CKRecord`, cola de cambios pendientes, tombstones y resolución de conflictos por `updated_at` a nivel de registro.

Es la fase de mayor riesgo técnico y por eso va al final, sobre un esquema que ya nació preparado para ella.

Reglas: el sync es **offline-first** (los cambios se aplican en local primero, la UI nunca espera a la red); un fallo de red no es un error de usuario, se reintenta sin alertas; y un `Entry` con sus `EntryLine` se sube y aplica **junto**, porque un asiento a medio sincronizar es un asiento descuadrado.

---

## 10. Verificación

```bash
tuist install
tuist generate --no-open

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

Criterios de aceptación por fase:

- **Entorno de IA** — editar un `.swift` deja el archivo formateado sin intervención; tocar `Project.swift` regenera el proyecto; el agente revisor detecta un `import GRDB` introducido a propósito dentro de una feature.
- **Dominio** — un asiento cuyas líneas no suman cero es rechazado con error; un asiento de una sola línea es rechazado; sumar `Money` de divisas distintas falla en vez de aproximar; una cuenta de gasto o ingreso con banco es rechazada; el patrimonio neto es correcto mezclando activo y pasivo, y **no varía** al crear, renombrar o archivar una categoría; el informe del mes y la variación del patrimonio en ese mes coinciden al céntimo.
- **Persistencia** — crear, editar y borrar cuentas y movimientos sobre base de datos en memoria; el borrado marca `deleted_at` y la fila deja de aparecer en las consultas; las migraciones aplican en orden sobre una base vacía y sobre una con datos; los saldos derivados coinciden con la suma de líneas.
- **UI** — galería de previews revisada en tema claro y oscuro; recorrido manual en simulador de crear cuenta → registrar gasto → verlo en Resumen y en Movimientos → editarlo → borrarlo, con el patrimonio actualizándose en cada paso.
- **Import/Export** — exportar, borrar la base de datos, reimportar, y comprobar que el patrimonio y el número de movimientos coinciden exactamente.
- **Sync** — dos simuladores con la misma cuenta de iCloud; un cambio en uno aparece en el otro; editar el mismo movimiento en ambos resuelve sin duplicar ni perder datos.
- **CI** — verde en cada push. Un cambio que rompa la ley de dependencias entre módulos debe fallar en `tuist generate`.

---

## 11. Puntos abiertos

No bloquean nada, pero hay que resolverlos cuando toque:

- **Registro de identificadores en Apple Developer**: el bundle ID ya está fijado (`com.saleemsiddique.keepworth`), pero el App Group y el contenedor de CloudKit hay que darlos de alta en el portal. Necesario para dispositivo físico y para la Fase 9; el simulador no lo pide.
- **Team ID**: no hay `DEVELOPMENT_TEAM` en `Project.swift`. En simulador la firma ad-hoc basta; al instalar en un iPhone habrá que añadirlo.
- **Divisa base del usuario**: se elige en el primer arranque y se guarda en `app_setting`. La UI multi-divisa llega después de la v1.
- **Fuente de tipos de cambio**: hasta que exista el backend, introducción manual.
- **Backend futuro**: solo datos no personales. Cuando llegue el momento, es una conversación nueva.

### Abiertos desde la sesión del modelo de datos

- **Formato del CSV** (Fase 6): un asiento tiene dos o más líneas y una fila de CSV es plana. Hay que decidir si cada fila es una línea (fiel pero ilegible para un humano) o cada fila es un movimiento con columnas de origen y destino (legible, pero no representa asientos de tres o más líneas). Afecta al import tanto como al export. **Aplazado a la Fase 6 por decisión del usuario.**

---

## 12. Cómo trabajar en este proyecto

- **Responder siempre en español.**
- **No tomar decisiones de arquitectura en solitario**: presentar pros y contras, y esperar decisión del usuario.
- **No añadir features, refactors ni mejoras no pedidas.** Sugerirlas si procede.
- Preguntar ante cualquier ambigüedad antes de empezar.
- Los subagentes de este proyecto usan `model: opus`.
- Ejecutar los tests relevantes tras cada cambio e incluir el comando concreto de verificación en la respuesta.
- Si detectas un bug en código no relacionado con la tarea, menciónalo brevemente pero no lo arregles sin instrucción explícita.
