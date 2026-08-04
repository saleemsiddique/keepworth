// swift-tools-version: 6.0
import PackageDescription

#if TUIST
    import struct ProjectDescription.PackageSettings

    let packageSettings = PackageSettings(
        productTypes: [
            "GRDB": .framework
        ]
    )
#endif

// Única dependencia externa aprobada del proyecto. Cualquier añadido se propone
// al usuario con alternativas antes de instalarse (ver CLAUDE.md).
let package = Package(
    name: "KeepworthDependencies",
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0")
    ]
)
