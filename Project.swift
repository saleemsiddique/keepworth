import ProjectDescription

// El Team ID se resuelve en el Mac al configurar el proyecto por primera vez.
// Cambiar `bundleIdPrefix` implica cambiar también el App Group y el contenedor de CloudKit.
let bundleIdPrefix = "com.keepworth"
let appGroup = "group.com.keepworth"
let iCloudContainer = "iCloud.com.keepworth"

let deploymentTargets: DeploymentTargets = .iOS("26.0")
let destinations: Destinations = [.iPhone, .iPad]

let baseSettings: SettingsDictionary = [
    "SWIFT_VERSION": "6.0",
    "SWIFT_STRICT_CONCURRENCY": "complete",
    "SWIFT_TREAT_WARNINGS_AS_ERRORS": "YES",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
]

/// Declara un módulo como framework con su target de tests asociado.
///
/// La lista de `dependencies` de cada llamada es la aplicación literal de la ley de
/// dependencias documentada en `CLAUDE.md`. Si una feature necesita GRDB, el error
/// está en el diseño de la feature, no aquí.
func module(
    name: String,
    path: String,
    dependencies: [TargetDependency] = []
) -> [Target] {
    [
        .target(
            name: name,
            destinations: destinations,
            product: .framework,
            bundleId: "\(bundleIdPrefix).\(name.lowercased())",
            deploymentTargets: deploymentTargets,
            sources: ["\(path)/Sources/**"],
            dependencies: dependencies,
            settings: .settings(base: baseSettings)
        ),
        .target(
            name: "\(name)Tests",
            destinations: destinations,
            product: .unitTests,
            bundleId: "\(bundleIdPrefix).\(name.lowercased()).tests",
            deploymentTargets: deploymentTargets,
            sources: ["\(path)/Tests/**"],
            dependencies: [.target(name: name)],
            settings: .settings(base: baseSettings)
        ),
    ]
}

let coreModules: [Target] =
    module(
        name: "KeepworthDomain",
        path: "Modules/Core/KeepworthDomain"
    )
    + module(
        name: "KeepworthPersistence",
        path: "Modules/Core/KeepworthPersistence",
        dependencies: [
            .target(name: "KeepworthDomain"),
            .external(name: "GRDB"),
        ]
    )
    + module(
        name: "KeepworthSync",
        path: "Modules/Core/KeepworthSync",
        dependencies: [
            .target(name: "KeepworthDomain"),
            .target(name: "KeepworthPersistence"),
        ]
    )
    + module(
        name: "KeepworthDesignSystem",
        path: "Modules/Core/KeepworthDesignSystem"
    )

// Composition root: el único módulo autorizado a conocer implementaciones concretas.
let appCore: [Target] = module(
    name: "KeepworthAppCore",
    path: "Modules/KeepworthAppCore",
    dependencies: [
        .target(name: "KeepworthDomain"),
        .target(name: "KeepworthPersistence"),
        .target(name: "KeepworthSync"),
        .target(name: "KeepworthDesignSystem"),
    ]
)

let app: Target = .target(
    name: "Keepworth",
    destinations: destinations,
    product: .app,
    bundleId: bundleIdPrefix,
    deploymentTargets: deploymentTargets,
    infoPlist: .extendingDefault(with: [
        "CFBundleDisplayName": "Keepworth",
        "UILaunchScreen": [:],
        "NSFaceIDUsageDescription":
            "Keepworth usa Face ID para que solo tú puedas ver tus finanzas.",
        "ITSAppUsesNonExemptEncryption": false,
    ]),
    sources: ["Apps/Keepworth/Sources/**"],
    entitlements: "Apps/Keepworth/Keepworth.entitlements",
    dependencies: [
        .target(name: "KeepworthAppCore")
    ],
    settings: .settings(base: baseSettings)
)

// El target `KeepworthWidgets` (product: .appExtension, NSExtensionPointIdentifier
// com.apple.widgetkit-extension) se añade en la Fase 7. Dependerá de Domain,
// Persistence y DesignSystem: es la única excepción a la regla de que solo AppCore
// toca la capa de datos, porque lee la base de datos compartida por App Group.
//
// Los targets de features se añaden en la Fase 4, cuando existan.

let project = Project(
    name: "Keepworth",
    organizationName: "Keepworth",
    targets: coreModules + appCore + [app]
)
