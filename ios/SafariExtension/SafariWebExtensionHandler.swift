import SafariServices
import os.log

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

  private let appGroupId = "group.com.amacass.novelNotification"
  private let logger = Logger(subsystem: "com.amacass.novelNotification.SafariExtension", category: "handler")

  func beginRequest(with context: NSExtensionContext) {
    let request = context.inputItems.first as? NSExtensionItem
    let message = request?.userInfo?[SFExtensionMessageKey]

    guard let dict = message as? [String: Any],
      let action = dict["action"] as? String
    else {
      context.completeRequest(returningItems: [], completionHandler: nil)
      return
    }

    let responseItem = NSExtensionItem()

    switch action {
    case "getToken":
      let defaults = UserDefaults(suiteName: appGroupId)
      let token = defaults?.string(forKey: "supabase_access_token") ?? ""
      responseItem.userInfo = [SFExtensionMessageKey: ["token": token]]

    default:
      logger.warning("Unknown action: \(action)")
      responseItem.userInfo = [SFExtensionMessageKey: ["error": "Unknown action"]]
    }

    context.completeRequest(returningItems: [responseItem], completionHandler: nil)
  }
}
