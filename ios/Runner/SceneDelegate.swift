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

    // Handle URL scheme open (novelnotification://) when app is already running
    override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        super.scene(scene, openURLContexts: URLContexts)
        checkForSharedUrl(scene: scene)
    }

    private func checkForSharedUrl(scene: UIScene) {
        guard let userDefaults = UserDefaults(suiteName: appGroupId) else { return }

        let pending = userDefaults.stringArray(forKey: sharedUrlKey) ?? []
        guard !pending.isEmpty else { return }

        // Clear the queue so items aren't processed again
        userDefaults.removeObject(forKey: sharedUrlKey)
        userDefaults.synchronize()

        // Send all pending URLs to Flutter as a single batch
        sendToFlutterWithRetry(urls: pending, scene: scene)
    }

    private func sendToFlutterWithRetry(urls: [String], scene: UIScene, attempts: Int = 0) {
        guard attempts < 20 else { return }

        if let windowScene = scene as? UIWindowScene {
            for window in windowScene.windows {
                if let flutterVC = window.rootViewController as? FlutterViewController,
                   flutterVC.engine.isolateId != nil {
                    let channel = FlutterMethodChannel(
                        name: "com.amacass.novelNotification/share",
                        binaryMessenger: flutterVC.binaryMessenger
                    )
                    channel.invokeMethod("sharedUrls", arguments: urls)
                    return
                }
            }
        }

        // Flutter not ready yet, retry after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.sendToFlutterWithRetry(urls: urls, scene: scene, attempts: attempts + 1)
        }
    }
}
