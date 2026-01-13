//
//  EchoVaultApp.swift
//  EchoVault
//
//  Created by Oluwadarasimi Oloyede on 13/01/2026.
//

import SwiftUI
import CoreData

@main
struct EchoVaultApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
