import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var privacyCover: UIView?

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
