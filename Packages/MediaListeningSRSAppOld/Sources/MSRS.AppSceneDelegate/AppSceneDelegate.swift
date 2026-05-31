import UIKit
import MSRS_AppDependencies
import MSRS_HomeScene

open class AppSceneDelegate: UIResponder, UIWindowSceneDelegate {

  public var window: UIWindow?

  public var dependencies: AppDependencies!

  public override init() {
    super.init()
  }

  open func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { fatalError() }

    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = HomeScene()
    window.makeKeyAndVisible()
    self.window = window
  }

}
