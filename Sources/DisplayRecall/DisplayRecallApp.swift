import AppKit
import DisplayRecallCore
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

@main
struct DisplayRecallApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var displayChangeObserver: NSObjectProtocol?
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        DockIconController.applyCurrentPreference()
        statusBarController = StatusBarController()
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
        statusBarController?.invalidate()
        statusBarController = nil
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

@MainActor
final class LocalizationController: ObservableObject {
    static let shared = LocalizationController()

    @Published var preference = LanguagePreference.system

    private init() {}

    var language: LanguagePreference {
        preference.resolved()
    }

    func text(_ key: AppLocalizationKey) -> String {
        AppLocalization.text(key, language: preference)
    }

    func pendingApplyTitle(profileName: String, remainingSeconds: Int) -> String {
        AppLocalization.pendingApplyTitle(
            profileName: profileName,
            remainingSeconds: remainingSeconds,
            language: preference
        )
    }

    func triggerTitle(_ trigger: AutomaticApplyTrigger) -> String {
        switch (language, trigger) {
        case (.simplifiedChinese, .startup):
            "启动"
        case (.simplifiedChinese, .displayChange):
            "显示器已变化"
        case (_, .startup):
            "Startup"
        case (_, .displayChange):
            "Display changed"
        }
    }

    func status(_ english: String, chinese: String) -> String {
        language == .simplifiedChinese ? chinese : english
    }

    func createdProfile(_ name: String) -> String {
        status("Created \(name)", chinese: "已创建 \(name)")
    }

    func appliedProfile(_ name: String) -> String {
        status("Applied \(name).", chinese: "已应用 \(name)。")
    }

    func highRiskAppliedProfile(_ name: String) -> String {
        status(
            "Applied \(name). Review this high-risk change.",
            chinese: "已应用 \(name)。请检查这个高风险变更。"
        )
    }

    func countdownLabel(seconds: Int) -> String {
        status("Countdown: \(seconds)s", chinese: "倒计时：\(seconds) 秒")
    }

    func configuredShortcuts(_ count: Int) -> String {
        status("Configured shortcuts: \(count)", chinese: "已配置快捷键：\(count)")
    }

    func defaultProfileName(index: Int) -> String {
        ProfileNameGenerator.defaultName(index: index, language: preference)
    }

    func defaultProfileName(existingNames: [String]) -> String {
        ProfileNameGenerator.firstAvailableDefaultName(existingNames: existingNames, language: preference)
    }
}

@MainActor
final class PendingApplyPanelController {
    static let shared = PendingApplyPanelController()

    private var panel: NSPanel?

    private init() {}

    func show(
        profile: DisplayProfile,
        remainingSeconds: Int,
        trigger: AutomaticApplyTrigger,
        applyNow: @escaping () -> Void,
        stop: @escaping () -> Void
    ) {
        let rootView = PendingApplyPanelView(
            profileName: profile.name,
            remainingSeconds: remainingSeconds,
            trigger: trigger,
            applyNow: applyNow,
            stop: stop
        )

        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 340, height: 150),
                styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isReleasedWhenClosed = false
            self.panel = panel
        }

        panel?.contentView = NSHostingView(rootView: rootView)
        positionPanel()
        panel?.orderFrontRegardless()
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func positionPanel() {
        guard let panel,
              let screenFrame = NSScreen.main?.visibleFrame else {
            return
        }

        let origin = NSPoint(
            x: screenFrame.maxX - panel.frame.width - 18,
            y: screenFrame.maxY - panel.frame.height - 18
        )
        panel.setFrameOrigin(origin)
    }
}

struct PendingApplyPanelView: View {
    @ObservedObject private var localization = LocalizationController.shared

    let profileName: String
    let remainingSeconds: Int
    let trigger: AutomaticApplyTrigger
    let applyNow: () -> Void
    let stop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(localization.pendingApplyTitle(
                        profileName: profileName,
                        remainingSeconds: remainingSeconds
                    ))
                        .font(.headline)
                    Text(localization.triggerTitle(trigger))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: Double(max(0, 5 - remainingSeconds)), total: 5)

            HStack {
                Spacer()
                Button(localization.text(.stop), action: stop)
                Button(localization.text(.applyNow), action: applyNow)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 340)
    }
}

@MainActor
final class MainWindowController {
    static let shared = MainWindowController()

    private var window: NSWindow?

    private init() {}

    func show(section: MainWindowSection) {
        MainWindowRouter.shared.select(section)

        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 920, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = AppWindow.main.title
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(
                rootView: MainWindowView()
                    .environmentObject(LocalizationController.shared)
            )
            window.center()
            self.window = window
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var document = ProfileStoreDocument()
    private var currentFingerprint: DisplaySetupFingerprint?
    private var automationStatus = AutomationStatus.enabled
    private var automaticCoordinator = AutomaticApplyCoordinator(countdownSeconds: 5)
    private var pendingApplyTask: Task<Void, Never>?
    private var displayChangeObserver: NSObjectProtocol?
    private var startupObserver: NSObjectProtocol?

    override init() {
        super.init()
        configureStatusItem()
        observeAutomaticApplyTriggers()
        Task {
            await refreshCurrentSetup()
            loadProfiles()
        }
    }

    func invalidate() {
        if let displayChangeObserver {
            NotificationCenter.default.removeObserver(displayChangeObserver)
        }
        if let startupObserver {
            NotificationCenter.default.removeObserver(startupObserver)
        }
        displayChangeObserver = nil
        startupObserver = nil
        pendingApplyTask?.cancel()
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }
        button.image = NSImage(systemSymbolName: "display.2", accessibilityDescription: AppConfiguration.displayName)
        button.target = self
        button.action = #selector(handleStatusItemClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func observeAutomaticApplyTriggers() {
        displayChangeObserver = NotificationCenter.default.addObserver(
            forName: .displayRecallDisplaySetupChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.scheduleAutomaticApply(trigger: .displayChange)
            }
        }

