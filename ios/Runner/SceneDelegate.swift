import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

    private let appGroupId = "group.com.amacass.novelNotification"
    private let sharedUrlKey = "SharedURL"

    override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        super.scene(scene, willConnectTo: session, options: connectionOptions)

        // Handle cold start: check App Group for shared URL
        checkForSharedUrl(scene: scene)
    }

    override func sceneDidBecomeActive(_ scene: UIScene) {
        super.sceneDidBecomeActive(scene)

        // Handle warm start: check App Group for shared URL when app comes to foreground
        checkForSharedUrl(scene: scene)
    }

    private func checkForSharedUrl(scene: UIScene) {
        guard let userDefaults = UserDefaults(suiteName: appGroupId),
              let sharedUrl = userDefaults.string(forKey: sharedUrlKey),
              !sharedUrl.isEmpty else {
            return
        }

        // Clear the shared URL so it's not processed again
        userDefaults.removeObject(forKey: sharedUrlKey)
        userDefaults.synchronize()

        // Send to Flutter
        sendToFlutterWithRetry(sharedUrl: sharedUrl, scene: scene)
    }

    private func sendToFlutter(sharedUrl: String, scene: UIScene) {
        guard let windowScene = scene as? UIWindowScene else { return }
        for window in windowScene.windows {
            if let flutterVC = window.rootViewController as? FlutterViewController {
                let channel = FlutterMethodChannel(name: "com.amacass.novelNotification/share", binaryMessenger: flutterVC.binaryMessenger)
                channel.invokeMethod("sharedUrl", arguments: sharedUrl)
                return
            }
        }
    }

    private func sendToFlutterWithRetry(sharedUrl: String, scene: UIScene, attempts: Int = 0) {
        guard attempts < 10 else { return }

        if let windowScene = scene as? UIWindowScene {
            for window in windowScene.windows {
                if let flutterVC = window.rootViewController as? FlutterViewController {
                    let channel = FlutterMethodChannel(name: "com.amacass.novelNotification/share", binaryMessenger: flutterVC.binaryMessenger)
                    channel.invokeMethod("sharedUrl", arguments: sharedUrl)
                    return
                }
            }
        }

        // Flutter not ready yet, retry after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.sendToFlutterWithRetry(sharedUrl: sharedUrl, scene: scene, attempts: attempts + 1)
        }
    }
}
