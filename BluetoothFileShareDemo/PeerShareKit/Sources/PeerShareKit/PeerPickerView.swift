import MultipeerConnectivity
import SwiftUI
import Combine

public struct PeerPickerView: View {
    @StateObject private var adapter = PeerPickerAdapter()
    @State private var sending: Set<MCPeerID> = []
    let manager = PeerShareManager.shared
    let onSelectPeer: (MCPeerID) -> Progress?

    public init(onSelectPeer: @escaping (MCPeerID) -> Progress) {
        self.onSelectPeer = onSelectPeer
    }

    public var body: some View {
        NavigationView {
            List {
                Section("Połączone") {
                    ForEach(adapter.connected, id: \.self) { p in
                        HStack {
                            Text("✅ \(p.displayName)")
                            if let pr = adapter.progressMap[p] {
                                Spacer()
                                Text(String(format: "%.0f%%", pr * 100))
                            }
                        }
                    }
                }
                Section("Urządzenia w pobliżu") {
                    ForEach(adapter.peers, id: \.self) { p in
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
            adapter.bind(to: manager)
        }
        .onDisappear {
            adapter.unbind(from: manager)
        }
    }
}

private final class PeerPickerAdapter: ObservableObject, PeerShareSending {
    @Published var peers: [MCPeerID] = []
    @Published var connected: [MCPeerID] = []
    @Published var progressMap: [MCPeerID: Double] = [:]
    private weak var previousDelegate: PeerShareSending?

    func bind(to manager: PeerShareManager) {
        previousDelegate = manager.sendingDelegate
        manager.sendingDelegate = self
        connected = manager.session.connectedPeers
        manager.start()
    }

    func unbind(from manager: PeerShareManager) {
        if manager.sendingDelegate === self {
            manager.sendingDelegate = previousDelegate
        }
        previousDelegate = nil
    }

    func peerShareManager(_ manager: PeerShareManager, didDiscover peer: MCPeerID) {
        DispatchQueue.main.async {
            if !self.peers.contains(peer) {
                self.peers.append(peer)
            }
        }
    }

    func peerShareManager(_ manager: PeerShareManager, didLose peer: MCPeerID) {
        DispatchQueue.main.async {
            self.peers.removeAll { $0 == peer }
            self.progressMap.removeValue(forKey: peer)
        }
    }

    func peerShareManager(_ manager: PeerShareManager, didChangeState state: MCSessionState, for peer: MCPeerID) {
        DispatchQueue.main.async {
            self.connected = manager.session.connectedPeers
        }
    }

    func peerShareManager(_ manager: PeerShareManager, didUpdate progress: Progress, forFileNamed name: String, from peer: MCPeerID) {
        DispatchQueue.main.async {
            self.progressMap[peer] = progress.fractionCompleted
        }
    }
}
