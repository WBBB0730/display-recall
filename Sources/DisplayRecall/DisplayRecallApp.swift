import AppKit
import DisplayRecallCore
import SwiftUI

@main
struct DisplayRecallApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra(AppConfiguration.displayName, systemImage: "display.2") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.window)

        WindowGroup(AppWindow.profiles.title, id: AppWindow.profiles.id) {
            ProfilesView()
        }
        .defaultSize(width: 760, height: 520)

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DockIconController.applyCurrentPreference()
    }
}

@MainActor
enum DockIconController {
    static func applyCurrentPreference(defaults: UserDefaults = .standard) {
        let showDockIcon = defaults.bool(forKey: DockIconPreference.userDefaultsKey)
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
    }

    static func apply(showDockIcon: Bool) {
        UserDefaults.standard.set(showDockIcon, forKey: DockIconPreference.userDefaultsKey)
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
    }
}

struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppConfiguration.displayName)
                .font(.headline)

            Divider()

            Button(AppMenuAction.openProfiles.title) {
                openWindow(id: AppWindow.profiles.id)
                NSApp.activate(ignoringOtherApps: true)
            }

            Button(AppMenuAction.openSettings.title) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            Button(AppMenuAction.quit.title) {
                NSApp.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 260)
    }
}

struct ProfilesView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Text("Profiles")
            }
            .navigationTitle(AppWindow.profiles.title)
        } detail: {
            VStack(spacing: 12) {
                Image(systemName: "display.2")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)

                Text("No Profiles")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Save your current display layout to create a profile.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }
}

struct SettingsView: View {
    @AppStorage(DockIconPreference.userDefaultsKey) private var showDockIcon = false

    var body: some View {
        Form {
            Section("Backend") {
                LabeledContent("Source", value: "Bundled")
                LabeledContent("displayplacer", value: DisplayplacerBackend.bundledMetadata.version)
                LabeledContent("Architecture", value: DisplayplacerBackendArchitecture.current.rawValue)
            }

            Toggle("Show Dock icon", isOn: $showDockIcon)
                .onChange(of: showDockIcon) { newValue in
                    DockIconController.apply(showDockIcon: newValue)
                }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 420)
    }
}
