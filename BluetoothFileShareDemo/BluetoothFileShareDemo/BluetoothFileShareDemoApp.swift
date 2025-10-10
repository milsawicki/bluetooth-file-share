//
//  BluetoothFileShareDemoApp.swift
//  BluetoothFileShareDemo
//
//  Created by Milan Sawicki on 09/10/2025.
//

import SwiftUI

@main
struct BluetoothFileShareDemoApp: App {
    
    @StateObject private var vm = PeerDemoVM()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .onAppear { vm.start() }
        }
    }
}
