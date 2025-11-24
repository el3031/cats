//
//  MoodleApp.swift
//  Moodle
//
//  Created by Elaine Lee on 11/24/25.
//

import SwiftUI

@main
struct MoodleApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        // Debug: List available fonts on app launch
        #if DEBUG
        FontHelper.listAvailableFonts()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
