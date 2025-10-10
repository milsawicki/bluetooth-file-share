import SwiftUI
import MultipeerConnectivity
import UIKit

public enum PeerShare {
    @discardableResult
    public static func presentPickerAndSendPDF(from presenter: UIViewController, pdfURL: URL) -> PeerShareController {
        let controller = PeerShareController(pdfURL: pdfURL)
        presenter.present(controller.browserVC, animated: true)
        return controller
    }

    public static func SwiftUISheet(pdfURL: URL) -> some View {
        PeerShareSheet(pdfURL: pdfURL)
    }
}

public final class PeerShareController: NSObject, MCBrowserViewControllerDelegate, MCSessionDelegate {
    private let manager = PeerShareManager.shared
    private let serviceType = "psk-share"

    public let browserVC: MCBrowserViewController
    private let pdfURL: URL

    public init(pdfURL: URL) {
        self.pdfURL = pdfURL
        manager.start()
        browserVC = MCBrowserViewController(serviceType: serviceType, session: manager.session)
        super.init()
        browserVC.delegate = self
        manager.session.delegate = self
    }

    public func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        browserViewController.dismiss(animated: true)
        sendIfPossible()
    }

    public func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        browserViewController.dismiss(animated: true)
    }

    private func sendIfPossible() {
        guard let peer = manager.session.connectedPeers.first else { return }
        _ = manager.send(file: pdfURL, to: peer)
    }

    // MCSessionDelegate (no-op except state)
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {}
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {}
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

public struct PeerShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    let pdfURL: URL
    @State private var selectedPeer: MCPeerID?

    public init(pdfURL: URL) { self.pdfURL = pdfURL }

    public var body: some View {
        PeerPickerView { peer in
            selectedPeer = peer
            if let p = selectedPeer {
                _ = PeerShareManager.shared.send(file: pdfURL, to: p)
                dismiss()
            }
        }
    }
}
