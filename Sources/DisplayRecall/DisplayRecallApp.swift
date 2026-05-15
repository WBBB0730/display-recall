import AppKit
import Carbon
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
    private var shortcutController: ShortcutHotKeyController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        DockIconController.applyCurrentPreference()
        statusBarController = StatusBarController()
        shortcutController = ShortcutHotKeyController.shared
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
        shortcutController?.invalidate()
        shortcutController = nil
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        MainWindowController.shared.show(section: MainWindowSection.default)
        return false
    }
}

@MainActor
final class ShortcutHotKeyController {
    static let shared = ShortcutHotKeyController()

    private static let signature = OSType(0x4452434C)

    private var registeredHotKeys: [EventHotKeyRef] = []
    private var hotKeyProfileIDs: [UInt32: UUID] = [:]
    private var nextHotKeyID: UInt32 = 1
    private var eventHandler: EventHandlerRef?
    private var profilesObserver: NSObjectProtocol?
    private var shortcutsObserver: NSObjectProtocol?

    private init() {
        installHandlerIfNeeded()
        reload(showFailures: false)
        profilesObserver = NotificationCenter.default.addObserver(
            forName: .displayRecallProfilesChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reload(showFailures: false)
            }
        }
        shortcutsObserver = NotificationCenter.default.addObserver(
            forName: .displayRecallShortcutsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reload(showFailures: true)
            }
        }
    }

    func invalidate() {
        unregisterAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        if let profilesObserver {
            NotificationCenter.default.removeObserver(profilesObserver)
        }
        if let shortcutsObserver {
            NotificationCenter.default.removeObserver(shortcutsObserver)
        }
        profilesObserver = nil
        shortcutsObserver = nil
    }

    func reload(showFailures: Bool) {
        unregisterAll()
        installHandlerIfNeeded()

        do {
            let store = try DisplayRecallStore.live()
            let document = try store.loadProfiles()
            let settings = try store.loadSettings().settings
            let profileIDs = Set(document.profiles.map(\.id))
            var failures: [String] = []

            for binding in settings.shortcutBindings where profileIDs.contains(binding.profileId) {
                guard let shortcut = binding.shortcut else {
                    continue
                }
                if let error = register(shortcut, profileID: binding.profileId) {
                    failures.append(shortcut.keyEquivalent)
                    recordShortcutRegistrationFailure(shortcut, error: error)
                }
            }

            if showFailures, !failures.isEmpty {
                showSimpleAlert(
                    title: LocalizationController.shared.status(
                        "Shortcut unavailable",
                        chinese: "快捷键暂时不可用"
                    ),
                    message: failures.joined(separator: ", ")
                )
            }
        } catch {
            recordActivity(ActivityLogEntry(
                type: .backendVerification,
                metadata: ["shortcutRegistrationError": error.localizedDescription]
            ))
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return noErr
                }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                let controller = Unmanaged<ShortcutHotKeyController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                Task { @MainActor in
                    controller.handleHotKey(id: hotKeyID.id)
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        if status != noErr {
            recordActivity(ActivityLogEntry(
                type: .backendVerification,
                metadata: ["shortcutHandlerError": "\(status)"]
            ))
        }
    }

    private func register(_ shortcut: ConfigurationShortcut, profileID: UUID) -> String? {
        let hotKeyID = nextHotKeyID
        nextHotKeyID += 1

        let eventHotKeyID = EventHotKeyID(
            signature: Self.signature,
            id: hotKeyID
        )
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            carbonModifiers(from: shortcut.modifierFlags),
            eventHotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let hotKeyRef else {
            return "\(status)"
        }

        registeredHotKeys.append(hotKeyRef)
        hotKeyProfileIDs[hotKeyID] = profileID
        return nil
    }

    private func unregisterAll() {
        for hotKey in registeredHotKeys {
            UnregisterEventHotKey(hotKey)
        }
        registeredHotKeys.removeAll()
        hotKeyProfileIDs.removeAll()
    }

    private func handleHotKey(id: UInt32) {
        guard let profileID = hotKeyProfileIDs[id] else {
            return
        }

        Task {
            await applyShortcut(profileID: profileID)
        }
    }

    private func applyShortcut(profileID: UUID) async {
        do {
            let store = try DisplayRecallStore.live()
            let document = try store.loadProfiles()
            guard let profile = document.profiles.first(where: { $0.id == profileID }) else {
                return
            }
            let currentFingerprint = await currentDisplayFingerprint()
            guard confirmApplyIfNeeded(profile, currentFingerprint: currentFingerprint) else {
                return
            }

            let runner = try DisplayplacerBackend.bundledRunner()
            let manager = ProfileManager(document: document)
            let result = try await manager.apply(profile) { arguments in
                try await runner.run(arguments: arguments)
            }
            recordActivity(ActivityLogEntry(
                type: result.exitCode == 0 ? .hotkeyApplied : .profileApplyFailed,
                trigger: .hotkey,
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
            ))
            if result.exitCode != 0 {
                showSimpleAlert(
                    title: LocalizationController.shared.status("Apply failed", chinese: "应用失败"),
                    message: result.stderr
                )
            }
        } catch {
            showSimpleAlert(
                title: LocalizationController.shared.status("Apply failed", chinese: "应用失败"),
                message: error.localizedDescription
            )
            recordActivity(ActivityLogEntry(
                type: .profileApplyFailed,
                trigger: .hotkey,
                profileSnapshot: nil,
                stderr: error.localizedDescription
            ))
        }
    }

    private func confirmApplyIfNeeded(
        _ profile: DisplayProfile,
        currentFingerprint: DisplaySetupFingerprint?
    ) -> Bool {
        let requiresConfirmation = profile.displaySetupFingerprint != currentFingerprint
            || profile.importedNeedsFirstApplyConfirmation
            || profile.isCommandEdited
        guard requiresConfirmation else {
            return true
        }

        let localization = LocalizationController.shared
        let alert = NSAlert()
        alert.messageText = localization.status("Apply \(profile.name)?", chinese: "应用 \(profile.name)？")
        alert.informativeText = localization.status(
            "This configuration may belong to a different display setup or need extra care.",
            chinese: "这个配置可能属于其他显示器组合，或需要额外确认。"
        )
        alert.addButton(withTitle: localization.text(.applyConfiguration))
        alert.addButton(withTitle: localization.text(.cancel))
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func currentDisplayFingerprint() async -> DisplaySetupFingerprint? {
        guard let service = try? FirstRunSetupService.live(),
              case let .ready(layout) = await service.verifyBackendAndReadCurrentLayout() else {
            return nil
        }
        return layout.displaySetupFingerprint
    }

    private func carbonModifiers(from modifierFlags: UInt) -> UInt32 {
        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)
        var carbonFlags: UInt32 = 0
        if flags.contains(.command) {
            carbonFlags |= UInt32(cmdKey)
        }
        if flags.contains(.option) {
            carbonFlags |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            carbonFlags |= UInt32(controlKey)
        }
        if flags.contains(.shift) {
            carbonFlags |= UInt32(shiftKey)
        }
        return carbonFlags
    }

    private func recordShortcutRegistrationFailure(
        _ shortcut: ConfigurationShortcut,
        error: String
    ) {
        recordActivity(ActivityLogEntry(
            type: .backendVerification,
            metadata: [
                "shortcut": shortcut.keyEquivalent,
                "registrationError": error
            ]
        ))
    }

    private func recordActivity(_ entry: ActivityLogEntry) {
        try? ActivityLogRecorder(store: DisplayRecallStore.live()).record(entry)
    }

    private func showSimpleAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: LocalizationController.shared.status("OK", chinese: "好"))
        alert.runModal()
    }
}

