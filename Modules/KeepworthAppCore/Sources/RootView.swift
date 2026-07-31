import SwiftUI

/// Vista raíz de la app.
///
/// La navegación real —Resumen · ⊕ · Movimientos en la barra inferior, con Ajustes en
/// la toolbar— se construye en la Fase 4, junto con el contenedor de dependencias que
/// inyecta los repositorios concretos en cada feature.
public struct RootView: View {
    public init() {}

    public var body: some View {
        // `verbatim` a propósito: los textos localizables viven en el String Catalog,
        // que llega con las primeras pantallas reales.
        Text(verbatim: "Keepworth")
    }
}
