# KeepworthDesignSystem

Traduce la dirección estética "Ledger" a componentes SwiftUI. Es la **única** fuente de color, tipografía y espaciado del proyecto.

## Contrato

**Importa**: SwiftUI. Nada de negocio: este módulo no sabe qué es una cuenta ni un asiento. En particular **no ve `Money`**, así que todo componente que enseña dinero recibe un `String` ya formateado — convertir unidades menores en texto necesita divisa y locale, y eso es asunto de quien llama.

Tampoco tiene String Catalog ni debe tenerlo: no sabe en qué idioma está la pantalla. Los componentes reciben `String` y quien los usa es quien localiza.

**Expone**: tokens, tipografía, espaciado, los componentes y las dos galerías.

## Los siete tokens

Viven en `Resources/Tokens.xcassets` como Color Sets con variante clara y oscura, y se exponen en `Sources/Tokens/Colors.swift` como extensión de `ShapeStyle where Self == Color`, para que se lean como los de SwiftUI: `.foregroundStyle(.ink)`, `.background(.bg)`.

**Ninguna feature usa un color literal ni un color del sistema.**

| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| `bg` | `#F7F7F5` | `#000000` | Fondo. Negro OLED puro en oscuro |
| `surface` | `#FFFFFF` | `#0D0D0C` | Solo sheets |
| `ink` | `#141413` | `#F2F2EF` | Texto principal |
| `inkSoft` | `#6E6E69` | `#8A8A85` | Texto secundario y metadatos |
| `hairline` | `#E2E2DC` | `#232322` | Separadores de 0,5 pt |
| `accent` | `#1E9E5A` | `#30D158` | Fósforo: interactivo y dinero que entra |
| `expense` | `#B3382C` | `#FF6B5E` | Dinero que sale |

**Regla del color en los importes**: marca **dirección, nunca juicio**.

| Cuándo | Color | `AmountDirection` |
|---|---|---|
| El dinero **entra** | `accent` | `.incoming` |
| El dinero **sale o se debe** — un gasto, un saldo negativo, el total gastado de un periodo | `expense` | `.outgoing` |
| **Todo lo demás** — saldos positivos, y cifras derivadas como lo ahorrado | `ink` | `.neutral` |

El verde aparece además en los elementos interactivos.

`expense` espeja a `accent` en construcción: profundo y desaturado en claro, brillante en oscuro. **No es el rojo de alarma del sistema**, y esa contención es el punto: ninguno de los dos grita más que el otro.

**Lleva signo todo importe que sea negativo o que tenga dirección**; un saldo positivo no lleva ninguno. Se pone aunque el color ya diga lo mismo: redundante a propósito, para que la cifra se lea igual en escala de grises, con daltonismo o copiada a un sitio sin color.

Los componentes no deciden nada de esto: reciben el `String` con su signo y el `direction` ya elegido por quien llama.

El catálogo se lee con `Bundle.module` y nunca con un accesor sintetizado: el que genera Tuist importaría UIKit dentro de este target, y aquí solo entra SwiftUI. Por eso el proyecto lleva `disableSynthesizedResourceAccessors: true`.

## Tipografía

Dos voces, ambas del sistema. Cero assets, cero licencias, cero peso. Todas se construyen desde un text style, no desde un tamaño fijo, así que Dynamic Type funciona sin una línea extra en cada pantalla.

- **Importes**: SF Mono con `.monospacedDigit()`, para que los dígitos no bailen al actualizarse. `headlineAmount` va en semibold; `rowAmount` en peso normal, porque una columna entera de importes en semibold pesa demasiado.
- **Títulos y texto**: SF Pro (`rowTitle`, `rowSubtitle`, `primaryAction`).
- **Metadatos y etiquetas**: `sectionCaption` es el text style `.caption` en peso medio —unos 12 pt con el tamaño de texto por defecto, y escala con Dynamic Type—, más mayúsculas y tracking amplio. Las tres cosas van juntas siempre, así que se aplican en `SectionCaption` en vez de ofrecerse sueltas.

## Espaciado

`Spacing` nombra las medidas por lo que separan, no como una escala de tallas, y solo están las que algún componente usa hoy. Cuando una pantalla de una fase posterior necesite un hueco que no esté, se añade con nombre — no se aproxima con el más parecido.

Con una medida que no separa nada: `minimumTapTarget` son los 44 pt por debajo de los cuales Apple no deja bajar nada pulsable. Vive aquí porque la alternativa era un 44 suelto dentro del teclado numérico, que es el literal que este archivo existe para evitar.

## Contrato de cada pantalla

1. Una acción primaria por pantalla. El resto vive en gestos nativos: swipe, long-press, tirar para cerrar.
2. El número es el protagonista: cada pantalla se resume en una cifra grande arriba.
3. **Espacio en vez de cajas**: sin tarjetas ni sombras. La jerarquía se construye con espacio en blanco y hairlines de 0,5 pt.
4. Color = significado, nunca decoración.
5. Estados vacíos de una línea: "Sin movimientos. Añade el primero." Sin ilustraciones.

## Acabado

`contentTransition(.numericText())` en las cifras grandes · SF Symbols en peso `.light`, monocromos y pequeños · un único haptic ligero al guardar · tap en el patrimonio lo oculta con `redacted`.

## Componentes

