import Foundation
import MultipeerConnectivity

/// Core interface for the MultipeerConnectivity helper used by PeerShareKit.
/// Conformers expose lifecycle and transfer operations while emitting events
/// through ``PeerShareServiceDelegate``.
public protocol PeerShareManaging: AnyObject {
    var session: MCSession { get }
    var delegate: PeerShareServiceDelegate? { get set }

    func start()
    func stop()

    func invite(_ peer: MCPeerID, context: Data?, timeout: TimeInterval)

    @discardableResult
    func connectAndSend(file url: URL,
                        to peer: MCPeerID,
                        name: String?,
                        timeout: TimeInterval,
                        completion: ((Error?) -> Void)?) -> Progress?

    @discardableResult
    func send(file url: URL,
              to peer: MCPeerID,
              name: String?,
              completion: ((Error?) -> Void)?) -> Progress?
}

/// Delegate that receives connection, discovery, and transfer events.
public protocol PeerShareServiceDelegate: AnyObject {
    func peerShareService(_ service: PeerShareManaging,
                          didChange state: MCSessionState,
                          for peer: MCPeerID)

    func peerShareService(_ service: PeerShareManaging,
                          didReceiveSendRequestFrom peer: MCPeerID,
                          fileName: String?,
                          respond: @escaping (Bool) -> Void)

    func peerShareService(_ service: PeerShareManaging,
                          didStartReceiving progress: Progress,
                          resourceName: String,
                          from peer: MCPeerID)

    func peerShareService(_ service: PeerShareManaging,
                          didFinishReceivingFile url: URL,
                          named resourceName: String,
                          from peer: MCPeerID)

    func peerShareService(_ service: PeerShareManaging, found peer: MCPeerID)
    func peerShareService(_ service: PeerShareManaging, lost peer: MCPeerID)
}

public extension PeerShareServiceDelegate {
    func peerShareService(_ service: PeerShareManaging,
                          didChange state: MCSessionState,
                          for peer: MCPeerID) {}

    func peerShareService(_ service: PeerShareManaging,
                          didReceiveSendRequestFrom peer: MCPeerID,
                          fileName: String?,
                          respond: @escaping (Bool) -> Void) {
        respond(true)
    }

    func peerShareService(_ service: PeerShareManaging,
                          didStartReceiving progress: Progress,
                          resourceName: String,
                          from peer: MCPeerID) {}

    func peerShareService(_ service: PeerShareManaging,
                          didFinishReceivingFile url: URL,
                          named resourceName: String,
                          from peer: MCPeerID) {}

    func peerShareService(_ service: PeerShareManaging, found peer: MCPeerID) {}
    func peerShareService(_ service: PeerShareManaging, lost peer: MCPeerID) {}
}
