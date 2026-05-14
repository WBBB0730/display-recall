import AppKit
import DisplayRecallCore
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

@main
struct DisplayRecallApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra(AppConfiguration.displayName, systemImage: "display.2") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.window)

        WindowGroup(AppWindow.main.title, id: AppWindow.main.id) {
            MainWindowView()
        }
        .defaultSize(width: 920, height: 620)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var displayChangeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        DockIconController.applyCurrentPreference()
        displayChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            NotificationCenter.default.post(name: .displayRecallDisplaySetupChanged, object: nil)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(AutomaticApplyCoordinator.startupStabilitySeconds))
            NotificationCenter.default.post(name: .displayRecallStartupStabilized, object: nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let displayChangeObserver {
            NotificationCenter.default.removeObserver(displayChangeObserver)
        }
    }
}

extension Notification.Name {
    static let displayRecallDisplaySetupChanged = Notification.Name("DisplayRecallDisplaySetupChanged")
    static let displayRecallStartupStabilized = Notification.Name("DisplayRecallStartupStabilized")
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

@MainActor
final class MainWindowRouter: ObservableObject {
    static let shared = MainWindowRouter()

    @Published var selectedSection = MainWindowSection.default

    private init() {}

    func select(_ section: MainWindowSection) {
        selectedSection = section
    }
}

struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var document = ProfileStoreDocument()
    @State private var currentFingerprint: DisplaySetupFingerprint?
    @State private var automationStatus = AutomationStatus.enabled
    @State private var automaticCoordinator = AutomaticApplyCoordinator(countdownSeconds: 5)
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

