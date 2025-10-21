import UIKit
import MultipeerConnectivity

public final class PeerSendViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let manager = PeerShareManager.shared
    private let fileURL: URL
    private let fileName: String?
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var discoveredPeers: [MCPeerID] = []
    private var connectedPeers: [MCPeerID] = []
    private var progressMap: [MCPeerID: Double] = [:]
    private var sendingPeers: Set<MCPeerID> = []

    private var sendCompletion: ((Result<MCPeerID, Error>) -> Void)?
    private var previousFoundPeerHandler: ((MCPeerID) -> Void)?
    private var previousLostPeerHandler: ((MCPeerID) -> Void)?
    private var previousStateChangeHandler: ((MCPeerID, MCSessionState) -> Void)?
    private var previousProgressHandler: ((Progress, String, MCPeerID) -> Void)?

    public init(fileURL: URL, fileName: String? = nil, onFinish: ((Result<MCPeerID, Error>) -> Void)? = nil) {
        self.fileURL = fileURL
        self.fileName = fileName
        self.sendCompletion = onFinish
        super.init(nibName: nil, bundle: nil)
        title = "Send File"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        manager.start()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        bindManagerCallbacks()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unbindManagerCallbacks()
    }

    private func bindManagerCallbacks() {
        previousFoundPeerHandler = manager.onFoundPeer
        previousLostPeerHandler = manager.onLostPeer
        previousStateChangeHandler = manager.onStateChange
        previousProgressHandler = manager.onProgress

        manager.onFoundPeer = { [weak self] peer in
            guard let self else { return }
            DispatchQueue.main.async {
                if !self.discoveredPeers.contains(peer) {
                    self.discoveredPeers.append(peer)
                    self.tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
                }
            }
        }

        manager.onLostPeer = { [weak self] peer in
            guard let self else { return }
            DispatchQueue.main.async {
                self.discoveredPeers.removeAll { $0 == peer }
                self.tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
            }
        }

        manager.onStateChange = { [weak self] _, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.connectedPeers = self.manager.session.connectedPeers
                self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
            }
        }

        manager.onProgress = { [weak self] progress, _, peer in
            guard let self else { return }
            DispatchQueue.main.async {
                self.progressMap[peer] = progress.fractionCompleted
                if let index = self.connectedPeers.firstIndex(of: peer) {
                    self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                }
            }
        }
    }

    private func unbindManagerCallbacks() {
        manager.onFoundPeer = previousFoundPeerHandler
        manager.onLostPeer = previousLostPeerHandler
        manager.onStateChange = previousStateChangeHandler
        manager.onProgress = previousProgressHandler
    }

    public func numberOfSections(in tableView: UITableView) -> Int { 2 }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return connectedPeers.count
        default: return discoveredPeers.count
        }
    }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Connected" : "Nearby"
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.selectionStyle = .none

        switch indexPath.section {
        case 0:
            let peer = connectedPeers[indexPath.row]
            var content = cell.defaultContentConfiguration()
            content.text = peer.displayName
            if let progress = progressMap[peer] {
                content.secondaryText = String(format: "%.0f%%", progress * 100)
            } else {
                content.secondaryText = "Connected"
            }
            cell.contentConfiguration = content
        default:
            let peer = discoveredPeers[indexPath.row]
            var content = cell.defaultContentConfiguration()
            content.text = peer.displayName
            if sendingPeers.contains(peer) {
                content.secondaryText = "Sending..."
            } else {
                content.secondaryText = "Tap to send"
            }
            cell.contentConfiguration = content
        }

        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 1 else { return }
        let peer = discoveredPeers[indexPath.row]
        guard !sendingPeers.contains(peer) else { return }
        sendingPeers.insert(peer)
        tableView.reloadRows(at: [indexPath], with: .none)

        manager.connectAndSend(file: fileURL, to: peer, name: fileName) { [weak self] error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.sendingPeers.remove(peer)
                self.tableView.reloadRows(at: [indexPath], with: .automatic)
                if let error {
                    self.sendCompletion?(.failure(error))
                } else {
                    self.sendCompletion?(.success(peer))
                }
            }
        }
    }
}
