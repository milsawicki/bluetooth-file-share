import Foundation
import PeerShareKit
import MultipeerConnectivity

// PeerDemoVM.swift
final class PeerDemoVM: ObservableObject {
    @Published var receivedFiles: [URL] = []
    @Published var connectedPeers: [MCPeerID] = []
    @Published var lastReceivedURL: URL? // NEW
    @Published var incomingInvitation: IncomingInvitation?

    struct IncomingInvitation: Identifiable {
        let id = UUID()
        let peer: MCPeerID
        let fileName: String?
        let respond: (Bool) -> Void
    }

    func start() {
        let mgr = PeerShareManager.shared
        mgr.start()

        mgr.onStateChange = { [weak self] _, _ in
            DispatchQueue.main.async { self?.connectedPeers = mgr.session.connectedPeers }
        }

        mgr.onReceiveFile = { [weak self] tmpURL, name, _ in
            let dst = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(name)
            try? FileManager.default.removeItem(at: dst)
            try? FileManager.default.copyItem(at: tmpURL, to: dst)
            DispatchQueue.main.async {
                self?.receivedFiles.insert(dst, at: 0)
                self?.lastReceivedURL = dst
            }
        }

        mgr.onInvitation = { [weak self] peer, context, respond in
            let fileName = Self.fileName(from: context)
            DispatchQueue.main.async {
                self?.incomingInvitation = IncomingInvitation(peer: peer, fileName: fileName, respond: respond)
            }
        }
    }

    func respond(to invitation: IncomingInvitation, accept: Bool) {
        invitation.respond(accept)
        DispatchQueue.main.async {
            self.incomingInvitation = nil
        }
    }

    private static func fileName(from context: Data?) -> String? {
        guard
            let context,
            let obj = try? JSONSerialization.jsonObject(with: context) as? [String: Any]
        else { return nil }
        return obj["name"] as? String
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
