import UIKit
import MSRS_AppDependencies
import MSRS_MediaSourcesListScene

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

    let rootVC = MediaSourcesListVC(dependencies: dependencies)
    let navigationController = UINavigationController(rootViewController: rootVC)

    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = navigationController
    window.makeKeyAndVisible()
    self.window = window
  }

}
