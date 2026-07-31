# KeepworthDesignSystem

Traduce la dirección estética "Ledger" a componentes SwiftUI. Es la **única** fuente de color y tipografía del proyecto.

## Contrato

**Importa**: SwiftUI. Nada de negocio: este módulo no sabe qué es una cuenta ni un asiento.

**Expone**: tokens, tipografía y componentes reutilizables.

## Los seis tokens

Definidos como Color Sets con variante clara y oscura. **Ninguna feature usa un color literal ni un color del sistema.**

| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| `bg` | `#F7F7F5` | `#000000` | Fondo. Negro OLED puro en oscuro |
| `surface` | `#FFFFFF` | `#0D0D0C` | Solo sheets |
| `ink` | `#141413` | `#F2F2EF` | Texto principal |
| `inkSoft` | `#6E6E69` | `#8A8A85` | Texto secundario y metadatos |
| `hairline` | `#E2E2DC` | `#232322` | Separadores de 0,5 pt |
| `accent` | `#1E9E5A` | `#30D158` | Fósforo |

**Regla del acento**: el verde aparece solo en elementos interactivos y en dinero que **entra**. Los gastos van en `ink`. **Nunca rojo**: la app no regaña al usuario.

## Tipografía

Dos voces, ambas del sistema. Cero assets, cero licencias, cero peso.

- **Importes**: SF Mono semibold con `.monospacedDigit()`, para que los dígitos no bailen al actualizarse.
- **Títulos y texto**: SF Pro.
- **Metadatos y etiquetas**: SF Pro 11–13 pt, mayúsculas, tracking amplio.

## Contrato de cada pantalla

1. Una acción primaria por pantalla. El resto vive en gestos nativos: swipe, long-press, tirar para cerrar.
2. El número es el protagonista: cada pantalla se resume en una cifra grande arriba.
3. **Espacio en vez de cajas**: sin tarjetas ni sombras. La jerarquía se construye con espacio en blanco y hairlines de 0,5 pt.
4. Color = significado, nunca decoración.
5. Estados vacíos de una línea: "Sin movimientos. Añade el primero." Sin ilustraciones.

## Acabado

`contentTransition(.numericText())` en las cifras grandes · SF Symbols en peso `.light`, monocromos y pequeños · un único haptic ligero al guardar · tap en el patrimonio lo oculta con `redacted`.

## Componentes

`LedgerRow`, `HeadlineAmount`, `SectionCaption`, `Hairline`, `PrimaryAction`, `EmptyStateLine`, `LedgerTabBar`.

## Verificación

Cada componente lleva previews en **ambos temas**. La galería de previews es la herramienta de revisión visual del proyecto: si un componente nuevo no aparece en ella, no está terminado.
