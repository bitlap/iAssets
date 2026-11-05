import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var privacyCover: UIView?

  override func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    for context in connectionOptions.urlContexts {
      _ = (UIApplication.shared.delegate as? AppDelegate)?.openWidgetURL(context.url)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    let otherURLs = URLContexts.filter { context in
      !((UIApplication.shared.delegate as? AppDelegate)?.openWidgetURL(context.url) ?? false)
    }
    if !otherURLs.isEmpty { super.scene(scene, openURLContexts: Set(otherURLs)) }
  }

  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    guard privacyCover == nil else { return }
    guard let windows = (scene as? UIWindowScene)?.windows,
          let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first else { return }
    let cover = UIView(frame: window.bounds)
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    cover.backgroundColor = .systemBackground
    let icon = UIImageView(image: UIImage(systemName: "lock.shield"))
    icon.tintColor = .secondaryLabel
    icon.contentMode = .scaleAspectFit
    icon.frame = CGRect(x: 0, y: 0, width: 48, height: 48)
    icon.center = CGPoint(x: cover.bounds.midX, y: cover.bounds.midY)
    icon.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin,
                             .flexibleTopMargin, .flexibleBottomMargin]
    cover.addSubview(icon)
    window.addSubview(cover)
    privacyCover = cover
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    privacyCover?.removeFromSuperview()
    privacyCover = nil
  }
}
