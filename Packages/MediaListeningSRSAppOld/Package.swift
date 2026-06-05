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
    PackageDependency.ElixirSync.packageDependency,
    PackageDependency.SwiftTagged.packageDependency,
    PackageDependency.SwiftCustomDump.packageDependency,
    PackageDependency.IdentifiedCollections.packageDependency,
    PackageDependency.GRDB.packageDependency,
    PackageDependency.JapaneseMediaLibrary.packageDependency,
    PackageDependency.MediaWordBankTagger.packageDependency,
    PackageDependency.NyanimeSharedAnimeClipDatabase.packageDependency,
    PackageDependency.iYomi.packageDependency,

    PackageDependency.Firebase.packageDependency,
//    PackageDependency.Lottie.packageDependency,
//    PackageDependency.Superwall.packageDependency,
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
  case CandidateDetailScene
  case ClipExportService
  case ClipStorageClient
  case FSRS
  case HomeScene
  case MediaListeningSRSApp
  case MediaListeningSRSDatabaseClient
  case MediaListeningSRSDatabaseClientGRDB
  case MediaSourceImportEpisodePickerScene
  case MediaSourceImportPickerScene
  case MediaSourceImportService
  case MediaSourcesListScene
  case ProcessingQueueScene
  case SettingsScene
  case SRSCardReviewScene
  case Shared
  case StudyStatsScene
  case SharedModels
  case WordsListScene

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
          .ClipExportService,
          .ClipStorageClient,
          .MediaListeningSRSDatabaseClient,
          .MediaListeningSRSDatabaseClientGRDB,
          .MediaSourceImportService,
          .Shared,
          .SharedModels
        ) + [
          PackageDependency.ElixirShared.Product.ElixirShared.targetDependency,
          PackageDependency.JapaneseMediaLibrary.Product.JMLDatabaseClient.targetDependency,
          PackageDependency.JapaneseMediaLibrary.Product.JMLDatabaseClientGRDB.targetDependency,
          PackageDependency.MediaWordBankTagger.Product.METGDatabaseClient.targetDependency,
          PackageDependency.MediaWordBankTagger.Product.METGDatabaseClientGRDB.targetDependency,
          PackageDependency.NyanimeSharedAnimeClipDatabase.Product.SharedAnimeClipDatabase.targetDependency,
          PackageDependency.iYomi.Product.DictionaryClient.targetDependency,
          PackageDependency.iYomi.Product.JapaneseParserClient.targetDependency,
          PackageDependency.ElixirSync.Product.ElixirSyncClient.targetDependency,
          PackageDependency.ElixirSync.Product.ElixirSyncClientFirebase.targetDependency,
        ],
        resources: [.copy("Resources/dictionary.sqlite")]
      )

    case .AppSceneDelegate:
      return createPackageTarget(
        dependencies: createTargetDependencies(
          .AppDependencies,
          .ClipStorageClient,
          .HomeScene,
          .MediaSourceImportService,
          .MediaSourcesListScene,
          .Shared,
          .SharedModels,
          .StudyStatsScene,
          .WordsListScene
        ) + [
          PackageDependency.ElixirSync.Product.ElixirSyncClient.targetDependency,
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

    case .MediaListeningSRSDatabaseClient:
      return createPackageTarget(
        dependencies: createTargetDependencies(
          .Shared,
          .SharedModels
        ) + [
          PackageDependency.SwiftTagged.Product.tagged.targetDependency,
        ]
      )

    case .MediaListeningSRSDatabaseClientGRDB:
      return createPackageTarget(
        dependencies: createTargetDependencies(
          .FSRS,
          .MediaListeningSRSDatabaseClient,
          .Shared,
          .SharedModels
        ) + [
          PackageDependency.GRDB.Product.GRDB.targetDependency,
          PackageDependency.JapaneseMediaLibrary.Product.JMLSharedModels.targetDependency,
        ]
      )

    case .MediaSourceImportService:
      return createPackageTarget(
        dependencies: createTargetDependencies(
          .MediaListeningSRSDatabaseClient,
          .Shared,
          .SharedModels
        ) + [
          PackageDependency.ElixirShared.Product.ElixirShared.targetDependency,
          PackageDependency.JapaneseMediaLibrary.Product.JMLDatabaseClient.targetDependency,
          PackageDependency.JapaneseMediaLibrary.Product.JMLSharedModels.targetDependency,
          PackageDependency.MediaWordBankTagger.Product.METGDatabaseClient.targetDependency,
          PackageDependency.iYomi.Product.JapaneseParserClient.targetDependency,
        ]
      )

    case .CandidateDetailScene:
      return createPackageTarget(
        dependencies: createTargetDependencies(
          .ClipExportService,
          .ClipStorageClient,
          .MediaListeningSRSDatabaseClient,
          .Shared,
          .SharedModels
        ) + [
          PackageDependency.ElixirShared.Product.ElixirShared.targetDependency,
          PackageDependency.JapaneseMediaLibrary.Product.JMLDatabaseClient.targetDependency,
          PackageDependency.JapaneseMediaLibrary.Product.JMLSharedModels.targetDependency,
          PackageDependency.MediaWordBankTagger.Product.METGDatabaseClient.targetDependency,
          PackageDependency.MediaWordBankTagger.Product.SharedModels.targetDependency,
          PackageDependency.iYomi.Product.DictionaryClient.targetDependency,
          PackageDependency.iYomi.Product.DictionaryModels.targetDependency,
        ]
      )

    case .ClipExportService:
      return createPackageTarget(
        dependencies: createTargetDependencies(
          .SharedModels
        ) + [
        ]
      )

    case .ClipStorageClient:
      return createPackageTarget(
        dependencies: createTargetDependencies(
        ) + [
          PackageDependency.Firebase.Product.FirebaseStorage.targetDependency,
        ]
      )

    case .FSRS:
      return createPackageTarget(
        dependencies: createTargetDependencies(
        ) + [
        ]
      )

    case .MediaSourceImportEpisodePickerScene:
      return createPackageTarget(
        dependencies: createTargetDependencies(
          .MediaSourceImportService,
          .SharedModels
        ) + [
          PackageDependency.JapaneseMediaLibrary.Product.JMLDatabaseClient.targetDependency,
          PackageDependency.JapaneseMediaLibrary.Product.JMLSharedModels.targetDependency,
          PackageDependency.MediaWordBankTagger.Product.METGDatabaseClient.targetDependency,
        ]
      )

    case .MediaSourceImportPickerScene:
      return createPackageTarget(
        dependencies: createTargetDependencies(
          .MediaSourceImportEpisodePickerScene,
          .MediaSourceImportService,
          .SharedModels
        ) + [
          PackageDependency.JapaneseMediaLibrary.Product.JMLDatabaseClient.targetDependency,
          PackageDependency.JapaneseMediaLibrary.Product.JMLSharedModels.targetDependency,
          PackageDependency.MediaWordBankTagger.Product.METGDatabaseClient.targetDependency,
        ]
      )

    case .MediaSourcesListScene:
      return createPackageTarget(
        dependencies: createTargetDependencies(
          .MediaListeningSRSDatabaseClient,
          .MediaSourceImportPickerScene,
          .ProcessingQueueScene,
          .SettingsScene,
          .SharedModels,
          .SRSCardReviewScene
        ) + [
          PackageDependency.ElixirSync.Product.ElixirSyncClient.targetDependency,
          PackageDependency.JapaneseMediaLibrary.Product.JMLDatabaseClient.targetDependency,
          PackageDependency.JapaneseMediaLibrary.Product.JMLSharedModels.targetDependency,
          PackageDependency.iYomi.Product.JapaneseParserClient.targetDependency,
        ]
      )

    case .ProcessingQueueScene:
      return createPackageTarget(
        dependencies: createTargetDependencies(
          .CandidateDetailScene,
          .ClipExportService,
          .MediaListeningSRSDatabaseClient,
          .Shared,
          .SharedModels
        ) + [
          PackageDependency.ElixirShared.Product.ElixirShared.targetDependency,
          PackageDependency.JapaneseMediaLibrary.Product.JMLDatabaseClient.targetDependency,
          PackageDependency.JapaneseMediaLibrary.Product.JMLSharedModels.targetDependency,
          PackageDependency.MediaWordBankTagger.Product.METGDatabaseClient.targetDependency,
          PackageDependency.iYomi.Product.DictionaryClient.targetDependency,
          PackageDependency.iYomi.Product.JapaneseParserClient.targetDependency,
        ]
      )

    case .SettingsScene:
      return createPackageTarget(
        dependencies: createTargetDependencies(
          .MediaListeningSRSDatabaseClient,
          .Shared
        ) + [
          PackageDependency.ElixirSync.Product.ElixirSyncClient.targetDependency,
        ]
      )

    case .SRSCardReviewScene:
      return createPackageTarget(
        dependencies: createTargetDependencies(
          .ClipExportService,
          .ClipStorageClient,
          .MediaListeningSRSDatabaseClient,
          .Shared,
          .SharedModels
        ) + [
          PackageDependency.iYomi.Product.DictionaryClient.targetDependency,
          PackageDependency.iYomi.Product.DictionaryModels.targetDependency,
          PackageDependency.iYomi.Product.DictionaryUIKit.targetDependency,
          PackageDependency.iYomi.Product.JapaneseParserClient.targetDependency,
          PackageDependency.iYomi.Product.JapaneseModels.targetDependency,
        ]
      )

    case .Shared:
      return createPackageTarget(
        dependencies: createTargetDependencies(
        ) + [
          PackageDependency.ElixirShared.Product.ElixirShared.targetDependency,
          PackageDependency.SwiftTagged.Product.tagged.targetDependency,
          PackageDependency.IdentifiedCollections.Product.identifiedCollections.targetDependency,
          PackageDependency.iYomi.Product.DictionaryClient.targetDependency,
          PackageDependency.iYomi.Product.DictionaryModels.targetDependency,
          PackageDependency.iYomi.Product.DictionaryUIKit.targetDependency,
          PackageDependency.iYomi.Product.JapaneseModels.targetDependency,
          PackageDependency.iYomi.Product.JapaneseTextClient.targetDependency,
        ],
        resources: [.process("Resources")]
      )

    case .StudyStatsScene:
      return createPackageTarget(
        dependencies: createTargetDependencies(
          .MediaListeningSRSDatabaseClient,
          .SharedModels
        ) + [
        ]
      )

    case .SharedModels:
      return createPackageTarget(
        dependencies: createTargetDependencies(
          .Shared
        ) + [
          PackageDependency.SwiftTagged.Product.tagged.targetDependency,
          PackageDependency.IdentifiedCollections.Product.identifiedCollections.targetDependency,
          PackageDependency.JapaneseMediaLibrary.Product.JMLSharedModels.targetDependency,
          PackageDependency.iYomi.Product.JapaneseModels.targetDependency,
        ]
      )

    case .WordsListScene:
      return createPackageTarget(
        dependencies: createTargetDependencies(
          .MediaListeningSRSDatabaseClient,
          .Shared,
          .SharedModels
        ) + [
          PackageDependency.iYomi.Product.DictionaryClient.targetDependency,
          PackageDependency.iYomi.Product.DictionaryModels.targetDependency,
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

// MARK: - ElixirSync
extension PackageDependency {

  enum ElixirSync {
    static let package = "ElixirSyncApp"

    static var packageDependency: Package.Dependency {
      .package(
        url: "file:///Users/annguyen/Documents/2. Areas/Xcode Projects/ElixirSync/Packages/ElixirSyncApp",
        branch: "main"
      )
    }

    enum Product: String {
      case ElixirSyncClient = "SYNC.ElixirSyncClient"
      case ElixirSyncClientFirebase = "SYNC.ElixirSyncClientFirebase"

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

// MARK: - JapaneseMediaLibrary
extension PackageDependency {

  enum JapaneseMediaLibrary {
    static let package = "JapaneseMediaLibraryApp"

    static var packageDependency: Package.Dependency {
      .package(
        url: "file:///Users/annguyen/Documents/2. Areas/Xcode Projects/JapaneseMediaLibrary/Packages/JapaneseMediaLibraryApp",
        branch: "main"
      )
    }

    enum Product: String {
      case JMLDatabaseClient
      case JMLDatabaseClientGRDB
      case JMLSharedModels
      case SceneDelegate

      var targetDependency: Target.Dependency {
        .product(name: "JML." + self.rawValue, package: package)
      }
    }
  }

}

// MARK: - MediaWordBankTagger
extension PackageDependency {

  enum MediaWordBankTagger {
    static let package = "MediaWordBankTaggerApp"

    static var packageDependency: Package.Dependency {
      .package(
        url: "file:///Users/annguyen/Documents/2. Areas/Xcode Projects/MediaWordBankTagger/Packages/MediaWordBankTaggerApp",
        branch: "main"
      )
    }

    enum Product: String {
      case METGDatabaseClient
      case METGDatabaseClientGRDB
      case SharedModels

      var targetDependency: Target.Dependency {
        .product(name: "METG." + self.rawValue, package: package)
      }
    }
  }

}

// MARK: - NyanimeSharedAnimeClipDatabase
extension PackageDependency {

  enum NyanimeSharedAnimeClipDatabase {
    static let package = "NyanimeSharedAnimeClipDatabase"

    static var packageDependency: Package.Dependency {
      .package(
        url: "file:///Users/annguyen/Documents/2. Areas/Xcode Projects/NyanimeSharedAnimeClipDatabase/Packages/NyanimeSharedAnimeClipDatabase",
        branch: "main"
      )
    }

    enum Product: String {
      case SharedAnimeClipDatabase
      case RemoteStorageClient

      var targetDependency: Target.Dependency {
        .product(name: "NYAN." + self.rawValue, package: package)
      }
    }
  }

}

// MARK: - iYomi
extension PackageDependency {

  enum iYomi {
    static let package = "iYomi"

    static var packageDependency: Package.Dependency {
      .package(
        url: "file:///Users/annguyen/Documents/2. Areas/Xcode Projects/iYomi/Packages/iYomi",
        branch: "main"
      )
    }

    enum Product: String {
      case DictionaryClient
      case DictionaryLookupClient
      case DictionaryModels
      case DictionaryUIKit
      case DeinflectionClient
      case JapaneseModels
      case JapaneseParserClient
      case JapaneseTextClient

      var targetDependency: Target.Dependency {
        .product(name: "IYO." + self.rawValue, package: package)
      }
    }
  }

}
