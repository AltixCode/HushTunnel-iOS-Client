import ApplicationLibrary
import Foundation
import Library
import SwiftUI

@main
struct Application: App {
    @UIApplicationDelegateAdaptor private var appDelegate: ApplicationDelegate
    @StateObject private var environments = ExtensionEnvironments()
    @StateObject private var authStore = AuthStore.shared
    @StateObject private var langManager = LanguageManager.shared

    init() {
        Task { @MainActor in
            ImportedFontStore.shared.bootstrap()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environments)
                .environmentObject(authStore)
                .environmentObject(langManager)
        }
    }
}
