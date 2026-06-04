import Foundation

public enum FloatingWindowSettings {

  public static let didChangeNotification = Notification.Name("MSRS.FloatingWindowSettings.didChange")

  private static let userDefaultsKey = "MSRS.floatingWindowEnabled"

  public static var isEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: userDefaultsKey) }
    set {
      UserDefaults.standard.set(newValue, forKey: userDefaultsKey)
      NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
  }
}

#if targetEnvironment(macCatalyst)
public enum MacWindowBridge {

  private static let normalLevel = 0
  private static let floatingLevel = 3

  public static func applyFloating(_ floating: Bool) {
    let level = floating ? floatingLevel : normalLevel
    guard let nsAppClass = NSClassFromString("NSApplication") as? NSObject.Type,
          let sharedApp = nsAppClass.value(forKey: "sharedApplication") as? NSObject,
          let windows = sharedApp.value(forKey: "windows") as? [NSObject] else {
      return
    }
    for window in windows {
      window.setValue(level, forKey: "level")
    }
  }
}
#endif
