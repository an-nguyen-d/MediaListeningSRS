import UIKit

public enum MSRSDeviceType: Sendable {
  case iPhone
  case iPad
  case mac

  @MainActor
  public static let current: MSRSDeviceType = {
    #if targetEnvironment(macCatalyst)
    return .mac
    #else
    switch UIDevice.current.userInterfaceIdiom {
    case .pad: return .iPad
    default: return .iPhone
    }
    #endif
  }()
}
