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
///
/// `resourceGlobs` are relative to `path` and default to none: a glob matching nothing fails
/// generation, so a module without resources must not ask for them.
func module(
    name: String,
    path: String,
    dependencies: [TargetDependency] = [],
    resourceGlobs: [String] = []
) -> [Target] {
    let resources: ResourceFileElements? =
        resourceGlobs.isEmpty
        ? nil
        : .resources(resourceGlobs.map { .glob(pattern: "\(path)/\($0)") })

    return [
        .target(
            name: name,
            destinations: destinations,
            product: .framework,
            bundleId: "\(bundleIdPrefix).\(name.lowercased())",
            deploymentTargets: deploymentTargets,
            sources: ["\(path)/Sources/**"],
            resources: resources,
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
    // Its resources are the asset catalog: the seven semantic colours, each with a light and
    // a dark variant. The modules with text carry a String Catalog instead.
    + module(
        name: "KeepworthDesignSystem",
        path: "Modules/Core/KeepworthDesignSystem",
        resourceGlobs: ["Resources/**"]
    )

// One folder per feature. A feature talks to the protocols in `Domain` and draws with
// `DesignSystem`: it never sees `Persistence`, `Sync` or GRDB.
//
// `FeatureSupport` is the exception in shape but not in rights: it is a feature-layer module
// that holds what two screens both draw, and it may import exactly what a feature may.
let features: [Target] =
    module(
        name: "FeatureSupport",
        path: "Modules/Features/FeatureSupport",
        dependencies: [
            .target(name: "KeepworthDomain"),
            .target(name: "KeepworthDesignSystem"),
        ]
    )
    + module(
        name: "FeatureSummary",
        path: "Modules/Features/FeatureSummary",
        dependencies: [
            .target(name: "KeepworthDomain"),
            .target(name: "KeepworthDesignSystem"),
            .target(name: "FeatureSupport"),
        ],
        resourceGlobs: ["Resources/**"]
    )
    + module(
        name: "FeatureTransactions",
        path: "Modules/Features/FeatureTransactions",
        dependencies: [
            .target(name: "KeepworthDomain"),
            .target(name: "KeepworthDesignSystem"),
            .target(name: "FeatureSupport"),
        ],
        resourceGlobs: ["Resources/**"]
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
        .target(name: "FeatureSummary"),
        .target(name: "FeatureTransactions"),
    ],
    resourceGlobs: ["Resources/**"]
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
        // Read by `KeepworthAppCore` instead of being hardcoded there: the identifier already
        // has to match the entitlements file, and a third copy is a third place to drift.
        "KeepworthAppGroup": .string(appGroup),
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

// Synthesized asset accessors are off because Tuist's accessor imports UIKit into the target
// that owns the catalog, and `KeepworthDesignSystem` may import SwiftUI and nothing else. The
// option still leaves `Bundle.module`, which is Foundation only and is all `Colors.swift`
// needs. It applies to the whole project, so no target gets generated accessors for strings,
// assets or fonts: read the String Catalog with `String(localized:)`, not with an `L10n` type.
let project = Project(
    name: "Keepworth",
    organizationName: "Keepworth",
    options: .options(disableSynthesizedResourceAccessors: true),
    targets: coreModules + features + appCore + [app]
)
