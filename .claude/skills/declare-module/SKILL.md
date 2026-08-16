---
name: declare-module
description: Declara un módulo nuevo de Keepworth en Project.swift con su target de tests, sus dependencias según la ley de capas y, si lo necesita, su carpeta de recursos. Úsalo al crear cualquier módulo — una feature de la Fase 4, el widget de la Fase 7, o cualquier carpeta nueva bajo Modules/.
---

# Declarar un módulo nuevo

Las reglas —qué puede importar cada capa y por qué— están en `CLAUDE.md` § «Ley de dependencias». Esto son los pasos.

## Lo primero: el target y el primer archivo van en el MISMO commit

Un `.swift` bajo `Modules/` **sin target declarado en `Project.swift` no lo ve nadie**: ni `tuist generate`, ni el build, ni el CI, ni la validación de dependencias. Puede importar GRDB desde una feature y salir todo en verde.

Lo encontró el agente revisor en la Fase 0 y es el fallo más silencioso del proyecto. Declara el target antes o a la vez que escribes el primer archivo, nunca después.

## Pasos

### 1. Crear las carpetas

```bash
mkdir -p Modules/Features/FeatureX/{Sources,Tests}
```

Un módulo con recursos lleva además `Resources/`. Hoy solo `KeepworthDesignSystem` la tiene.

### 2. Añadir la llamada en `Project.swift`

El helper `module(name:path:dependencies:resourceGlobs:)` crea el framework y su target de tests de una vez. Las dependencias son la aplicación literal de la tabla de `CLAUDE.md`:

```swift
+ module(
    name: "FeatureSummary",
    path: "Modules/Features/FeatureSummary",
    dependencies: [
        .target(name: "KeepworthDomain"),
        .target(name: "KeepworthDesignSystem"),
    ]
)
```

Y hay que añadirlo a la lista de `targets` del `Project(...)` del final, o el módulo no entra en el workspace.

**Si lleva recursos**, `resourceGlobs:` es **relativo al `path`**, no una ruta completa:

```swift
resourceGlobs: ["Resources/**"]
```

Por defecto está vacío a propósito: un glob que no casa con nada hace fallar la generación, así que no se pone «por si acaso».

### 3. Escribir un test desde el principio

Un target de tests sin un solo `@Test` compila y no avisa de nada. Swift Testing, nunca XCTest:

```swift
import Testing

@testable import FeatureSummary
```

Si el test construye una `View`, necesita `@MainActor`: en modo de lenguaje Swift 6, conformar a `View` aísla el inicializador al actor principal.

### 4. Regenerar y comprobar

Editar `Project.swift` dispara `.claude/hooks/regenerate-tuist.sh`, que ejecuta `tuist install` + `tuist generate`. **Si el hook falla, el manifiesto no compila** — el error sale en su salida y hay que arreglarlo ahí, no seguir.

Los archivos nuevos bajo un target ya declarado también necesitan una regeneración, porque la lista de archivos queda fijada en el `.xcodeproj`. Renombrar un archivo sin regenerar da `Build input file cannot be found`.

```bash
export PATH="$HOME/.local/share/mise/shims:$PATH"
tuist generate --no-open

tuist xcodebuild build -workspace Keepworth.xcworkspace \
  -scheme Keepworth-Workspace \
  -destination 'platform=iOS Simulator,name=iPhone 17'

xcodebuild test -workspace Keepworth.xcworkspace \
  -scheme Keepworth-Workspace \
  -destination 'platform=iOS Simulator,name=iPhone 17' | xcbeautify
```

El esquema es **`Keepworth-Workspace`**. El de `Keepworth` es el de la app y su acción de test está vacía: ejecuta cero tests sin decírtelo.

### 5. Comprobar que la ley de capas se cumple de verdad

```bash
grep -rh "^import" Modules/Features/FeatureX/Sources | sort -u
```

Contrasta con la tabla de `CLAUDE.md`. Un `import GRDB`, `import KeepworthPersistence` o `import CloudKit` en una feature es un error de arquitectura, no un atajo: si la feature necesita algo que no está en los protocolos de `Domain`, **se amplía el protocolo**.

### 6. Actualizar la documentación

- El árbol de `ESTADO.md` §2, que lista qué existe y qué no.
- El `CLAUDE.md` raíz § «Estructura» si el módulo estrena una categoría — por ejemplo, el primer `Modules/Features/`.
- Un `CLAUDE.md` propio si es un módulo Core, con el contrato de la capa.

## Trampas conocidas

- **`Tuist/Package.resolved` cambia su `originHash`** al regenerar, sin que se mueva ningún pin. Es ruido: déjalo fuera del commit salvo que cambie una versión de verdad.
- **Los accesores sintetizados de recursos están desactivados** en todo el proyecto (`disableSynthesizedResourceAccessors: true`), porque el de assets importa UIKit en el target dueño del catálogo. Sigue existiendo `Bundle.module`, que es solo Foundation. Consecuencia para la Fase 4: el String Catalog se lee con `String(localized:)`, **no** con un tipo `L10n` generado.
- **El CI dispara en `pull_request` y en `push` a `main`.** Empujar la rama sola no ejecuta nada.
