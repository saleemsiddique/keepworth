# KeepworthDomain

El corazón contable de la app. Define **qué es** una cuenta, un asiento y el dinero, y **qué reglas** no pueden violarse jamás.

## Contrato

**Importa**: nada. Ni GRDB, ni SwiftUI, ni CloudKit, ni UIKit. Solo `Foundation` cuando sea estrictamente necesario.

Si escribiendo aquí necesitas importar algo, la lógica no pertenece a esta capa.

**Expone**:
- Entidades: `Money`, `CurrencyCode`, `Institution`, `Account`, `AccountKind`, `Entry`, `EntryLine`.
- Tipos de apoyo: `CalendarDate` —fecha sin hora ni zona, la de `occurredOn`— e `Identifier<T>`, que da `AccountID`, `EntryID`, `InstitutionID` y `EntryLineID`.
- Protocolos de repositorio: `InstitutionRepository`, `AccountRepository`, `EntryRepository`, `SettingsRepository`, con `EntryLineQuery` como única forma de pedir líneas. Definidos aquí, implementados en `KeepworthPersistence`.
- Casos de uso: `RecordExpense`, `RecordIncome`, `TransferBetweenAccounts`, `SetOpeningBalance`, `CalculateNetWorth`, `CalculateAccountBalance`, `CalculateInstitutionTotal`, `SummarizePeriod`, `SeedFirstLaunch`.
- Errores de dominio descriptivos, nunca `nil` para señalar fallo.

`Entry.twoLine` es **interno a propósito**: construir un movimiento pasa siempre por un caso de uso, que es quien valida los tipos de cuenta. Si una pantalla necesita un movimiento que hoy no existe, se añade un caso de uso, no se abre el constructor.

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

Casos que siempre deben existir: asiento desequilibrado rechazado, asiento de una sola línea rechazado, suma entre divisas distintas rechazada sin tipo de cambio, cuenta de gasto o ingreso con banco rechazada, patrimonio neto correcto con cuentas de activo y de pasivo mezcladas, patrimonio neto que **no varía** al crear, renombrar o archivar una categoría, y `PeriodSummary.netWorthChange` que coincide al céntimo con la variación del patrimonio en el periodo.

Ese último tiene una trampa que ya costó una corrección: **el saldo de partida de una cuenta sube el patrimonio sin ser un ingreso.** Por eso la igualdad se comprueba contra `netWorthChange` —que suma `saved` y `openingBalances`— y no contra `saved` a secas, y hay un test con una cuenta declarada dentro del periodo que lo fija.
