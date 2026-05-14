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
    @State private var document = ProfileStoreDocument()
    @State private var currentFingerprint: DisplaySetupFingerprint?
    @State private var automationStatus = AutomationStatus.enabled
    @State private var statusMessage = ""

    private var menuModel: MenuBarModel {
        MenuBarModel.build(
            document: document,
            currentFingerprint: currentFingerprint,
            automationStatus: automationStatus
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: menuModel.iconState.systemImage)
                VStack(alignment: .leading) {
                    Text(AppConfiguration.displayName)
                        .font(.headline)
                    Text(menuModel.statusTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            if !menuModel.matchingProfiles.isEmpty {
                Text("Current Display Setup")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(menuModel.matchingProfiles) { item in
                    profileButton(item)
                }
            } else {
                Text("No matching profiles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !menuModel.otherProfiles.isEmpty {
                DisclosureGroup("Other Profiles") {
                    ForEach(menuModel.otherProfiles) { item in
                        profileButton(item)
                    }
                }
            }

            Button("Save Current Layout") {
                Task {
                    await saveCurrentLayout()
                }
            }

            Button(automationStatus == .paused ? "Resume Automation" : "Pause Automation") {
                automationStatus = automationStatus == .paused ? .enabled : .paused
            }

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
        .frame(width: 300)
        .task {
            await refreshCurrentSetup()
            loadProfiles()
        }
    }

    private func profileButton(_ item: MenuBarProfileItem) -> some View {
        Button {
            Task {
                await apply(item)
            }
        } label: {
            HStack {
                Text(item.profile.name)
                if item.isAutomaticDefault {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                if item.requiresHighRiskApply {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func loadProfiles() {
        do {
            document = try DisplayRecallStore.live().loadProfiles()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func refreshCurrentSetup() async {
        do {
            let service = try FirstRunSetupService.live()
            if case let .ready(layout) = await service.verifyBackendAndReadCurrentLayout() {
                currentFingerprint = layout.displaySetupFingerprint
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func saveCurrentLayout() async {
        do {
            let service = try FirstRunSetupService.live()
            guard case let .ready(layout) = await service.verifyBackendAndReadCurrentLayout() else {
                statusMessage = "Could not read current layout."
                return
            }
            var manager = ProfileManager(document: document)
            document = try manager.saveCurrentLayout(layout)
            try DisplayRecallStore.live().save(document)
            currentFingerprint = layout.displaySetupFingerprint
            statusMessage = "Saved current layout."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func apply(_ item: MenuBarProfileItem) async {
        do {
            let runner = try DisplayplacerBackend.bundledRunner()
            let manager = ProfileManager(document: document)
            let result = try await manager.apply(item.profile) { arguments in
                try await runner.run(arguments: arguments)
            }
            if item.requiresHighRiskApply {
                statusMessage = result.exitCode == 0
                    ? "Applied \(item.profile.name). Review this high-risk change."
                    : result.stderr
            } else {
                statusMessage = result.exitCode == 0 ? "Applied \(item.profile.name)." : result.stderr
            }
        } catch {
            statusMessage = error.localizedDescription
        }
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
    @State private var document = ProfileStoreDocument()
    @State private var selectedProfileID: UUID?
    @State private var statusMessage = ""

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedProfileID) {
                ForEach(document.profiles) { profile in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .fontWeight(.medium)
                        Text(profile.displaySummary.isEmpty ? profile.displaySetupFingerprint.rawValue : profile.displaySummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if isAutomaticDefault(profile) {
                            Label("Automatic default", systemImage: "checkmark.circle")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    .tag(profile.id)
                }
            }
            .navigationTitle(AppWindow.profiles.title)
            .toolbar {
                Button {
                    Task {
                        await saveCurrentLayout()
                    }
                } label: {
                    Label("Save Current Layout", systemImage: "plus")
                }
            }
        } detail: {
            if let selectedProfileBinding {
                ProfileDetailView(
                    profile: selectedProfileBinding,
                    isAutomaticDefault: isAutomaticDefault(selectedProfileBinding.wrappedValue),
                    statusMessage: statusMessage,
                    onApply: { profile in
                        Task {
                            await apply(profile)
                        }
                    },
                    onSetDefault: { profile in
                        setAutomaticDefault(profile)
                    },
                    onClearDefault: { profile in
                        clearAutomaticDefault(profile)
                    },
                    onRebind: { profile in
                        Task {
                            await rebind(profile)
                        }
                    },
                    onSaveCommand: { profile, command in
                        updateCommand(profile, command: command)
                    }
                )
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "display.2")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)

                    Text("No Profile Selected")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Save your current display layout or select a profile.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .task {
            loadProfiles()
        }
    }

    private var selectedProfileBinding: Binding<DisplayProfile>? {
        guard let selectedProfileID,
              let index = document.profiles.firstIndex(where: { $0.id == selectedProfileID }) else {
            return nil
        }

        return Binding(
            get: { document.profiles[index] },
            set: { newValue in
                document.profiles[index] = newValue
                saveDocument()
            }
        )
    }

    private func loadProfiles() {
        do {
            let store = try DisplayRecallStore.live()
            document = try store.loadProfiles()
            selectedProfileID = selectedProfileID ?? document.profiles.first?.id
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func saveDocument() {
        do {
            try DisplayRecallStore.live().save(document)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func saveCurrentLayout() async {
        do {
            let service = try FirstRunSetupService.live()
            guard case let .ready(layout) = await service.verifyBackendAndReadCurrentLayout() else {
                statusMessage = "Could not read current layout."
                return
            }
            var manager = ProfileManager(document: document)
            document = try manager.saveCurrentLayout(layout)
            selectedProfileID = document.profiles.last?.id
            saveDocument()
            statusMessage = "Saved current layout."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func apply(_ profile: DisplayProfile) async {
        do {
            let runner = try DisplayplacerBackend.bundledRunner()
            let manager = ProfileManager(document: document)
            let result = try await manager.apply(profile) { arguments in
                try await runner.run(arguments: arguments)
            }
            statusMessage = result.exitCode == 0 ? "Applied \(profile.name)." : result.stderr
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func setAutomaticDefault(_ profile: DisplayProfile) {
        do {
            var manager = ProfileManager(document: document)
            try manager.setAutomaticDefault(
                profileID: profile.id,
                for: profile.displaySetupFingerprint
            )
            document = manager.document
            saveDocument()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func clearAutomaticDefault(_ profile: DisplayProfile) {
        var manager = ProfileManager(document: document)
        manager.clearAutomaticDefault(for: profile.displaySetupFingerprint)
        document = manager.document
        saveDocument()
    }

    private func rebind(_ profile: DisplayProfile) async {
        do {
            let service = try FirstRunSetupService.live()
            guard case let .ready(layout) = await service.verifyBackendAndReadCurrentLayout() else {
                statusMessage = "Could not read current display setup."
                return
            }
            var manager = ProfileManager(document: document)
            try manager.rebind(
                profileID: profile.id,
                to: layout.displaySetupFingerprint,
                displaySummary: layout.displaySummary
            )
            document = manager.document
            saveDocument()
            statusMessage = "Rebound \(profile.name)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func updateCommand(_ profile: DisplayProfile, command: String) {
        do {
            var manager = ProfileManager(document: document)
            try manager.updateCommand(profileID: profile.id, command: command)
            document = manager.document
            saveDocument()
            statusMessage = "Command saved."
        } catch {
            statusMessage = "Invalid displayplacer command."
        }
    }

    private func isAutomaticDefault(_ profile: DisplayProfile) -> Bool {
        document.automaticDefaultRules.contains {
            $0.profileId == profile.id && $0.displaySetupFingerprint == profile.displaySetupFingerprint
        }
    }
}

struct ProfileDetailView: View {
    @Binding var profile: DisplayProfile
    let isAutomaticDefault: Bool
    let statusMessage: String
    let onApply: (DisplayProfile) -> Void
    let onSetDefault: (DisplayProfile) -> Void
    let onClearDefault: (DisplayProfile) -> Void
    let onRebind: (DisplayProfile) -> Void
    let onSaveCommand: (DisplayProfile, String) -> Void

    @State private var commandDraft = ""

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Name", text: $profile.name)
                TextField("Notes", text: $profile.notes, axis: .vertical)
            }

            Section("Display Setup") {
                LabeledContent("Summary", value: profile.displaySummary)
                LabeledContent("Fingerprint", value: profile.displaySetupFingerprint.rawValue)
                Toggle("Automatic default for this setup", isOn: .constant(isAutomaticDefault))
                    .disabled(true)
                HStack {
                    Button(isAutomaticDefault ? "Clear Default" : "Set Default") {
                        isAutomaticDefault ? onClearDefault(profile) : onSetDefault(profile)
                    }
                    Button("Rebind to Current Displays") {
                        onRebind(profile)
                    }
                }
            }

            Section("Advanced Command") {
                TextEditor(text: $commandDraft)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)
                    .onAppear {
                        commandDraft = profile.command
                    }
                    .onChange(of: profile.id) { _ in
                        commandDraft = profile.command
                    }

                HStack {
                    Button("Save Command") {
                        onSaveCommand(profile, commandDraft)
                    }
                    Button("Apply") {
                        onApply(profile)
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }

            if !statusMessage.isEmpty {
                Section("Status") {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
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
