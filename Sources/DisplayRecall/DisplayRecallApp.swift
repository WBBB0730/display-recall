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
    @AppStorage(SetupPreference.completedUserDefaultsKey) private var setupCompleted = false

    var body: some View {
        if setupCompleted {
            ProfilesContentView()
        } else {
            SetupView(setupCompleted: $setupCompleted)
        }
    }
}

struct SetupView: View {
    @Binding var setupCompleted: Bool
    @State private var setupState = FirstRunSetupState.idle
    @State private var profileName = ""
    @State private var makeAutomaticDefault = true
    @State private var createdProfile: DisplayProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Welcome to Display Recall")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Display Recall will verify its bundled displayplacer backend, then save your current display layout as the first profile.")
                .foregroundStyle(.secondary)

            setupContent

            Spacer()
        }
        .padding(28)
        .frame(minWidth: 560, minHeight: 420)
        .task {
            await verifyBackend()
        }
    }

    @ViewBuilder
    private var setupContent: some View {
        switch setupState {
        case .idle, .verifying:
            ProgressView("Verifying bundled displayplacer...")

        case let .failed(error):
            VStack(alignment: .leading, spacing: 12) {
                Label("displayplacer verification failed", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                Text(error.stderr)
                    .foregroundStyle(.secondary)
                Button(error.recoveryActionTitle) {
                    Task {
                        await verifyBackend()
                    }
                }
            }

        case let .ready(layout):
            VStack(alignment: .leading, spacing: 14) {
                Label("displayplacer is ready", systemImage: "checkmark.circle")
                    .font(.headline)

                TextField("Profile name", text: $profileName)
                    .textFieldStyle(.roundedBorder)
                    .onAppear {
                        if profileName.isEmpty {
                            profileName = layout.generatedProfileName
                        }
                    }

                Toggle("Automatically use this profile for this display setup", isOn: $makeAutomaticDefault)

                Button("Create Profile") {
                    completeSetup(with: layout)
                }
                .keyboardShortcut(.defaultAction)
            }

        case let .completed(profile):
            VStack(alignment: .leading, spacing: 12) {
                Label("Created \(profile.name)", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                Button("Open Profiles") {
                    setupCompleted = true
                }
            }
        }
    }

    private func verifyBackend() async {
        setupState = .verifying

        do {
            let service = try FirstRunSetupService.live()
            setupState = await service.verifyBackendAndReadCurrentLayout()
        } catch let error as DisplayplacerBackendError {
            setupState = .failed(error)
        } catch {
            setupState = .failed(
                DisplayplacerBackendError(
                    kind: .launchFailed,
                    backendPath: "displayplacer",
                    backendVersion: DisplayplacerBackend.bundledMetadata.version,
                    backendSource: .bundled,
                    stderr: error.localizedDescription
                )
            )
        }
    }

    private func completeSetup(with layout: CurrentDisplayLayout) {
        let service = FirstRunSetupService { DisplayplacerBackendRunResult(
            stdout: "",
            stderr: "",
            exitCode: 0,
            backendPath: "",
            backendArchitecture: .current,
            backendVersion: DisplayplacerBackend.bundledMetadata.version,
            backendSource: .bundled
        ) }
        let completion = service.createFirstProfile(
            from: layout,
            editedName: profileName,
            makeAutomaticDefault: makeAutomaticDefault
        )

        do {
            let store = try DisplayRecallStore.live()
            try store.save(
                ProfileStoreDocument(
                    profiles: [completion.profile],
                    automaticDefaultRules: completion.automaticDefaultRule.map { [$0] } ?? []
                )
            )
            try store.save(
                SettingsStoreDocument(
                    settings: AppSettings(setupCompleted: true, showDockIcon: false)
                )
            )
            createdProfile = completion.profile
            setupState = .completed(completion.profile)
            setupCompleted = true
        } catch {
            setupState = .failed(
                DisplayplacerBackendError(
                    kind: .launchFailed,
                    backendPath: "Application Support",
                    backendVersion: DisplayplacerBackend.bundledMetadata.version,
                    backendSource: .bundled,
                    stderr: error.localizedDescription
                )
            )
        }
    }
}

struct ProfilesContentView: View {
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
