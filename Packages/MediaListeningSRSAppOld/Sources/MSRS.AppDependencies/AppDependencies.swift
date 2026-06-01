import Foundation
import ElixirShared
import MSRS_ClipExportService
import MSRS_FSRS
import MSRS_MediaListeningSRSDatabaseClient
import MSRS_MediaListeningSRSDatabaseClientGRDB
import MSRS_MediaSourceImportService
import MSRS_Shared
import JML_JMLDatabaseClient
import JML_JMLDatabaseClientGRDB
import METG_METGDatabaseClient
import METG_METGDatabaseClientGRDB
import IYO_DictionaryClient
import IYO_JapaneseParserClient
import NYAN_SharedAnimeClipDatabase

public struct AppDependencies:
  HasClipExportService,
  HasDictionaryClient,
  HasExportedClipsDirectoryURL,
  HasJMLDatabaseClient,
  HasMediaListeningSRSDatabaseClient,
  HasMediaSourceImportService,
  HasJapaneseParserClient,
  HasMETGDatabaseClient,
  HasSRTParserClient
{

  public let mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient
  public let mediaSourceImportService: MediaSourceImportService
  public let clipExportService: ClipExportService
  public let japaneseParserClient: JapaneseParserClient
  public let srtParserClient: SRTParserClient

  public let jmlDatabaseClient: JMLDatabaseClient
  public let metgDatabaseClient: METGDatabaseClient
  public let dictionaryClient: DictionaryClient

  public let exportedClipsDirectoryURL: URL

  public init() {
    let appDataDirectoryURL = Self.createAndReturnAppDataDirectoryURL()
    let databaseFileURL = appDataDirectoryURL
      .appendingPathComponent("database.sqlite", isDirectory: false)
    self.exportedClipsDirectoryURL = Self.exportedClipsDirectoryURL()

    self.mediaListeningSRSDatabaseClient = .grdbValue(
      configuration: .file(path: databaseFileURL.path),
      fsrsParameters: FSRSParameters()
    )

    self.dictionaryClient = .sqliteValue(
      databasePath: NyanimeDBConstants.dictionaryDatabasePath
    )

    self.jmlDatabaseClient = .grdbValue(
      configuration: .file(path: NyanimeDBConstants.jmlDatabasePath)
    )

    self.metgDatabaseClient = .grdbValue(
      configuration: .file(path: NyanimeDBConstants.metgDatabasePath),
      jmlDatabaseClient: self.jmlDatabaseClient,
      dictionaryClient: self.dictionaryClient
    )

    self.srtParserClient = .liveValue()

    self.japaneseParserClient = .liveValue(
      dictionaryClient: self.dictionaryClient
    )

    self.mediaSourceImportService = .liveValue(
      jmlDatabaseClient: self.jmlDatabaseClient,
      metgDatabaseClient: self.metgDatabaseClient,
      mediaListeningSRSDatabaseClient: self.mediaListeningSRSDatabaseClient,
      srtParserClient: self.srtParserClient,
      japaneseParserClient: self.japaneseParserClient
    )

    self.clipExportService = .avFoundationValue()
  }

  // MARK: - App data directory

  public static let appDataDirectoryName = "MediaListeningSRS"
  public static let exportedClipsSubdirectoryName = "clips"

  public static func appDataDirectoryURL() -> URL {
    let fileManager = FileManager.default
    guard let documentsURL = fileManager.urls(
      for: .documentDirectory,
      in: .userDomainMask
    ).first else {
      fatalError("AppDependencies: could not locate the user's Documents directory")
    }
    return documentsURL.appendingPathComponent(appDataDirectoryName, isDirectory: true)
  }

  public static func exportedClipsDirectoryURL() -> URL {
    return appDataDirectoryURL()
      .appendingPathComponent(exportedClipsSubdirectoryName, isDirectory: true)
  }

  private static func createAndReturnAppDataDirectoryURL() -> URL {
    let directoryURL = appDataDirectoryURL()
    let clipsDirectoryURL = exportedClipsDirectoryURL()
    let fileManager = FileManager.default
    do {
      try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
      try fileManager.createDirectory(at: clipsDirectoryURL, withIntermediateDirectories: true)
    } catch {
      fatalError("AppDependencies: could not create app data directory: \(error)")
    }
    return directoryURL
  }

}
