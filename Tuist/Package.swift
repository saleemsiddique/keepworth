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

// The only approved external dependency. Anything else is proposed to the user with
// alternatives before being installed (see CLAUDE.md).
let package = Package(
    name: "KeepworthDependencies",
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0")
    ]
)
