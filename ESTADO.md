# Keepworth — Estado del proyecto y plan completo

> Documento de traspaso. Si abres una sesión de Claude Code en el Mac y no tienes contexto previo, **este archivo es el punto de partida**. Contiene el plan íntegro, las decisiones tomadas y por qué, lo que ya existe, lo que está sin verificar y los pasos siguientes.
>
> Las reglas de trabajo del día a día están en `CLAUDE.md` (raíz) y en el `CLAUDE.md` de cada módulo. Este documento explica el **porqué**; los `CLAUDE.md` imponen el **qué**.

Última actualización: 2026-07-31.

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

La **Fase 0 está escrita pero no verificada**. Se redactó desde una máquina Windows, donde no hay Xcode ni Tuist, así que ni una línea ha sido compilada, formateada ni ejecutada.

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
tuist generate               # genera Keepworth.xcworkspace
tuist build

# 3. Tests
xcodebuild test \
  -workspace Keepworth.xcworkspace \
  -scheme Keepworth \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

El `.xcodeproj` y el `.xcworkspace` son artefactos generados: no se editan a mano ni se versionan. Para añadir un módulo o cambiar dependencias se edita `Project.swift`.

### Puntos a corregir o confirmar en el primer arranque

Ordenados por probabilidad de dar problemas:

1. **`bundleIdPrefix` en `Project.swift`** está como `com.keepworth`, un placeholder. Al fijarlo hay que cambiarlo también en `Apps/Keepworth/Keepworth.entitlements`, donde aparecen el App Group `group.com.keepworth` y el contenedor `iCloud.com.keepworth`. Ambos hay que registrarlos en el portal de Apple Developer (la cuenta de pago está activa).

2. **Versión de GRDB**: `Tuist/Package.swift` pide `from: "7.0.0"`. Comprobar cuál es la versión actual y si la API asumida en las fases siguientes coincide.

3. **Xcode en el CI**: `.github/workflows/ci.yml` hace `xcode-select -s /Applications/Xcode_26.app`. El nombre exacto depende de la imagen del runner de GitHub. Si falla, `ls /Applications | grep Xcode` en un paso temporal dice qué hay disponible.

4. **`SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`** combinado con `SWIFT_STRICT_CONCURRENCY: complete` es deliberadamente severo. Si el primer build se ahoga en warnings de concurrencia procedentes de GRDB, hay dos salidas —arreglarlos o relajar el ajuste— y **la decisión es del usuario**, no se toma sola.

5. **Simulador**: `iPhone 17` puede no existir en la instalación local. Ajustar el `-destination`.

6. **`.gitignore`**: se añadió `*.xcodeproj` y `*.xcworkspace`. Es lo correcto con Tuist, pero conviene confirmarlo antes del primer commit: revertirlo después de haber versionado un proyecto generado es molesto.

### Verificar que el entorno de IA funciona

- Editar cualquier `.swift` y comprobar que queda formateado sin intervención. Si no, `xcrun --find swift-format` dirá si la herramienta está disponible (requiere Xcode 16+).
- Tocar `Project.swift` y comprobar que el proyecto se regenera solo.
- Lanzar el agente `architecture-reviewer` sobre un `import GRDB` introducido a propósito en una feature y comprobar que lo detecta.

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
| Divisas | Esquema multi-divisa desde el día 1, UI monodivisa en v1 | Coste casi cero ahora; añadirlo después no requiere migrar datos de usuario |
| Sync | CKSyncEngine a nivel de registro | Multi-dispositivo real con resolución de conflictos, sin servidor propio |
| Protección | Data Protection de iOS + Face ID al abrir | Cifrado por hardware sin dependencias ni riesgo de perder claves; el modelo de amenaza real es "alguien coge tu iPhone" |
| Dependencias | Solo GRDB aprobada | Cualquier otra se propone al usuario con alternativas; nunca se añade por iniciativa propia |
| Tests | Swift Testing + GitHub Actions | Es la única garantía objetiva de que el código generado funciona |
| Idiomas | Inglés y español desde v1 | Retrofitear traducciones sobre textos incrustados es carísimo |
| Telemetría | Solo informes anónimos de Apple | Un SDK de terceros contradiría el "local only" |
| Estética | Dirección "Ledger", acento verde fósforo, temas claro y oscuro | Definida en el artefacto de referencia |
| Alcance v1 | Cuentas, movimientos, categorías simples, import/export CSV | Mínimo que resulta genuinamente usable |
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

