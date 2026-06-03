import SafariServices
import os.log

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    private let appGroupId = "group.com.amacass.novelNotification"
    private let sharedUrlKey = "SharedURL"

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem
        let message: Any?
        if #available(iOS 15.0, *) {
            message = request?.userInfo?[SFExtensionMessageKey]
        } else {
            message = request?.userInfo?["message"]
        }

        var success = false
        if let dict = message as? [String: Any],
           let action = dict["action"] as? String, action == "register",
           let url = dict["url"] as? String, !url.isEmpty,
           let defaults = UserDefaults(suiteName: appGroupId) {
            var pending = defaults.stringArray(forKey: sharedUrlKey) ?? []
            pending.append(url)
            defaults.set(pending, forKey: sharedUrlKey)
            defaults.synchronize()
            success = true
            os_log(.default, "Safari Extension: saved URL to App Group: %@", url)
        }

        let response = NSExtensionItem()
        if #available(iOS 15.0, *) {
            response.userInfo = [SFExtensionMessageKey: ["success": success]]
        } else {
            response.userInfo = ["message": ["success": success]]
        }
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}
