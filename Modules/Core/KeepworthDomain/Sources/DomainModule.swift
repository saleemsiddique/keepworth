/// Andamiaje del módulo de dominio.
///
/// Las entidades (`Money`, `CurrencyCode`, `Account`, `Entry`, `EntryLine`), los
/// protocolos de repositorio y los casos de uso llegan en la Fase 1. Este tipo existe
/// para que el target enlace y sea testeable desde la Fase 0, y desaparece cuando el
/// módulo tenga contenido real.
public enum DomainModule {
    public static let name = "KeepworthDomain"
}
