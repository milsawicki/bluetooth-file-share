import MultipeerConnectivity
import SwiftUI
import Combine

public struct PeerPickerView: View {
    @State private var peers: [MCPeerID] = []
    @State private var connected: [MCPeerID] = []
    @State private var progressMap: [MCPeerID: Double] = [:]
    @State private var sending: Set<MCPeerID> = []
    @State private var cancellables: [MCPeerID: AnyCancellable] = [:]
    let manager = PeerShareManager.shared
    let onSelectPeer: (MCPeerID) -> Progress?

    public init(onSelectPeer: @escaping (MCPeerID) -> Progress) {
        self.onSelectPeer = onSelectPeer
    }

    public var body: some View {
        NavigationView {
            List {
                Section("Połączone") {
                    ForEach(connected, id: \.self) { p in
                        HStack {
                            Text("✅ \(p.displayName)")
                            if let pr = progressMap[p] {
                                Spacer()
                                Text(String(format: "%.0f%%", pr * 100))
                            }
                        }
                    }
                }
                Section("Urządzenia w pobliżu") {
                    ForEach(peers, id: \.self) { p in
                        HStack {
                            Text(p.displayName)
                            Spacer()
                            Button {
                                guard !sending.contains(p) else { return }
                                sending.insert(p)
                                onSelectPeer(p) // tu wywołasz connectAndSend(...)
                            } label: {
                                sending.contains(p) ? AnyView(ProgressView().controlSize(.small))
                                                    : AnyView(Text("Wyślij"))
                            }

                            .disabled(sending.contains(p))

                        }
                    }
                }
            }
            .navigationTitle("Wybierz urządzenie")
        }
        .onAppear {
            manager.onFoundPeer = { peer in
                DispatchQueue.main.async {
                    if !peers.contains(peer) { peers.append(peer) }
                }
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
            DispatchQueue.main.async {
                progressMap[peer] = progress.fractionCompleted
            }
        }
        manager.start()

    }
}
