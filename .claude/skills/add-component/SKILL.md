---
name: add-component
description: Añade un componente nuevo a KeepworthDesignSystem con la forma que comparten los siete existentes, sus previews en ambos temas y su entrada en la galería. Úsalo al crear cualquier vista reutilizable del design system.
---

# Añadir un componente al design system

Las reglas —los siete tokens, la regla del color y del signo, sin tarjetas ni sombras— están en `Modules/Core/KeepworthDesignSystem/CLAUDE.md`. Léelas antes; esto son los pasos.

## La forma que comparten los siete

Copia la estructura de `Modules/Core/KeepworthDesignSystem/Sources/Components/SectionCaption.swift`, que es el más pequeño:

```swift
import SwiftUI

/// Qué es, y el porqué de lo que no se deduce del código.
public struct MiComponente: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.sectionCaption)
            .foregroundStyle(.inkSoft)
    }
}
```

Cinco cosas que cumplen los siete y tiene que cumplir el octavo:

1. **`import SwiftUI` y nada más.** El módulo importa una sola cosa; que siga así. Si necesitas `CGFloat`, SwiftUI ya lo reexporta — no importes `CoreGraphics`.
2. **Propiedades `private let`, `init` público.** Nada de `@State` salvo que el componente tenga estado propio de verdad (`PrimaryAction` lo tiene solo para disparar el haptic).
3. **Es tonto**: pinta lo que recibe, no lo calcula. No ve `Money`, ni `Account`, ni nada de `Domain`.
4. **Recibe `String` ya localizado.** El módulo no tiene String Catalog ni debe tenerlo: no sabe en qué idioma está la pantalla.
5. **Colores y medidas de los tokens.** `.foregroundStyle(.ink)`, `Spacing.row`, `Font.rowTitle`. Cero literales.

**Sin flags booleanos.** `LedgerRow` empezó con `isIncoming: Bool` y acabó en `AmountDirection` en cuanto apareció el tercer caso. Si dudas entre `Bool` y `enum`, es `enum`.

## Previews: el `private struct`, no dos cuerpos copiados

Cada componente lleva **dos** `#Preview`, claro y oscuro. El cuerpo va en un `private struct` para que solo se escriba una vez — copiarlo lleva a tocar el claro y olvidar el oscuro, y el oscuro es justo donde se delata un color que se ha ido de la paleta:

```swift
private struct MiComponentePreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.betweenSections) {
            MiComponente("Patrimonio")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.screenMargin)
        .background(.bg)
    }
}

#Preview("Light") {
    MiComponentePreview().preferredColorScheme(.light)
}

#Preview("Dark") {
    MiComponentePreview().preferredColorScheme(.dark)
}
```

El `.background(.bg)` no es decoración: sin él la preview usa el fondo del sistema y el tema oscuro engaña.

Los literales en previews y galerías son datos de ejemplo, no texto de producto: **no van al String Catalog**. Es una excepción documentada, no un olvido.

## Meterlo en la galería

**Si no aparece en `ComponentGallery`, no está terminado.** Es la regla de verificación del módulo.

En `Modules/Core/KeepworthDesignSystem/Sources/Gallery/ComponentGallery.swift`, añádelo como una propiedad computada con nombre —`accounts`, `thisMonth`, `recent`— y súmala al `VStack` del `body`. Si es un componente que ninguna pantalla real usaría ahí, va bajo la cabecera `outOfContext`, como `PrimaryAction`.

## Actualizar la documentación

Dos sitios, y ambos hay que tocarlos a mano:

- `Modules/Core/KeepworthDesignSystem/CLAUDE.md` § «Componentes»: la tabla de firmas. Tiene que coincidir **literalmente** con el `init` del código.
- `ESTADO.md` §7 § «Componentes»: la lista de nombres.

## Verificar

```bash
export PATH="$HOME/.local/share/mise/shims:$PATH"
tuist generate --no-open          # el archivo nuevo no está en el .xcodeproj hasta esto

tuist xcodebuild build -workspace Keepworth.xcworkspace \
  -scheme Keepworth-Workspace \
  -destination 'platform=iOS Simulator,name=iPhone 17'

xcrun swift-format lint --configuration .swift-format --recursive --strict Modules Apps
```

Y la comprobación mecánica de la regla de color, que conviene repetir en cada fase de UI:

```bash
grep -rn -E 'Color\(red:|\.foregroundColor|Color\.(gray|black|white|red|blue|green|primary|secondary)|Divider\(\)|\.shadow\(' \
  --include='*.swift' Modules Apps | grep -v 'Sources/Tokens/Colors.swift'
```

Sin resultados. `Divider()` cuenta como hallazgo: usa `Hairline`, que es el único separador con el grosor y el token correctos.

**Lo último no lo puedes hacer tú**: abrir `ComponentGallery` en el canvas de Xcode (`⇧⌘O` → nombre del archivo, luego `⌥⌘↩`) y mirarlo en los dos temas. Pídeselo al usuario y dile qué mirar.