Contabilidad por **partida doble**: todo movimiento es un asiento cuyas líneas suman cero. Un gasto no es un número negativo suelto, es una transferencia de una cuenta de activo a una cuenta de gasto.

**Decisión clave: las categorías son cuentas** de tipo `expense` / `income`. Esto elimina una tabla redundante y hace que gastos, ingresos y transferencias sean exactamente la misma operación. La UI las presenta como "categorías"; el ledger las trata como cuentas.

```sql
account(
  id TEXT PRIMARY KEY,              -- UUID, nunca autoincremental (requisito de sync)
  name TEXT NOT NULL,
  kind TEXT NOT NULL,               -- asset | liability | income | expense | equity
  currency_code TEXT NOT NULL,      -- ISO 4217
  symbol_name TEXT,                 -- SF Symbol
  sort_order INTEGER NOT NULL,
  is_archived INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT                   -- soft delete: tombstones obligatorios para sync
)

entry(
  id TEXT PRIMARY KEY,
  occurred_on TEXT NOT NULL,
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
  amount_minor INTEGER NOT NULL,    -- unidades menores (céntimos). NUNCA Double
  currency_code TEXT NOT NULL,
  rate_to_base INTEGER NOT NULL,    -- tipo de cambio en punto fijo; 1:1 = 1_000_000
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
)
```

Gasto de 42,30 € en Mercadona:

| línea | cuenta | tipo | amount_minor |
|---|---|---|---|
| 1 | BBVA | asset | −4230 |
| 2 | Comida | expense | +4230 |

### Invariantes

Garantizados en `KeepworthDomain` y cubiertos por tests:

1. La suma de `amount_minor × rate_to_base` de un asiento es **exactamente cero** en divisa base.
2. Todo asiento tiene **al menos dos líneas**.
3. Los importes son `Int64` en unidades menores. **Un `Double` en el dominio monetario es un bug**, incluso "solo para mostrar".
4. **Ninguna fila se borra físicamente**: se marca `deleted_at`. Sin tombstone, el registro reaparece en el siguiente sync.

### Derivaciones

Son consultas, no columnas almacenadas:

- Saldo de cuenta = suma de sus líneas vivas.
- Patrimonio neto = saldos `asset` − saldos `liability`.
- Gasto por categoría = suma de líneas en cuentas `expense` en el rango de fechas.

### Reglas de esquema