            switch automaticCoordinator.state {
            case let .pending(profile, remainingSeconds, trigger):
                VStack(alignment: .leading, spacing: 8) {
                    Label("Pending automatic apply", systemImage: "timer")
                        .font(.headline)
                    Text("\(remainingSeconds)s: \(profile.name)")
                        .font(.caption)
                    Text(trigger == .startup ? "Startup" : "Display change")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Apply Now") {
                            Task {
                                automaticCoordinator.state = .idle
                                await apply(MenuBarProfileItem(
                                    profile: profile,
                                    currentFingerprint: currentFingerprint,
                                    isAutomaticDefault: true
                                ))
                            }
                        }
                        Button("Stop") {
                            automaticCoordinator.stopPendingApply()
                        }
                        Button("Pause") {
                            automationStatus = .paused
                            automaticCoordinator.pauseAutomation()
                        }
                    }
                }
                Divider()

            case let .needsChoice(matchingProfiles):
                VStack(alignment: .leading, spacing: 8) {
                    Label("Choose a profile", systemImage: "questionmark.circle")
                        .font(.headline)
                    ForEach(matchingProfiles) { profile in
                        Button(profile.name) {
                            Task {
                                await apply(MenuBarProfileItem(
                                    profile: profile,
                                    currentFingerprint: currentFingerprint,
                                    isAutomaticDefault: false
                                ))
                            }
                        }
                    }
                }
                Divider()

            case .idle:
                EmptyView()
            }

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

            Button(AppMenuAction.openDisplayRecall.title) {
                openMainWindow(section: .profiles)
            }

            Button(AppMenuAction.openSettings.title) {
                openMainWindow(section: .settings)
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
        .onReceive(NotificationCenter.default.publisher(for: .displayRecallDisplaySetupChanged)) { _ in
            Task {
                await scheduleAutomaticApply(trigger: .displayChange)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .displayRecallStartupStabilized)) { _ in
            Task {
                await scheduleAutomaticApply(trigger: .startup)
            }
        }
    }

    private func openMainWindow(section: MainWindowSection) {
        MainWindowRouter.shared.select(section)
        openWindow(id: AppWindow.main.id)
        NSApp.activate(ignoringOtherApps: true)
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
        automaticCoordinator.cancelForManualApply()
        do {
            let runner = try DisplayplacerBackend.bundledRunner()
            let manager = ProfileManager(document: document)
            let result = try await manager.apply(item.profile) { arguments in
                try await runner.run(arguments: arguments)
            }
            recordActivity(
                type: result.exitCode == 0 ? .profileApplied : .profileApplyFailed,
                trigger: .manual,
                profile: item.profile,
                result: result
            )
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

    private func scheduleAutomaticApply(trigger: AutomaticApplyTrigger) async {
        await refreshCurrentSetup()
        loadProfiles()
        guard let currentFingerprint else { return }

        switch trigger {
        case .displayChange:
            let state = automaticCoordinator.handleDisplayChange(
                document: document,
                currentFingerprint: currentFingerprint,
                automationStatus: automationStatus
            )
            recordAutomaticDecision(state: state, trigger: trigger)
        case .startup:
            let state = automaticCoordinator.handleStartup(
                document: document,
                currentFingerprint: currentFingerprint,
                automationStatus: automationStatus
            )
            recordAutomaticDecision(state: state, trigger: trigger)
        }
    }

    private func recordAutomaticDecision(state: AutomaticApplyState, trigger: AutomaticApplyTrigger) {
        let activityTrigger: ActivityTrigger = trigger == .startup ? .startup : .automatic
        switch state {
        case let .pending(profile, remainingSeconds, _):
            recordActivity(
                ActivityLogEntry(
                    type: .pendingCountdown,
                    trigger: activityTrigger,
                    profileSnapshot: ProfileSnapshot(id: profile.id, name: profile.name),
                    metadata: ["remainingSeconds": "\(remainingSeconds)"]
                )
            )
        case let .needsChoice(matchingProfiles):
            recordActivity(
                ActivityLogEntry(
                    type: .matchingDecision,
                    trigger: activityTrigger,
                    metadata: ["matchingProfiles": "\(matchingProfiles.count)"]
                )
            )
        case .idle:
            recordActivity(
                ActivityLogEntry(
                    type: .displaySetChanged,
                    trigger: activityTrigger,
                    metadata: ["result": "idle"]
                )
            )
        }
    }

    private func recordActivity(
        type: ActivityLogEventType,
        trigger: ActivityTrigger,
        profile: DisplayProfile,
        result: DisplayplacerBackendRunResult
    ) {
        recordActivity(
            ActivityLogEntry(
                type: type,
                trigger: trigger,
                profileSnapshot: ProfileSnapshot(id: profile.id, name: profile.name),
                backend: BackendSnapshot(
                    path: result.backendPath,
                    version: result.backendVersion,
                    source: result.backendSource
                ),
                command: profile.command,
                stdout: result.stdout,
                stderr: result.stderr,
                exitCode: result.exitCode
            )
        )
    }

    private func recordActivity(_ entry: ActivityLogEntry) {
        do {
            try ActivityLogRecorder(store: DisplayRecallStore.live()).record(entry)
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

struct MainWindowView: View {
    @AppStorage(SetupPreference.completedUserDefaultsKey) private var setupCompleted = false
    @ObservedObject private var router = MainWindowRouter.shared

    var body: some View {
        if setupCompleted {
            NavigationSplitView {
                List(selection: $router.selectedSection) {
                    ForEach(MainWindowSection.allCases) { section in
                        Label(section.title, systemImage: section.systemImage)
                            .tag(section)
                    }
                }
                .navigationTitle(AppConfiguration.displayName)
            } detail: {
                selectedContent
                    .navigationTitle(router.selectedSection.title)
            }
        } else {
            SetupView(setupCompleted: $setupCompleted)
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch router.selectedSection {
        case .profiles:
            ProfilesContentView()
        case .activityLog:
            ActivityLogPageView()
        case .settings:
            SettingsView()
        case .about:
            AboutPageView()
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
    @State private var selectedProfileIDs = Set<UUID>()
    @State private var statusMessage = ""

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedProfileIDs) {
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
            .navigationTitle(MainWindowSection.profiles.title)
            .toolbar {
                Button {
                    Task {
                        await saveCurrentLayout()
                    }
                } label: {
                    Label("Save Current Layout", systemImage: "plus")
                }
                Button {
                    exportSelectedProfiles()
                } label: {
                    Label("Export Selected", systemImage: "square.and.arrow.up")
                }
                .disabled(selectedProfileIDs.isEmpty)

                Button {
                    Task {
                        await importBackup()
                    }
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
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
                    onExport: { profile in
                        exportProfile(profile)
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
        guard let selectedProfileID = selectedProfileIDs.first,
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
            if selectedProfileIDs.isEmpty, let firstProfileID = document.profiles.first?.id {
                selectedProfileIDs = [firstProfileID]
            }
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
            selectedProfileIDs = Set(document.profiles.last.map { [$0.id] } ?? [])
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
            recordActivity(
                ActivityLogEntry(
                    type: result.exitCode == 0 ? .profileApplied : .profileApplyFailed,
                    trigger: .manual,
                    profileSnapshot: ProfileSnapshot(id: profile.id, name: profile.name),
                    backend: BackendSnapshot(
                        path: result.backendPath,
                        version: result.backendVersion,
                        source: result.backendSource
                    ),
                    command: profile.command,
                    stdout: result.stdout,
                    stderr: result.stderr,
                    exitCode: result.exitCode
                )
            )
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

    private func exportSelectedProfiles() {
        let selection: ProfileExportSelection = selectedProfileIDs.count == document.profiles.count
            ? .all
            : .multiple(Array(selectedProfileIDs))
        export(selection: selection, suggestedName: "Display Recall Profiles")
    }

    private func exportProfile(_ profile: DisplayProfile) {
        export(selection: .single(profile.id), suggestedName: profile.name)
    }

    private func export(selection: ProfileExportSelection, suggestedName: String) {
        do {
            let settings = try? DisplayRecallStore.live().loadSettings().settings
            let backup = ProfileExporter.export(document: document, settings: settings, selection: selection)
            try saveBackup(backup, suggestedName: suggestedName)
            recordActivity(ActivityLogEntry(type: .importExport, trigger: .manual, metadata: ["action": "export"]))
            statusMessage = "Exported backup."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func importBackup() async {
        do {
            guard let backup = try openBackup() else {
                return
            }
            let currentFingerprint = await currentDisplayFingerprint()
            let preview = try ProfileImporter.preview(
                backup: backup,
                currentDocument: document,
                currentFingerprint: currentFingerprint
            )
            guard confirmImport(preview: preview) else {
                return
            }

            document = try ProfileImporter.importProfiles(
                from: backup,
                into: document,
                currentFingerprint: currentFingerprint,
                conflictStrategy: .keepBoth
            )
            saveDocument()
            recordActivity(ActivityLogEntry(
                type: .importExport,
                trigger: .manual,
                metadata: [
                    "action": "import",
                    "profiles": "\(preview.profileCount)",
                    "conflicts": "\(preview.conflicts.count)"
                ]
            ))
            statusMessage = "Imported \(preview.profileCount) profiles."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func currentDisplayFingerprint() async -> DisplaySetupFingerprint? {
        guard let service = try? FirstRunSetupService.live(),
              case let .ready(layout) = await service.verifyBackendAndReadCurrentLayout() else {
            return nil
        }
        return layout.displaySetupFingerprint
    }

    private func saveBackup(_ backup: ProfileBackupDocument, suggestedName: String) throws {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(suggestedName).display-recall.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(backup)
        try data.write(to: url, options: .atomic)
    }

    private func openBackup() throws -> ProfileBackupDocument? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ProfileBackupDocument.self, from: data)
    }

    private func confirmImport(preview: ProfileImportPreview) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Import \(preview.profileCount) profiles?"
        alert.informativeText = [
            "Profiles: \(preview.profileNames.joined(separator: ", "))",
            "Conflicts: \(preview.conflicts.count)",
            "Matching current setup: \(preview.matchingStatuses.filter(\.matchesCurrentDisplaySetup).count)"
        ].joined(separator: "\n")
        alert.addButton(withTitle: "Import")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func recordActivity(_ entry: ActivityLogEntry) {
        do {
            try ActivityLogRecorder(store: DisplayRecallStore.live()).record(entry)
        } catch {
            statusMessage = error.localizedDescription
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
    let onExport: (DisplayProfile) -> Void
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
                    Button("Export") {
                        onExport(profile)
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

struct ActivityLogPageView: View {
    @State private var activityLog = ActivityLogStoreDocument()
    @State private var statusMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Activity Log")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Recent automation, apply, import, and diagnostic events.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Refresh") {
                    loadActivityLog()
                }
            }

            if activityLog.entries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No recent activity")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(activityLog.entries.suffix(50).reversed()) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ActivityLogRenderer.title(for: entry, language: .english))
                            .fontWeight(.medium)
                        Text(ActivityLogRenderer.details(for: entry))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .task {
            loadActivityLog()
        }
    }

    private func loadActivityLog() {
        do {
            activityLog = try DisplayRecallStore.live().loadActivityLog()
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

struct AboutPageView: View {
    private let catalog = AcknowledgementsCatalog.current()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AboutMetadata.current().displayString)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(catalog.independenceNotice)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text("Acknowledgements")
                .font(.headline)

            ForEach(catalog.items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(item.name) \(item.version)")
                        .fontWeight(.medium)
                    Text("\(item.licenseName) - \(item.modificationStatus.title)")
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(24)
    }
}

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage(DockIconPreference.userDefaultsKey) private var showDockIcon = false
    @State private var settings = AppSettings()
    @State private var activityLog = ActivityLogStoreDocument()
    @State private var statusMessage = ""

    var body: some View {
        Form {
            Section("Backend") {
                LabeledContent("Source", value: "Bundled")
                LabeledContent("displayplacer", value: DisplayplacerBackend.bundledMetadata.version)
                LabeledContent("Architecture", value: DisplayplacerBackendArchitecture.current.rawValue)
                TextField("Custom backend path", text: Binding(
                    get: { settings.backendSelection.customPath ?? "" },
                    set: { newValue in
                        settings.backendSelection = BackendSelection(
                            source: newValue.isEmpty ? .bundled : .custom(path: newValue),
                            customPath: newValue.isEmpty ? nil : newValue
                        )
                        saveSettings()
                    }
                ))
            }

            Section("Automation") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { newValue in
                        settings.launchAtLogin = newValue
                        setLaunchAtLogin(newValue)
                        saveSettings()
                    }
                ))

                Toggle("Automatic Apply", isOn: Binding(
                    get: { settings.automaticApplyEnabled },
                    set: { settings.automaticApplyEnabled = $0; saveSettings() }
                ))

                Stepper(
                    "Countdown: \(settings.automaticApplyCountdownSeconds)s",
                    value: Binding(
                        get: { settings.automaticApplyCountdownSeconds },
                        set: { settings.automaticApplyCountdownSeconds = $0; saveSettings() }
                    ),
                    in: 1...30
                )
            }

            Section("Appearance") {
                Toggle("Show Dock icon", isOn: $showDockIcon)
                    .onChange(of: showDockIcon) { newValue in
                        settings.showDockIcon = newValue
                        DockIconController.apply(showDockIcon: newValue)
                        saveSettings()
                    }

                Picker("Language", selection: Binding(
                    get: { settings.language },
                    set: { settings.language = $0; saveSettings() }
                )) {
                    ForEach(LanguagePreference.allCases, id: \.self) { language in
                        Text(language.title).tag(language)
                    }
                }
            }

            Section("Shortcuts") {
                Text("Shortcuts are optional. Permission is requested only after a shortcut is configured.")
                    .foregroundStyle(.secondary)
                Text("Configured shortcuts: \(settings.shortcutBindings.filter { $0.keyEquivalent?.isEmpty == false }.count)")
                    .foregroundStyle(.secondary)
            }

            Section("Updates") {
                LabeledContent("Version", value: AboutMetadata.current().displayString)
                Button("Check for Updates") {
                    openURL(ReleaseConfiguration.production().sparklePolicy.feedURL)
                }
                Text("Automatic update checks are optional and never install silently.")
                    .foregroundStyle(.secondary)
            }

            Section("Acknowledgements") {
                Text(AcknowledgementsCatalog.current().independenceNotice)
                    .foregroundStyle(.secondary)

                ForEach(AcknowledgementsCatalog.current().items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(item.name) \(item.version)")
                            .fontWeight(.medium)
                        Text("\(item.licenseName) - \(item.modificationStatus.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Open Project") {
                            openURL(item.projectURL)
                        }
                    }
                }
            }

            Section("Activity Log") {
                if recentActivityEntries.isEmpty {
                    Text("No recent activity.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recentActivityEntries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(ActivityLogRenderer.title(for: entry, language: settings.language))
                                .fontWeight(.medium)
                            Text(ActivityLogRenderer.summary(for: entry, language: settings.language))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Copy Details") {
                                copy(ActivityLogRenderer.copyableDiagnostics(for: entry))
                            }
                        }
                    }
                }

                HStack {
                    Button("Refresh") {
                        loadActivityLog()
                    }
                    Button("Copy Diagnostic Export") {
                        copyDiagnosticExport()
                    }
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
        .frame(width: 420)
        .task {
            loadSettings()
            loadActivityLog()
        }
    }

    private var recentActivityEntries: [ActivityLogEntry] {
        Array(activityLog.entries.suffix(5).reversed())
    }

    private func loadSettings() {
        do {
            settings = try DisplayRecallStore.live().loadSettings().settings
            showDockIcon = settings.showDockIcon
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func loadActivityLog() {
        do {
            activityLog = try DisplayRecallStore.live().loadActivityLog()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func saveSettings() {
        do {
            try DisplayRecallStore.live().save(SettingsStoreDocument(settings: settings))
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func copyDiagnosticExport() {
        let backend = BackendSnapshot(
            path: DisplayplacerBackend.bundledExecutableURL()?.path ?? "Backends",
            version: DisplayplacerBackend.bundledMetadata.version,
            source: DisplayplacerBackend.bundledMetadata.source
        )
        let recentErrors = activityLog.entries
            .suffix(20)
            .map(\.stderr)
            .filter { !$0.isEmpty }
        let export = DiagnosticExporter.export(
            logs: activityLog.entries,
            backend: backend,
            recentErrors: recentErrors
        )
        copy("\(export.summary)\n\n\(export.json)")
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        statusMessage = "Copied."
    }
}
