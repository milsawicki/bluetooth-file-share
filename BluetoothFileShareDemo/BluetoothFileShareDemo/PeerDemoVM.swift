import Foundation
import PeerShareKit
import MultipeerConnectivity

final class PeerDemoVM: ObservableObject {
    @Published var receivedFiles: [URL] = []
    @Published var connectedPeers: [MCPeerID] = []

    func start() {
        let mgr = PeerShareManager.shared
        mgr.start()

        mgr.onStateChange = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.connectedPeers = mgr.session.connectedPeers
            }
        }

        mgr.onReceiveFile = { [weak self] tmpURL, name, _ in
            let dst = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(name)
            try? FileManager.default.removeItem(at: dst)
            try? FileManager.default.copyItem(at: tmpURL, to: dst)
            DispatchQueue.main.async { self?.receivedFiles.insert(dst, at: 0) }
        }
    }

    func sendPDF(_ url: URL) {
        guard let peer = PeerShareManager.shared.session.connectedPeers.first else { return }
        _ = PeerShareManager.shared.send(file: url, to: peer)
    }
}
