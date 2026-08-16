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

El identificador del App Group **no está escrito aquí**: sale del Info.plist, que `Project.swift` rellena desde la misma constante que usa para los entitlements. Ya tiene que coincidir en dos sitios; una tercera copia sería un tercer sitio del que se desincroniza.

## Primer arranque

`FirstLaunch.prepareIfNeeded` siembra si no hay divisa base, y no hace nada si ya la hay.

**No hay pantalla de bienvenida.** La divisa sale del `Locale` del dispositivo, con el euro de reserva. Lo primero que enseña la app debería ser el dinero del usuario, no un formulario, y quien haya acertado mal lo cambia en Ajustes — un toque que dan unos pocos, en vez de una pantalla que ven todos.

Los nombres de las cuentas sembradas salen del String Catalog. La lista está en `ESTADO.md` §6 y **no tiene un cajón de sastre «Otros»** en gastos: se traga justo lo que el usuario quería entender.

## Textos

`Resources/Localizable.xcstrings`, en inglés y español desde la primera cadena.

**Siempre con `bundle: .module`.** En un framework, `String(localized:)` y `Text(_:)` buscan en el bundle principal, así que sin él las cadenas salen como su clave —`seed.expense.groceries` en pantalla— sin dar ningún error. Hay un test que lo caza.

## Navegación

Dos destinos en la barra inferior con el botón de añadir en el centro exacto, y Ajustes como icono en la toolbar superior:

```
│ Resumen  ⊕  Movimientos │
```

- **Resumen** — patrimonio neto, cuentas agrupadas por banco, lo gastado y ahorrado del mes, movimientos recientes.
- **⊕** — abre el editor de movimiento como sheet con detents. Único elemento con color de acento en la barra.
- **Movimientos** — lista completa, buscable y filtrable.
- **⚙ Ajustes** — en la toolbar, no en la barra inferior.
- **Informe** — pantalla de detalle empujada desde Resumen. Abre en el mes en curso, con flechas entre meses y un selector de rango libre.

**Regla de crecimiento**: presupuestos y metas serán secciones del scroll de Resumen; el informe es una pantalla de detalle empujada desde Resumen; buscar y filtrar vive en Movimientos, y las programadas son un filtro suyo. **Nunca se añade una tercera tab.** Si una funcionalidad nueva no encuentra sitio bajo esta regla, se discute con el usuario antes de tocar la navegación.
