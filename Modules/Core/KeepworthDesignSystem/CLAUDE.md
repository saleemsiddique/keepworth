# KeepworthDesignSystem

Traduce la dirección estética "Ledger" a componentes SwiftUI. Es la **única** fuente de color y tipografía del proyecto.

## Contrato

**Importa**: SwiftUI. Nada de negocio: este módulo no sabe qué es una cuenta ni un asiento. En particular **no ve `Money`**, así que todo componente que enseña dinero recibe un `String` ya formateado — convertir unidades menores en texto necesita divisa y locale, y eso es asunto de quien llama.

Tampoco tiene String Catalog ni debe tenerlo: no sabe en qué idioma está la pantalla. Los componentes reciben `String` y quien los usa es quien localiza.

**Expone**: tokens, tipografía, espaciado, los siete componentes y las dos galerías.

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

**Regla del color en los importes**: marca **dirección, nunca juicio**. `accent` para lo que entra, `expense` para lo que sale, `ink` para lo que no es ninguna de las dos —un saldo positivo, una cifra que solo es un total—. El verde aparece además en los elementos interactivos.

`expense` espeja a `accent` en construcción: profundo y desaturado en claro, brillante en oscuro. **No es el rojo de alarma del sistema**, y esa contención es el punto: ninguno de los dos grita más que el otro.

**Todo importe lleva su signo**, aunque el color ya diga la dirección. Redundante a propósito: la cifra debe leerse igual en escala de grises, con daltonismo o copiada a un sitio sin color.

### Por qué hay recursos aquí y en ningún otro módulo

El helper `module()` de `Project.swift` acepta un parámetro `resources:` opcional, y este es el único que lo usa. Es opcional a propósito: un glob que no casa con nada hace fallar la generación.

Además el proyecto lleva `disableSynthesizedResourceAccessors: true`. El accesor de assets que sintetiza Tuist **importa UIKit dentro del target dueño del catálogo**, y este módulo solo puede importar SwiftUI. La opción quita ese accesor y conserva `Bundle.module`, que es solo Foundation y es todo lo que `Colors.swift` necesita.

## Tipografía

Dos voces, ambas del sistema. Cero assets, cero licencias, cero peso. Todas se construyen desde un text style, no desde un tamaño fijo, así que Dynamic Type funciona sin una línea extra en cada pantalla.

- **Importes**: SF Mono semibold con `.monospacedDigit()`, para que los dígitos no bailen al actualizarse.
- **Títulos y texto**: SF Pro.
- **Metadatos y etiquetas**: SF Pro 11–13 pt, mayúsculas, tracking amplio. Las tres cosas van juntas siempre, así que se aplican en `SectionCaption` en vez de ofrecerse sueltas.

## Espaciado

`Spacing` nombra las medidas por lo que separan, no como una escala de tallas, y solo están las que algún componente usa hoy. Cuando una pantalla de una fase posterior necesite un hueco que no esté, se añade con nombre — no se aproxima con el más parecido.

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
| `PrimaryAction` | `init(_ title: String, action: @escaping () -> Void)` |
| `EmptyStateLine` | `EmptyStateLine(_ text: String)` |
| `LedgerTabBar` | `init(selection: Binding<Tag>, leading: LedgerTabItem<Tag>, trailing: LedgerTabItem<Tag>, centerLabel: String, centerAction: @escaping () -> Void)` |

Todos son tontos: pintan lo que reciben, no lo calculan.

Dos decisiones que conviene no reabrir por costumbre:

- **`HeadlineAmount` no se oculta a sí mismo.** El tap que redacta el patrimonio es estado de una pantalla, así que quien llama es quien aplica `.redacted(reason: .placeholder)`.
- **`LedgerTabBar` es genérico sobre su tag.** No conoce los destinos de la app: nombrarlos aquí metería la navegación dentro del design system, y las dos cosas crecen a ritmos distintos.

`LedgerRow` empezó con un `isIncoming: Bool`, y al añadirse el token `expense` apareció el tercer caso que el propio contrato preveía. Hoy es `AmountDirection` —`.incoming`, `.outgoing`, `.neutral`—, y **el módulo no tiene ningún flag booleano**. Que siga así.

## Verificación

Cada componente lleva previews en **ambos temas**. `ComponentGallery` es la herramienta de revisión visual del proyecto: si un componente nuevo no aparece en ella, no está terminado. `TokenGallery` enseña la paleta y las voces tipográficas.

Las dos galerías son herramientas de desarrollo, no pantallas: su texto va con `Text(verbatim:)` o como dato de ejemplo, y **no entra en el String Catalog**.

### Los tests importan UIKit, y el módulo no

`Color("typo", bundle:)` nunca falla: devuelve un color de relleno, así que un asset mal escrito o no empaquetado se publicaría sin síntoma. `UIColor(named:in:compatibleWith:)` es la única API que admite no haber encontrado el color, y por eso `ColorTokenTests` importa UIKit.

Es una excepción deliberada y acotada al target de tests. El contrato de arriba limita lo que importa el **módulo**, no sus tests.

Los tests comprueban tres cosas por token, y cada una tapa un fallo silencioso distinto:

1. **Que está en el bundle** — un nombre mal escrito o un recurso no empaquetado.
2. **Que sus valores claro y oscuro son los hex documentados** — sin esto, un Color Set al que le falte la variante oscura pasaría: resuelve al valor claro en los dos temas.
3. **Que el alfa es 1 en ambos** — un `"alpha": "0.500"` colado en un `Contents.json` pasa las dos anteriores y no se nota hasta que el color está encima de otra cosa.

No hay tests de snapshot: meterían una dependencia externa, y solo GRDB está aprobada.
