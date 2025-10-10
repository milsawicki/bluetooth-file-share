import SwiftUI
import MultipeerConnectivity

public struct PeerPickerView: View {
    @State private var peers: [MCPeerID] = []
    @State private var connected: [MCPeerID] = []
    @State private var progressMap: [MCPeerID: Double] = [:]

    let manager = PeerShareManager.shared
    let onSelectPeer: (MCPeerID) -> Void

    public init(onSelectPeer: @escaping (MCPeerID) -> Void) {
        self.onSelectPeer = onSelectPeer
    }

    public var body: some View {
        NavigationView {
            List {
                Section("Połączone") {
                    ForEach(connected, id: \.self) { p in
                        HStack {
                            Text("✅ \(p.displayName)")
                            if let pr = progressMap[p] { Spacer(); Text(String(format: "%.0f%%", pr * 100)) }
                        }
                    }
                }
                Section("Urządzenia w pobliżu") {
                    ForEach(peers, id: \.self) { p in
                        HStack {
                            Text(p.displayName)
                            Spacer()
                            Button("Połącz") { manager.invite(p) }
                            Button("Wyślij") { onSelectPeer(p) }
                                .disabled(!connected.contains(p))
                        }
                    }
                }
            }
            .navigationTitle("Wybierz urządzenie")
        }
        .onAppear {
            manager.onFoundPeer = { peer in
                DispatchQueue.main.async { if !peers.contains(peer) { peers.append(peer) } }
            }
            manager.onLostPeer = { peer in
                DispatchQueue.main.async { peers.removeAll { $0 == peer } }
            }
bind()
        }
    }

    private func bind() {
        // PeerPickerView.bind()
        manager.onStateChange = { _, _ in
            DispatchQueue.main.async {
                connected = manager.session.connectedPeers
            }
        }
        manager.onProgress = { progress, _, peer in
            DispatchQueue.main.async { progressMap[peer] = progress.fractionCompleted }
        }
        manager.start()

    }
}
