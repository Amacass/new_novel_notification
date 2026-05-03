import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  private let appGroupId = "group.com.amacass.novelNotification"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Flutter からセッショントークンを受け取り App Group に保存
    // Safari Extension がこのトークンを使って Supabase に直接登録する
    let channel = FlutterMethodChannel(
      name: "com.amacass.novelNotification/session",
      binaryMessenger: engineBridge.pluginRegistry.registrar(forPlugin: "session").messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "saveSession":
        if let args = call.arguments as? [String: String],
          let token = args["access_token"],
          let defaults = UserDefaults(suiteName: self.appGroupId)
        {
          defaults.set(token, forKey: "supabase_access_token")
          defaults.synchronize()
        }
        result(nil)
      case "clearSession":
        if let defaults = UserDefaults(suiteName: self.appGroupId) {
          defaults.removeObject(forKey: "supabase_access_token")
          defaults.synchronize()
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
