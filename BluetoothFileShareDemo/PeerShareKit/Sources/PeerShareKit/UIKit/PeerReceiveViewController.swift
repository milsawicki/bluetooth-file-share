import UIKit
import MultipeerConnectivity

public final class PeerReceiveViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let manager = PeerShareManager.shared
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let statusLabel = UILabel()
    private var previewController: UIDocumentInteractionController?

    private var connectedPeers: [MCPeerID] = [] {
        didSet { updateStatus() }
    }
    private var receivedFiles: [URL] = []
    private var previousStateChangeHandler: ((MCPeerID, MCSessionState) -> Void)?
    private var previousIncomingRequestHandler: ((MCPeerID, String?, @escaping (Bool) -> Void) -> Void)?
    private var previousReceiveFileHandler: ((URL, String, MCPeerID) -> Void)?

    public var onFileReceived: ((URL) -> Void)?
    public var shouldAutoAcceptRequests: Bool

    public init(shouldAutoAcceptRequests: Bool = false, onFileReceived: ((URL) -> Void)? = nil) {
        self.shouldAutoAcceptRequests = shouldAutoAcceptRequests
        self.onFileReceived = onFileReceived
        super.init(nibName: nil, bundle: nil)
        title = "Incoming Files"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        view.addSubview(statusLabel)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        manager.start()
        updateStatus()
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
        previousStateChangeHandler = manager.onStateChange
        previousIncomingRequestHandler = manager.onIncomingRequest
        previousReceiveFileHandler = manager.onReceiveFile

        manager.onStateChange = { [weak self] _, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.connectedPeers = self.manager.session.connectedPeers
            }
        }

        manager.onIncomingRequest = { [weak self] peer, fileName, respond in
            guard let self else { return }
            if self.shouldAutoAcceptRequests {
                respond(true)
                return
            }

            let message = fileName ?? "Accept incoming file from \(peer.displayName)?"
            DispatchQueue.main.async {
                let alert = UIAlertController(title: peer.displayName, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Decline", style: .cancel, handler: { _ in respond(false) }))
                alert.addAction(UIAlertAction(title: "Accept", style: .default, handler: { _ in respond(true) }))
                self.present(alert, animated: true)
            }
        }

        manager.onReceiveFile = { [weak self] tempURL, name, _ in
            guard let self else { return }
            let destination = self.makeDestinationURL(fileName: name)
            do {
                try FileManager.default.removeItem(at: destination)
            } catch { }

            do {
                try FileManager.default.copyItem(at: tempURL, to: destination)
                DispatchQueue.main.async {
                    self.receivedFiles.insert(destination, at: 0)
                    self.tableView.reloadData()
                    self.onFileReceived?(destination)
                }
            } catch {
                DispatchQueue.main.async {
                    self.presentError("Failed to copy incoming file: \(error.localizedDescription)")
                }
            }
        }
    }

    private func unbindManagerCallbacks() {
        manager.onStateChange = previousStateChangeHandler
        manager.onIncomingRequest = previousIncomingRequestHandler
        manager.onReceiveFile = previousReceiveFileHandler
    }

    private func updateStatus() {
        let names = connectedPeers.map { $0.displayName }.joined(separator: ", ")
        if names.isEmpty {
            statusLabel.text = "Waiting for peers..."
        } else {
            statusLabel.text = "Connected: \(names)"
        }
    }

    private func makeDestinationURL(fileName: String?) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let safeName = fileName?.isEmpty == false ? fileName! : UUID().uuidString + ".dat"
        return docs.appendingPathComponent(safeName)
    }

    private func presentError(_ message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }

    // MARK: UITableView

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        receivedFiles.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let url = receivedFiles[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = url.lastPathComponent
        content.secondaryText = url.deletingPathExtension().lastPathComponent
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let url = receivedFiles[indexPath.row]
        let preview = UIDocumentInteractionController(url: url)
        preview.delegate = self
        previewController = preview
        preview.presentPreview(animated: true)
    }
}

extension PeerReceiveViewController: UIDocumentInteractionControllerDelegate {
    public func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        self
    }

    public func documentInteractionControllerDidEndPreview(_ controller: UIDocumentInteractionController) {
        if previewController === controller {
            previewController = nil
        }
    }
}
