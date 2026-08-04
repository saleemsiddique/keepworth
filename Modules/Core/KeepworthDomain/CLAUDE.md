# KeepworthDomain

El corazón contable de la app. Define **qué es** una cuenta, un asiento y el dinero, y **qué reglas** no pueden violarse jamás.

## Contrato

**Importa**: nada. Ni GRDB, ni SwiftUI, ni CloudKit, ni UIKit. Solo `Foundation` cuando sea estrictamente necesario.

Si escribiendo aquí necesitas importar algo, la lógica no pertenece a esta capa.

**Expone**:
- Entidades: `Money`, `CurrencyCode`, `Institution`, `Account`, `AccountKind`, `Entry`, `EntryLine`.
- Protocolos de repositorio: `InstitutionRepository`, `AccountRepository`, `EntryRepository`. Definidos aquí, implementados en `KeepworthPersistence`.
- Casos de uso: `RecordExpense`, `RecordIncome`, `TransferBetweenAccounts`, `CalculateNetWorth`, `CalculateAccountBalance`, `CalculateInstitutionTotal`, `SummarizePeriod`.
- Errores de dominio descriptivos, nunca `nil` para señalar fallo.

## Invariantes

Estas reglas son la razón de existir del módulo. Cada una tiene tests que la demuestran:

1. **Todo asiento cuadra**: la suma de `baseAmountMinor` de las líneas de un `Entry` es exactamente cero. Siempre, con una divisa o con cinco.
2. **Todo asiento tiene al menos dos líneas.** Un movimiento con una sola línea no es contabilidad, es un número suelto.
3. **El dinero es `Int64` de unidades menores.** `Money` no expone ni acepta `Double`. Operar entre divisas distintas sin tipo de cambio explícito lanza error.
4. **El valor en divisa base se guarda, no se calcula.** `baseAmountMinor` es el importe que realmente se movió en la divisa del usuario. Derivarlo multiplicando por un tipo de cambio deja restos de redondeo y vuelve inalcanzable el invariante 1.
5. **Las categorías son cuentas** de tipo `.expense` o `.income`. No existe un tipo `Category`.
6. **El patrimonio neto solo mira `.asset` y `.liability`.** Una categoría que sume al patrimonio es el bug más grave posible aquí: le dice al usuario que tiene dinero que no tiene.
7. **Una cuenta `.expense`, `.income` o `.equity` nunca pertenece a una `Institution`.** Un banco agrupa cuentas donde hay dinero; una categoría no es un sitio donde haya dinero.

## Cómo se registra un gasto

Un gasto de 42,30 € en Mercadona no es `-42.30`. Es un asiento de dos líneas:

| cuenta | tipo | amountMinor |
|---|---|---|
| BBVA · Nómina | `.asset` | −4230 |
| Supermercado | `.expense` | +4230 |

El patrimonio baja porque baja el saldo de una cuenta real, no porque exista la categoría. El "saldo" de una cuenta `.expense` no es un saldo: es cuánto ha pasado por ahí.

Los casos de uso construyen ese asiento a partir de una entrada simple. La UI nunca compone líneas a mano.

## Tests

Swift Testing. Es la capa con mayor exigencia de cobertura del proyecto: aquí un bug es dinero mal contado.

Casos que siempre deben existir: asiento desequilibrado rechazado, asiento de una sola línea rechazado, suma entre divisas distintas rechazada sin tipo de cambio, cuenta de gasto o ingreso con banco rechazada, patrimonio neto correcto con cuentas de activo y de pasivo mezcladas, patrimonio neto que **no varía** al crear, renombrar o archivar una categoría, e informe del mes que coincide al céntimo con la variación del patrimonio en ese mes.
