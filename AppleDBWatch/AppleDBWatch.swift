//
//  AppleDBWatchApp.swift
//  AppleDBWatchApp
//
//  Created by Kane Parkinson on 06/05/2024.
//

import SwiftUI

@main
struct PearDBWrist_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, HardwareProvider.shared.viewContext)
        }
    }
}