| Componente | Firma |
|---|---|
| `Hairline` | `Hairline()` |
| `SectionCaption` | `SectionCaption(_ text: String)` |
| `HeadlineAmount` | `init(caption: String, amount: String, detail: String? = nil)` |
| `LedgerRow` | `init(title: String, subtitle: String? = nil, symbolName: String? = nil, amount: String, direction: AmountDirection = .neutral)` |
| `PrimaryAction` | `init(_ title: String, availability: ActionAvailability = .available, action: @escaping () -> Void)` |
| `EmptyStateLine` | `EmptyStateLine(_ text: String)` |
| `LedgerTabBar` | `init(selection: Binding<Tag>, leading: LedgerTabItem<Tag>, trailing: LedgerTabItem<Tag>, centerLabel: String, centerAction: @escaping () -> Void)` |

Y los de entrada, que llegaron con la Fase 5 — hasta entonces los siete de arriba eran de solo lectura y no había ni un campo en toda la app:

| Componente | Firma |
|---|---|
| `DigitAmount` | `init(minorUnits: Int64 = 0)`, con `append(_:)` y `deleteLast()` |
| `AmountKeypad` | `init(onDigit: @escaping (Int) -> Void, onDelete: @escaping () -> Void)` |
| `FormRow` | `init(title: String, value: String = "", action: @escaping () -> Void)` |
| `TextEntryRow` | `init(title: String, prompt: String, text: Binding<String>)` |
| `ChoiceBar` | `init(selection: Binding<Tag>, items: [ChoiceItem<Tag>])` |
| `SelectionRow` | `init(tag: Tag, selection: Tag?, title: String, subtitle: String? = nil, symbolName: String? = nil, action: @escaping () -> Void)` |
| `SheetSurface` | `init(title: String, actionTitle: String, availability: ActionAvailability = .available, action: @escaping () -> Void, @ViewBuilder content: () -> Content)` |

Todos son tontos: pintan lo que reciben, no lo calculan.

**`DigitAmount` es la única excepción, y no ve dinero.** Un importe se teclea dígito a dígito sobre las unidades menores que ya suma —4, 2, 3, 0 se lee 0,04 / 0,42 / 4,23 / 42,30—, así que nunca existe a medio escribir y no hay nada que parsear ni que rechazar. Cuenta en `Int64` porque el módulo no puede ver `Money`; quien lo usa es quien le pone divisa.

**La sheet no tiene botón de cancelar.** Salir sin guardar es el arrastre nativo, la misma regla que pone el borrado en un swipe: una acción primaria por pantalla y el resto en gestos que el sistema ya enseñó.

Dos decisiones que conviene no reabrir por costumbre:

- **`HeadlineAmount` no se oculta a sí mismo.** El tap que redacta el patrimonio es estado de una pantalla, así que quien llama es quien aplica `.redacted(reason: .placeholder)`.
- **`LedgerTabBar` es genérico sobre su tag.** No conoce los destinos de la app: nombrarlos aquí metería la navegación dentro del design system.

**El módulo no tiene ni un flag booleano, y que siga así.** `LedgerRow` empezó con `isIncoming: Bool` y acabó en `AmountDirection` en cuanto el token `expense` trajo el tercer caso. Hay dos formas de evitarlos, según de quién sea el estado:

- **«Cuál de estos es»**: se compara el tag. `SelectionRow` recibe el suyo y el seleccionado en vez de un `isSelected`, igual que `LedgerTabBar` y `ChoiceBar` comparan dentro. Sin booleano y sin tipo nuevo.
- **Estado del propio componente**: se nombra con un enum. `ActionAvailability` —`.available`, `.unavailable`— apaga el botón de guardar mientras falte algo, y `PrimaryAction("Guardar", availability: .unavailable)` dice en el sitio de llamada lo que un `true` dejaría a adivinar.

## Verificación

Cada componente lleva previews en **ambos temas**. `ComponentGallery` es la herramienta de revisión visual del proyecto: si un componente nuevo no aparece en ella, no está terminado. Con una excepción razonada: `SheetSurface` pinta una capa modal entera, así que meterlo en la galería sería dibujar una sheet dentro de un scroll. Se revisa en sus dos previews. `TokenGallery` enseña la paleta y las voces tipográficas.

Las dos galerías son herramientas de desarrollo, no pantallas: su texto va con `Text(verbatim:)` o como dato de ejemplo, y **no entra en el String Catalog**.

### Los tests importan UIKit, y el módulo no

`Color("typo", bundle:)` nunca falla: devuelve un color de relleno, así que un asset mal escrito o no empaquetado se publicaría sin síntoma. `UIColor(named:in:compatibleWith:)` es la única API que admite no haber encontrado el color, y por eso `ColorTokenTests` importa UIKit.

Es una excepción deliberada y acotada al target de tests. El contrato de arriba limita lo que importa el **módulo**, no sus tests.

Los tests comprueban tres cosas por token, y cada una tapa un fallo silencioso distinto:

1. **Que está en el bundle** — un nombre mal escrito o un recurso no empaquetado.
2. **Que sus valores claro y oscuro son los hex documentados** — sin esto, un Color Set al que le falte la variante oscura pasaría: resuelve al valor claro en los dos temas.
3. **Que el alfa es 1 en ambos** — un `"alpha": "0.500"` colado en un `Contents.json` pasa las dos anteriores y no se nota hasta que el color está encima de otra cosa.

No hay tests de snapshot: meterían una dependencia externa, y solo GRDB está aprobada. Lo demás no se testea porque no hay nada que afirmar sobre una vista tonta — salvo `DigitAmount`, que es la única lógica del módulo y sí los tiene, incluido el caso de que un importe imposible de representar deje de crecer en vez de dar la vuelta a negativo.
