// swift-tools-version: 6.1

import PackageDescription

let package = Package(
  name: "MediaListeningSRSApp",
  platforms: [
    .iOS(.v18),
    .macOS(.v13)
  ],
  products: PackageTarget.allProducts,
  dependencies: [
    PackageDependency.ComposableArchitecture.packageDependency,
    PackageDependency.ElixirShared.packageDependency,
    PackageDependency.SwiftTagged.packageDependency,
    PackageDependency.SwiftCustomDump.packageDependency,
    PackageDependency.IdentifiedCollections.packageDependency,

    // Pre-stubbed but inactive — uncomment to activate.
//    PackageDependency.Firebase.packageDependency,
//    PackageDependency.Lottie.packageDependency,
//    PackageDependency.Superwall.packageDependency,
//    PackageDependency.GRDB.packageDependency,
//    PackageDependency.SQLiteSwift.packageDependency,
//    PackageDependency.SwiftLint.packageDependency,
//    PackageDependency.Quick.packageDependency,
//    PackageDependency.Nimble.packageDependency,
  ],
  targets: PackageTarget.allTargets
)


// MARK: - PackageTarget
enum PackageTarget: String, CaseIterable {

  private static let testCases: [Self] = [
    .SharedModelsTests
  ]

  static var allProducts: [Product] {
    allCases.filter { !testCases.contains($0) }
      .map(\.product)
  }

  static var allTargets: [Target] {
    allCases.map(\.target)
  }

  // MARK: Cases

  case AppDependencies
  case AppSceneDelegate
  case HomeScene
  case MediaListeningSRSApp
  case Shared
  case SharedModels

  // Tests
  case SharedModelsTests


  private var name: String {
    let packagePrefix = "MSRS"
    return packagePrefix + "." + self.rawValue
  }

  var product: Product {
    .library(name: name, targets: [name])
  }

  var targetDependency: Target.Dependency {
    .init(stringLiteral: name)
  }

  // MARK: Target
  var target: Target {
    switch self {

    case .AppDependencies:
      return createPackageTarget(
        dependencies: createTargetDependencies(
          .Shared,
          .SharedModels
        ) + [
          PackageDependency.ElixirShared.Product.ElixirShared.targetDependency,
        ]
      )

    case .AppSceneDelegate:
      return createPackageTarget(
        dependencies: createTargetDependencies(
          .AppDependencies,
          .HomeScene,
          .Shared,
          .SharedModels
        ) + [
        ]
      )

    case .HomeScene:
      return createPackageTarget(
        dependencies: createTargetDependencies(
          .Shared,
          .SharedModels
        ) + [
        ]
      )

    case .MediaListeningSRSApp:
      return createPackageTarget(
        dependencies: createTargetDependencies(
        ) + [
        ]
      )

    case .Shared:
      return createPackageTarget(
        dependencies: createTargetDependencies(
        ) + [
          PackageDependency.ElixirShared.Product.ElixirShared.targetDependency,
          PackageDependency.SwiftTagged.Product.tagged.targetDependency,
          PackageDependency.IdentifiedCollections.Product.identifiedCollections.targetDependency,
        ]
      )

    case .SharedModels:
      return createPackageTarget(
        dependencies: createTargetDependencies(
          .Shared
        ) + [
          PackageDependency.SwiftTagged.Product.tagged.targetDependency,
          PackageDependency.IdentifiedCollections.Product.identifiedCollections.targetDependency,
        ]
      )

    case .SharedModelsTests:
      return createPackageTestTarget(
        dependencies: createTargetDependencies(
          .SharedModels
        )
      )

    }
  }

  // MARK: Helpers

  private func createTargetDependencies(
    _ packageTargets: PackageTarget...
  ) -> [Target.Dependency] {
    packageTargets.map(\.targetDependency)
  }

  private func createPackageTarget(
    dependencies: [Target.Dependency] = [],
    resources: [Resource]? = nil,
    plugins: [Target.PluginUsage] = []
  ) -> Target {

    return Target.target(
      name: self.name,
      dependencies: dependencies,
      resources: resources,
      swiftSettings: [
        .unsafeFlags([
          "-driver-time-compilation",
          "-Xfrontend",
          "-debug-time-function-bodies",
          "-Xfrontend",
          "-debug-time-expression-type-checking",
          "-Xfrontend",
          "-warn-long-function-bodies=100",
          "-Xfrontend",
          "-warn-long-expression-type-checking=100",
          "-Xfrontend",
          "-enable-experimental-concurrency"
        ])
      ],
      plugins: []
    )
  }

  private func createPackageTestTarget(
    dependencies: [Target.Dependency]
  ) -> Target {
    var dependencies = dependencies
    dependencies += [
      PackageDependency.SwiftCustomDump.Product.customDump.targetDependency
    ]

    return .testTarget(
      name: self.name,
      dependencies: dependencies
    )
  }

}

// MARK: - PackageDependency
enum PackageDependency {

  // MARK: Helper
  static func localPackageDependency(_ name: String) -> Package.Dependency {
    .package(name: name, path: "../\(name)")
  }

}

// MARK: - ComposableArchitecture
extension PackageDependency {

  enum ComposableArchitecture {
    static let package = "swift-composable-architecture"
    static var packageDependency: Package.Dependency {
      .package(
        url: "https://github.com/pointfreeco/swift-composable-architecture",
        exact: "1.20.2"
      )
    }

    enum Product: String {
      case composableArchitecture = "ComposableArchitecture"

      var targetDependency: Target.Dependency {
        .product(name: self.rawValue, package: package)
      }
    }
  }

}

// MARK: - ElixirShared
extension PackageDependency {

  enum ElixirShared {
    static let package = "ElixirShared"

