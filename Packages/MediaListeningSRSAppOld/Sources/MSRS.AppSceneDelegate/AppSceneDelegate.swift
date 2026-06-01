import UIKit
import MSRS_AppDependencies
import MSRS_MediaSourcesListScene
import MSRS_StudyStatsScene
import MSRS_WordsListScene

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

    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = tabBarController
    window.makeKeyAndVisible()
    self.window = window

    createDailySnapshotIfNeeded()
  }

  open func sceneDidBecomeActive(_ scene: UIScene) {
    createDailySnapshotIfNeeded()
  }

  private func createDailySnapshotIfNeeded() {
    Task {
      try? await dependencies.mediaListeningSRSDatabaseClient.dailySnapshot.createIfNeeded(
        .init(date: Date())
      )
    }
  }

}