extension Notification.Name {
    static let displayRecallDisplaySetupChanged = Notification.Name("DisplayRecallDisplaySetupChanged")
    static let displayRecallProfilesChanged = Notification.Name("DisplayRecallProfilesChanged")
    static let displayRecallStartupStabilized = Notification.Name("DisplayRecallStartupStabilized")
    static let displayRecallShortcutsChanged = Notification.Name("DisplayRecallShortcutsChanged")
}

@MainActor
enum DockIconController {
    static func applyCurrentPreference(isMainWindowVisible: Bool = false) {
        let preference = (try? DisplayRecallStore.live().loadSettings().settings.dockIconVisibility)
            ?? storedPreference(defaults: .standard)
        apply(preference: preference, isMainWindowVisible: isMainWindowVisible)
    }

    static func apply(
        preference: DockIconVisibilityPreference,
        isMainWindowVisible: Bool
    ) {
        UserDefaults.standard.set(preference.rawValue, forKey: DockIconVisibilityPreference.userDefaultsKey)
        NSApp.setActivationPolicy(
            DockIconVisibilityPolicy.activationPolicy(
                preference: preference,
                isMainWindowVisible: isMainWindowVisible
            ).appKitActivationPolicy
        )
        if DockIconVisibilityPolicy.shouldPreserveMainWindowVisibility(
            preference: preference,
            isMainWindowVisible: isMainWindowVisible
        ) {
            MainWindowController.shared.restoreVisibleWindow()
        }
    }

    private static func storedPreference(defaults: UserDefaults) -> DockIconVisibilityPreference {
        if let rawValue = defaults.string(forKey: DockIconVisibilityPreference.userDefaultsKey),
           let preference = DockIconVisibilityPreference(rawValue: rawValue) {
            return preference
        }
        if defaults.object(forKey: DockIconVisibilityPreference.legacyShowDockIconUserDefaultsKey) != nil {
            return defaults.bool(forKey: DockIconVisibilityPreference.legacyShowDockIconUserDefaultsKey)
                ? .alwaysShow
                : .automatic
        }
        return DockIconVisibilityPreference.defaultValue
    }
}

private extension DockIconActivationPolicy {
    var appKitActivationPolicy: NSApplication.ActivationPolicy {
        switch self {
        case .regular:
            .regular
        case .accessory:
            .accessory
        }
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

    private init() {
        if let settings = try? DisplayRecallStore.live().loadSettings().settings {
            preference = settings.language
        }
    }

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

    func defaultDisplaySetupGroupName(existingNames: [String]) -> String {
        DisplaySetupGroupNameGenerator.firstAvailableDefaultName(existingNames: existingNames, language: preference)
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
        let shouldFocus = panel?.isVisible != true
        let rootView = PendingApplyPanelView(
            profileName: profile.name,
            remainingSeconds: remainingSeconds,
            trigger: trigger,
            applyNow: applyNow,
            stop: stop
        )

        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 312, height: 118),
                styleMask: [.titled],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.title = AppConfiguration.displayName
            panel.isReleasedWhenClosed = false
            self.panel = panel
        }

        panel?.contentView = NSHostingView(rootView: rootView)
        positionPanel()
        if shouldFocus {
            NSApp.activate(ignoringOtherApps: true)
            panel?.makeKeyAndOrderFront(nil)
        }
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
            x: screenFrame.maxX - panel.frame.width - 10,
            y: screenFrame.maxY - panel.frame.height - 10
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
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
        .frame(width: 312)
    }
}

private struct MenuSaveProfilePanelView: View {
    @EnvironmentObject private var localization: LocalizationController
    let suggestedName: String
    let initialMakeAutomaticDefault: Bool
    let onCancel: () -> Void
    let onSave: (String, Bool) -> Void

    @State private var name: String
    @State private var makeAutomaticDefault: Bool
    @FocusState private var nameFocused: Bool

