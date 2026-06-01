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

  private static let minimumCardCoverageCountKey = "MSRS.Settings.minimumCardCoverageCount"
  public static let minimumCardCoverageCountDefault: Int = 50

  private static let showFrontTranscriptKey = "MSRS.Settings.showFrontTranscript"

  public static var showFrontTranscript: Bool {
    get {
      if UserDefaults.standard.object(forKey: showFrontTranscriptKey) == nil {
        return true
      }
      return UserDefaults.standard.bool(forKey: showFrontTranscriptKey)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: showFrontTranscriptKey)
    }
  }

  public static var minimumCardCoverageCount: Int {
    get {
      if UserDefaults.standard.object(forKey: minimumCardCoverageCountKey) == nil {
        return minimumCardCoverageCountDefault
      }
      let value = UserDefaults.standard.integer(forKey: minimumCardCoverageCountKey)
      return max(1, value)
    }
    set {
      UserDefaults.standard.set(max(1, newValue), forKey: minimumCardCoverageCountKey)
    }
  }

  private static let studySessionInactivityTimeoutKey = "MSRS.Settings.studySessionInactivityTimeout"
  public static let studySessionInactivityTimeoutDefault: Int = 300

  public static var studySessionInactivityTimeout: Int {
    get {
      if UserDefaults.standard.object(forKey: studySessionInactivityTimeoutKey) == nil {
        return studySessionInactivityTimeoutDefault
      }
      let value = UserDefaults.standard.integer(forKey: studySessionInactivityTimeoutKey)
      return max(30, value)
    }
    set {
      UserDefaults.standard.set(max(30, newValue), forKey: studySessionInactivityTimeoutKey)
    }
  }
}
