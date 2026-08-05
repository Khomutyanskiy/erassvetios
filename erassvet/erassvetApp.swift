//
//  erassvetApp.swift
//  erassvet
//
//  Created by Khomutyanskiy Aleksey on 02.08.2026.
//

import SwiftUI
import CoreData
import FirebaseCore

@main
struct erassvetApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let persistenceController = PersistenceController.shared
    @StateObject private var authViewModel = AuthViewModel()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(authViewModel)
                .preferredColorScheme(.dark)
        }
    }
}
