# Modules/Features

Una carpeta por pantalla, más `FeatureSupport`. Cada feature dibuja y decide qué enseñar; ninguna sabe de dónde salen los datos.

## Contrato

**Importa**: `KeepworthDomain`, `KeepworthDesignSystem` y `FeatureSupport`. Nada más.

**Nunca**: `KeepworthPersistence`, `KeepworthSync`, `GRDB` ni `CloudKit`. Una feature recibe protocolos de `Domain` y no sabe qué implementación le han inyectado — por eso se puede testear con dobles en memoria. Si necesita algo que hoy no está en los protocolos, **se amplía el protocolo**, no se importa la capa de datos.

**Una feature nunca importa otra feature.** Resumen no puede saber que `FeatureSettings` o `FeatureMovementEditor` existen: recibe un `onSelect` y `KeepworthAppCore` es quien monta la toolbar, presenta la sheet y conecta los cabos.

`FeatureSupport` está en esta capa y tiene sus mismos derechos: guarda lo que **dos pantallas dibujan igual** —`MovementRow`, `UndoBanner`, `PlainRow`, `MovementDeletion`— y no puede importar nada que una feature no pueda. Lo que solo usa una pantalla se queda en su feature.

## Textos

Cada feature con texto lleva su `Resources/Localizable.xcstrings`, en inglés y español desde la primera cadena, declarado con `resourceGlobs: ["Resources/**"]` en `Project.swift`. Se lee con `String(localized:)` y `bundle: .module` —la regla y su porqué están en `CLAUDE.md` § «Textos»—, **nunca** con un tipo `L10n` generado: los accesores sintetizados están desactivados en todo el proyecto.

## Modelos

`@Observable`, con las dependencias inyectadas por `init`. El modelo carga y publica; la vista solo dibuja.

Una pantalla que debe refrescarse sola escucha `LedgerChanges` de `Domain`, que avisa de que el libro se movió sin decir qué. La pantalla ya sabe recargar lo que enseña.

## Tests

Con dobles en memoria de los protocolos de `Domain`, **nunca contra una base de datos real**.

Cada target de test **repite** sus propios dobles (`FakeRepositories.swift`). Es deliberado y **no es un hallazgo**: un target de test no exporta nada, y la alternativa sería enviar dobles dentro de un módulo de producción.

Un test que construye una `View` necesita `@MainActor`: en modo de lenguaje Swift 6, conformar a `View` aísla el inicializador al actor principal.
