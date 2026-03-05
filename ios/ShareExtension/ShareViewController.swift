import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let appGroupId = "group.com.amacass.novelNotification"
    private let sharedUrlKey = "SharedURL"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        handleSharedItems()
    }

    private func handleSharedItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem],
              !extensionItems.isEmpty else {
            completeExtension()
            return
        }

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (data, error) in
                        DispatchQueue.main.async {
                            if let url = data as? URL {
                                self?.saveAndComplete(urlString: url.absoluteString)
                            } else {
                                self?.completeExtension()
                            }
                        }
                    }
                    return
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (data, error) in
                        DispatchQueue.main.async {
                            if let text = data as? String,
                               let url = URL(string: text),
                               url.scheme?.hasPrefix("http") == true {
                                self?.saveAndComplete(urlString: text)
                            } else {
                                self?.completeExtension()
                            }
                        }
                    }
                    return
                }
            }
        }

        completeExtension()
    }

    private func saveAndComplete(urlString: String) {
        // Save URL to App Group shared UserDefaults
        if let userDefaults = UserDefaults(suiteName: appGroupId) {
            userDefaults.set(urlString, forKey: sharedUrlKey)
            userDefaults.synchronize()
        }
        completeExtension()
    }

    private func completeExtension() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
