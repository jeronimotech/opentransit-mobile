import MobileCoreServices
import UIKit
import UniformTypeIdentifiers

/// Hand a shared place to the app.
///
/// Deliberately the thinnest extension that can work: it reads what was shared, hands the raw text
/// to the app through the `opentransit://shared?text=…` link the Android side already uses, and
/// gets out of the way. Every decision about what that text means — a `geo:` URI, a Google or Apple
/// Maps link, a bare coordinate pair, an address — is `parseSharedLocation` in Dart, which is
/// tested against the shapes real apps send. Duplicating any of it here would mean two parsers that
/// have to agree.
///
/// `extensionContext.open(_:)` is public API and needs no App Group, no shared container and no new
/// entitlement, which is why this does not have any. If iOS declines to open the app the extension
/// says so rather than dismissing as though it worked.
final class ShareViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await handle() }
    }

    private func handle() async {
        guard let item = (extensionContext?.inputItems as? [NSExtensionItem])?.first,
              let provider = item.attachments?.first else {
            return finish(opened: false)
        }

        // A URL first: a map link shared from Maps arrives as one, and its string is exactly what
        // the Dart parser wants. Plain text second, for an address someone copied.
        if let url = await load(provider, as: UTType.url.identifier) as? URL {
            return await open(url.absoluteString)
        }
        if let text = await load(provider, as: UTType.plainText.identifier) as? String {
            return await open(text)
        }
        // Some apps attach a map item rather than a URL; its own text is the best we can do.
        if let text = item.attributedContentText?.string, !text.isEmpty {
            return await open(text)
        }
        finish(opened: false)
    }

    private func load(_ provider: NSItemProvider, as type: String) async -> Any? {
        guard provider.hasItemConformingToTypeIdentifier(type) else { return nil }
        return try? await provider.loadItem(forTypeIdentifier: type)
    }

    private func open(_ text: String) async {
        var components = URLComponents()
        components.scheme = "opentransit"
        components.host = "shared"
        components.queryItems = [URLQueryItem(name: "text", value: text)]
        guard let url = components.url else { return finish(opened: false) }
        let ok = await extensionContext?.open(url) ?? false
        finish(opened: ok)
    }

    private func finish(opened: Bool) {
        guard let context = extensionContext else { return }
        if opened {
            context.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        // Nothing usable, or iOS would not switch apps. Saying so beats disappearing silently:
        // someone who shared a place and saw nothing happen will share it again.
        let alert = UIAlertController(
            title: NSLocalizedString("Could not open opentransit", comment: ""),
            message: NSLocalizedString("Open the app and paste the address instead.", comment: ""),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
            context.completeRequest(returningItems: [], completionHandler: nil)
        })
        present(alert, animated: true)
    }
}
