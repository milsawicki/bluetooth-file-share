import Foundation
import PeerShareKit
import MultipeerConnectivity

// PeerDemoVM.swift
final class PeerDemoVM: ObservableObject {
    @Published var receivedFiles: [URL] = []
    @Published var connectedPeers: [MCPeerID] = []
    @Published var lastReceivedURL: URL? // NEW
    @Published var incomingRequest: IncomingRequest?

    struct IncomingRequest: Identifiable {
        let id = UUID()
        let peer: MCPeerID
        let fileName: String?
        let respond: (Bool) -> Void
    }

    func start() {
        let mgr = PeerShareManager.shared
        mgr.delegate = self
        mgr.start()
    }

    func respond(to request: IncomingRequest, accept: Bool) {
        request.respond(accept)
        DispatchQueue.main.async {
            self.incomingRequest = nil
        }
    }
}

extension PeerDemoVM: PeerShareServiceDelegate {
    func peerShareService(_ service: PeerShareManaging, didChange state: MCSessionState, for peer: MCPeerID) {
        DispatchQueue.main.async {
            self.connectedPeers = service.session.connectedPeers
        }
    }

    func peerShareService(_ service: PeerShareManaging,
                          didReceiveSendRequestFrom peer: MCPeerID,
                          fileName: String?,
                          respond: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            self.incomingRequest = IncomingRequest(peer: peer, fileName: fileName, respond: respond)
        }
    }

    func peerShareService(_ service: PeerShareManaging,
                          didFinishReceivingFile url: URL,
                          named resourceName: String,
                          from peer: MCPeerID) {
        let dst = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(resourceName)
        try? FileManager.default.removeItem(at: dst)
        try? FileManager.default.copyItem(at: url, to: dst)

        DispatchQueue.main.async {
            self.receivedFiles.insert(dst, at: 0)
            self.lastReceivedURL = dst
        }
    }
}

import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct FileExporterView: UIViewControllerRepresentable {
    let url: URL
    let onFinish: (Bool) -> Void // true = zapisano, false = anulowano

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let vc = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coord { Coord(onFinish: onFinish) }
    final class Coord: NSObject, UIDocumentPickerDelegate {
        let onFinish: (Bool) -> Void
        init(onFinish: @escaping (Bool) -> Void) { self.onFinish = onFinish }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onFinish(false)
        }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onFinish(true)
        }
    }
}
