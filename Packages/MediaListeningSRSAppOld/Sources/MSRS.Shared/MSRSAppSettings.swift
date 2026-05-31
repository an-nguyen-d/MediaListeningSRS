import Foundation

public enum MSRSAppSettings {

  private static let requireConfirmationKey = "MSRS.Settings.requireSkipOrMakeCardConfirmation"
  public static let desiredRetentionKey = "MSRS.Settings.desiredRetention"
  public static let desiredRetentionDefault: Double = 0.9

  public static var requireSkipOrMakeCardConfirmation: Bool {
    get {
      if UserDefaults.standard.object(forKey: requireConfirmationKey) == nil {
        return true
      }
      return UserDefaults.standard.bool(forKey: requireConfirmationKey)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: requireConfirmationKey)
    }
  }

  public static var desiredRetention: Double {
    get {
      if UserDefaults.standard.object(forKey: desiredRetentionKey) == nil {
        return desiredRetentionDefault
      }
      return UserDefaults.standard.double(forKey: desiredRetentionKey)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: desiredRetentionKey)
    }
  }
}
