import SwiftUI
import UniformTypeIdentifiers
import PeerShareKit

struct ContentView: View {
    @EnvironmentObject var vm: PeerDemoVM
    @State private var showPeerSheet = false
    @State private var showFilePicker = false
    @State private var pickedURL: URL?

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Button("Wyślij przez PeerPickerView (SwiftUI sheet)") {
                    showFilePicker = true
                }

                Button("Wyślij przez systemowy modal (MCBrowserViewController)") {
                    showFilePicker = true
                }
                

                Text("Połączone: \(vm.connectedPeers.map { $0.displayName }.joined(separator: ", "))")
                    .font(.footnote).foregroundColor(.secondary)
                
                // w ContentView.swift (pod listą przycisków):
                List(vm.receivedFiles, id: \.self) { url in
                    Text(url.lastPathComponent)
                }

            }
            .padding()
            .navigationTitle("PeerShare Demo")
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { res in
            if case .success(let urls) = res, let url = urls.first {
                pickedURL = url
                // Jeśli chcesz PeerPickerView → pokaż sheet:
                showPeerSheet = true
                // Jeśli wolisz systemowy modal, odkomentuj 3 linie poniżej i usuń showPeerSheet:
                // if let topVC = topViewController() {
                //     _ = PeerShare.presentPickerAndSendPDF(from: topVC, pdfURL: url)
                // }
            }
        }
        .sheet(isPresented: $showPeerSheet) {
            if let url = pickedURL {
                PeerPickerView { peer in
                    _ = PeerShareManager.shared.send(file: url, to: peer)
                }
            }
        }
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