- La base de datos vive en el contenedor del **App Group**, no en Documents: el widget necesita leerla.
- `DatabasePool`, no `DatabaseQueue`: hay lecturas concurrentes desde el widget.
- Protección de fichero **`.completeUntilFirstUserAuthentication`**. No usar `.complete`: impediría al widget leer con el dispositivo bloqueado.
- Cada cambio de esquema es una migración nueva y versionada. **Una migración publicada no se edita jamás**, ni para corregir un typo.

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
│ BBVA      12.480,00 │
│ Santander  8.020,50 │
│ ─────────────────── │
│ RECIENTE            │
│ Mercadona   −42,30  │
├─────────────────────┤
│ Resumen  ⊕  Movim.  │
└─────────────────────┘
```

- **Resumen** — patrimonio neto grande, lista de cuentas, movimientos recientes.
- **⊕** — abre el editor de movimiento como sheet con detents. Único elemento con color de acento en la barra.
- **Movimientos** — lista completa, buscable y filtrable por cuenta, categoría y fecha.
- **⚙ Ajustes** — categorías, gestión de cuentas, import/export, apariencia, privacidad, iCloud.

### Regla de crecimiento

Existe para no reorganizar la navegación en v2:

| Funcionalidad futura | Dónde vive |
|---|---|
| Presupuestos | sección del scroll de Resumen |
| Metas de ahorro | sección del scroll de Resumen |
| Informes | filtros aplicados en Movimientos |
| Recurrentes | filtro "programadas" en Movimientos |
| Categorías | Ajustes |

**Nunca se añade una tercera tab.** Si algo no encuentra sitio bajo esta regla, se discute con el usuario antes de tocar la navegación.

---

## 9. Fases

Cada fase termina compilando, con sus tests en verde y en CI. No se empieza una fase con la anterior a medias.

### Fase 0 — Bootstrap del proyecto y del entorno de IA — *escrita, sin verificar*

*Proyecto*: Tuist, `Project.swift` con targets y ley de dependencias, bundle ID, App Group, entitlements de CloudKit, workflow de CI, un test trivial por módulo.

*Entorno de IA*: `CLAUDE.md` raíz y por módulo Core, hook de formato Swift, hook de regeneración de Tuist, agente `architecture-reviewer`.

**Queda pendiente**: ejecutar todo en el Mac y corregir lo que falle (ver sección 3).

### Fase 1 — Dominio

`Money`, `CurrencyCode`, `Account`, `AccountKind`, `Entry`, `EntryLine` y las reglas de balance. Protocolos `AccountRepository` y `EntryRepository`. Casos de uso: `RecordExpense`, `RecordIncome`, `TransferBetweenAccounts`, `CalculateNetWorth`, `CalculateAccountBalance`, `SummarizeSpendingByCategory`.

Cero dependencias externas, cobertura alta: es la capa donde los invariantes contables se demuestran. Aquí un bug es dinero mal contado.

Eliminar `DomainModule.swift` al empezar.

### Fase 2 — Persistencia

Conexión GRDB con `DatabasePool` en el App Group y la protección de fichero indicada arriba. Migraciones versionadas desde el inicio. Records GRDB e implementación de los repositorios, **sin exponer tipos de GRDB en la API pública**. Cuentas semilla al primer arranque (Efectivo, más categorías básicas de gasto e ingreso). Tests contra base de datos en memoria.

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

`FeatureSummary` y `FeatureTransactions` con SwiftUI y `@Observable`. Barra inferior con ⊕ centrado y Ajustes en toolbar. Observación reactiva con `ValueObservation` de GRDB para que la UI se refresque sola. **Localización EN/ES desde la primera cadena**, sin textos incrustados.

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
tuist generate
tuist build

xcodebuild test \
  -workspace Keepworth.xcworkspace \
  -scheme Keepworth \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Criterios de aceptación por fase:

- **Entorno de IA** — editar un `.swift` deja el archivo formateado sin intervención; tocar `Project.swift` regenera el proyecto; el agente revisor detecta un `import GRDB` introducido a propósito dentro de una feature.
- **Dominio** — un asiento cuyas líneas no suman cero es rechazado con error; un asiento de una sola línea es rechazado; las conversiones entre divisas distintas fallan si no hay tipo de cambio explícito; el patrimonio neto es correcto mezclando cuentas de activo y de pasivo.
- **Persistencia** — crear, editar y borrar cuentas y movimientos sobre base de datos en memoria; el borrado marca `deleted_at` y la fila deja de aparecer en las consultas; las migraciones aplican en orden sobre una base vacía y sobre una con datos; los saldos derivados coinciden con la suma de líneas.
- **UI** — galería de previews revisada en tema claro y oscuro; recorrido manual en simulador de crear cuenta → registrar gasto → verlo en Resumen y en Movimientos → editarlo → borrarlo, con el patrimonio actualizándose en cada paso.
- **Import/Export** — exportar, borrar la base de datos, reimportar, y comprobar que el patrimonio y el número de movimientos coinciden exactamente.
- **Sync** — dos simuladores con la misma cuenta de iCloud; un cambio en uno aparece en el otro; editar el mismo movimiento en ambos resuelve sin duplicar ni perder datos.
- **CI** — verde en cada push. Un cambio que rompa la ley de dependencias entre módulos debe fallar en `tuist generate`.

---

## 11. Puntos abiertos

No bloquean nada, pero hay que resolverlos cuando toque:

- **Bundle ID y contenedor de CloudKit**: se fijan al arrancar en el Mac (ver sección 3).
- **Divisa base del usuario**: se elige en el primer arranque de la app y se guarda. La UI multi-divisa llega después de la v1.
- **Fuente de tipos de cambio**: hasta que exista el backend, introducción manual.
- **Backend futuro**: solo datos no personales. Cuando llegue el momento, es una conversación nueva.

---

## 12. Cómo trabajar en este proyecto

- **Responder siempre en español.**
- **No tomar decisiones de arquitectura en solitario**: presentar pros y contras, y esperar decisión del usuario.
- **No añadir features, refactors ni mejoras no pedidas.** Sugerirlas si procede.
- Preguntar ante cualquier ambigüedad antes de empezar.
- Los subagentes de este proyecto usan `model: opus`.
- Ejecutar los tests relevantes tras cada cambio e incluir el comando concreto de verificación en la respuesta.
- Si detectas un bug en código no relacionado con la tarea, menciónalo brevemente pero no lo arregles sin instrucción explícita.
