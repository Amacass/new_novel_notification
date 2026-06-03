import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let appGroupId = "group.com.amacass.novelNotification"
    private let sharedUrlKey = "SharedURL"

    // MARK: - UI

    private let card: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.systemBackground
        v.layer.cornerRadius = 16
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.18
        v.layer.shadowRadius = 12
        v.layer.shadowOffset = CGSize(width: 0, height: 4)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let iconLabel: UILabel = {
        let l = UILabel()
        l.text = "📚"
        l.font = .systemFont(ofSize: 36)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Novelmark"
        l.font = .systemFont(ofSize: 17, weight: .semibold)
        l.textColor = .label
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let statusLabel: UILabel = {
        let l = UILabel()
        l.text = "登録中..."
        l.font = .systemFont(ofSize: 14)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let spinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .medium)
        s.hidesWhenStopped = true
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        spinner.startAnimating()
        handleSharedItems()
    }

    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        view.addSubview(card)
        card.addSubview(iconLabel)
        card.addSubview(titleLabel)
        card.addSubview(statusLabel)
        card.addSubview(spinner)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 240),
            card.heightAnchor.constraint(equalToConstant: 140),

            iconLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            iconLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            titleLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),

            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            statusLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),

            spinner.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
        ])

        // Tap outside card to cancel
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapBackground))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func didTapBackground(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        if !card.frame.contains(location) {
            completeExtension()
        }
    }

    // MARK: - Processing

    private func handleSharedItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem],
              !extensionItems.isEmpty else {
            showResult(success: false, message: "URLが取得できませんでした")
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
                                self?.showResult(success: false, message: "URLが取得できませんでした")
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
                                self?.showResult(success: false, message: "URLが取得できませんでした")
                            }
                        }
                    }
                    return
                }
            }
        }

        showResult(success: false, message: "対応していないURLです")
    }

    private func saveAndComplete(urlString: String) {
        if let userDefaults = UserDefaults(suiteName: appGroupId) {
            userDefaults.set(urlString, forKey: sharedUrlKey)
            userDefaults.synchronize()
        }
        showResult(success: true, message: "登録しました")
    }

    private func showResult(success: Bool, message: String) {
        spinner.stopAnimating()
        statusLabel.text = message
        iconLabel.text = success ? "✅" : "❌"

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.completeExtension()
        }
    }

    private func completeExtension() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
