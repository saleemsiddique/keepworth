# KeepworthAppCore

Composition root de la app. Es el **único** módulo autorizado a conocer implementaciones concretas.

## Contrato

**Importa**: todos los módulos. Es el único que puede.

**Expone**: la vista raíz y el contenedor de dependencias.

## Responsabilidad

Aquí, y solo aquí, se instancian los repositorios reales de `KeepworthPersistence` y se inyectan en las features como protocolos de `KeepworthDomain`. Una feature nunca sabe qué implementación recibe: por eso se puede testear con dobles en memoria.

Si una feature necesita algo que hoy no está en los protocolos de `Domain`, la solución es ampliar el protocolo, **no** dejar que la feature importe `Persistence`.

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
