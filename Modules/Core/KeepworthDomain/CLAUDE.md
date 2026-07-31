# KeepworthDomain

El corazón contable de la app. Define **qué es** una cuenta, un asiento y el dinero, y **qué reglas** no pueden violarse jamás.

## Contrato

**Importa**: nada. Ni GRDB, ni SwiftUI, ni CloudKit, ni UIKit. Solo `Foundation` cuando sea estrictamente necesario.

Si escribiendo aquí necesitas importar algo, la lógica no pertenece a esta capa.

**Expone**:
- Entidades: `Money`, `CurrencyCode`, `Account`, `AccountKind`, `Entry`, `EntryLine`.
- Protocolos de repositorio: `AccountRepository`, `EntryRepository`. Definidos aquí, implementados en `KeepworthPersistence`.
- Casos de uso: `RecordExpense`, `RecordIncome`, `TransferBetweenAccounts`, `CalculateNetWorth`, `CalculateAccountBalance`, `SummarizeSpendingByCategory`.
- Errores de dominio descriptivos, nunca `nil` para señalar fallo.

## Invariantes

Estas cuatro reglas son la razón de existir del módulo. Cada una tiene tests que la demuestran:

1. **Todo asiento cuadra**: la suma de `amountMinor × rateToBase` de las líneas de un `Entry` es exactamente cero en divisa base.
2. **Todo asiento tiene al menos dos líneas.** Un movimiento con una sola línea no es contabilidad, es un número suelto.
3. **El dinero es `Int64` de unidades menores.** `Money` no expone ni acepta `Double`. Operar entre divisas distintas sin tipo de cambio explícito lanza error.
4. **Las categorías son cuentas** de tipo `.expense` o `.income`. No existe un tipo `Category`.

## Cómo se registra un gasto

Un gasto de 42,30 € en Mercadona no es `-42.30`. Es un asiento de dos líneas:

| cuenta | tipo | amountMinor |
|---|---|---|
| BBVA | `.asset` | −4230 |
| Comida | `.expense` | +4230 |

Los casos de uso construyen ese asiento a partir de una entrada simple. La UI nunca compone líneas a mano.

## Tests

Swift Testing. Es la capa con mayor exigencia de cobertura del proyecto: aquí un bug es dinero mal contado.

Casos que siempre deben existir: asiento desequilibrado rechazado, asiento de una sola línea rechazado, suma entre divisas distintas rechazada sin tipo de cambio, patrimonio neto correcto con cuentas de activo y de pasivo mezcladas.