        startupObserver = NotificationCenter.default.addObserver(
            forName: .displayRecallStartupStabilized,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.scheduleAutomaticApply(trigger: .startup)
            }
        }
    }

    @objc private func handleStatusItemClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            Task {
                await showMenu()
            }
        } else {
            MainWindowController.shared.show(section: .profiles)
        }
    }

    private func showMenu() async {
        await refreshCurrentSetup()
        loadProfiles()
        let menu = buildMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let model = MenuBarModel.build(
            document: document,
            currentFingerprint: currentFingerprint,
            automationStatus: automationStatus
        )

        for item in model.matchingProfiles + model.otherProfiles {
            menu.addItem(profileMenuItem(item))
        }

        if !document.profiles.isEmpty {
            menu.addItem(.separator())
        }

        menu.addItem(actionItem(
            title: LocalizationController.shared.text(.saveCurrentLayout),
            action: #selector(saveCurrentLayoutFromMenu)
        ))

        menu.addItem(.separator())
        menu.addItem(actionItem(
            title: LocalizationController.shared.text(.openDisplayRecall),
            action: #selector(openProfilesFromMenu)
        ))
        menu.addItem(actionItem(
            title: LocalizationController.shared.text(.settings),
            action: #selector(openSettingsFromMenu)
        ))

        let automationItem = actionItem(
            title: LocalizationController.shared.text(.automaticApply),
            action: #selector(toggleAutomaticApplyFromMenu)
        )
        automationItem.state = automationStatus == .enabled ? .on : .off
        menu.addItem(automationItem)

        menu.addItem(actionItem(
            title: LocalizationController.shared.text(.checkForUpdates),
            action: #selector(checkForUpdatesFromMenu)
        ))

        menu.addItem(.separator())
        menu.addItem(actionItem(
            title: LocalizationController.shared.text(.quitDisplayRecall),
            action: #selector(quitFromMenu)
        ))

        return menu
    }

    private func profileMenuItem(_ item: MenuBarProfileItem) -> NSMenuItem {
        let menuItem = actionItem(title: truncatedMenuTitle(item.profile.name), action: #selector(applyProfileFromMenu(_:)))
        menuItem.representedObject = item.profile.id.uuidString
        menuItem.toolTip = item.profile.name
        return menuItem
    }

    private func actionItem(title: String, action: Selector) -> NSMenuItem {
        let menuItem = NSMenuItem(title: truncatedMenuTitle(title), action: action, keyEquivalent: "")
        menuItem.target = self
        menuItem.isEnabled = true
        menuItem.toolTip = title
        return menuItem
    }

    private func truncatedMenuTitle(_ title: String, maxLength: Int = 28) -> String {
        guard title.count > maxLength else {
            return title
        }
        return "\(title.prefix(maxLength - 1))…"
    }

    @objc private func applyProfileFromMenu(_ sender: NSMenuItem) {
        guard let idString = sender.representedObject as? String,
              let id = UUID(uuidString: idString),
              let profile = document.profiles.first(where: { $0.id == id }) else {
            return
        }

        Task {
            await apply(profile)
        }
    }

    @objc private func saveCurrentLayoutFromMenu() {
        Task {
            await saveCurrentLayout()
        }
    }

    @objc private func openProfilesFromMenu() {
        MainWindowController.shared.show(section: .profiles)
    }

    @objc private func openSettingsFromMenu() {
        MainWindowController.shared.show(section: .settings)
    }

    @objc private func toggleAutomaticApplyFromMenu() {
        automationStatus = automationStatus == .enabled ? .paused : .enabled
    }

    @objc private func checkForUpdatesFromMenu() {
        NSWorkspace.shared.open(ReleaseConfiguration.production().sparklePolicy.feedURL)
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    private func loadProfiles() {
        do {
            document = try DisplayRecallStore.live().loadProfiles()
        } catch {
            recordActivity(ActivityLogEntry(
                type: .backendVerification,
                metadata: ["error": error.localizedDescription]
            ))
        }
    }

    private func refreshCurrentSetup() async {
        do {
            let service = try FirstRunSetupService.live()
            if case let .ready(layout) = await service.verifyBackendAndReadCurrentLayout() {
                currentFingerprint = layout.displaySetupFingerprint
            }
        } catch {
            recordActivity(ActivityLogEntry(
                type: .backendVerification,
                metadata: ["error": error.localizedDescription]
            ))
        }
    }

    private func saveCurrentLayout() async {
        do {
            let service = try FirstRunSetupService.live()
            guard case let .ready(layout) = await service.verifyBackendAndReadCurrentLayout() else {
                return
            }
            var manager = ProfileManager(document: document)
            document = try manager.saveCurrentLayout(
                layout,
                name: LocalizationController.shared.defaultProfileName(
                    existingNames: document.profiles.map(\.name)
                )
            )
            try DisplayRecallStore.live().save(document)
            currentFingerprint = layout.displaySetupFingerprint
        } catch {
            recordActivity(ActivityLogEntry(
                type: .backendVerification,
                metadata: ["error": error.localizedDescription]
            ))
        }
    }

    private func apply(_ profile: DisplayProfile) async {
        automaticCoordinator.cancelForManualApply()
        do {
            let runner = try DisplayplacerBackend.bundledRunner()
            let manager = ProfileManager(document: document)
            let result = try await manager.apply(profile) { arguments in
                try await runner.run(arguments: arguments)
            }
            recordActivity(
                type: result.exitCode == 0 ? .profileApplied : .profileApplyFailed,
                trigger: .manual,
                profile: profile,
                result: result
            )
            await refreshCurrentSetup()
            loadProfiles()
        } catch {
            recordActivity(ActivityLogEntry(
                type: .profileApplyFailed,
                trigger: .manual,
                profileSnapshot: ProfileSnapshot(id: profile.id, name: profile.name),
                stderr: error.localizedDescription
            ))
        }
    }

    private func scheduleAutomaticApply(trigger: AutomaticApplyTrigger) async {
        pendingApplyTask?.cancel()
        PendingApplyPanelController.shared.close()
        await refreshCurrentSetup()
        loadProfiles()
        guard let currentFingerprint else { return }

        let state: AutomaticApplyState
        switch trigger {
        case .displayChange:
            state = automaticCoordinator.handleDisplayChange(
                document: document,
                currentFingerprint: currentFingerprint,
                automationStatus: automationStatus
            )
        case .startup:
            state = automaticCoordinator.handleStartup(
                document: document,
                currentFingerprint: currentFingerprint,
                automationStatus: automationStatus
            )
        }
        recordAutomaticDecision(state: state, trigger: trigger)
        presentPendingPanelIfNeeded(state)
    }

    private func presentPendingPanelIfNeeded(_ state: AutomaticApplyState) {
        guard case let .pending(profile, remainingSeconds, trigger) = state else {
            PendingApplyPanelController.shared.close()
            return
        }

        pendingApplyTask?.cancel()
        showPendingPanel(profile: profile, remainingSeconds: remainingSeconds, trigger: trigger)

        pendingApplyTask = Task {
            var remaining = remainingSeconds
            while remaining > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                remaining -= 1
                await MainActor.run {
                    if remaining > 0 {
                        showPendingPanel(profile: profile, remainingSeconds: remaining, trigger: trigger)
                    }
                }
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                PendingApplyPanelController.shared.close()
            }

            do {
                let freshFingerprint = try await rereadCurrentFingerprint(
                    fallback: profile.displaySetupFingerprint
                )
                let selected = await MainActor.run {
                    automaticCoordinator.state = .idle
                    return automaticDefaultProfile(for: freshFingerprint)
                }
                if let selected {
                    await apply(selected)
                }
            } catch {
                recordActivity(ActivityLogEntry(
                    type: .profileApplyFailed,
                    trigger: trigger == .startup ? .startup : .automatic,
                    profileSnapshot: ProfileSnapshot(id: profile.id, name: profile.name),
                    stderr: error.localizedDescription
                ))
            }
        }
    }

    private func showPendingPanel(
        profile: DisplayProfile,
        remainingSeconds: Int,
        trigger: AutomaticApplyTrigger
    ) {
        PendingApplyPanelController.shared.show(
            profile: profile,
            remainingSeconds: remainingSeconds,
            trigger: trigger,
            applyNow: {
                self.pendingApplyTask?.cancel()
                PendingApplyPanelController.shared.close()
                self.automaticCoordinator.state = .idle
                Task {
                    await self.apply(profile)
                }
            },
            stop: {
                self.pendingApplyTask?.cancel()
                self.automaticCoordinator.stopPendingApply()
                PendingApplyPanelController.shared.close()
                self.recordActivity(ActivityLogEntry(
                    type: .cancellation,
                    trigger: trigger == .startup ? .startup : .automatic,
                    profileSnapshot: ProfileSnapshot(id: profile.id, name: profile.name),
                    metadata: ["reason": "userStoppedPendingApply"]
                ))
            }
        )
    }

    private func rereadCurrentFingerprint(
        fallback: DisplaySetupFingerprint
    ) async throws -> DisplaySetupFingerprint {
        let service = try FirstRunSetupService.live()
        guard case let .ready(layout) = await service.verifyBackendAndReadCurrentLayout() else {
            return fallback
        }
        return layout.displaySetupFingerprint
    }

    private func automaticDefaultProfile(for fingerprint: DisplaySetupFingerprint) -> DisplayProfile? {
        guard let rule = document.automaticDefaultRules.first(where: {
            $0.displaySetupFingerprint == fingerprint
        }) else {
            return nil
        }
        return document.profiles.first { $0.id == rule.profileId }
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
        try? ActivityLogRecorder(store: DisplayRecallStore.live()).record(entry)
    }
}

struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var localization: LocalizationController
    @State private var document = ProfileStoreDocument()
    @State private var currentFingerprint: DisplaySetupFingerprint?
    @State private var automationStatus = AutomationStatus.enabled
    @State private var automaticCoordinator = AutomaticApplyCoordinator(countdownSeconds: 5)
    @State private var pendingApplyTask: Task<Void, Never>?
    @State private var statusMessage = ""

    private var menuModel: MenuBarModel {
        MenuBarModel.build(
            document: document,
            currentFingerprint: currentFingerprint,
            automationStatus: automationStatus
        )
    }

    var body: some View {
        Group {
            Text(menuModel.statusTitle)
            if !menuModel.matchingProfiles.isEmpty {
            Text(localization.text(.currentDisplaySetup))
                ForEach(menuModel.matchingProfiles) { item in
                    profileButton(item)
                }
            } else {
                Text(localization.text(.noMatchingProfiles))
            }

            if !menuModel.otherProfiles.isEmpty {
                Menu(localization.text(.otherProfiles)) {
                    ForEach(menuModel.otherProfiles) { item in
                        profileButton(item)
                    }
                }
            }

            Button(localization.text(.saveCurrentLayout)) {
                Task {
                    await saveCurrentLayout()
                }
            }

            if !statusMessage.isEmpty {
                Text(statusMessage)
            }

            Divider()

            Button(localization.text(.openDisplayRecall)) {
                openMainWindow(section: .profiles)
            }

            Button(localization.text(.settings)) {
                openMainWindow(section: .settings)
            }

            Toggle(localization.text(.automaticApply), isOn: Binding(
                get: { automationStatus == .enabled },
                set: { automationStatus = $0 ? .enabled : .paused }
            ))

            Button(localization.text(.checkForUpdates)) {
                NSWorkspace.shared.open(ReleaseConfiguration.production().sparklePolicy.feedURL)
            }

            Divider()

            Button(localization.text(.quitDisplayRecall)) {
                NSApp.terminate(nil)
            }
        }
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
                statusMessage = localization.status(
                    "Could not read current layout.",
                    chinese: "无法读取当前布局。"
                )
                return
            }
            var manager = ProfileManager(document: document)
            document = try manager.saveCurrentLayout(
                layout,
                name: localization.defaultProfileName(existingNames: document.profiles.map(\.name))
            )
            try DisplayRecallStore.live().save(document)
            currentFingerprint = layout.displaySetupFingerprint
            statusMessage = localization.status("Saved current layout.", chinese: "已保存当前布局。")
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
                    ? localization.highRiskAppliedProfile(item.profile.name)
                    : result.stderr
            } else {
                statusMessage = result.exitCode == 0 ? localization.appliedProfile(item.profile.name) : result.stderr
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func scheduleAutomaticApply(trigger: AutomaticApplyTrigger) async {
        pendingApplyTask?.cancel()
        PendingApplyPanelController.shared.close()
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
            presentPendingPanelIfNeeded(state)
        case .startup:
            let state = automaticCoordinator.handleStartup(
                document: document,
                currentFingerprint: currentFingerprint,
                automationStatus: automationStatus
            )
            recordAutomaticDecision(state: state, trigger: trigger)
            presentPendingPanelIfNeeded(state)
        }
    }

    private func presentPendingPanelIfNeeded(_ state: AutomaticApplyState) {
        guard case let .pending(profile, remainingSeconds, trigger) = state else {
            PendingApplyPanelController.shared.close()
            return
        }

        pendingApplyTask?.cancel()
        showPendingPanel(profile: profile, remainingSeconds: remainingSeconds, trigger: trigger)

        pendingApplyTask = Task {
            var remaining = remainingSeconds
            while remaining > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                remaining -= 1
                await MainActor.run {
                    if remaining > 0 {
                        showPendingPanel(profile: profile, remainingSeconds: remaining, trigger: trigger)
                    }
                }
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                PendingApplyPanelController.shared.close()
            }

            do {
                let freshFingerprint = try await rereadCurrentFingerprint(
                    fallback: profile.displaySetupFingerprint
                )
                let selected = await MainActor.run {
                    automaticCoordinator.state = .idle
                    return automaticDefaultProfile(for: freshFingerprint)
                }
                if let selected {
                    await apply(MenuBarProfileItem(
                        profile: selected,
                        currentFingerprint: selected.displaySetupFingerprint,
                        isAutomaticDefault: true
                    ))
                }
            } catch {
                await MainActor.run {
                    statusMessage = error.localizedDescription
                }
            }
        }
    }

    private func showPendingPanel(
        profile: DisplayProfile,
        remainingSeconds: Int,
        trigger: AutomaticApplyTrigger
    ) {
        PendingApplyPanelController.shared.show(
            profile: profile,
            remainingSeconds: remainingSeconds,
            trigger: trigger,
            applyNow: {
                pendingApplyTask?.cancel()
                PendingApplyPanelController.shared.close()
                automaticCoordinator.state = .idle
                Task {
                    await apply(MenuBarProfileItem(
                        profile: profile,
                        currentFingerprint: currentFingerprint,
                        isAutomaticDefault: true
                    ))
                }
            },
            stop: {
                pendingApplyTask?.cancel()
                automaticCoordinator.stopPendingApply()
                PendingApplyPanelController.shared.close()
                recordActivity(ActivityLogEntry(
                    type: .cancellation,
                    trigger: trigger == .startup ? .startup : .automatic,
                    profileSnapshot: ProfileSnapshot(id: profile.id, name: profile.name),
                    metadata: ["reason": "userStoppedPendingApply"]
                ))
            }
        )
    }

    private func rereadCurrentFingerprint(
        fallback: DisplaySetupFingerprint
    ) async throws -> DisplaySetupFingerprint {
        let service = try FirstRunSetupService.live()
        guard case let .ready(layout) = await service.verifyBackendAndReadCurrentLayout() else {
            return fallback
        }
        return layout.displaySetupFingerprint
    }

    private func automaticDefaultProfile(for fingerprint: DisplaySetupFingerprint) -> DisplayProfile? {
        guard let rule = document.automaticDefaultRules.first(where: {
            $0.displaySetupFingerprint == fingerprint
        }) else {
            return nil
        }
        return document.profiles.first { $0.id == rule.profileId }
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
    @EnvironmentObject private var localization: LocalizationController
    @ObservedObject private var router = MainWindowRouter.shared

    var body: some View {
        if setupCompleted {
            NavigationSplitView {
                List(selection: $router.selectedSection) {
                    ForEach(MainWindowSection.allCases) { section in
                        Label(localizedTitle(for: section), systemImage: section.systemImage)
                            .tag(section)
                    }
                }
                .navigationTitle(AppConfiguration.displayName)
            } detail: {
                selectedContent
                    .navigationTitle(localizedTitle(for: router.selectedSection))
            }
        } else {
            SetupView(setupCompleted: $setupCompleted)
        }
    }

    private func localizedTitle(for section: MainWindowSection) -> String {
        switch section {
        case .profiles:
            localization.text(.profiles)
        case .activityLog:
            localization.text(.activityLog)
        case .settings:
            localization.text(.settings)
        case .about:
            localization.text(.about)
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
    @EnvironmentObject private var localization: LocalizationController
    @State private var setupState = FirstRunSetupState.idle
    @State private var profileName = ""
    @State private var makeAutomaticDefault = true
    @State private var createdProfile: DisplayProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(localization.text(.welcomeToDisplayRecall))
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text(localization.text(.displayRecallSetupDescription))
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
            ProgressView(localization.status(
                "Verifying bundled displayplacer...",
                chinese: "正在验证内置 displayplacer..."
            ))

        case let .failed(error):
            VStack(alignment: .leading, spacing: 12) {
                Label(localization.text(.backendVerificationFailed), systemImage: "exclamationmark.triangle")
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
                Label(localization.text(.backendReady), systemImage: "checkmark.circle")
                    .font(.headline)

                TextField(localization.text(.profileName), text: $profileName)
                    .textFieldStyle(.roundedBorder)
                    .onAppear {
                        if profileName.isEmpty {
                            profileName = localization.defaultProfileName(index: 1)
                        }
                    }

                Toggle(localization.text(.automaticDefaultForSetup), isOn: $makeAutomaticDefault)

                Button(localization.text(.createProfile)) {
                    completeSetup(with: layout)
                }
                .keyboardShortcut(.defaultAction)
            }

        case let .completed(profile):
            VStack(alignment: .leading, spacing: 12) {
                Label(localization.createdProfile(profile.name), systemImage: "checkmark.circle.fill")
                    .font(.headline)
                Button(localization.text(.openProfiles)) {
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

private enum ProfileExportScope: String, CaseIterable, Identifiable {
    case current
    case selected
    case all

    var id: Self { self }
}

private struct ProfileExportSheetState: Identifiable {
    let id = UUID()
    let initialScope: ProfileExportScope
    let currentProfileID: UUID?
    let selectedProfileIDs: Set<UUID>
}

private struct ProfileImportPreviewSheetState: Identifiable {
    let id = UUID()
    let backup: ProfileBackupDocument
    let preview: ProfileImportPreview
    let currentFingerprint: DisplaySetupFingerprint?
}

private struct CreateProfileSheetState: Identifiable {
    let id = UUID()
    let layout: CurrentDisplayLayout
    let suggestedName: String
    let makeAutomaticDefault: Bool
}

private struct CreateProfileSheet: View {
    @EnvironmentObject private var localization: LocalizationController
    let state: CreateProfileSheetState
    let onCancel: () -> Void
    let onSave: (String, Bool) -> Void

    @State private var name: String
    @State private var makeAutomaticDefault: Bool

    init(
        state: CreateProfileSheetState,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String, Bool) -> Void
    ) {
        self.state = state
        self.onCancel = onCancel
        self.onSave = onSave
        _name = State(initialValue: state.suggestedName)
        _makeAutomaticDefault = State(initialValue: state.makeAutomaticDefault)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(localization.text(.createProfile))
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(state.layout.displaySummary)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            TextField(localization.text(.profileName), text: $name)
                .textFieldStyle(.roundedBorder)

            Toggle(localization.text(.automaticDefaultForSetup), isOn: $makeAutomaticDefault)

            HStack {
                Spacer()
                Button(localization.text(.cancel), action: onCancel)
                Button(localization.text(.saveCurrentLayout)) {
                    onSave(name, makeAutomaticDefault)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

private struct ExportProfilesSheet: View {
    @EnvironmentObject private var localization: LocalizationController
    let state: ProfileExportSheetState
    let document: ProfileStoreDocument
    let onCancel: () -> Void
    let onExport: (ProfileExportScope) -> Void

    @State private var scope: ProfileExportScope

    init(
        state: ProfileExportSheetState,
        document: ProfileStoreDocument,
        onCancel: @escaping () -> Void,
        onExport: @escaping (ProfileExportScope) -> Void
    ) {
        self.state = state
        self.document = document
        self.onCancel = onCancel
        self.onExport = onExport
        _scope = State(initialValue: state.initialScope)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(localization.text(.exportProfiles))
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(localization.text(.chooseExportScope))
                    .foregroundStyle(.secondary)
            }

            Picker(localization.text(.exportScope), selection: $scope) {
                ForEach(ProfileExportScope.allCases) { scope in
                    Text(title(for: scope)).tag(scope)
                }
            }
            .pickerStyle(.radioGroup)

            let preview = selectedPreview
            LabeledContent(localization.text(.profileCount), value: "\(preview?.profileCount ?? 0)")
            if let preview, !preview.profileNames.isEmpty {
                Text(preview.profileNames.joined(separator: ", "))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack {
                Spacer()
                Button(localization.text(.cancel), action: onCancel)
                Button(localization.text(.export)) {
                    onExport(scope)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedPreview == nil || selectedPreview?.profileCount == 0)
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private var selectedPreview: ProfileExportPreview? {
        guard let selection = selection(for: scope) else {
            return nil
        }
        return ProfileExporter.preview(document: document, selection: selection)
    }

    private func selection(for scope: ProfileExportScope) -> ProfileExportSelection? {
        switch scope {
        case .current:
            guard let currentProfileID = state.currentProfileID else {
                return nil
            }
            return .single(currentProfileID)
        case .selected:
            guard !state.selectedProfileIDs.isEmpty else {
                return nil
            }
            return .multiple(Array(state.selectedProfileIDs))
        case .all:
            guard !document.profiles.isEmpty else {
                return nil
            }
            return .all
        }
    }

    private func title(for scope: ProfileExportScope) -> String {
        switch scope {
        case .current:
            localization.text(.currentProfile)
        case .selected:
            localization.text(.selectedProfiles)
        case .all:
            localization.text(.allProfiles)
        }
    }
}

private struct ImportPreviewSheet: View {
    @EnvironmentObject private var localization: LocalizationController
    let state: ProfileImportPreviewSheetState
    let onCancel: () -> Void
    let onImport: (ImportConflictStrategy) -> Void

    @State private var conflictStrategy = ImportConflictStrategy.keepBoth

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(localization.text(.importPreview))
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(localization.status(
                    "Review this backup before importing.",
                    chinese: "导入前先确认这个备份。"
                ))
                .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                GridRow {
                    Text(localization.text(.profileCount))
                    Text("\(state.preview.profileCount)")
                        .foregroundStyle(.secondary)
                }
                GridRow {
                    Text(localization.text(.conflicts))
                    Text("\(state.preview.conflicts.count)")
                        .foregroundStyle(state.preview.conflicts.isEmpty ? Color.secondary : Color.orange)
                }
                GridRow {
                    Text(localization.text(.matchingCurrentSetup))
                    Text("\(matchingCount)")
                        .foregroundStyle(.secondary)
                }
                GridRow {
                    Text(localization.text(.needsRebind))
                    Text("\(needsRebindCount)")
                        .foregroundStyle(needsRebindCount == 0 ? Color.secondary : Color.orange)
                }
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(state.preview.matchingStatuses, id: \.profileID) { status in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(status.profileName)
                                    .fontWeight(.medium)
                                if state.preview.conflicts.contains(where: { $0.importedProfileID == status.profileID }) {
                                    Text(localization.text(.conflicts))
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                            Spacer()
                            Label(
                                status.matchesCurrentDisplaySetup
                                    ? localization.text(.matchesCurrentSetup)
                                    : localization.text(.needsRebind),
                                systemImage: status.matchesCurrentDisplaySetup ? "checkmark.circle" : "link.badge.plus"
                            )
                            .foregroundStyle(status.matchesCurrentDisplaySetup ? .green : .orange)
                            .font(.caption)
                        }
                    }
                }
            }
            .frame(maxHeight: 180)

            Picker(localization.text(.importConflictStrategy), selection: $conflictStrategy) {
                Text(localization.text(.keepBoth)).tag(ImportConflictStrategy.keepBoth)
                Text(localization.text(.replaceExisting)).tag(ImportConflictStrategy.replaceExisting)
                Text(localization.text(.skipConflicts)).tag(ImportConflictStrategy.skipConflict)
            }
            .pickerStyle(.radioGroup)

            HStack {
                Spacer()
                Button(localization.text(.cancel), action: onCancel)
                Button(localization.text(.importProfiles)) {
                    onImport(conflictStrategy)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
    }

    private var matchingCount: Int {
        state.preview.matchingStatuses.filter(\.matchesCurrentDisplaySetup).count
    }

    private var needsRebindCount: Int {
        state.preview.matchingStatuses.count - matchingCount
    }
}

struct ProfilesContentView: View {
    @EnvironmentObject private var localization: LocalizationController
    @State private var document = ProfileStoreDocument()
    @State private var selectedProfileIDs = Set<UUID>()
    @State private var searchQuery = ""
    @State private var currentFingerprint: DisplaySetupFingerprint?
    @State private var statusMessage = ""
    @State private var exportSheet: ProfileExportSheetState?
    @State private var importPreviewSheet: ProfileImportPreviewSheetState?
    @State private var createProfileSheet: CreateProfileSheetState?

    private var visibleProfiles: [DisplayProfile] {
        ProfileListFilter.filter(document.profiles, query: searchQuery)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedProfileIDs) {
                ForEach(visibleProfiles) { profile in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.name)
                                .fontWeight(.medium)
                            Text(profile.displaySummary.isEmpty ? profile.displaySetupFingerprint.rawValue : profile.displaySummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        HStack(spacing: 6) {
                            if profile.displaySetupFingerprint == currentFingerprint {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            if isAutomaticDefault(profile) {
                                Image(systemName: "bolt.fill")
                                    .foregroundStyle(.blue)
                            }
                            if profile.importedNeedsFirstApplyConfirmation || profile.isCommandEdited {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .imageScale(.small)
                    }
                    .tag(profile.id)
                }
            }
            .navigationTitle(localization.text(.profiles))
            .searchable(text: $searchQuery, prompt: localization.text(.searchProfiles))
            .toolbar {
                Button {
                    Task {
                        await saveCurrentLayout()
                    }
                } label: {
                    Label(localization.text(.createProfile), systemImage: "plus")
                }
                Button {
                    exportSelectedProfiles()
                } label: {
                    Label(localization.text(.export), systemImage: "square.and.arrow.up")
                }
                .disabled(document.profiles.isEmpty)

                Button {
                    Task {
                        await importBackup()
                    }
                } label: {
                    Label(localization.text(.importProfiles), systemImage: "square.and.arrow.down")
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
                    onDelete: { profile in
                        deleteProfile(profile)
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

                    Text(localization.text(.noProfileSelected))
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(localization.text(.noProfileSelectedDescription))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .task {
            loadProfiles()
            await refreshCurrentFingerprint()
        }
        .sheet(item: $exportSheet) { sheet in
            ExportProfilesSheet(
                state: sheet,
                document: document,
                onCancel: {
                    exportSheet = nil
                },
                onExport: { scope in
                    exportSheet = nil
                    export(selection: selection(for: scope, state: sheet), suggestedName: suggestedName(for: scope))
                }
            )
            .environmentObject(localization)
        }
        .sheet(item: $createProfileSheet) { sheet in
            CreateProfileSheet(
                state: sheet,
                onCancel: {
                    createProfileSheet = nil
                },
                onSave: { name, makeAutomaticDefault in
                    createProfileSheet = nil
                    createProfile(from: sheet.layout, name: name, makeAutomaticDefault: makeAutomaticDefault)
                }
            )
            .environmentObject(localization)
        }
        .sheet(item: $importPreviewSheet) { sheet in
            ImportPreviewSheet(
                state: sheet,
                onCancel: {
                    importPreviewSheet = nil
                },
                onImport: { strategy in
                    importPreviewSheet = nil
                    performImport(sheet, conflictStrategy: strategy)
                }
            )
            .environmentObject(localization)
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

    private func refreshCurrentFingerprint() async {
        guard let service = try? FirstRunSetupService.live(),
              case let .ready(layout) = await service.verifyBackendAndReadCurrentLayout() else {
            return
        }
        currentFingerprint = layout.displaySetupFingerprint
    }

    private func saveCurrentLayout() async {
        do {
            let service = try FirstRunSetupService.live()
            guard case let .ready(layout) = await service.verifyBackendAndReadCurrentLayout() else {
                statusMessage = localization.status(
                    "Could not read current layout.",
                    chinese: "无法读取当前布局。"
                )
                return
            }
            createProfileSheet = CreateProfileSheetState(
                layout: layout,
                suggestedName: localization.defaultProfileName(existingNames: document.profiles.map(\.name)),
                makeAutomaticDefault: true
            )
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func createProfile(
        from layout: CurrentDisplayLayout,
        name: String,
        makeAutomaticDefault: Bool
    ) {
        do {
            var manager = ProfileManager(document: document)
            document = try manager.saveCurrentLayout(
                layout,
                name: name,
                makeAutomaticDefault: makeAutomaticDefault
            )
            selectedProfileIDs = Set(document.profiles.last.map { [$0.id] } ?? [])
            saveDocument()
            statusMessage = localization.status("Saved current layout.", chinese: "已保存当前布局。")
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
            statusMessage = result.exitCode == 0 ? localization.appliedProfile(profile.name) : result.stderr
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
                statusMessage = localization.status(
                    "Could not read current display setup.",
                    chinese: "无法读取当前显示器组合。"
                )
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
            statusMessage = localization.status("Rebound \(profile.name).", chinese: "已重新绑定 \(profile.name)。")
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
            statusMessage = localization.status("Command saved.", chinese: "命令已保存。")
        } catch {
            statusMessage = localization.status("Invalid displayplacer command.", chinese: "无效的 displayplacer 命令。")
        }
    }

    private func isAutomaticDefault(_ profile: DisplayProfile) -> Bool {
        document.automaticDefaultRules.contains {
            $0.profileId == profile.id && $0.displaySetupFingerprint == profile.displaySetupFingerprint
        }
    }

    private func exportSelectedProfiles() {
        presentExportSheet(defaultScope: selectedProfileIDs.isEmpty ? .all : .selected)
    }

    private func deleteProfile(_ profile: DisplayProfile) {
        let alert = NSAlert()
        alert.messageText = localization.status(
            "Delete \(profile.name)?",
            chinese: "删除 \(profile.name)？"
        )
        alert.informativeText = localization.status(
            "This deletes the profile and removes related automatic default rules and shortcuts.",
            chinese: "这会删除配置，并清理相关自动默认规则和快捷键。"
        )
        alert.addButton(withTitle: localization.text(.deleteProfile))
        alert.addButton(withTitle: localization.status("Cancel", chinese: "取消"))
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        do {
            let store = try DisplayRecallStore.live()
            let settings = try store.loadSettings().settings
            let result = try ProfileDeletion.delete(
                profileID: profile.id,
                profilesDocument: document,
                settings: settings
            )
            document = result.profilesDocument
            selectedProfileIDs = Set(result.nextSelectedProfileID.map { [$0] } ?? [])
            try store.save(result.profilesDocument)
            try store.save(SettingsStoreDocument(settings: result.settings))
            try ActivityLogRecorder(store: store).record(result.logEntry)
            statusMessage = localization.status("Deleted profile.", chinese: "已删除配置。")
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func exportProfile(_ profile: DisplayProfile) {
        presentExportSheet(defaultScope: .current, currentProfileID: profile.id)
    }

    private func presentExportSheet(
        defaultScope: ProfileExportScope,
        currentProfileID: UUID? = nil
    ) {
        exportSheet = ProfileExportSheetState(
            initialScope: defaultScope,
            currentProfileID: currentProfileID ?? selectedProfileIDs.first,
            selectedProfileIDs: selectedProfileIDs
        )
    }

    private func export(selection: ProfileExportSelection?, suggestedName: String) {
        guard let selection else {
            return
        }

        do {
            let settings = try? DisplayRecallStore.live().loadSettings().settings
            let backup = ProfileExporter.export(document: document, settings: settings, selection: selection)
            try saveBackup(backup, suggestedName: suggestedName)
            recordActivity(ActivityLogEntry(type: .importExport, trigger: .manual, metadata: ["action": "export"]))
            statusMessage = localization.status("Exported backup.", chinese: "已导出备份。")
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func selection(
        for scope: ProfileExportScope,
        state: ProfileExportSheetState
    ) -> ProfileExportSelection? {
        switch scope {
        case .current:
            guard let currentProfileID = state.currentProfileID else {
                return nil
            }
            return .single(currentProfileID)
        case .selected:
            guard !state.selectedProfileIDs.isEmpty else {
                return nil
            }
            return .multiple(Array(state.selectedProfileIDs))
        case .all:
            return .all
        }
    }

    private func suggestedName(for scope: ProfileExportScope) -> String {
        switch scope {
        case .current:
            selectedProfileBinding?.wrappedValue.name ?? "Display Recall Profile"
        case .selected:
            "Display Recall Selected Profiles"
        case .all:
            "Display Recall Profiles"
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
            importPreviewSheet = ProfileImportPreviewSheetState(
                backup: backup,
                preview: preview,
                currentFingerprint: currentFingerprint
            )
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func performImport(
        _ state: ProfileImportPreviewSheetState,
        conflictStrategy: ImportConflictStrategy
    ) {
        do {
            document = try ProfileImporter.importProfiles(
                from: state.backup,
                into: document,
                currentFingerprint: state.currentFingerprint,
                conflictStrategy: conflictStrategy
            )
            saveDocument()
            recordActivity(ActivityLogEntry(
                type: .importExport,
                trigger: .manual,
                metadata: [
                    "action": "import",
                    "profiles": "\(state.preview.profileCount)",
                    "conflicts": "\(state.preview.conflicts.count)",
                    "strategy": "\(conflictStrategy)"
                ]
            ))
            statusMessage = localization.status(
                "Imported \(state.preview.profileCount) profiles.",
                chinese: "已导入 \(state.preview.profileCount) 个配置。"
            )
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

    private func recordActivity(_ entry: ActivityLogEntry) {
        do {
            try ActivityLogRecorder(store: DisplayRecallStore.live()).record(entry)
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

struct ProfileDetailView: View {
    @EnvironmentObject private var localization: LocalizationController
    @Binding var profile: DisplayProfile
    let isAutomaticDefault: Bool
    let statusMessage: String
    let onApply: (DisplayProfile) -> Void
    let onSetDefault: (DisplayProfile) -> Void
    let onClearDefault: (DisplayProfile) -> Void
    let onRebind: (DisplayProfile) -> Void
    let onExport: (DisplayProfile) -> Void
    let onDelete: (DisplayProfile) -> Void
    let onSaveCommand: (DisplayProfile, String) -> Void

    @State private var commandDraft = ""
    @State private var showsAdvancedCommand = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(profile.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(profile.displaySummary.isEmpty ? profile.displaySetupFingerprint.rawValue : profile.displaySummary)
                        .foregroundStyle(.secondary)
                    HStack {
                        Label(
                            isAutomaticDefault ? localization.text(.automaticDefault) : localization.text(.differentSetup),
                            systemImage: isAutomaticDefault ? "bolt.circle.fill" : "circle"
                        )
                        if profile.importedNeedsFirstApplyConfirmation || profile.isCommandEdited {
                            Label(localization.text(.highRisk), systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                    }
                    Button(localization.text(.apply)) {
                        onApply(profile)
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }

            Section(localization.text(.profile)) {
                TextField(localization.text(.name), text: $profile.name)
                TextField(localization.text(.notes), text: $profile.notes, axis: .vertical)
            }

            Section(localization.text(.displaySetup)) {
                LabeledContent(localization.text(.summary), value: profile.displaySummary)
                LabeledContent(localization.text(.fingerprint), value: profile.displaySetupFingerprint.rawValue)
                Toggle(localization.text(.automaticDefaultForSetup), isOn: .constant(isAutomaticDefault))
                    .disabled(true)
                HStack {
                    Button(isAutomaticDefault ? localization.text(.clearDefault) : localization.text(.setDefault)) {
                        isAutomaticDefault ? onClearDefault(profile) : onSetDefault(profile)
                    }
                    Button(localization.text(.rebindToCurrentDisplays)) {
                        onRebind(profile)
                    }
                }
            }

            Section {
                DisclosureGroup(localization.text(.advancedCommand), isExpanded: $showsAdvancedCommand) {
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
                        Button(localization.text(.saveCommand)) {
                            onSaveCommand(profile, commandDraft)
                        }
                        Button(localization.text(.export)) {
                            onExport(profile)
                        }
                    }
                }
            }

            Section(localization.text(.dangerZone)) {
                Button(role: .destructive) {
                    onDelete(profile)
                } label: {
                    Label(localization.text(.deleteProfile), systemImage: "trash")
                }
            }

            if !statusMessage.isEmpty {
                Section(localization.text(.status)) {
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
    @EnvironmentObject private var localization: LocalizationController
    @State private var activityLog = ActivityLogStoreDocument()
    @State private var selectedEntryID: ActivityLogEntry.ID?
    @State private var filter = ActivityLogFilter.all
    @State private var statusMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localization.text(.activityLog))
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(localization.text(.recentActivityDescription))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(localization.text(.refresh)) {
                    loadActivityLog()
                }
            }

            Picker(localization.text(.activityLog), selection: $filter) {
                ForEach(ActivityLogFilter.allCases, id: \.self) { filter in
                    Text(title(for: filter)).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: filter) { _ in
                selectedEntryID = filteredEntries.first?.id
            }

            if filteredEntries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text(localization.text(.noRecentActivity))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 16) {
                    List(selection: $selectedEntryID) {
                        ForEach(filteredEntries) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ActivityLogRenderer.title(for: entry, language: localization.preference))
                                    .fontWeight(.medium)
                                Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(ActivityLogRenderer.summary(for: entry, language: localization.preference))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 4)
                            .tag(entry.id)
                        }
                    }
                    .frame(minWidth: 280)

                    Divider()

                    activityDetail
                        .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack {
                Button(localization.text(.copyDiagnosticExport)) {
                    copyDiagnosticExport()
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .task {
            loadActivityLog()
        }
    }

    @ViewBuilder
    private var activityDetail: some View {
        if let selectedEntry {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ActivityLogRenderer.title(for: selectedEntry, language: localization.preference))
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(selectedEntry.timestamp.formatted(date: .complete, time: .standard))
                        .foregroundStyle(.secondary)
                }

                Text(ActivityLogRenderer.summary(for: selectedEntry, language: localization.preference))
                    .foregroundStyle(.secondary)

                ScrollView {
                    Text(ActivityLogRenderer.copyableDiagnostics(for: selectedEntry))
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    Button(localization.text(.copyEntry)) {
                        copy(ActivityLogRenderer.copyableDiagnostics(for: selectedEntry))
                    }
                    Button(localization.text(.copyDiagnosticExport)) {
                        copyDiagnosticExport()
                    }
                }
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text(localization.text(.noEntrySelected))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var filteredEntries: [ActivityLogEntry] {
        ActivityLogQuery.entries(activityLog.entries, filter: filter)
    }

    private var selectedEntry: ActivityLogEntry? {
        filteredEntries.first { $0.id == selectedEntryID } ?? filteredEntries.first
    }

    private func loadActivityLog() {
        do {
            activityLog = try DisplayRecallStore.live().loadActivityLog()
            selectedEntryID = filteredEntries.first?.id
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func title(for filter: ActivityLogFilter) -> String {
        switch filter {
        case .all:
            localization.text(.allActivity)
        case .applies:
            localization.text(.applyEvents)
        case .automation:
            localization.text(.automationEvents)
        case .errors:
            localization.text(.errorEvents)
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
        statusMessage = localization.status("Copied.", chinese: "已复制。")
    }
}

struct AboutPageView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var localization: LocalizationController
    private let catalog = AcknowledgementsCatalog.current()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(localization.text(.about))
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                Text(AboutMetadata.current().displayString)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(localization.status(
                    "Independent companion for displayplacer.",
                    chinese: "displayplacer 的独立伴随工具。"
                ))
                .foregroundStyle(.secondary)
                Text(catalog.independenceNotice)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button(localization.text(.checkForUpdates)) {
                    openURL(ReleaseConfiguration.production().sparklePolicy.feedURL)
                }
                Button(localization.text(.openProject)) {
                    openURL(URL(string: "https://github.com/wbbb/display-recall")!)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text(localization.text(.acknowledgements))
                    .font(.headline)

                ForEach(catalog.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(item.name) \(item.version)")
                            .fontWeight(.medium)
                        Text("\(item.licenseName) - \(item.modificationStatus.title)")
                            .foregroundStyle(.secondary)
                        Button(localization.text(.openProject)) {
                            openURL(item.projectURL)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(24)
    }
}

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var localization: LocalizationController
    @AppStorage(DockIconPreference.userDefaultsKey) private var showDockIcon = false
    @State private var settings = AppSettings()
    @State private var activityLog = ActivityLogStoreDocument()
    @State private var statusMessage = ""
    @State private var showsAdvancedBackend = false

    var body: some View {
        Form {
            Section(localization.text(.general)) {
                Toggle(localization.text(.launchAtLogin), isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { newValue in
                        settings.launchAtLogin = newValue
                        setLaunchAtLogin(newValue)
                        saveSettings()
                    }
                ))

                Toggle(localization.text(.showDockIcon), isOn: $showDockIcon)
                    .onChange(of: showDockIcon) { newValue in
                        settings.showDockIcon = newValue
                        DockIconController.apply(showDockIcon: newValue)
                        saveSettings()
                    }

                Picker(localization.text(.language), selection: Binding(
                    get: { settings.language },
                    set: {
                        settings.language = $0
                        localization.preference = $0
                        saveSettings()
                    }
                )) {
                    ForEach(LanguagePreference.allCases, id: \.self) { language in
                        Text(language.title).tag(language)
                    }
                }
            }

            Section(localization.text(.automation)) {
                Toggle(localization.text(.automaticApply), isOn: Binding(
                    get: { settings.automaticApplyEnabled },
                    set: { settings.automaticApplyEnabled = $0; saveSettings() }
                ))

                Stepper(
                    localization.countdownLabel(seconds: settings.automaticApplyCountdownSeconds),
                    value: Binding(
                        get: { settings.automaticApplyCountdownSeconds },
                        set: { settings.automaticApplyCountdownSeconds = $0; saveSettings() }
                    ),
                    in: 1...30
                )
            }

            Section(localization.text(.backend)) {
                LabeledContent(localization.text(.source), value: "Bundled")
                LabeledContent("displayplacer", value: DisplayplacerBackend.bundledMetadata.version)
                LabeledContent(localization.text(.architecture), value: DisplayplacerBackendArchitecture.current.rawValue)

                DisclosureGroup(
                    localization.text(.advancedBackend),
                    isExpanded: $showsAdvancedBackend
                ) {
                    Text(localization.status(
                        "Use only when testing another displayplacer build.",
                        chinese: "仅在测试其他 displayplacer 构建时使用。"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    TextField(localization.text(.customBackendPath), text: Binding(
                        get: { settings.backendSelection.customPath ?? "" },
                        set: { newValue in
                            settings.backendSelection = BackendSelection(
                                source: newValue.isEmpty ? .bundled : .custom(path: newValue),
                                customPath: newValue.isEmpty ? nil : newValue
                            )
                            saveSettings()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            }

            Section(localization.text(.shortcuts)) {
                Text(localization.text(.shortcutsDescription))
                    .foregroundStyle(.secondary)
                Text(localization.configuredShortcuts(
                    settings.shortcutBindings.filter { $0.keyEquivalent?.isEmpty == false }.count
                ))
                .foregroundStyle(.secondary)
            }

            Section(localization.text(.updates)) {
                LabeledContent(localization.text(.version), value: AboutMetadata.current().displayString)
                Button(localization.text(.checkForUpdates)) {
                    openURL(ReleaseConfiguration.production().sparklePolicy.feedURL)
                }
                Text(localization.text(.updateChecksDescription))
                    .foregroundStyle(.secondary)
            }

            Section(localization.text(.diagnostics)) {
                Button(localization.text(.openActivityLog)) {
                    MainWindowRouter.shared.select(.activityLog)
                }
                Button(localization.text(.copyDiagnosticExport)) {
                    copyDiagnosticExport()
                }
                Text(localization.status(
                    "Logs stay in Activity Log; Settings only exposes diagnostic actions.",
                    chinese: "日志保留在活动日志页；设置页只提供诊断操作。"
                ))
                .foregroundStyle(.secondary)
            }

            if !statusMessage.isEmpty {
                Section(localization.text(.status)) {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(maxWidth: 620)
        .task {
            loadSettings()
            loadActivityLog()
        }
    }

    private func loadSettings() {
        do {
            settings = try DisplayRecallStore.live().loadSettings().settings
            localization.preference = settings.language
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
        statusMessage = localization.status("Copied.", chinese: "已复制。")
    }
}