    init(
        suggestedName: String,
        initialMakeAutomaticDefault: Bool = false,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String, Bool) -> Void
    ) {
        self.suggestedName = suggestedName
        self.initialMakeAutomaticDefault = initialMakeAutomaticDefault
        self.onCancel = onCancel
        self.onSave = onSave
        _name = State(initialValue: suggestedName)
        _makeAutomaticDefault = State(initialValue: initialMakeAutomaticDefault)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(localization.text(.profileName), text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($nameFocused)

            Toggle(localization.text(.automaticApply), isOn: $makeAutomaticDefault)

            HStack {
                Spacer()
                Button(localization.text(.cancel), action: onCancel)
                Button(localization.text(.save)) {
                    onSave(trimmedName, makeAutomaticDefault)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedName.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 300)
        .onAppear {
            nameFocused = true
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    static let shared = MainWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    var isMainWindowVisible: Bool {
        window?.isVisible == true
    }

    func show(section: MainWindowSection) {
        let shouldSelectSection = window?.isVisible != true
        if shouldSelectSection {
            MainWindowRouter.shared.select(section)
        }

        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = AppWindow.main.title
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(
                rootView: MainWindowView()
                    .environmentObject(LocalizationController.shared)
            )
            window.center()
            window.delegate = self
            self.window = window
        }

        DockIconController.applyCurrentPreference(isMainWindowVisible: true)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func restoreVisibleWindow() {
        guard window?.isVisible == true else {
            return
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        DockIconController.applyCurrentPreference(isMainWindowVisible: false)
    }
}

@MainActor
final class StatusBarController: NSObject {
    private struct MenuSaveProfileOptions {
        let name: String
        let makeAutomaticDefault: Bool
    }

    private let menuMinimumWidth: CGFloat = 200
    private let menuTitleMaximumWidth: CGFloat = 150
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var document = ProfileStoreDocument()
    private var settings = AppSettings()
    private var currentFingerprint: DisplaySetupFingerprint?
    private var automaticCoordinator = AutomaticApplyCoordinator(countdownSeconds: 5)
    private var pendingApplyTask: Task<Void, Never>?
    private var displayChangeObserver: NSObjectProtocol?
    private var profileChangeObserver: NSObjectProtocol?
    private var startupObserver: NSObjectProtocol?

    override init() {
        super.init()
        configureStatusItem()
        observeAutomaticApplyTriggers()
        Task {
            loadSettings()
            await refreshCurrentSetup()
            loadProfiles()
        }
    }

    private var automationStatus: AutomationStatus {
        settings.automaticApplyEnabled ? .enabled : .paused
    }

    func invalidate() {
        if let displayChangeObserver {
            NotificationCenter.default.removeObserver(displayChangeObserver)
        }
        if let profileChangeObserver {
            NotificationCenter.default.removeObserver(profileChangeObserver)
        }
        if let startupObserver {
            NotificationCenter.default.removeObserver(startupObserver)
        }
        displayChangeObserver = nil
        profileChangeObserver = nil
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

        profileChangeObserver = NotificationCenter.default.addObserver(
            forName: .displayRecallProfilesChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadProfiles()
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
        loadSettings()
        let menu = buildMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.minimumWidth = menuMinimumWidth

        let model = MenuBarModel.build(
            document: document,
            currentFingerprint: currentFingerprint,
            automationStatus: automationStatus
        )

        menu.addItem(actionItem(
            title: LocalizationController.shared.text(.openDisplayRecall),
            action: #selector(openProfilesFromMenu)
        ))
        menu.addItem(.separator())

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
            title: LocalizationController.shared.text(.settings),
            action: #selector(openSettingsFromMenu)
        ))
        menu.addItem(actionItem(
            title: LocalizationController.shared.text(.quitDisplayRecall),
            action: #selector(quitFromMenu)
        ))

        return menu
    }

    private func profileMenuItem(_ item: MenuBarProfileItem) -> NSMenuItem {
        let menuItem = actionItem(title: item.profile.name, action: #selector(applyProfileFromMenu(_:)))
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

    private func truncatedMenuTitle(_ title: String) -> String {
        let font = NSFont.menuFont(ofSize: 0)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        guard title.size(withAttributes: attributes).width > menuTitleMaximumWidth else {
            return title
        }

        var lowerBound = 0
        var upperBound = title.count
        var bestFit = "…"

        while lowerBound <= upperBound {
            let midpoint = (lowerBound + upperBound) / 2
            let candidate = "\(title.prefix(midpoint))…"
            if candidate.size(withAttributes: attributes).width <= menuTitleMaximumWidth {
                bestFit = candidate
                lowerBound = midpoint + 1
            } else {
                upperBound = midpoint - 1
            }
        }

        return bestFit
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
        settings.automaticApplyEnabled.toggle()
        saveSettings()
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

    private func loadSettings() {
        do {
            settings = try DisplayRecallStore.live().loadSettings().settings
            automaticCoordinator = AutomaticApplyCoordinator(
                countdownSeconds: settings.automaticApplyCountdownSeconds
            )
        } catch {
            recordActivity(ActivityLogEntry(
                type: .backendVerification,
                metadata: ["error": error.localizedDescription]
            ))
        }
    }

    private func saveSettings() {
        do {
            try DisplayRecallStore.live().save(SettingsStoreDocument(settings: settings))
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
            let suggestedName = LocalizationController.shared.defaultProfileName(
                existingNames: document.profiles.map(\.name)
            )
            guard let options = requestProfileSaveOptions(suggestedName: suggestedName) else {
                return
            }

            var manager = ProfileManager(document: document)
            document = try manager.saveCurrentLayout(
                layout,
                name: options.name,
                makeAutomaticDefault: options.makeAutomaticDefault,
                displaySetupGroupLanguage: LocalizationController.shared.preference
            )
            try DisplayRecallStore.live().save(document)
            NotificationCenter.default.post(name: .displayRecallProfilesChanged, object: nil)
            currentFingerprint = layout.displaySetupFingerprint
        } catch {
            recordActivity(ActivityLogEntry(
                type: .backendVerification,
                metadata: ["error": error.localizedDescription]
            ))
        }
    }

    private func requestProfileSaveOptions(suggestedName: String) -> MenuSaveProfileOptions? {
        let localization = LocalizationController.shared
        var result: MenuSaveProfileOptions?
        var panel: NSPanel!

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 1),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.title = localization.text(.saveCurrentProfile)
        panel.isReleasedWhenClosed = false
        let contentView = NSHostingView(
            rootView: MenuSaveProfilePanelView(
                suggestedName: suggestedName,
                initialMakeAutomaticDefault: false,
                onCancel: {
                    NSApp.stopModal(withCode: .cancel)
                },
                onSave: { name, makeAutomaticDefault in
                    result = MenuSaveProfileOptions(
                        name: name,
                        makeAutomaticDefault: makeAutomaticDefault
                    )
                    NSApp.stopModal(withCode: .OK)
                }
            )
            .environmentObject(localization)
        )
        panel.contentView = contentView
        panel.setContentSize(contentView.fittingSize)
        centerPanelOnVisibleScreen(panel)

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        let response = NSApp.runModal(for: panel)
        panel.close()
        return response == .OK ? result : nil
    }

    private func centerPanelOnVisibleScreen(_ panel: NSPanel) {
        guard let screenFrame = NSScreen.main?.visibleFrame else {
            panel.center()
            return
        }

        let frame = panel.frame
        let origin = NSPoint(
            x: screenFrame.midX - frame.width / 2,
            y: screenFrame.midY - frame.height / 2
        )
        panel.setFrameOrigin(origin)
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
        let previousFingerprint = currentFingerprint
        await refreshCurrentSetup()
        loadProfiles()
        loadSettings()
        guard let currentFingerprint else {
            pendingApplyTask?.cancel()
            PendingApplyPanelController.shared.close()
            return
        }
        if trigger == .displayChange && previousFingerprint == currentFingerprint {
            return
        }

        pendingApplyTask?.cancel()
        PendingApplyPanelController.shared.close()

        let state: AutomaticApplyState
        switch trigger {
        case .displayChange:
            state = automaticCoordinator.handleDisplayChange(
                document: document,
                previousFingerprint: previousFingerprint,
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
        if case let .readyToApply(profile, _) = state {
            pendingApplyTask?.cancel()
            PendingApplyPanelController.shared.close()
            Task {
                await apply(profile)
            }
            return
        }

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
                guard !Task.isCancelled else { return }
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
        case let .readyToApply(profile, _):
            recordActivity(
                ActivityLogEntry(
                    type: .matchingDecision,
                    trigger: activityTrigger,
                    profileSnapshot: ProfileSnapshot(id: profile.id, name: profile.name),
                    metadata: ["result": "readyToApply"]
                )
            )
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
    @State private var settings = AppSettings()
    @State private var currentFingerprint: DisplaySetupFingerprint?
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

    private var automationStatus: AutomationStatus {
        settings.automaticApplyEnabled ? .enabled : .paused
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
                set: {
                    settings.automaticApplyEnabled = $0
                    saveSettings()
                }
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
            loadSettings()
            await refreshCurrentSetup()
            loadProfiles()
        }
        .onReceive(NotificationCenter.default.publisher(for: .displayRecallDisplaySetupChanged)) { _ in
            Task {
                await scheduleAutomaticApply(trigger: .displayChange)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .displayRecallProfilesChanged)) { _ in
            loadProfiles()
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

    private func loadSettings() {
        do {
            settings = try DisplayRecallStore.live().loadSettings().settings
            automaticCoordinator = AutomaticApplyCoordinator(
                countdownSeconds: settings.automaticApplyCountdownSeconds
            )
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
                name: localization.defaultProfileName(existingNames: document.profiles.map(\.name)),
                displaySetupGroupLanguage: localization.preference
            )
            try DisplayRecallStore.live().save(document)
            NotificationCenter.default.post(name: .displayRecallProfilesChanged, object: nil)
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
        let previousFingerprint = currentFingerprint
        await refreshCurrentSetup()
        loadProfiles()
        loadSettings()
        guard let currentFingerprint else {
            pendingApplyTask?.cancel()
            PendingApplyPanelController.shared.close()
            return
        }
        if trigger == .displayChange && previousFingerprint == currentFingerprint {
            return
        }

        pendingApplyTask?.cancel()
        PendingApplyPanelController.shared.close()

        switch trigger {
        case .displayChange:
            let state = automaticCoordinator.handleDisplayChange(
                document: document,
                previousFingerprint: previousFingerprint,
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
        if case let .readyToApply(profile, _) = state {
            pendingApplyTask?.cancel()
            PendingApplyPanelController.shared.close()
            Task {
                await apply(MenuBarProfileItem(
                    profile: profile,
                    currentFingerprint: currentFingerprint,
                    isAutomaticDefault: true
                ))
            }
            return
        }

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
                guard !Task.isCancelled else { return }
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
        case let .readyToApply(profile, _):
            recordActivity(
                ActivityLogEntry(
                    type: .matchingDecision,
                    trigger: activityTrigger,
                    profileSnapshot: ProfileSnapshot(id: profile.id, name: profile.name),
                    metadata: ["result": "readyToApply"]
                )
            )
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
    private let sidebarWidth: CGFloat = 172
    @AppStorage(SetupPreference.completedUserDefaultsKey) private var setupCompleted = false
    @EnvironmentObject private var localization: LocalizationController
    @ObservedObject private var router = MainWindowRouter.shared

    var body: some View {
        if setupCompleted {
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    List(selection: $router.selectedSection) {
                        ForEach(MainWindowSection.allCases) { section in
                            Label(localizedTitle(for: section), systemImage: section.systemImage)
                                .tag(section)
                        }
                    }
                    .listStyle(.sidebar)
                    .frame(width: sidebarWidth)

                    Divider()

                    selectedContent
                        .frame(
                            width: max(0, proxy.size.width - sidebarWidth - 1),
                            height: proxy.size.height
                        )
                        .clipped()
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(minWidth: 640, minHeight: 480)
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
            NotificationCenter.default.post(name: .displayRecallProfilesChanged, object: nil)
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

private struct ProfileExportSheetState: Identifiable {
    let id = UUID()
    let initialSelectedProfileIDs: Set<UUID>
}

private enum CheckboxSelectionState {
    case off
    case mixed
    case on

    var controlState: NSControl.StateValue {
        switch self {
        case .off:
            .off
        case .mixed:
            .mixed
        case .on:
            .on
        }
    }
}

private struct TriStateCheckbox: NSViewRepresentable {
    let state: CheckboxSelectionState
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(checkboxWithTitle: "", target: context.coordinator, action: #selector(Coordinator.toggle))
        button.allowsMixedState = true
        button.setButtonType(.switch)
        button.isBordered = false
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 18),
            button.heightAnchor.constraint(equalToConstant: 18)
        ])
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.action = action
        button.state = state.controlState
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func toggle() {
            action()
        }
    }
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

private enum RenameTarget {
    case profile(UUID)
    case displaySetupGroup(UUID)
}

private struct RenameSheetState: Identifiable {
    let id = UUID()
    let title: String
    let initialName: String
    let target: RenameTarget
}

private struct ShortcutSheetState: Identifiable {
    let id = UUID()
    let profile: DisplayProfile
    let existingShortcut: ConfigurationShortcut?
}

private struct RenameSheet: View {
    @EnvironmentObject private var localization: LocalizationController
    let state: RenameSheetState
    let onCancel: () -> Void
    let onSave: (String) -> Void

    @State private var name: String

    init(
        state: RenameSheetState,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String) -> Void
    ) {
        self.state = state
        self.onCancel = onCancel
        self.onSave = onSave
        _name = State(initialValue: state.initialName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(state.title)
                .font(.headline)
            TextField(localization.text(.name), text: $name)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button(localization.text(.cancel), action: onCancel)
                Button(localization.text(.save)) {
                    onSave(name)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 320)
    }
}

private struct ShortcutCaptureSheet: View {
    @EnvironmentObject private var localization: LocalizationController
    let state: ShortcutSheetState
    let conflictName: (ConfigurationShortcut?) -> String?
    let onCancel: () -> Void
    let onClear: () -> Void
    let onSave: (ConfigurationShortcut) -> Void
    let onReplace: (ConfigurationShortcut) -> Void

    @State private var shortcut: ConfigurationShortcut?

    init(
        state: ShortcutSheetState,
        conflictName: @escaping (ConfigurationShortcut?) -> String?,
        onCancel: @escaping () -> Void,
        onClear: @escaping () -> Void,
        onSave: @escaping (ConfigurationShortcut) -> Void,
        onReplace: @escaping (ConfigurationShortcut) -> Void
    ) {
        self.state = state
        self.conflictName = conflictName
        self.onCancel = onCancel
        self.onClear = onClear
        self.onSave = onSave
        self.onReplace = onReplace
        _shortcut = State(initialValue: state.existingShortcut)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localization.status("Set Shortcut", chinese: "设置快捷键"))
                .font(.headline)
            Text(state.profile.name)
                .foregroundStyle(.secondary)

            ShortcutRecorderField(
                shortcut: $shortcut,
                placeholder: localization.status("Press shortcut", chinese: "按下快捷键"),
                onCancel: onCancel
            )
            .frame(height: 30)

            if let conflict = conflictName(shortcut), let shortcut {
                Text(localization.status(
                    "\(shortcut.keyEquivalent) is already used by “\(conflict)”",
                    chinese: "\(shortcut.keyEquivalent) 已被“\(conflict)”使用"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            HStack {
                Button(localization.status("Clear", chinese: "清除"), action: onClear)
                    .disabled(state.existingShortcut == nil && shortcut == nil)
                Spacer()
                Button(localization.text(.cancel), action: onCancel)
                if conflictName(shortcut) != nil, let shortcut {
                    Button(localization.status("Modify", chinese: "修改")) {
                        self.shortcut = nil
                    }
                    Button(localization.status("Replace", chinese: "替换")) {
                        onReplace(shortcut)
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button(localization.text(.save)) {
                        guard let shortcut else { return }
                        onSave(shortcut)
                    }
                    .disabled(shortcut == nil)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(18)
        .frame(width: 340)
    }
}

private struct ShortcutRecorderField: NSViewRepresentable {
    @Binding var shortcut: ConfigurationShortcut?
    let placeholder: String
    let onCancel: () -> Void

    func makeNSView(context: Context) -> ShortcutRecorderTextField {
        let textField = ShortcutRecorderTextField()
        textField.onCapture = { shortcut in
            self.shortcut = shortcut
        }
        textField.onClear = {
            self.shortcut = nil
        }
        textField.onCancel = onCancel
        return textField
    }

    func updateNSView(_ nsView: ShortcutRecorderTextField, context: Context) {
        nsView.placeholderString = placeholder
        nsView.stringValue = shortcut?.keyEquivalent ?? ""
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

@MainActor
private final class ShortcutRecorderTextField: NSTextField {
    var onCapture: ((ConfigurationShortcut) -> Void)?
    var onClear: (() -> Void)?
    var onCancel: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53:
            onCancel?()
        case 51, 117:
            onClear?()
        default:
            guard let shortcut = shortcut(from: event) else {
                NSSound.beep()
                return
            }
            onCapture?(shortcut)
        }
    }

    private func configure() {
        isEditable = false
        isSelectable = false
        alignment = .center
        bezelStyle = .roundedBezel
        focusRingType = .default
    }

    private func shortcut(from event: NSEvent) -> ConfigurationShortcut? {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !modifiers.isEmpty,
              let key = event.charactersIgnoringModifiers?.uppercased(),
              !key.isEmpty else {
            return nil
        }

        return ConfigurationShortcut(
            keyEquivalent: displayString(modifiers: modifiers, key: key),
            keyCode: event.keyCode,
            modifierFlags: modifiers.rawValue
        )
    }

    private func displayString(modifiers: NSEvent.ModifierFlags, key: String) -> String {
        var result = ""
        if modifiers.contains(.command) {
            result += "⌘"
        }
        if modifiers.contains(.shift) {
            result += "⇧"
        }
        if modifiers.contains(.option) {
            result += "⌥"
        }
        if modifiers.contains(.control) {
            result += "⌃"
        }
        return result + key
    }
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

            Toggle(localization.text(.automaticApply), isOn: $makeAutomaticDefault)

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
    let sections: [ProfileGroupSection]
    let onCancel: () -> Void
    let onExport: (Set<UUID>) -> Void

    @State private var selectedProfileIDs: Set<UUID>

    init(
        state: ProfileExportSheetState,
        sections: [ProfileGroupSection],
        onCancel: @escaping () -> Void,
        onExport: @escaping (Set<UUID>) -> Void
    ) {
        self.state = state
        self.sections = sections
        self.onCancel = onCancel
        self.onExport = onExport
        _selectedProfileIDs = State(initialValue: state.initialSelectedProfileIDs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localization.text(.exportProfiles))
                .font(.title3)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                triStateSelectionRow(
                    title: localization.text(.allProfiles),
                    state: selectionState(for: allProfileIDs),
                    fontWeight: .medium
                ) {
                    toggleAllProfiles()
                }

                Spacer()

                Text(selectedCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(sections, id: \.group.id) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                triStateSelectionRow(
                                    title: displayName(for: section.group),
                                    state: selectionState(for: Set(section.profiles.map(\.id))),
                                    fontWeight: .semibold
                                ) {
                                    toggleGroup(section)
                                }

                                Spacer()

                                Text(groupCountText(for: section))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(section.profiles) { profile in
                                    Toggle(profile.name, isOn: profileBinding(for: profile))
                                        .toggleStyle(.checkbox)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.leading, 24)
                        }
                        .padding(12)

                        if section.group.id != sections.last?.group.id {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.quinary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .frame(maxHeight: 280)

            let preview = selectedPreview
            HStack {
                Text(selectionSummaryText(count: preview?.profileCount ?? 0))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(localization.text(.cancel), action: onCancel)
                Button(localization.text(.export)) {
                    onExport(selectedProfileIDs)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedPreview == nil || selectedPreview?.profileCount == 0)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private var selectedPreview: ProfileExportPreview? {
        guard !selectedProfileIDs.isEmpty else {
            return nil
        }
        let document = ProfileStoreDocument(
            profiles: sections.flatMap(\.profiles),
            automaticDefaultRules: [],
            displaySetupGroups: sections.map(\.group)
        )
        return ProfileExporter.preview(document: document, selection: .multiple(Array(selectedProfileIDs)))
    }

    private var allProfileIDs: Set<UUID> {
        Set(sections.flatMap(\.profiles).map(\.id))
    }

    private var selectedCountText: String {
        "\(selectedProfileIDs.count)/\(allProfileIDs.count)"
    }

    private func selectionSummaryText(count: Int) -> String {
        localization.status(
            "\(count) selected",
            chinese: "已选择 \(count) 个"
        )
    }

    private func groupCountText(for section: ProfileGroupSection) -> String {
        let profileIDs = Set(section.profiles.map(\.id))
        let selectedCount = profileIDs.intersection(selectedProfileIDs).count
        return "\(selectedCount)/\(profileIDs.count)"
    }

    private func triStateSelectionRow(
        title: String,
        state: CheckboxSelectionState,
        fontWeight: Font.Weight,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 5) {
            TriStateCheckbox(state: state, action: action)
                .frame(width: 18, height: 18)

            Text(title)
                .fontWeight(fontWeight)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }

    private func selectionState(for profileIDs: Set<UUID>) -> CheckboxSelectionState {
        guard !profileIDs.isEmpty else {
            return .off
        }

        let selectedCount = profileIDs.intersection(selectedProfileIDs).count
        if selectedCount == 0 {
            return .off
        }
        if selectedCount == profileIDs.count {
            return .on
        }
        return .mixed
    }

    private func toggleAllProfiles() {
        if selectionState(for: allProfileIDs) == .on {
            selectedProfileIDs.removeAll()
        } else {
            selectedProfileIDs = allProfileIDs
        }
    }

    private func toggleGroup(_ section: ProfileGroupSection) {
        let profileIDs = Set(section.profiles.map(\.id))
        if selectionState(for: profileIDs) == .on {
            selectedProfileIDs.subtract(profileIDs)
        } else {
            selectedProfileIDs.formUnion(profileIDs)
        }
    }

    private func profileBinding(for profile: DisplayProfile) -> Binding<Bool> {
        Binding(
            get: { selectedProfileIDs.contains(profile.id) },
            set: { isSelected in
                if isSelected {
                    selectedProfileIDs.insert(profile.id)
                } else {
                    selectedProfileIDs.remove(profile.id)
                }
            }
        )
    }

    private func displayName(for group: DisplaySetupGroup) -> String {
        DisplaySetupGroupNameGenerator.localizedDefaultNameIfNeeded(group.name, language: localization.preference)
    }
}

private struct ImportPreviewSheet: View {
    @EnvironmentObject private var localization: LocalizationController
    let state: ProfileImportPreviewSheetState
    let onCancel: () -> Void
    let onImport: (ImportConflictStrategy) -> Void

    @State private var conflictStrategy = ImportConflictStrategy.keepBoth

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localization.text(.importPreview))
                .font(.title3)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 6) {
                Text(localization.status(
                    "Import \(summary.profileCount) configurations",
                    chinese: "将导入 \(summary.profileCount) 个配置"
                ))

                if summary.showsConflictStrategy {
                    Text(localization.status(
                        "\(summary.conflictCount) configurations already exist",
                        chinese: "其中 \(summary.conflictCount) 个配置已存在"
                    ))
                    .foregroundStyle(.secondary)
                }
            }

            if summary.showsConflictStrategy {
                Picker(localization.text(.importConflictStrategy), selection: $conflictStrategy) {
                    Text(localization.text(.keepBoth)).tag(ImportConflictStrategy.keepBoth)
                    Text(localization.text(.replaceExisting)).tag(ImportConflictStrategy.replaceExisting)
                    Text(localization.text(.skipConflicts)).tag(ImportConflictStrategy.skipConflict)
                }
                .pickerStyle(.radioGroup)
            }

            HStack {
                Spacer()
                Button(localization.text(.cancel), action: onCancel)
                Button(localization.text(.importProfiles)) {
                    onImport(conflictStrategy)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 360)
    }

    private var summary: ImportPreviewConfirmationSummary {
        ImportPreviewConfirmationSummary(preview: state.preview)
    }
}

private let profileHoverAnimation = Animation.easeInOut(duration: 0.18)

private struct GroupHeaderHoverShape: Shape {
    let radius: CGFloat
    let roundsBottomCorners: Bool

    func path(in rect: CGRect) -> Path {
        let cornerRadius = min(radius, rect.width / 2, rect.height / 2)
        let bottomRadius = roundsBottomCorners ? cornerRadius : 0
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY))
        if bottomRadius > 0 {
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRadius),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - bottomRadius))
        if bottomRadius > 0 {
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
        } else {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        path.closeSubpath()

        return path
    }
}

private struct IconActionButton: View {
    let systemImage: String
    let title: String
    var role: ButtonRole?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemImage)
                .imageScale(.medium)
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(title)
        .accessibilityLabel(title)
        .onHover { hovered in
            withAnimation(profileHoverAnimation) {
                isHovered = hovered
            }
        }
    }

    private var iconColor: Color {
        guard isHovered else { return .secondary }
        return .primary
    }
}

private struct ImportantButtonHoverModifier: ViewModifier {
    let isProminent: Bool
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .brightness(isProminent && isHovered ? 0.08 : 0)
            .shadow(
                color: isProminent && isHovered ? Color.accentColor.opacity(0.24) : Color.clear,
                radius: isProminent && isHovered ? 6 : 0,
                y: isProminent && isHovered ? 1 : 0
            )
            .background(
                !isProminent && isHovered ? Color.primary.opacity(0.08) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .onHover { hovered in
                withAnimation(profileHoverAnimation) {
                    isHovered = hovered
                }
            }
    }
}

private extension View {
    func importantButtonHover(isProminent: Bool = false) -> some View {
        modifier(ImportantButtonHoverModifier(isProminent: isProminent))
    }

    func displayRecallSwitchControl() -> some View {
        toggleStyle(.switch)
            .controlSize(.small)
    }
}

struct ProfilesContentView: View {
    @EnvironmentObject private var localization: LocalizationController
    @State private var document = ProfileStoreDocument()
    @State private var settings = AppSettings()
    @State private var selectedProfileIDs = Set<UUID>()
    @State private var currentFingerprint: DisplaySetupFingerprint?
    @State private var statusMessage = ""
    @State private var exportSheet: ProfileExportSheetState?
    @State private var importPreviewSheet: ProfileImportPreviewSheetState?
    @State private var createProfileSheet: CreateProfileSheetState?
    @State private var renameSheet: RenameSheetState?
    @State private var shortcutSheet: ShortcutSheetState?
    @State private var expandedGroupIDs = Set<UUID>()
    @State private var didInitializeExpandedGroups = false
    @State private var hoveredGroupID: UUID?
    @State private var hoveredGroupActionID: UUID?
    @State private var hoveredProfileID: UUID?
    @State private var hoveredShortcutProfileID: UUID?

    private var groupSections: [ProfileGroupSection] {
        ProfileGroupingProjection.sections(
            document: document,
            currentFingerprint: currentFingerprint
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    Task {
                        await saveCurrentLayout()
                    }
                } label: {
                    Label(localization.text(.saveCurrentLayout), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .importantButtonHover(isProminent: true)

                Spacer()

                Button(localization.text(.importProfiles)) {
                    Task {
                        await importBackup()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .importantButtonHover()

                Button(localization.text(.export)) {
                    presentExportSheet()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .importantButtonHover()
            }
            .padding(.horizontal, 20)

            if groupSections.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "display.2")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(localization.status("No configurations yet.", chinese: "还没有配置"))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(groupSections, id: \.group.id) { section in
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 8) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 9, weight: .semibold))
                                            .frame(width: 12, height: 12)
                                            .rotationEffect(.degrees(isExpanded(section.group) ? 90 : 0))
                                        Text(displayName(for: section.group))
                                            .font(.headline)
                                        if section.isCurrent {
                                            Text(localization.text(.currentDisplaySetup))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }

                                    HStack(spacing: 0) {
                                        IconActionButton(
                                            systemImage: "square.and.pencil",
                                            title: localization.status("Rename Display Setup", chinese: "重命名显示器组合")
                                        ) {
                                            renameSheet = RenameSheetState(
                                                title: localization.status("Rename Display Setup", chinese: "重命名显示器组合"),
                                                initialName: displayName(for: section.group),
                                                target: .displaySetupGroup(section.group.id)
                                            )
                                        }

                                        if isStoredGroup(section.group) {
                                            IconActionButton(
                                                systemImage: "trash",
                                                title: localization.status("Delete Display Setup Group", chinese: "删除显示器组合")
                                            ) {
                                                deleteDisplaySetupGroup(section.group)
                                            }
                                        }
                                    }
                                    .frame(width: 56, height: 28)
                                    .opacity(hoveredGroupID == section.group.id ? 1 : 0)
                                    .allowsHitTesting(hoveredGroupID == section.group.id)
                                    .onHover { isHovered in
                                        hoveredGroupActionID = isHovered ? section.group.id : nil
                                    }
                                    .animation(profileHoverAnimation, value: hoveredGroupID)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    hoveredGroupID == section.group.id && hoveredGroupActionID != section.group.id
                                        ? Color.primary.opacity(0.08)
                                        : Color.clear,
                                    in: GroupHeaderHoverShape(
                                        radius: 6,
                                        roundsBottomCorners: !isExpanded(section.group)
                                    )
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    toggleExpanded(section.group)
                                }
                                .onHover { isHovered in
                                    hoveredGroupID = isHovered ? section.group.id : nil
                                }
                                .animation(profileHoverAnimation, value: hoveredGroupID)

                                if isExpanded(section.group) {
                                    VStack(alignment: .leading, spacing: 0) {
                                        if section.profiles.isEmpty {
                                            Text(localization.status("No configurations yet.", chinese: "还没有配置"))
                                                .foregroundStyle(.secondary)
                                                .padding(.vertical, 8)
                                        } else {
                                            ForEach(Array(section.profiles.enumerated()), id: \.element.id) { index, profile in
                                                VStack(alignment: .leading, spacing: 8) {
                                                HStack(spacing: 8) {
                                                    Text(profile.name)
                                                        .fontWeight(.medium)
                                                        .lineLimit(1)
                                                    Spacer()
                                                    profileActions(profile)
                                                        .opacity(hoveredProfileID == profile.id ? 1 : 0)
                                                        .allowsHitTesting(hoveredProfileID == profile.id)
                                                        .animation(profileHoverAnimation, value: hoveredProfileID)
                                                }

                                                HStack(spacing: 12) {
                                                    Button(localization.text(.applyConfiguration)) {
                                                        applyProfileFromRow(profile)
                                                    }
                                                    .font(.body)
                                                    .buttonStyle(.borderedProminent)
                                                    .controlSize(.large)
                                                    .importantButtonHover(isProminent: true)

                                                        Toggle(
                                                            localization.text(.automaticApplyConfiguration),
                                                            isOn: automaticApplyBinding(for: profile)
                                                        )
                                                        .displayRecallSwitchControl()

                                                        Spacer()

                                                        Button(shortcutDisplayTitle(for: profile)) {
                                                            shortcutSheet = ShortcutSheetState(
                                                                profile: profile,
                                                                existingShortcut: shortcutBinding(for: profile)?.shortcut
                                                            )
                                                        }
                                                        .font(.body)
                                                        .buttonStyle(.borderless)
                                                        .foregroundStyle(
                                                            hoveredShortcutProfileID == profile.id
                                                                ? .primary
                                                                : .secondary
                                                        )
                                                        .opacity(
                                                            shortcutBinding(for: profile)?.shortcut == nil
                                                                && hoveredProfileID != profile.id
                                                                ? 0
                                                                : 1
                                                        )
                                                        .allowsHitTesting(
                                                            shortcutBinding(for: profile)?.shortcut != nil
                                                                || hoveredProfileID == profile.id
                                                        )
                                                        .onHover { isHovered in
                                                            withAnimation(profileHoverAnimation) {
                                                                hoveredShortcutProfileID = isHovered ? profile.id : nil
                                                            }
                                                        }
                                                        .animation(profileHoverAnimation, value: hoveredProfileID)
                                                        .animation(profileHoverAnimation, value: hoveredShortcutProfileID)
                                                    }
                                            }
                                            .padding(.vertical, 12)
                                            .onHover { isHovered in
                                                hoveredProfileID = isHovered ? profile.id : nil
                                            }

                                            if index < section.profiles.count - 1 {
                                                Divider()
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.bottom, 8)
                                    .transition(.opacity)
                                }
                            }
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .clipped()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                }
            }

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 20)
        .task {
            await refreshProfileState(initializesExpandedGroups: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .displayRecallProfilesChanged)) { _ in
            Task {
                await refreshProfileState()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .displayRecallDisplaySetupChanged)) { _ in
            Task {
                await refreshProfileState()
            }
        }
        .sheet(item: $exportSheet) { sheet in
            ExportProfilesSheet(
                state: sheet,
                sections: groupSections,
                onCancel: {
                    exportSheet = nil
                },
                onExport: { selectedProfileIDs in
                    exportSheet = nil
                    export(
                        selection: exportSelection(for: selectedProfileIDs),
                        suggestedName: suggestedExportName(for: selectedProfileIDs)
                    )
                }
            )
            .environmentObject(localization)
        }
        .sheet(item: $createProfileSheet) { sheet in
            MenuSaveProfilePanelView(
                suggestedName: sheet.suggestedName,
                initialMakeAutomaticDefault: sheet.makeAutomaticDefault,
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
        .sheet(item: $renameSheet) { sheet in
            RenameSheet(
                state: sheet,
                onCancel: {
                    renameSheet = nil
                },
                onSave: { name in
                    renameSheet = nil
                    rename(sheet.target, to: name)
                }
            )
            .environmentObject(localization)
        }
        .sheet(item: $shortcutSheet) { sheet in
            ShortcutCaptureSheet(
                state: sheet,
                conflictName: { shortcut in
                    shortcutConflictName(for: sheet, shortcut: shortcut)
                },
                onCancel: {
                    shortcutSheet = nil
                },
                onClear: {
                    saveShortcut(nil, for: sheet.profile.id)
                    shortcutSheet = nil
                },
                onSave: { shortcut in
                    saveShortcut(shortcut, for: sheet.profile.id)
                    shortcutSheet = nil
                },
                onReplace: { shortcut in
                    saveShortcut(shortcut, for: sheet.profile.id)
                    shortcutSheet = nil
                }
            )
            .environmentObject(localization)
        }
    }

    private func profileActions(_ profile: DisplayProfile) -> some View {
        HStack(spacing: 2) {
            IconActionButton(
                systemImage: "square.and.pencil",
                title: localization.status("Rename Configuration", chinese: "重命名配置")
            ) {
                renameSheet = RenameSheetState(
                    title: localization.status("Rename Configuration", chinese: "重命名配置"),
                    initialName: profile.name,
                    target: .profile(profile.id)
                )
            }

            IconActionButton(
                systemImage: "square.and.arrow.up",
                title: localization.status("Export Configuration", chinese: "导出配置")
            ) {
                export(selection: .single(profile.id), suggestedName: profile.name)
            }

            IconActionButton(
                systemImage: "trash",
                title: localization.status("Delete Configuration", chinese: "删除配置"),
                role: .destructive
            ) {
                deleteProfile(profile)
            }
        }
        .frame(width: 88, height: 28, alignment: .trailing)
    }

    private func shortcutBinding(for profile: DisplayProfile) -> ShortcutBinding? {
        settings.shortcutBindings.first { $0.profileId == profile.id }
    }

    private func shortcutDisplayTitle(for profile: DisplayProfile) -> String {
        guard let shortcut = shortcutBinding(for: profile)?.keyEquivalent else {
            return localization.status("Set Shortcut", chinese: "设置快捷键")
        }
        return shortcut.map(String.init).joined(separator: " ")
    }

    private func shortcutConflictName(
        for sheet: ShortcutSheetState,
        shortcut: ConfigurationShortcut?
    ) -> String? {
        guard let shortcut,
              let conflict = ShortcutBindingEditor.conflict(
                for: shortcut,
                profileId: sheet.profile.id,
                in: settings.shortcutBindings
              ) else {
            return nil
        }
        return document.profiles.first { $0.id == conflict.profileId }?.name
    }

    private func saveShortcut(_ shortcut: ConfigurationShortcut?, for profileID: UUID) {
        if let shortcut {
            settings.shortcutBindings = ShortcutBindingEditor.replace(
                shortcut,
                for: profileID,
                in: settings.shortcutBindings
            )
        } else {
            settings.shortcutBindings = ShortcutBindingEditor.clear(
                profileId: profileID,
                in: settings.shortcutBindings
            )
        }
        saveSettings()
        NotificationCenter.default.post(name: .displayRecallShortcutsChanged, object: nil)
    }

    private func isExpanded(_ group: DisplaySetupGroup) -> Bool {
        expandedGroupIDs.contains(group.id)
    }

    private func isStoredGroup(_ group: DisplaySetupGroup) -> Bool {
        document.displaySetupGroups.contains { $0.id == group.id }
    }

    private func displayName(for group: DisplaySetupGroup) -> String {
        DisplaySetupGroupNameGenerator.localizedDefaultNameIfNeeded(group.name, language: localization.preference)
    }

    private func toggleExpanded(_ group: DisplaySetupGroup) {
        withAnimation(.easeInOut(duration: 0.18)) {
            if expandedGroupIDs.contains(group.id) {
                expandedGroupIDs.remove(group.id)
            } else {
                expandedGroupIDs.insert(group.id)
            }
        }
    }

    private func initializeExpandedGroupsIfNeeded() {
        guard !didInitializeExpandedGroups else { return }
        expandedGroupIDs = Set(groupSections.filter(\.isExpandedByDefault).map(\.group.id))
        didInitializeExpandedGroups = true
    }

    private func syncExpandedGroupsWithVisibleSections() {
        let visibleGroupIDs = Set(groupSections.map(\.group.id))
        expandedGroupIDs.formIntersection(visibleGroupIDs)
        expandedGroupIDs.formUnion(groupSections.filter(\.isExpandedByDefault).map(\.group.id))
    }

    private func automaticApplyBinding(for profile: DisplayProfile) -> Binding<Bool> {
        Binding(
            get: {
                ProfileManager(document: document).isAutomaticApplyEnabled(for: profile.id)
            },
            set: { isEnabled in
                do {
                    var manager = ProfileManager(document: document)
                    try manager.setAutomaticApply(profileID: profile.id, isEnabled: isEnabled)
                    document = manager.document
                    saveDocument()
                } catch {
                    statusMessage = error.localizedDescription
                }
            }
        )
    }

    private func rename(_ target: RenameTarget, to name: String) {
        do {
            var manager = ProfileManager(document: document)
            switch target {
            case let .profile(id):
                try manager.rename(profileID: id, to: name)
            case let .displaySetupGroup(id):
                try manager.renameDisplaySetupGroup(groupID: id, to: name)
            }
            document = manager.document
            saveDocument()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func applyProfileFromRow(_ profile: DisplayProfile) {
        guard confirmApplyIfNeeded(profile) else {
            return
        }
        Task {
            await apply(profile)
        }
    }

    private func confirmApplyIfNeeded(_ profile: DisplayProfile) -> Bool {
        let requiresConfirmation = profile.displaySetupFingerprint != currentFingerprint
            || profile.importedNeedsFirstApplyConfirmation
            || profile.isCommandEdited
        guard requiresConfirmation else {
            return true
        }

        let alert = NSAlert()
        alert.messageText = localization.status(
            "Apply \(profile.name)?",
            chinese: "应用 \(profile.name)？"
        )
        alert.informativeText = localization.status(
            "This configuration may belong to a different display setup or need extra care.",
            chinese: "这个配置可能属于其他显示器组合，或需要额外确认。"
        )
        alert.addButton(withTitle: localization.text(.applyConfiguration))
        alert.addButton(withTitle: localization.text(.cancel))
        return alert.runModal() == .alertFirstButtonReturn
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
            let availableProfileIDs = Set(document.profiles.map(\.id))
            selectedProfileIDs.formIntersection(availableProfileIDs)
            if selectedProfileIDs.isEmpty, let firstProfileID = document.profiles.first?.id {
                selectedProfileIDs = [firstProfileID]
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func loadSettings() {
        do {
            settings = try DisplayRecallStore.live().loadSettings().settings
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

    private func saveDocument() {
        do {
            try DisplayRecallStore.live().save(document)
            NotificationCenter.default.post(name: .displayRecallProfilesChanged, object: nil)
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

    private func refreshProfileState(initializesExpandedGroups: Bool = false) async {
        loadProfiles()
        loadSettings()
        await refreshCurrentFingerprint()
        if initializesExpandedGroups {
            initializeExpandedGroupsIfNeeded()
        } else {
            syncExpandedGroupsWithVisibleSections()
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
            createProfileSheet = CreateProfileSheetState(
                layout: layout,
                suggestedName: localization.defaultProfileName(existingNames: document.profiles.map(\.name)),
                makeAutomaticDefault: false
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
                makeAutomaticDefault: makeAutomaticDefault,
                displaySetupGroupLanguage: localization.preference
            )
            selectedProfileIDs = Set(document.profiles.last.map { [$0.id] } ?? [])
            currentFingerprint = layout.displaySetupFingerprint
            syncExpandedGroupsWithVisibleSections()
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
            await refreshProfileState()
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

    private func deleteProfile(_ profile: DisplayProfile) {
        let alert = NSAlert()
        alert.messageText = localization.status(
            "Delete “\(profile.name)”?",
            chinese: "删除“\(profile.name)”？"
        )
        alert.informativeText = localization.status(
            "Related automatic apply settings and shortcuts will also be removed.",
            chinese: "相关自动应用设置和快捷键也会移除。"
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
            NotificationCenter.default.post(name: .displayRecallProfilesChanged, object: nil)
            try store.save(SettingsStoreDocument(settings: result.settings))
            try ActivityLogRecorder(store: store).record(result.logEntry)
            statusMessage = localization.status("Deleted profile.", chinese: "已删除配置。")
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func deleteDisplaySetupGroup(_ group: DisplaySetupGroup) {
        let profilesInGroup = document.profiles.filter {
            $0.displaySetupFingerprint == group.fingerprint
        }
        let groupName = displayName(for: group)
        let alert = NSAlert()
        alert.messageText = localization.status(
            "Delete “\(groupName)”?",
            chinese: "删除“\(groupName)”？"
        )
        if profilesInGroup.isEmpty {
            alert.informativeText = localization.status(
                "This display setup group will be removed.",
                chinese: "这个显示器组合会被移除。"
            )
        } else {
            alert.informativeText = localization.status(
                "This will also delete \(profilesInGroup.count) configurations.",
                chinese: "这也会删除其中 \(profilesInGroup.count) 个配置。"
            )
        }
        alert.addButton(withTitle: localization.status("Delete", chinese: "删除"))
        alert.addButton(withTitle: localization.text(.cancel))
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        do {
            let store = try DisplayRecallStore.live()
            let settings = try store.loadSettings().settings
            let result = try DisplaySetupGroupDeletion.delete(
                groupID: group.id,
                profilesDocument: document,
                settings: settings
            )
            document = result.profilesDocument
            selectedProfileIDs = Set(result.nextSelectedProfileID.map { [$0] } ?? [])
            expandedGroupIDs.remove(group.id)
            try store.save(result.profilesDocument)
            NotificationCenter.default.post(name: .displayRecallProfilesChanged, object: nil)
            try store.save(SettingsStoreDocument(settings: result.settings))
            try ActivityLogRecorder(store: store).record(result.logEntry)
            statusMessage = localization.status("Deleted display setup group.", chinese: "已删除显示器组合。")
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func exportProfile(_ profile: DisplayProfile) {
        export(selection: .single(profile.id), suggestedName: profile.name)
    }

    private func presentExportSheet() {
        exportSheet = ProfileExportSheetState(
            initialSelectedProfileIDs: Set(document.profiles.map(\.id))
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
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func exportSelection(for selectedProfileIDs: Set<UUID>) -> ProfileExportSelection? {
        guard !selectedProfileIDs.isEmpty else {
            return nil
        }
        return .multiple(Array(selectedProfileIDs))
    }

    private func suggestedExportName(for selectedProfileIDs: Set<UUID>) -> String {
        if selectedProfileIDs == Set(document.profiles.map(\.id)) {
            return "Display Recall Profiles"
        }

        if selectedProfileIDs.count == 1,
           let profile = document.profiles.first(where: { selectedProfileIDs.contains($0.id) }) {
            return profile.name
        }

        return "Display Recall Selected Profiles"
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
            statusMessage = ""
        } catch {
            showImportFailureAlert(error)
        }
    }

    private func showImportFailureAlert(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = localization.status("Import failed", chinese: "导入失败")
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: localization.status("OK", chinese: "好"))
        alert.runModal()
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
        panel.nameFieldStringValue = "\(suggestedName).json"
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
                    .frame(minWidth: 220, idealWidth: 280, maxWidth: 320)

                    Divider()

                    activityDetail
                        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

struct AdjustableNumberField: NSViewRepresentable {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let isEnabled: Bool

    func makeNSView(context: Context) -> AdjustableNumberTextField {
        let textField = AdjustableNumberTextField()
        textField.delegate = context.coordinator
        textField.alignment = .right
        textField.bezelStyle = .roundedBezel
        textField.onStep = { delta in
            context.coordinator.step(delta: delta)
            textField.selectText(nil)
        }
        return textField
    }

    func updateNSView(_ nsView: AdjustableNumberTextField, context: Context) {
        context.coordinator.parent = self
        if nsView.integerValue != value {
            nsView.integerValue = value
        }
        nsView.isEnabled = isEnabled
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: AdjustableNumberField

        init(parent: AdjustableNumberField) {
            self.parent = parent
        }

        func step(delta: Int) {
            parent.value = min(max(parent.value + delta, parent.range.lowerBound), parent.range.upperBound)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else {
                return
            }
            parent.value = min(max(textField.integerValue, parent.range.lowerBound), parent.range.upperBound)
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                step(delta: 1)
                return true
            case #selector(NSResponder.moveDown(_:)):
                step(delta: -1)
                return true
            default:
                return false
            }
        }
    }
}

@MainActor
final class AdjustableNumberTextField: NSTextField {
    var onStep: ((Int) -> Void)?
    private var outsideClickMonitor: Any?

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            installOutsideClickMonitor()
            DispatchQueue.main.async { [weak self] in
                self?.selectText(nil)
            }
        }
        return result
    }

    override func resignFirstResponder() -> Bool {
        removeOutsideClickMonitor()
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126:
            onStep?(1)
        case 125:
            onStep?(-1)
        default:
            super.keyDown(with: event)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        guard window?.firstResponder == currentEditor() else {
            super.scrollWheel(with: event)
            return
        }

        if event.scrollingDeltaY > 0 {
            onStep?(1)
        } else if event.scrollingDeltaY < 0 {
            onStep?(-1)
        } else {
            super.scrollWheel(with: event)
        }
    }

    private func installOutsideClickMonitor() {
        guard outsideClickMonitor == nil else {
            return
        }

        outsideClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, event.window === self.window else {
                return event
            }

            let localPoint = self.convert(event.locationInWindow, from: nil)
            if !self.bounds.contains(localPoint) {
                self.window?.makeFirstResponder(nil)
            }
            return event
        }
    }

    private func removeOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var localization: LocalizationController
    @AppStorage(DockIconVisibilityPreference.userDefaultsKey)
    private var dockIconVisibilityRaw = DockIconVisibilityPreference.defaultValue.rawValue
    @State private var settings = AppSettings()
    @State private var statusMessage = ""

    var body: some View {
        Form {
            Section {
                Toggle(localization.text(.launchAtLogin), isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { newValue in
                        settings.launchAtLogin = newValue
                        setLaunchAtLogin(newValue)
                        saveSettings()
                    }
                ))
                .displayRecallSwitchControl()

                Picker(localization.text(.dockIconVisibility), selection: Binding(
                    get: { settings.dockIconVisibility },
                    set: { newValue in
                        settings.dockIconVisibility = newValue
                        dockIconVisibilityRaw = newValue.rawValue
                        DockIconController.apply(
                            preference: newValue,
                            isMainWindowVisible: MainWindowController.shared.isMainWindowVisible
                        )
                        saveSettings()
                    }
                )) {
                    ForEach(DockIconVisibilityPreference.allCases, id: \.self) { preference in
                        Text(localizedDockIconVisibility(preference)).tag(preference)
                    }
                }
                .pickerStyle(.segmented)

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

                HStack(alignment: .center, spacing: 8) {
                    Text(localization.text(.automaticApply))
                    Spacer(minLength: 16)
                    AdjustableNumberField(
                        value: Binding(
                            get: { settings.automaticApplyCountdownSeconds },
                            set: { newValue in
                                settings.automaticApplyCountdownSeconds = AutomaticApplyCountdownPolicy.normalized(newValue)
                                saveSettings()
                            }
                        ),
                        range: AutomaticApplyCountdownPolicy.allowedRange,
                        isEnabled: settings.automaticApplyEnabled
                    )
                    .frame(width: 56)
                    Text(localization.status("seconds", chinese: "秒"))
                        .foregroundStyle(.secondary)
                    Toggle("", isOn: Binding(
                        get: { settings.automaticApplyEnabled },
                        set: { settings.automaticApplyEnabled = $0; saveSettings() }
                    ))
                    .labelsHidden()
                    .displayRecallSwitchControl()
                }
                .frame(minHeight: 28, alignment: .center)
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
        }
    }

    private func loadSettings() {
        do {
            settings = try DisplayRecallStore.live().loadSettings().settings
            localization.preference = settings.language
            dockIconVisibilityRaw = settings.dockIconVisibility.rawValue
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

    private func localizedDockIconVisibility(_ preference: DockIconVisibilityPreference) -> String {
        switch preference {
        case .automatic:
            localization.text(.dockIconAutomatic)
        case .alwaysShow:
            localization.text(.dockIconAlwaysShow)
        case .alwaysHide:
            localization.text(.dockIconAlwaysHide)
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
}
