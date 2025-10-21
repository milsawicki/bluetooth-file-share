import Foundation
import MultipeerConnectivity
import UIKit

public final class PeerShareManager: NSObject {
    public static let shared = PeerShareManager()

    public let serviceType: String = "psk-share" // ≤ 15 chars, a–z0–9
    public let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private struct PendingSend {
        let url: URL
        let name: String?
        let completion: ((Error?) -> Void)?
    }

    private var pendingRequests: [MCPeerID: PendingSend] = [:]
    private var awaitingApproval: [MCPeerID: PendingSend] = [:]

    public private(set) lazy var session: MCSession = {
        let s = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        s.delegate = self
        return s
    }()

    private lazy var advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
    private lazy var browser   = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)

    // MARK: Public API
    public var onReceiveFile: ((URL, String, MCPeerID) -> Void)?
    public var onProgress: ((Progress, String, MCPeerID) -> Void)?
    public var onStateChange: ((MCPeerID, MCSessionState) -> Void)?
    public var onIncomingRequest: ((MCPeerID, String?, @escaping (Bool) -> Void) -> Void)?
    public var onFoundPeer: ((MCPeerID) -> Void)?
    public var onLostPeer: ((MCPeerID) -> Void)?

    public weak var receivingDelegate: PeerShareReceiving?
    public weak var sendingDelegate: PeerShareSending?

    override private init() { super.init() }

    public func start() {
        advertiser.delegate = self
        browser.delegate = self
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }

    public func stop() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }
    @discardableResult
    public func connectAndSend(file url: URL,
                               to peer: MCPeerID,
                               name: String? = nil,
                               timeout: TimeInterval = 15,
                               completion: ((Error?) -> Void)? = nil) -> Progress? {
        let pending = PendingSend(url: url, name: name, completion: completion)

        if pendingRequests[peer] != nil || awaitingApproval[peer] != nil {
            completion?(NSError(domain: "PeerShare", code: -4,
                                 userInfo: [NSLocalizedDescriptionKey: "Transfer already in progress"]))
            return nil
        }

        if session.connectedPeers.contains(peer) {
            requestApproval(for: pending, from: peer)
            return nil
        }

        pendingRequests[peer] = pending
        invite(peer, context: nil, timeout: timeout)
        return nil
    }
    private func requestApproval(for pending: PendingSend, from peerID: MCPeerID) {
        awaitingApproval[peerID] = pending
        let fileName = pending.name ?? pending.url.lastPathComponent

        do {
            try sendControlMessage(.requestSend(fileName: fileName), to: peerID)
        } catch {
            awaitingApproval.removeValue(forKey: peerID)
            pending.completion?(error)
        }
    }
    public func invite(_ peer: MCPeerID, context: Data? = nil, timeout: TimeInterval = 15) {
        browser.invitePeer(peer, to: session, withContext: context, timeout: timeout)
    }

    @discardableResult
    public func send(file url: URL, to peer: MCPeerID, name: String? = nil, completion: ((Error?) -> Void)? = nil) -> Progress? {
        return session.sendResource(at: url, withName: name ?? url.lastPathComponent, toPeer: peer) { err in
            completion?(err)
        }
    }

    private func sendControlMessage(_ message: ControlMessage, to peer: MCPeerID) throws {
        let data = try JSONEncoder().encode(message)
        try session.send(data, toPeers: [peer], with: .reliable)
    }

    private func handleIncomingRequest(from peer: MCPeerID, fileName: String?) {
        var responded = false
        let responder: (Bool) -> Void = { [weak self] accept in
            guard let self, !responded else { return }
            responded = true

            do {
                try self.sendControlMessage(.responseSend(accepted: accept), to: peer)
            } catch {
                if accept {
                    self.awaitingApproval.removeValue(forKey: peer)
                }
            }

            if !accept {
                self.session.cancelConnectPeer(peer)
            }
        }

        var handledExternally = false

        if let onIncomingRequest {
            handledExternally = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                onIncomingRequest(peer, fileName, responder)
                self.receivingDelegate?.peerShareManager(self, didReceiveIncomingRequestFrom: peer, fileName: fileName, respond: responder)
            }
        } else if let delegate = receivingDelegate {
            handledExternally = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                delegate.peerShareManager(self, didReceiveIncomingRequestFrom: peer, fileName: fileName, respond: responder)
            }
        }

        if !handledExternally {
            responder(true)
        }
    }

    private func handleResponse(from peer: MCPeerID, accepted: Bool) {
        guard let pending = awaitingApproval.removeValue(forKey: peer) else { return }

        if accepted {
            _ = send(file: pending.url, to: peer, name: pending.name, completion: pending.completion)
        } else {
            pending.completion?(NSError(domain: "PeerShare", code: -3,
                                       userInfo: [NSLocalizedDescriptionKey: "Remote peer declined file"]))
            session.cancelConnectPeer(peer)
        }
    }
}

