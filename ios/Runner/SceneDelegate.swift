import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private let privacyOverlayTag = 20261009
  private let screenshotOverlayTag = 20261010

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenCaptureChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(userDidTakeScreenshot),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )
    applyScreenCaptureProtection()
  }

  override func sceneDidDisconnect(_ scene: UIScene) {
    NotificationCenter.default.removeObserver(self)
    super.sceneDidDisconnect(scene)
  }

  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    showPrivacyOverlay(in: scene, text: "Epsilon")
  }

  override func sceneDidEnterBackground(_ scene: UIScene) {
    super.sceneDidEnterBackground(scene)
    showPrivacyOverlay(in: scene, text: "Epsilon")
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    if UIScreen.main.isCaptured {
      showPrivacyOverlay(in: scene, text: "تم حجب المحتوى أثناء تسجيل الشاشة")
    } else {
      hidePrivacyOverlay(in: scene)
    }
  }

  @objc private func screenCaptureChanged() {
    applyScreenCaptureProtection()
  }

  @objc private func userDidTakeScreenshot() {
    guard let scene = foregroundScene() else {
      return
    }
    showScreenshotOverlay(in: scene)
    showScreenshotWarning(in: scene)
  }

  private func applyScreenCaptureProtection() {
    for scene in UIApplication.shared.connectedScenes {
      if UIScreen.main.isCaptured {
        showPrivacyOverlay(in: scene, text: "تم حجب المحتوى أثناء تسجيل الشاشة")
      } else if scene.activationState == .foregroundActive {
        hidePrivacyOverlay(in: scene)
      }
    }
  }

  private func foregroundScene() -> UIScene? {
    return UIApplication.shared.connectedScenes.first {
      $0.activationState == .foregroundActive
    }
  }

  private func showPrivacyOverlay(in scene: UIScene, text: String) {
    guard let windowScene = scene as? UIWindowScene else {
      return
    }
    for window in windowScene.windows {
      guard window.viewWithTag(privacyOverlayTag) == nil else {
        continue
      }
      let overlay = UIView(frame: window.bounds)
      overlay.tag = privacyOverlayTag
      overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      overlay.backgroundColor = UIColor(red: 0.05, green: 0.07, blue: 0.12, alpha: 1)

      let label = UILabel()
      label.text = text
      label.textColor = .white
      label.font = .boldSystemFont(ofSize: 24)
      label.numberOfLines = 0
      label.textAlignment = .center
      label.translatesAutoresizingMaskIntoConstraints = false
      overlay.addSubview(label)

      NSLayoutConstraint.activate([
        label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
        label.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
      ])

      window.addSubview(overlay)
    }
  }

  private func hidePrivacyOverlay(in scene: UIScene) {
    guard let windowScene = scene as? UIWindowScene else {
      return
    }
    for window in windowScene.windows {
      window.viewWithTag(privacyOverlayTag)?.removeFromSuperview()
    }
  }

  private func showScreenshotOverlay(in scene: UIScene) {
    guard let windowScene = scene as? UIWindowScene else {
      return
    }
    for window in windowScene.windows {
      window.viewWithTag(screenshotOverlayTag)?.removeFromSuperview()

      let overlay = UIView(frame: window.bounds)
      overlay.tag = screenshotOverlayTag
      overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      overlay.backgroundColor = UIColor(red: 0.05, green: 0.07, blue: 0.12, alpha: 0.96)

      let label = UILabel()
      label.text = "لقطات الشاشة غير مسموحة"
      label.textColor = .white
      label.font = .boldSystemFont(ofSize: 22)
      label.textAlignment = .center
      label.translatesAutoresizingMaskIntoConstraints = false
      overlay.addSubview(label)

      NSLayoutConstraint.activate([
        label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
        label.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
      ])

      window.addSubview(overlay)
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        overlay.removeFromSuperview()
      }
    }
  }

  private func showScreenshotWarning(in scene: UIScene) {
    guard
      let windowScene = scene as? UIWindowScene,
      let presenter = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
    else {
      return
    }
    let alert = UIAlertController(
      title: "تنبيه",
      message: "لقطات الشاشة غير مسموحة داخل التطبيق.",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "حسنًا", style: .default))
    topViewController(from: presenter)?.present(alert, animated: true)
  }

  private func topViewController(from controller: UIViewController?) -> UIViewController? {
    if let navigationController = controller as? UINavigationController {
      return topViewController(from: navigationController.visibleViewController)
    }
    if let tabController = controller as? UITabBarController {
      return topViewController(from: tabController.selectedViewController)
    }
    if let presented = controller?.presentedViewController {
      return topViewController(from: presented)
    }
    return controller
  }
}
