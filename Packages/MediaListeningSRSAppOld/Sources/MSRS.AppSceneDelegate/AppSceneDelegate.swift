import UIKit
import JML_JMLDatabaseClient
import MSRS_AppDependencies
import MSRS_ClipExportService
import MSRS_ClipStorageClient
import MSRS_MediaSourceImportService
import MSRS_MediaSourcesListScene
import MSRS_Shared
import MSRS_StudyStatsScene
import MSRS_WordsListScene
import SYNC_ElixirSyncClient

open class AppSceneDelegate: UIResponder, UIWindowSceneDelegate {

  public var window: UIWindow?

  public var dependencies: AppDependencies!

  private var isSyncOperationInProgress = false
  private var periodicSyncTimer: Timer?

  public override init() {
    super.init()
  }

  open func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { fatalError() }

    loadAppSettings()
    migrateUserDefaultsToSQLiteIfNeeded()
    buildAndSetRootViewController(windowScene: windowScene)

    startSyncListener()
    startPeriodicSyncTimer()
    observeAppLifecycleNotifications()
    performInitialSyncThenMaintenance()
    setupGlobalHotkeys()
    setupFloatingWindow()
  }

  open func sceneDidBecomeActive(_ scene: UIScene) {
    handleAppDidBecomeActive()
    applyFloatingWindowSetting()
  }

  open func sceneWillResignActive(_ scene: UIScene) {
    handleAppWillResignActive()
  }

  private func observeAppLifecycleNotifications() {
    #if targetEnvironment(macCatalyst)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidBecomeActiveNotification),
      name: NSNotification.Name("NSApplicationDidBecomeActiveNotification"),
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appWillResignActiveNotification),
      name: NSNotification.Name("NSApplicationWillResignActiveNotification"),
      object: nil
    )
    #else
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidBecomeActiveNotification),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appWillResignActiveNotification),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    #endif
  }

  @objc private func appDidBecomeActiveNotification() {
    handleAppDidBecomeActive()
  }

  @objc private func appWillResignActiveNotification() {
    handleAppWillResignActive()
  }

  private func handleAppDidBecomeActive() {
    performSyncCheck()
    startPeriodicSyncTimer()
  }

  private func handleAppWillResignActive() {
    periodicSyncTimer?.invalidate()
    periodicSyncTimer = nil
    performSyncCheck()
  }

  // MARK: - Root view controller

  private func buildAndSetRootViewController(windowScene: UIWindowScene) {
    let mediaSourcesVC = MediaSourcesListVC(dependencies: dependencies)
    let mediaNav = UINavigationController(rootViewController: mediaSourcesVC)
    mediaNav.tabBarItem = UITabBarItem(title: "Media", image: UIImage(systemName: "film"), tag: 0)

    let wordsListVC = WordsListVC(dependencies: dependencies)
    let wordsNav = UINavigationController(rootViewController: wordsListVC)
    wordsNav.tabBarItem = UITabBarItem(title: "Words", image: UIImage(systemName: "textformat.abc"), tag: 1)

    let studyStatsVC = StudyStatsVC(dependencies: dependencies)
    let statsNav = UINavigationController(rootViewController: studyStatsVC)
    statsNav.tabBarItem = UITabBarItem(title: "Stats", image: UIImage(systemName: "chart.bar"), tag: 2)

    let tabBarController = UITabBarController()
    tabBarController.viewControllers = [mediaNav, wordsNav, statsNav]

    if let existingWindow = window {
      existingWindow.rootViewController = tabBarController
    } else {
      let window = UIWindow(windowScene: windowScene)
      window.rootViewController = tabBarController
      window.makeKeyAndVisible()
      self.window = window
    }
  }

  // MARK: - Startup maintenance

  private var hasRunStartupMaintenance = false

  private func performInitialSyncThenMaintenance() {
    guard !isSyncOperationInProgress else { return }
    isSyncOperationInProgress = true
    SyncStatusTracker.status = .checking

    dependencies.elixirSyncClient.checkSync { [weak self] result in
      DispatchQueue.main.async {
        guard let self else { return }
        SyncStatusTracker.lastSyncCheckDate = Date()
        switch result {
        case .failure(let error):
          print("[ElixirSync] initial checkSync error: \(error)")
          SyncStatusTracker.status = .error(error.localizedDescription)
          self.isSyncOperationInProgress = false
          self.runStartupMaintenanceOnce()
        case .success(let response):
          switch response.status {
          case .inSync:
            SyncStatusTracker.status = .inSync
            self.isSyncOperationInProgress = false
            self.runStartupMaintenanceOnce()
          case .localNewer:
            SyncStatusTracker.status = .localNewer
            self.pushLocalChanges()
            self.runStartupMaintenanceOnce()
          case .remoteNewer(let date):
            SyncStatusTracker.status = .inSync
            self.isSyncOperationInProgress = false
            self.runStartupMaintenanceOnce()
            self.showRemoteNewerAlert(remoteDate: date)
          case .diverged(let remote, let local):
            SyncStatusTracker.status = .inSync
            self.isSyncOperationInProgress = false
            self.runStartupMaintenanceOnce()
            self.showDivergedAlert(remoteDate: remote, localDate: local)
          }
        }
      }
    }
  }

  private func runStartupMaintenanceOnce() {
    guard !hasRunStartupMaintenance else { return }
    hasRunStartupMaintenance = true
    createDailySnapshotIfNeeded()
    backfillInflectionKeysIfNeeded()
    backfillTranscriptCacheIfNeeded()
    backfillClipUploadsIfNeeded()
    backfillLabelRangesIfNeeded()
    repairOrphanedClipsIfNeeded()
  }

  // MARK: - Sync

  private func performSyncCheck() {
    guard !isSyncOperationInProgress else { return }
    isSyncOperationInProgress = true
    SyncStatusTracker.status = .checking

    dependencies.elixirSyncClient.checkSync { [weak self] result in
      DispatchQueue.main.async {
        guard let self else { return }
        SyncStatusTracker.lastSyncCheckDate = Date()
        switch result {
        case .failure(let error):
          print("[ElixirSync] checkSync error: \(error)")
          SyncStatusTracker.status = .error(error.localizedDescription)
          self.isSyncOperationInProgress = false
        case .success(let response):
          switch response.status {
          case .inSync:
            SyncStatusTracker.status = .inSync
            self.isSyncOperationInProgress = false
          case .localNewer:
            SyncStatusTracker.status = .localNewer
            self.pushLocalChanges()
          case .remoteNewer(let date):
            SyncStatusTracker.status = .inSync
            self.isSyncOperationInProgress = false
            self.showRemoteNewerAlert(remoteDate: date)
          case .diverged(let remote, let local):
            SyncStatusTracker.status = .inSync
            self.isSyncOperationInProgress = false
            self.showDivergedAlert(remoteDate: remote, localDate: local)
          }
        }
      }
    }
  }

  private func startPeriodicSyncTimer() {
    periodicSyncTimer?.invalidate()
    let interval = TimeInterval(MSRSAppSettings.syncIntervalSeconds)
    periodicSyncTimer = Timer.scheduledTimer(
      timeInterval: interval,
      target: self,
      selector: #selector(periodicSyncTimerFired),
      userInfo: nil,
      repeats: true
    )
  }

  @objc private func periodicSyncTimerFired() {
    performSyncCheck()
  }

  private func startSyncListener() {
    dependencies.elixirSyncClient.startListening { [weak self] status in
      DispatchQueue.main.async {
        self?.handleListenerStatus(status)
      }
    }
  }

  private func handleListenerStatus(_ status: SyncStatus) {
    switch status {
    case .inSync:
      SyncStatusTracker.status = .inSync
    case .localNewer:
      SyncStatusTracker.status = .localNewer
      guard !isSyncOperationInProgress else { return }
      isSyncOperationInProgress = true
      pushLocalChanges()
    case .remoteNewer(let date):
      guard !isSyncOperationInProgress else { return }
      showRemoteNewerAlert(remoteDate: date)
    case .diverged(let remote, let local):
      guard !isSyncOperationInProgress else { return }
      showDivergedAlert(remoteDate: remote, localDate: local)
    }
  }

  private func pushLocalChanges() {
    print("[ElixirSync] Local newer — pushing")
    SyncStatusTracker.status = .pushing
    dependencies.elixirSyncClient.push { [weak self] result in
      DispatchQueue.main.async {
        guard let self else { return }
        switch result {
        case .failure(let error):
          print("[ElixirSync] Push error: \(error)")
          SyncStatusTracker.status = .error(error.localizedDescription)
        case .success:
          print("[ElixirSync] Push succeeded")
          SyncStatusTracker.status = .inSync
          SyncStatusTracker.lastPushDate = Date()
        }
        self.isSyncOperationInProgress = false
      }
    }
  }

  public func performDatabasePull(completion: @Sendable @escaping (Result<Void, Error>) -> Void) {
    guard !isSyncOperationInProgress else {
      completion(.failure(ElixirSyncPullError.syncOperationAlreadyInProgress))
      return
    }
    isSyncOperationInProgress = true

    dependencies.elixirSyncClient.stopListening()

    // Tear down root VC first to release ValueObservation tokens held by VCs,
    // so DatabaseQueue.close() won't fail with SQLITE_BUSY.
    window?.rootViewController = UIViewController()

    do {
      try dependencies.mediaListeningSRSDatabaseClient.close()
    } catch {
      print("[ElixirSync] DB close failed: \(error)")
      rebuildAfterFailedPull()
      completion(.failure(error))
      return
    }

    let dbFileURL = AppDependencies.databaseFileURL()
    let walURL = URL(fileURLWithPath: dbFileURL.path + "-wal")
    let shmURL = URL(fileURLWithPath: dbFileURL.path + "-shm")

    do {
      let fm = FileManager.default
      if fm.fileExists(atPath: walURL.path) { try fm.removeItem(at: walURL) }
      if fm.fileExists(atPath: shmURL.path) { try fm.removeItem(at: shmURL) }
    } catch {
      print("[ElixirSync] WAL/SHM cleanup failed: \(error)")
      rebuildAfterFailedPull()
      completion(.failure(error))
      return
    }

    dependencies.elixirSyncClient.pull { [weak self] result in
      DispatchQueue.main.async {
        guard let self else { return }

        self.dependencies = AppDependencies()
        self.loadAppSettings()
        if let windowScene = self.window?.windowScene {
          self.buildAndSetRootViewController(windowScene: windowScene)
        }
        self.startSyncListener()
        self.startPeriodicSyncTimer()
        self.isSyncOperationInProgress = false

        switch result {
        case .failure(let error):
          print("[ElixirSync] Pull failed: \(error)")
          completion(.failure(error))
        case .success:
          self.createDailySnapshotIfNeeded()
          completion(.success(()))
        }
      }
    }
  }

  private func rebuildAfterFailedPull() {
    dependencies = AppDependencies()
    loadAppSettings()
    if let windowScene = window?.windowScene {
      buildAndSetRootViewController(windowScene: windowScene)
    }
    startSyncListener()
    startPeriodicSyncTimer()
    isSyncOperationInProgress = false
  }

  // MARK: - Sync alerts

  private func showRemoteNewerAlert(remoteDate: Date) {
    let formatted = Self.formatSyncDate(remoteDate)
    let alert = UIAlertController(
      title: "Database Update Available",
      message: "A newer database was synced from another device (updated \(formatted)). Update now?",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))
    alert.addAction(UIAlertAction(title: "Update", style: .default) { [weak self] _ in
      self?.performDatabasePull { result in
        if case .failure(let error) = result {
          print("[ElixirSync] Pull from alert failed: \(error)")
        }
      }
    })
    presentAlertOnWindow(alert)
  }

  private func showDivergedAlert(remoteDate: Date, localDate: Date) {
    let remoteFormatted = Self.formatSyncDate(remoteDate)
    let localFormatted = Self.formatSyncDate(localDate)
    let alert = UIAlertController(
      title: "Database Conflict",
      message: "Database has changed on both this device and another device.\n\nRemote: \(remoteFormatted)\nLocal: \(localFormatted)\n\nWhich version do you want to keep?",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Keep Local (\(localFormatted))", style: .default) { [weak self] _ in
      guard let self, !self.isSyncOperationInProgress else { return }
      self.isSyncOperationInProgress = true
      self.pushLocalChanges()
    })
    alert.addAction(UIAlertAction(title: "Keep Remote (\(remoteFormatted))", style: .destructive) { [weak self] _ in
      self?.performDatabasePull { result in
        if case .failure(let error) = result {
          print("[ElixirSync] Pull from diverged alert failed: \(error)")
        }
      }
    })
    presentAlertOnWindow(alert)
  }

  private func presentAlertOnWindow(_ alert: UIAlertController) {
    guard let rootVC = window?.rootViewController else { return }
    var presenter = rootVC
    while let presented = presenter.presentedViewController {
      presenter = presented
    }
    presenter.present(alert, animated: true)
  }

  private static func formatSyncDate(_ date: Date) -> String {
    let now = Date()
    let interval = now.timeIntervalSince(date)
    if interval >= 0 && interval < 60 {
      return "just now"
    } else if interval >= 0 && interval < 3600 {
      let minutes = Int(interval / 60)
      return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
    } else if interval >= 0 && interval < 86400 {
      let hours = Int(interval / 3600)
      return "\(hours) hour\(hours == 1 ? "" : "s") ago"
    } else {
      let formatter = DateFormatter()
      formatter.dateStyle = .short
      formatter.timeStyle = .short
      return formatter.string(from: date)
    }
  }

  // MARK: - Global hotkeys

  private func setupGlobalHotkeys() {
    #if targetEnvironment(macCatalyst)
    let eventMask = (1 << CGEventType.keyDown.rawValue)

    let hotkeyMap: [Int64: (String, Notification.Name)] = [
      12: ("Q", GlobalHotkey.commandOptionQ),
      13: ("W", GlobalHotkey.commandOptionW),
      14: ("E", GlobalHotkey.commandOptionE),
      15: ("R", GlobalHotkey.commandOptionR),
      17: ("T", GlobalHotkey.commandOptionT),
      16: ("Y", GlobalHotkey.commandOptionY),
      32: ("U", GlobalHotkey.commandOptionU),
      34: ("I", GlobalHotkey.commandOptionI),
    ]

    let callback: CGEventTapCallBack = { _, _, event, refcon in
      let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
      let flags = event.flags

      guard flags.contains([.maskCommand, .maskAlternate]) else {
        return Unmanaged.passRetained(event)
      }

      let map = Unmanaged<NSDictionary>.fromOpaque(refcon!).takeUnretainedValue()
      guard let entry = map[NSNumber(value: keyCode)] as? [Any],
            let label = entry[0] as? String,
            let name = entry[1] as? Notification.Name else {
        return Unmanaged.passRetained(event)
      }

      DispatchQueue.main.async {
        print("[GlobalHotkey] ⌘⌥\(label) triggered")
        NotificationCenter.default.post(name: name, object: nil)
      }
      return nil
    }

    let mapDict = NSMutableDictionary()
    for (code, (label, name)) in hotkeyMap {
      mapDict[NSNumber(value: code)] = [label, name] as [Any]
    }
    let retainedMap = Unmanaged.passRetained(mapDict as NSDictionary)

    guard let eventTap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: CGEventMask(eventMask),
      callback: callback,
      userInfo: retainedMap.toOpaque()
    ) else {
      print("[GlobalHotkey] Failed to create event tap — check Accessibility permissions")
      return
    }

    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
    print("[GlobalHotkey] Event tap registered for ⌘⌥ Q/W/E/R/T/Y/U/I")
    #endif
  }

  // MARK: - Floating window

  private func setupFloatingWindow() {
    #if targetEnvironment(macCatalyst)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(floatingWindowSettingChanged),
      name: FloatingWindowSettings.didChangeNotification,
      object: nil
    )
    DispatchQueue.main.async {
      self.applyFloatingWindowSetting()
    }
    #endif
  }

  @objc private func floatingWindowSettingChanged() {
    applyFloatingWindowSetting()
  }

  private func applyFloatingWindowSetting() {
    #if targetEnvironment(macCatalyst)
    MacWindowBridge.applyFloating(FloatingWindowSettings.isEnabled)
    #endif
  }

  // MARK: - Daily maintenance

  private func createDailySnapshotIfNeeded() {
    Task {
      try? await dependencies.mediaListeningSRSDatabaseClient.dailySnapshot.createIfNeeded(
        .init(date: Date())
      )
    }
  }

  private func backfillTranscriptCacheIfNeeded() {
    #if targetEnvironment(macCatalyst)
    Task {
      await TranscriptCacheBackfillService.backfillIfNeeded(
        mediaListeningSRSDatabaseClient: dependencies.mediaListeningSRSDatabaseClient,
        jmlDatabaseClient: dependencies.jmlDatabaseClient,
        srtParserClient: dependencies.srtParserClient
      )
    }
    #endif
  }

  private func backfillClipUploadsIfNeeded() {
    #if targetEnvironment(macCatalyst)
    Task {
      await ClipUploadBackfillService.backfillIfNeeded(
        clipStorageClient: dependencies.clipStorageClient,
        exportedClipsDirectoryURL: dependencies.exportedClipsDirectoryURL
      )
    }
    #endif
  }

  private func backfillLabelRangesIfNeeded() {
    #if targetEnvironment(macCatalyst)
    Task {
      await LabelRangeBackfillService.backfillIfNeeded(
        mediaListeningSRSDatabaseClient: dependencies.mediaListeningSRSDatabaseClient,
        jmlDatabaseClient: dependencies.jmlDatabaseClient,
        metgDatabaseClient: dependencies.metgDatabaseClient,
        srtParserClient: dependencies.srtParserClient
      )
    }
    #endif
  }

  private func loadAppSettings() {
    Task {
      do {
        let response = try await dependencies.mediaListeningSRSDatabaseClient.appSettings.fetch(.init())
        await MainActor.run {
          MSRSAppSettings.loadFromModel(response.model)
        }
      } catch {
        print("[AppSettings] Failed to load from DB: \(error)")
      }
    }
  }

  private static let userDefaultsMigrationKey = "MSRS.UserDefaultsToSQLiteMigration.completed"

  private func migrateUserDefaultsToSQLiteIfNeeded() {
    #if targetEnvironment(macCatalyst)
    guard !UserDefaults.standard.bool(forKey: Self.userDefaultsMigrationKey) else { return }
    Task {
      let ud = UserDefaults.standard
      var model = AppSettingsModel()

      if ud.object(forKey: "MSRS.Settings.desiredRetention") != nil {
        model.desiredRetention = ud.double(forKey: "MSRS.Settings.desiredRetention")
      }
      if ud.object(forKey: "MSRS.Settings.showFrontTranscript") != nil {
        model.showFrontTranscript = ud.bool(forKey: "MSRS.Settings.showFrontTranscript")
      }
      if ud.object(forKey: "MSRS.Settings.minimumCardCoverageCount") != nil {
        let value = ud.integer(forKey: "MSRS.Settings.minimumCardCoverageCount")
        model.minimumCardCoverageCount = max(1, value)
      }
      if ud.object(forKey: "MSRS.Settings.studySessionInactivityTimeout") != nil {
        let value = ud.integer(forKey: "MSRS.Settings.studySessionInactivityTimeout")
        model.studySessionInactivityTimeout = max(30, value)
      }
      if ud.object(forKey: "MSRS.Settings.requireSkipOrMakeCardConfirmation") != nil {
        model.requireSkipOrMakeCardConfirmation = ud.bool(forKey: "MSRS.Settings.requireSkipOrMakeCardConfirmation")
      }
      if ud.object(forKey: "MSRS.Settings.autoLoopVideo") != nil {
        model.autoLoopVideo = ud.bool(forKey: "MSRS.Settings.autoLoopVideo")
      }
      if let prompt = ud.string(forKey: "MSRS.Settings.llmGradingPrompt"), !prompt.isEmpty {
        model.llmGradingPrompt = prompt
      }

      do {
        try await self.dependencies.mediaListeningSRSDatabaseClient.appSettings.update(
          .init(model: model)
        )
        MSRSAppSettings.loadFromModel(model)
        UserDefaults.standard.set(true, forKey: Self.userDefaultsMigrationKey)
        print("[AppSettings] Migrated UserDefaults values to SQLite")
      } catch {
        print("[AppSettings] UserDefaults migration failed: \(error)")
      }
    }
    #endif
  }

  private func repairOrphanedClipsIfNeeded() {
    #if targetEnvironment(macCatalyst)
    Task {
      await OrphanedClipRepairService.repairIfNeeded(
        mediaListeningSRSDatabaseClient: dependencies.mediaListeningSRSDatabaseClient,
        jmlDatabaseClient: dependencies.jmlDatabaseClient,
        clipExportService: dependencies.clipExportService,
        clipStorageClient: dependencies.clipStorageClient,
        exportedClipsDirectoryURL: dependencies.exportedClipsDirectoryURL
      )
    }
    #endif
  }

  private func backfillInflectionKeysIfNeeded() {
    #if targetEnvironment(macCatalyst)
    Task {
      await InflectionKeyBackfillService.backfillIfNeeded(
        mediaListeningSRSDatabaseClient: dependencies.mediaListeningSRSDatabaseClient,
        jmlDatabaseClient: dependencies.jmlDatabaseClient,
        metgDatabaseClient: dependencies.metgDatabaseClient,
        srtParserClient: dependencies.srtParserClient,
        japaneseParserClient: dependencies.japaneseParserClient
      )
    }
    #endif
  }

}

public enum ElixirSyncPullError: Error {
  case syncOperationAlreadyInProgress
}
