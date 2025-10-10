import Foundation
import MultipeerConnectivity
import UniformTypeIdentifiers
import UIKit

public final class PeerShareManager: NSObject {
    public static let shared = PeerShareManager()

    public let serviceType: String = "psk-share" // ≤ 15 chars, a–z0–9
    public let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private var pendingSends: [MCPeerID: (url: URL, completion: ((Error?) -> Void)?)] = [:]
    private var pending: [MCPeerID: (url: URL, name: String?, completion: ((Error?) -> Void)?)] = [:]

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
    public var onFoundPeer: ((MCPeerID) -> Void)?
    public var onLostPeer: ((MCPeerID) -> Void)?

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
        if session.connectedPeers.contains(peer) {
            return send(file: url, to: peer, name: name, completion: completion)
        }
        pending[peer] = (url, name, completion)
        invite(peer, timeout: timeout)
        return nil
    }


    // wywołaj to w miejscu, gdzie już masz callback o zmianie stanu peer’a
    // (np. session(_:peer:didChange:))
    private func onPeerConnected(_ peerID: MCPeerID) {
        if let pending = pendingSends.removeValue(forKey: peerID) {
            _ = send(file: pending.url, to: peerID, completion: pending.completion)
        }
    }
    
    private func onPeerDisconnected(_ peerID: MCPeerID) {
        if let pending = pendingSends.removeValue(forKey: peerID) {
            pending.completion?(NSError(domain: "PeerShare", code: -2,
                                        userInfo: [NSLocalizedDescriptionKey: "Peer disconnected"]))
        }
    }
    public func invite(_ peer: MCPeerID, timeout: TimeInterval = 15) {
        browser.invitePeer(peer, to: session, withContext: nil, timeout: timeout)
    }

    @discardableResult
    public func send(file url: URL, to peer: MCPeerID, name: String? = nil, completion: ((Error?) -> Void)? = nil) -> Progress? {
        return session.sendResource(at: url, withName: name ?? url.lastPathComponent, toPeer: peer) { err in
            completion?(err)
        }
    }
}

extension PeerShareManager: MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate, MCSessionDelegate {

    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        onFoundPeer?(peerID)
    }
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        onLostPeer?(peerID)
    }

    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) { print("Browser error:", error) }

    // Advertiser (accept; auto-accept here – expose UI higher to ask user)
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) { print("Advertiser error:", error) }

    // Session
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        onStateChange?(peerID, state)
        switch state {
        case .connected:
            if let p = pending.removeValue(forKey: peerID) {
                _ = send(file: p.url, to: peerID, name: p.name, completion: p.completion)
            }
        case .notConnected:
            if let p = pending.removeValue(forKey: peerID) {
                p.completion?(NSError(domain: "PeerShare", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "Invitation declined or failed"]))
            }
        case .connecting: break
        @unknown default: break
        }
    }
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) { }
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { }
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        onProgress?(progress, resourceName, peerID)
    }
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        guard error == nil, let localURL else { return }
        onReceiveFile?(localURL, resourceName, peerID)
    }
}
