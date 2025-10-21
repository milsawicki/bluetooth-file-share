import Foundation
import MultipeerConnectivity

public protocol PeerShareReceiving: AnyObject {
    func peerShareManager(_ manager: PeerShareManager,
                          didReceiveFileAt url: URL,
                          named name: String,
                          from peer: MCPeerID)
    func peerShareManager(_ manager: PeerShareManager,
                          didReceiveIncomingRequestFrom peer: MCPeerID,
                          fileName: String?,
                          respond: @escaping (Bool) -> Void)
}

public extension PeerShareReceiving {
    func peerShareManager(_ manager: PeerShareManager,
                          didReceiveFileAt url: URL,
                          named name: String,
                          from peer: MCPeerID) {}

    func peerShareManager(_ manager: PeerShareManager,
                          didReceiveIncomingRequestFrom peer: MCPeerID,
                          fileName: String?,
                          respond: @escaping (Bool) -> Void) {
        respond(true)
    }
}

public protocol PeerShareSending: AnyObject {
    func peerShareManager(_ manager: PeerShareManager,
                          didDiscover peer: MCPeerID)
    func peerShareManager(_ manager: PeerShareManager,
                          didLose peer: MCPeerID)
    func peerShareManager(_ manager: PeerShareManager,
                          didChangeState state: MCSessionState,
                          for peer: MCPeerID)
    func peerShareManager(_ manager: PeerShareManager,
                          didUpdate progress: Progress,
                          forFileNamed name: String,
                          from peer: MCPeerID)
}

public extension PeerShareSending {
    func peerShareManager(_ manager: PeerShareManager,
                          didDiscover peer: MCPeerID) {}

    func peerShareManager(_ manager: PeerShareManager,
                          didLose peer: MCPeerID) {}

    func peerShareManager(_ manager: PeerShareManager,
                          didChangeState state: MCSessionState,
                          for peer: MCPeerID) {}

    func peerShareManager(_ manager: PeerShareManager,
                          didUpdate progress: Progress,
                          forFileNamed name: String,
                          from peer: MCPeerID) {}
}