    static var packageDependency: Package.Dependency {
      .package(
        url: "file:///Users/annguyen/Documents/2. Areas/Xcode Projects/Genesis/Packages/ElixirShared",
        branch: "main"
      )
    }

    enum Product: String {
      case ElixirShared
      case YouTubeDLWorker
      case YouTubeDLWorkerLive

      var targetDependency: Target.Dependency {
        .product(name: self.rawValue, package: package)
      }
    }

  }

}

// MARK: - SwiftTagged
extension PackageDependency {

  enum SwiftTagged {
    static let package = "swift-tagged"

    static var packageDependency: Package.Dependency {
      .package(
        url: "https://github.com/pointfreeco/swift-tagged",
        exact: "0.10.0"
      )
    }

    enum Product: String {
      case tagged = "Tagged"

      var targetDependency: Target.Dependency {
        .product(name: self.rawValue, package: package)
      }
    }
  }

}

// MARK: - SwiftCustomDump
extension PackageDependency {

  enum SwiftCustomDump {
    static let package = "swift-custom-dump"
    static var packageDependency: Package.Dependency {
      .package(
        url: "https://github.com/pointfreeco/swift-custom-dump",
        exact: "1.3.3"
      )
    }

    enum Product: String {
      case customDump = "CustomDump"

      var targetDependency: Target.Dependency {
        .product(name: self.rawValue, package: package)
      }
    }
  }

}

// MARK: - IdentifiedCollections
extension PackageDependency {

  enum IdentifiedCollections {
    static let package = "swift-identified-collections"
    static var packageDependency: Package.Dependency {
      .package(
        url: "https://github.com/pointfreeco/swift-identified-collections",
        exact: "1.1.1"
      )
    }

    enum Product: String {
      case identifiedCollections = "IdentifiedCollections"

      var targetDependency: Target.Dependency {
        .product(name: self.rawValue, package: package)
      }
    }
  }

}

// MARK: - Firebase
extension PackageDependency {

  enum Firebase {
    static let package = "firebase-ios-sdk"
    static var packageDependency: Package.Dependency {
      .package(
        url: "https://github.com/firebase/firebase-ios-sdk",
        from: "11.0.0"
      )
    }

    enum Product: String {
      case FirebaseAnalytics
      case FirebaseAuth
      case FirebaseRemoteConfig
      case FirebaseCrashlytics
      case FirebasePerformance
      case FirebaseFirestore
      case FirebaseStorage
      case FirebaseFunctions

      var targetDependency: Target.Dependency {
        .product(name: self.rawValue, package: package)
      }
    }
  }

}

// MARK: - Lottie
extension PackageDependency {

  enum Lottie {
    static let package = "lottie-ios"
    static var packageDependency: Package.Dependency {
      .package(
        url: "https://github.com/airbnb/lottie-ios",
        from: "4.4.3"
      )
    }

    enum Product: String {
      case lottie = "Lottie"

      var targetDependency: Target.Dependency {
        .product(name: self.rawValue, package: package)
      }
    }
  }

}

// MARK: - Superwall
extension PackageDependency {

  enum Superwall {
    static let package = "Superwall-iOS"
    static var packageDependency: Package.Dependency {
      .package(
        url: "https://github.com/superwall/Superwall-iOS",
        from: "3.6.6"
      )
    }

    enum Product: String {
      case SuperwallKit

      var targetDependency: Target.Dependency {
        .product(name: self.rawValue, package: package)
      }
    }
  }

}

// MARK: - GRDB
extension PackageDependency {

  enum GRDB {
    static let package = "GRDB.swift"
    static var packageDependency: Package.Dependency {
      .package(
        url: "https://github.com/groue/GRDB.swift",
        exact: "7.5.0"
      )
    }

    enum Product: String {
      case GRDB
      case GRDBDynamic = "GRDB-dynamic"

      var targetDependency: Target.Dependency {
        .product(name: self.rawValue, package: package)
      }
    }
  }

}

// MARK: - SQLiteSwift
extension PackageDependency {

  enum SQLiteSwift {
    static let package = "SQLite.swift"
    static var packageDependency: Package.Dependency {
      .package(
        url: "https://github.com/stephencelis/SQLite.swift",
        exact: "0.15.5",
        traits: ["SQLCipher"]
      )
    }

    enum Product: String {
      case SQLite

      var targetDependency: Target.Dependency {
        .product(name: self.rawValue, package: package)
      }
    }
  }

}

// MARK: - SwiftLint
extension PackageDependency {

  enum SwiftLint {
    static let package = "SwiftLint"

    static var packageDependency: Package.Dependency {
      .package(
        url: "https://github.com/realm/SwiftLint",
        from: "0.51.0"
      )
    }

    enum Plugin: String {
      case swiftLintPlugin = "SwiftLintPlugin"

      var plugin: Target.PluginUsage {
        .plugin(name: self.rawValue, package: package)
      }
    }
  }

}

// MARK: - Quick
extension PackageDependency {

  enum Quick {
    static let package = "Quick"
    static var packageDependency: Package.Dependency {
      .package(
        url: "https://github.com/Quick/Quick",
        from: "6.0.0"
      )
    }

    enum Product: String {
      case quick = "Quick"

      var targetDependency: Target.Dependency {
        .product(name: self.rawValue, package: package)
      }
    }
  }

}

// MARK: - Nimble
extension PackageDependency {

  enum Nimble {
    static let package = "Nimble"
    static var packageDependency: Package.Dependency {
      .package(
        url: "https://github.com/Quick/Nimble",
        from: "12.0.0"
      )
    }

    enum Product: String {
      case nimble = "Nimble"

      var targetDependency: Target.Dependency {
        .product(name: self.rawValue, package: package)
      }
    }
  }

}
