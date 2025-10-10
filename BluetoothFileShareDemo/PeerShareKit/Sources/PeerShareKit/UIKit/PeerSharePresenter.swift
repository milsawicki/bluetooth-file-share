import UIKit
import UniformTypeIdentifiers

public final class PeerSharePresenter: NSObject, UIDocumentPickerDelegate {
    private weak var fromVC: UIViewController?

    public init(from viewController: UIViewController) {
        self.fromVC = viewController
    }

    public func presentPickerAndShare() {
        let doc = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        doc.delegate = self
        fromVC?.present(doc, animated: true)
    }

    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, let vc = fromVC else { return }
        _ = PeerShare.presentPickerAndSendPDF(from: vc, pdfURL: url)
    }
}
