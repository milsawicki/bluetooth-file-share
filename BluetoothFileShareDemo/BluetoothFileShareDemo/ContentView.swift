import SwiftUI
import UniformTypeIdentifiers
import PeerShareKit

struct ContentView: View {
    @EnvironmentObject var vm: PeerDemoVM
    @State private var showPeerSheet = false
    @State private var showFilePicker = false
    @State private var pickedURL: URL?
    @State private var previewURL: URL?
    @State private var askToSave = false
    @State private var toSaveURL: URL?
    @State private var showExporter = false


    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Button("Udostępnij plik") {
                    showFilePicker = true
                }
                

                Text("Połączone: \(vm.connectedPeers.map { $0.displayName }.joined(separator: ", "))")
                    .font(.footnote).foregroundColor(.secondary)
                

                // ...
                List(vm.receivedFiles, id: \.self) { url in
                    Button {
                        previewURL = url
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                            VStack(alignment: .leading) {
                                Text(url.lastPathComponent).lineLimit(1)
                                Text(url.deletingPathExtension().lastPathComponent)
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .contextMenu {
                        ShareLink(item: url) { Label("Udostępnij", systemImage: "square.and.arrow.up") }
                        Button(role: .destructive) {
                            try? FileManager.default.removeItem(at: url)
                            if let idx = vm.receivedFiles.firstIndex(of: url) { vm.receivedFiles.remove(at: idx) }
                        } label: { Label("Usuń", systemImage: "trash") }
                    }
                }
                .sheet(item: $previewURL) { url in
                    QuickLookPDF(url: url)
                }

            }
            .padding()
            .navigationTitle("mSzafir File Share - demo 📨")
        }
        .onReceive(vm.$lastReceivedURL.compactMap { $0 }) { url in
            toSaveURL = url
            askToSave = true
        }
        .alert("Chciałbyś zapisać ten plik na Dysk?", isPresented: $askToSave) {
            Button("Nie") {
                if let url = toSaveURL {
                    try? FileManager.default.removeItem(at: url)
                    if let idx = vm.receivedFiles.firstIndex(of: url) { vm.receivedFiles.remove(at: idx) }
                }
                toSaveURL = nil
            }
            Button("Tak") { showExporter = true }
        } message: {
            Text(toSaveURL?.lastPathComponent ?? "")
        }
        // Pokazanie eksportera
        .sheet(isPresented: $showExporter, onDismiss: {
            
        }) {
            if let url = toSaveURL {
                FileExporterView(url: url) { saved in
                    if !saved {
                        try? FileManager.default.removeItem(at: url)
                        if let idx = vm.receivedFiles.firstIndex(of: url) { vm.receivedFiles.remove(at: idx) }
                    }
                    toSaveURL = nil
                }
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { res in
            if case .success(let urls) = res, let src = urls.first {
                do {
                    let local = try prepareLocalURL(from: src)
                    pickedURL = local
                    showPeerSheet = true
                } catch {
                    print("Copy to tmp failed:", error)
                }
            }
        }

        .sheet(isPresented: $showPeerSheet) {
            if let url = pickedURL {
                PeerPickerView { peer in
                    return PeerShareManager.shared.connectAndSend(file: url, to: peer) { err in
                        if let err { print("Send error:", err) }
                    } ?? Progress(totalUnitCount: 0)
                }
            }
        }

    }
    

    func prepareLocalURL(from url: URL) throws -> URL {
        let fm = FileManager.default
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let tmp = fm.temporaryDirectory.appendingPathComponent(
            "\(UUID().uuidString)-\(url.lastPathComponent)"
        )

        // iCloud pliki → spróbuj dociągnąć
        if fm.isUbiquitousItem(at: url) {
            try? fm.startDownloadingUbiquitousItem(at: url)
        }

        // bezpieczny odczyt i kopia do tmp
        var coordErr: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordErr) { secureURL in
            try? fm.removeItem(at: tmp)
            try? fm.copyItem(at: secureURL, to: tmp)
        }
        if let e = coordErr { throw e }
        return tmp
    }

}



// Helper do wyciągnięcia top VC dla systemowego modala
func topViewController(base: UIViewController? = nil) -> UIViewController? {
    let baseVC = base ?? (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
        .windows.first(where: { $0.isKeyWindow })?.rootViewController
    if let nav = baseVC as? UINavigationController { return topViewController(base: nav.visibleViewController) }
    if let tab = baseVC as? UITabBarController { return tab.selectedViewController.flatMap { topViewController(base: $0) } }
    if let presented = baseVC?.presentedViewController { return topViewController(base: presented) }
    return baseVC
}
extension URL: Identifiable {
    public var id: String { path } // albo absoluteString
}
