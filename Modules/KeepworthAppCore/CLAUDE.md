# KeepworthAppCore

Composition root de la app. Es el **único** módulo autorizado a conocer implementaciones concretas.

## Contrato

**Importa**: todos los módulos. Es el único que puede.

**Expone**: la vista raíz y el contenedor de dependencias.

## Responsabilidad

Aquí, y solo aquí, se instancian los repositorios reales de `KeepworthPersistence` y se inyectan en las features como protocolos de `KeepworthDomain`. Una feature nunca sabe qué implementación recibe: por eso se puede testear con dobles en memoria.

Si una feature necesita algo que hoy no está en los protocolos de `Domain`, la solución es ampliar el protocolo, **no** dejar que la feature importe `Persistence`.

`Dependencies` es ese contenedor, y `Dependencies.live()` lo monta sobre la base de datos del App Group.

**`Dependencies.live()` no se llama desde el actor principal.** Abrir la base ejecuta las migraciones, y `SQLiteLedgerChanges` arranca una observación que bloquea hasta conseguir acceso de escritura: en el hilo principal eso congela el primer fotograma. `RootView` lo construye en una tarea desprendida por eso.

**El ⚙ se monta aquí, no en `SummaryView`.** Una feature nunca importa otra feature, así que Resumen no puede saber que `FeatureSettings` existe: `LedgerTabs` es quien le pone la toolbar y quien presenta la sheet. Lo mismo valdrá para el editor de movimiento.

El identificador del App Group **no está escrito aquí**: sale del Info.plist, que `Project.swift` rellena desde la misma constante que usa para los entitlements. Ya tiene que coincidir en dos sitios; una tercera copia sería un tercer sitio del que se desincroniza.

## Primer arranque

`FirstLaunch.prepareIfNeeded` siembra si no hay divisa base, y no hace nada si ya la hay.

**No hay pantalla de bienvenida.** La divisa sale del `Locale` del dispositivo, con el euro de reserva. Lo primero que enseña la app debería ser el dinero del usuario, no un formulario, y quien haya acertado mal lo cambia en Ajustes — un toque que dan unos pocos, en vez de una pantalla que ven todos.

Los nombres de las cuentas sembradas salen del String Catalog. La lista está en `ESTADO.md` §6 y **no tiene un cajón de sastre «Otros»** en gastos: se traga justo lo que el usuario quería entender.

## Textos

`Resources/Localizable.xcstrings`, en inglés y español desde la primera cadena, con `bundle: .module` — `CLAUDE.md` § «Textos». Aquí hay un test que caza su ausencia: sin él, los nombres de las cuentas sembradas saldrían como `seed.expense.groceries` en pantalla.

## Navegación

Dos destinos en la barra inferior con el ⊕ en el centro exacto, y Ajustes en la toolbar de Resumen:

```
│ Resumen  ⊕  Movimientos │
```

El mapa completo de pantallas —qué enseña cada una y qué falta— está en `ESTADO.md` §8. Aquí solo las reglas que atan la navegación a este módulo:

- **Todo lo que cruza features se monta aquí.** El ⚙ de Ajustes, el editor de movimiento desde el ⊕ y desde el tap en una fila: Resumen y Movimientos reciben un `onSelect` y no saben que el editor existe. `LedgerTabs` pone la toolbar y presenta las sheets.
- **Un saldo de partida no se abre en el editor**: su contrapartida es la cuenta interna de patrimonio, que no sale en ningún selector.
- **Nunca se añade una tercera tab.** Presupuestos y metas serán secciones del scroll de Resumen; el informe es detalle empujado desde Resumen; buscar, filtrar y las programadas viven en Movimientos. Si algo nuevo no encuentra sitio bajo esta regla, se discute con el usuario antes de tocar la navegación.
