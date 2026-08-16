---
name: add-color-token
description: Añade un token de color al design system de Keepworth tocando los cinco sitios que hay que sincronizar a mano — catálogo, Colors.swift, test, galería y las tablas de documentación. Úsalo también para cambiar el valor de un token existente.
---

# Añadir un token de color

Un token nuevo es una decisión de diseño, no un detalle de implementación: la paleta es corta a propósito. **Propónselo al usuario con sus dos valores antes de escribir nada**, y no lo añadas por iniciativa propia.

La regla de qué significa cada color está en `CLAUDE.md` § «Diseño». Esto son los pasos.

## Los cinco sitios, en orden

Nada de esto está automatizado. Saltarse uno no rompe el build: el fallo aparece renderizado, o no aparece nunca.

### 1. El Color Set

`Modules/Core/KeepworthDesignSystem/Resources/Tokens.xcassets/<nombre>.colorset/Contents.json`

Copia otro y cambia los componentes. Dos apariencias —la primera es la clara, la segunda lleva `luminosity/dark`—, `color-space: srgb`, componentes en hex de 8 bits y `alpha` a `1.000`:

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "0x2C", "green" : "0x38", "red" : "0xB3" }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "0x5E", "green" : "0x6B", "red" : "0xFF" }
      },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

**Sin la segunda apariencia el asset sigue cargando** y resuelve al valor claro en los dos temas. Por eso el test compara los dos.

### 2. `Modules/Core/KeepworthDesignSystem/Sources/Tokens/Colors.swift`

```swift
/// Para qué es, y para qué no. El comentario evita que el siguiente lo use de adorno.
public static var expense: Color { token("expense") }
```

La cadena tiene que coincidir con el nombre de la carpeta `.colorset`. `Color("typo", bundle:)` **nunca falla**: devuelve un color de relleno.

### 3. `Modules/Core/KeepworthDesignSystem/Tests/ColorTokenTests.swift`

Una línea en `colorTokens`, con los hex repetidos a mano:

```swift
ColorToken(name: "expense", light: 0xB3_382C, dark: 0xFF_6B5E),
```

Repetidos a propósito: un test que leyera el mismo `Contents.json` que el código no demostraría nada. El test comprueba tres cosas —que está en el bundle, que sus dos valores son los documentados, y que el alfa es 1— y es paramétrico, así que el token nuevo suma un caso solo.

### 4. `Modules/Core/KeepworthDesignSystem/Sources/Gallery/TokenGallery.swift`

Una entrada en `swatches`, para que el token se pueda mirar junto a los demás:

```swift
("expense", .expense),
```

El orden importa cuando dos tokens son una pareja: `accent` y `expense` van últimos y juntos, porque lo que hay que poder juzgar es que ninguno grita más que el otro.

### 5. Las tres tablas de documentación

Las tres tienen que decir lo mismo, con los mismos hex:

- `ESTADO.md` §7
- `Modules/Core/KeepworthDesignSystem/CLAUDE.md` § «Los N tokens»
- `CLAUDE.md` raíz § «Diseño» — ahí solo la lista de nombres

Y si el token cambia una **regla** —no solo añade un color—, hay un cuarto sitio que se olvida siempre: **`.claude/agents/architecture-reviewer.md`**. Es el agente que audita el diseño; si sus reglas se quedan viejas, denunciará como violación justo lo que se acaba de decidir. Ya pasó al añadir `expense`.

## Verificar

Contrasta las cuatro fuentes entre sí antes de dar por hecho que cuadran:

```bash
cd Modules/Core/KeepworthDesignSystem
echo "-- catálogo:"; ls Resources/Tokens.xcassets | grep colorset | sed 's/.colorset//' | sort | tr '\n' ' '; echo
echo "-- Colors.swift:"; grep -oE 'public static var [a-zA-Z]+' Sources/Tokens/Colors.swift | awk '{print $4}' | sort | tr '\n' ' '; echo
echo "-- tests:"; grep -oE 'name: "[a-zA-Z]+"' Tests/ColorTokenTests.swift | sed 's/name: //;s/"//g' | sort | tr '\n' ' '; echo
echo "-- galería:"; grep -oE '\("[a-zA-Z]+", \.' Sources/Gallery/TokenGallery.swift | sed 's/("//;s/", .//' | sort | tr '\n' ' '; echo
```

Las cuatro líneas tienen que salir idénticas. Después, los tests:

```bash
export PATH="$HOME/.local/share/mise/shims:$PATH"
tuist generate --no-open
xcodebuild test -workspace Keepworth.xcworkspace -scheme Keepworth-Workspace \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:KeepworthDesignSystemTests
```

Y pídele al usuario que mire `TokenGallery` en el canvas de Xcode en ambos temas: el contraste real no se deduce de un hex.

## Cambiar el valor de un token existente

Mismos sitios 1, 3 y 5. El test fallará hasta que actualices el hex, y esa es la señal de que está haciendo su trabajo. Ojo con el efecto dominó: cambiar `ink` o `bg` afecta a todas las pantallas, así que el repaso visual deja de ser opcional.
