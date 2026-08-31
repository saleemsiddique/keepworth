# KeepworthDomain

El corazón contable de la app. Define **qué es** una cuenta, un asiento y el dinero, y **qué reglas** no pueden violarse jamás.

## Contrato

**Importa**: nada. Ni GRDB, ni SwiftUI, ni CloudKit, ni UIKit. Solo `Foundation` cuando sea estrictamente necesario.

Si escribiendo aquí necesitas importar algo, la lógica no pertenece a esta capa.

**Expone** entidades, `Identifier<T>`, `CalendarDate`, los cuatro protocolos de repositorio, `LedgerChanges`, `MoneyFormatter`, los casos de uso y errores de dominio descriptivos — nunca `nil` para señalar fallo. La lista viva está en `Sources/`.

**`Decimal` solo aparece en `MoneyFormatter`, y solo en el último paso hacia el texto.** La aritmética sigue siendo `Int64`, que es lo que permite que un asiento sume exactamente cero. Un `Decimal` en cualquier otro archivo del dominio es un bug.

## Invariantes

Estas reglas son la razón de existir del módulo. Cada una tiene tests que la demuestran:

1. **Todo asiento cuadra**: la suma de `baseAmountMinor` de las líneas de un `Entry` es exactamente cero. Siempre, con una divisa o con cinco.
2. **Todo asiento tiene al menos dos líneas.** Un movimiento con una sola línea no es contabilidad, es un número suelto.
3. **El dinero es `Int64` de unidades menores.** `Money` no expone ni acepta `Double`. Operar entre divisas distintas sin tipo de cambio explícito lanza error.
4. **El valor en divisa base se guarda, no se calcula.** `baseAmountMinor` es el importe que realmente se movió en la divisa del usuario. Derivarlo multiplicando por un tipo de cambio deja restos de redondeo y vuelve inalcanzable el invariante 1.
5. **Las categorías son cuentas** de tipo `.expense` o `.income`. No existe un tipo `Category`.
6. **El patrimonio neto solo mira `.asset` y `.liability`.** Una categoría que sume al patrimonio es el bug más grave posible aquí: le dice al usuario que tiene dinero que no tiene.
7. **Una cuenta `.expense`, `.income` o `.equity` nunca pertenece a una `Institution`.** Un banco agrupa cuentas donde hay dinero; una categoría no es un sitio donde haya dinero.

## Reglas de uso

- **No existe un `Entry` parcial.** `Entry.init` valida que las líneas sumen cero, así que leer un asiento es leerlo entero. De ahí la regla menos obvia de `EntryQuery`: filtrar por cuenta elige **qué asientos**, nunca qué líneas.
- **`EntryQuery.limit` es obligatorio**, igual que `EntryLineQuery.accountIDs` no admite «todas». Un límite de cero o negativo lanza: SQLite interpreta un `LIMIT` negativo como «sin límite», así que dejarlo pasar convertiría la defensa en su contrario.
- **`Entry.twoLine` es interno a propósito.** Construir un movimiento pasa siempre por un caso de uso, que es quien valida los tipos de cuenta. Si una pantalla necesita un movimiento que hoy no existe, se añade un caso de uso, no se abre el constructor.
- **El undo recibe el `Entry`, no su id.** Es lo que dice exactamente qué líneas revivir.

El porqué de cada una está en `ESTADO.md` §6 bis.

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
