import ProjectDescription

// The Team ID is resolved when signing for a physical device; the simulator does not need it.
// Changing `bundleIdPrefix` means changing the App Group and the CloudKit container too, and
// registering all three again in the Apple Developer portal.
let bundleIdPrefix = "com.saleemsiddique.keepworth"
let appGroup = "group.com.saleemsiddique.keepworth"
let iCloudContainer = "iCloud.com.saleemsiddique.keepworth"

let deploymentTargets: DeploymentTargets = .iOS("26.0")
let destinations: Destinations = [.iPhone, .iPad]

// The Swift 6 language mode already implies complete strict concurrency, so
// `SWIFT_STRICT_CONCURRENCY` would be redundant here.
let baseSettings: SettingsDictionary = [
    "SWIFT_VERSION": "6.0",
    "SWIFT_TREAT_WARNINGS_AS_ERRORS": "YES",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
]

/// Declares a module as a framework with its own test target.
///
/// The `dependencies` list of each call is the literal application of the dependency law
/// documented in `CLAUDE.md`. If a feature needs GRDB, the mistake is in the design of the
/// feature, not here.
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

// Composition root: the only module allowed to know concrete implementations.
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

// The `KeepworthWidgets` target (product: .appExtension, NSExtensionPointIdentifier
// com.apple.widgetkit-extension) arrives in phase 7. It will depend on Domain,
// Persistence and DesignSystem: the single exception to the rule that only AppCore
// touches the data layer, because it reads the database shared through the App Group.
//
// Feature targets are added in phase 4, once they exist.

let project = Project(
    name: "Keepworth",
    organizationName: "Keepworth",
    targets: coreModules + appCore + [app]
)
