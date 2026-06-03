import Foundation

public enum SyncStatusTracker {

  public enum Status: Sendable {
    case unknown
    case inSync
    case localNewer
    case checking
    case pushing
    case error(String)
  }

  nonisolated(unsafe) private static var _status: Status = .unknown
  nonisolated(unsafe) private static var _lastSyncCheckDate: Date?
  nonisolated(unsafe) private static var _lastPushDate: Date?
  nonisolated(unsafe) private static var _onChange: (() -> Void)?

  public static var status: Status {
    get { _status }
    set {
      _status = newValue
      _onChange?()
    }
  }

  public static var lastSyncCheckDate: Date? {
    get { _lastSyncCheckDate }
    set {
      _lastSyncCheckDate = newValue
      _onChange?()
    }
  }

  public static var lastPushDate: Date? {
    get { _lastPushDate }
    set {
      _lastPushDate = newValue
      _onChange?()
    }
  }

  public static var onChange: (() -> Void)? {
    get { _onChange }
    set { _onChange = newValue }
  }
}