private struct ControlMessage: Codable {
    enum Action: String, Codable {
        case requestSend
        case responseSend
    }

    let action: Action
    let fileName: String?
    let accepted: Bool?

    static func requestSend(fileName: String?) -> ControlMessage {
        ControlMessage(action: .requestSend, fileName: fileName, accepted: nil)
    }

    static func responseSend(accepted: Bool) -> ControlMessage {
        ControlMessage(action: .responseSend, fileName: nil, accepted: accepted)
    }
}

extension PeerShareManager: MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate, MCSessionDelegate {

    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        onFoundPeer?(peerID)
        sendingDelegate?.peerShareManager(self, didDiscover: peerID)
    }
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        onLostPeer?(peerID)
        sendingDelegate?.peerShareManager(self, didLose: peerID)
    }

    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) { print("Browser error:", error) }

    // Advertiser automatically accepts the session; approval happens via a custom message later.
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) { print("Advertiser error:", error) }

    // Session
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        onStateChange?(peerID, state)
        sendingDelegate?.peerShareManager(self, didChangeState: state, for: peerID)
        switch state {
        case .connected:
            if let pending = pendingRequests.removeValue(forKey: peerID) {
                requestApproval(for: pending, from: peerID)
            }
        case .notConnected:
            if let p = pendingRequests.removeValue(forKey: peerID) {
                p.completion?(NSError(domain: "PeerShare", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "Invitation declined or failed"]))
            }
            if let awaiting = awaitingApproval.removeValue(forKey: peerID) {
                awaiting.completion?(NSError(domain: "PeerShare", code: -2,
                                             userInfo: [NSLocalizedDescriptionKey: "Peer disconnected"]))
            }
        case .connecting: break
        @unknown default: break
        }
    }
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(ControlMessage.self, from: data) else { return }

        switch message.action {
        case .requestSend:
            handleIncomingRequest(from: peerID, fileName: message.fileName)
        case .responseSend:
            handleResponse(from: peerID, accepted: message.accepted ?? false)
        }
    }
    public func session(_ session: MCSession,
                        didReceive certificate: [Any]?,
                        fromPeer peerID: MCPeerID,
                        certificateHandler: @escaping (Bool) -> Void) {
        guard session == self.session else {
            certificateHandler(false)
            return
        }

        // Requiring a certificate ensures the channel remains encrypted; decline if not provided.
        guard let certificate, !certificate.isEmpty else {
            certificateHandler(false)
            return
        }

        certificateHandler(true)
    }
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { }
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        onProgress?(progress, resourceName, peerID)
        sendingDelegate?.peerShareManager(self, didUpdate: progress, forFileNamed: resourceName, from: peerID)
    }
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        guard error == nil, let localURL else { return }
        onReceiveFile?(localURL, resourceName, peerID)
        receivingDelegate?.peerShareManager(self, didReceiveFileAt: localURL, named: resourceName, from: peerID)
    }
}
