import Flutter
import ObjectiveC
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  private let appGroupId = "group.com.amacass.novelNotification"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    Self.patchVSyncClientCrash()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Workaround: iOS 26 + ProMotion causes a null-pointer crash in Flutter's VSyncClient
  // during createTouchRateCorrectionVSyncClientIfNeeded. Replace with no-op at runtime.
  private static func patchVSyncClientCrash() {
    let sel = Selector("createTouchRateCorrectionVSyncClientIfNeeded")
    guard let method = class_getInstanceMethod(FlutterViewController.self, sel) else { return }
    let noop: @convention(block) (AnyObject) -> Void = { _ in }
    method_setImplementation(method, imp_implementationWithBlock(noop as AnyObject))
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let messenger = engineBridge.pluginRegistry.registrar(forPlugin: "session")?.messenger() else { return }
    let channel = FlutterMethodChannel(
      name: "com.amacass.novelNotification/session",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
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
        result(nil as Any?)
      case "clearSession":
        if let defaults = UserDefaults(suiteName: self.appGroupId) {
          defaults.removeObject(forKey: "supabase_access_token")
          defaults.synchronize()
        }
        result(nil as Any?)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
