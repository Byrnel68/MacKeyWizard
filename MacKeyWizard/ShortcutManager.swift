import Foundation
import Carbon
import AppKit

struct Shortcut: Codable, Identifiable {
    let id = UUID()
    let description: String
    let keys: [String]
    
    enum CodingKeys: String, CodingKey {
        case description = "Description"
        case keys = "Keys"
    }
}

struct ShortcutGroup: Codable {
    let name: String
    let shortcuts: [Shortcut]
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case shortcuts = "Shortcuts"
    }
}

class ShortcutManager: ObservableObject {
    @Published var shortcutGroups: [ShortcutGroup] = []
    private let fileManager = FileManager.default
    private let shortcutsDirectory: URL
    private var localMonitor: Any?
    private var globalMonitor: Any?
    
    init() {
        // Get the Documents directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        shortcutsDirectory = documentsPath.appendingPathComponent("Key Wizard")
        
        print("Shortcuts directory: \(shortcutsDirectory.path)")
        
        // Create the shortcuts directory if it doesn't exist
        try? fileManager.createDirectory(at: shortcutsDirectory, withIntermediateDirectories: true)
        
        // Copy bundled .json files if needed
        copyBundledShortcutsIfNeeded()
        
        // Load initial shortcuts
        loadShortcuts()
        
        // Start watching for changes
        setupFileWatcher()
        
        // Setup key monitoring
        setupKeyMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func setupKeyMonitoring() {
        // Local monitor (when app is active)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleKeyEvent(event: event) ?? event
        }
        
        // Global monitor (system-wide)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handleKeyEvent(event: event)
        }
    }
    
    private func handleKeyEvent(event: NSEvent) -> NSEvent? {
        // Handle our app's global shortcut (Command + Option + K)
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        
        if modifiers == [.command, .option] && key == "k" {
            toggleWindow()
            return nil // Consume the event
        }
        
        return event
    }
    
    private func stopMonitoring() {
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
    }
    
    private func toggleWindow() {
        if let window = NSApplication.shared.windows.first {
            if window.isVisible {
                window.orderOut(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    private func loadShortcuts() {
        do {
            print("Looking for shortcuts in: \(shortcutsDirectory.path)")
            let fileURLs = try fileManager.contentsOfDirectory(at: shortcutsDirectory, includingPropertiesForKeys: nil)
            print("Found files: \(fileURLs.map { $0.lastPathComponent })")
            let jsonFiles = fileURLs.filter { $0.pathExtension.lowercased() == "json" }
            print("JSON files to load: \(jsonFiles.map { $0.lastPathComponent })")
            shortcutGroups = try jsonFiles.compactMap { url in
                print("Attempting to load: \(url.lastPathComponent)")
                let data = try Data(contentsOf: url)
                let group = try JSONDecoder().decode(ShortcutGroup.self, from: data)
                print("Loaded group: \(group.name) with \(group.shortcuts.count) shortcuts")
                return group
            }
            print("Total shortcut groups loaded: \(shortcutGroups.count)")
            let allShortcuts = shortcutGroups.flatMap { $0.shortcuts }
            print("Total shortcuts loaded: \(allShortcuts.count)")
        } catch {
            print("Error loading shortcuts: \(error)")
        }
    }
    
    private func setupFileWatcher() {
        // Watch for changes in the shortcuts directory
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: open(shortcutsDirectory.path, O_EVTONLY),
            eventMask: .write,
            queue: .main
        )
        
        source.setEventHandler { [weak self] in
            print("Shortcuts directory changed, reloading...")
            self?.loadShortcuts()
        }
        
        source.setCancelHandler {
            close(source.handle)
        }
        
        source.resume()
    }
    
    func searchShortcuts(query: String) -> [Shortcut] {
        guard !query.isEmpty else { return [] }
        
        let results = shortcutGroups.flatMap { group in
            group.shortcuts.filter { shortcut in
                shortcut.description.localizedCaseInsensitiveContains(query)
            }
        }
        
        print("Search for '\(query)' found \(results.count) results")
        print("Search results: \(results.map { $0.description })")
        return results
    }
    
    func executeShortcut(_ shortcut: Shortcut, previousApp: NSRunningApplication? = nil) {
        guard AXIsProcessTrusted() else {
            print("Accessibility permission not granted")
            return
        }
        guard let ourWindow = NSApplication.shared.windows.first else { return }
        ourWindow.orderOut(nil)
        let appToActivate = previousApp ?? NSWorkspace.shared.frontmostApplication
        if let appToActivate = appToActivate {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                appToActivate.activate(options: .activateIgnoringOtherApps)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Hybrid: Use screencapture for screenshot shortcuts
                    let keys = shortcut.keys
                    if keys == ["COMMAND", "SHIFT", "3"] {
                        self.runScreencapture(args: ["~/Desktop/Screen.png"])
                        return
                    } else if keys == ["COMMAND", "SHIFT", "4"] {
                        self.runScreencapture(args: ["-i", "~/Desktop/Screen.png"])
                        return
                    } else if keys == ["COMMAND", "SHIFT", "4", "SPACE"] {
                        self.runScreencapture(args: ["-iW", "~/Desktop/Screen.png"])
                        return
                    } else if keys == ["COMMAND", "SHIFT", "5"] {
                        self.runScreenshotUI()
                        return
                    } else if keys == ["COMMAND", "SHIFT", "6"] {
                        self.runScreencapture(args: ["-T", "0", "-c", "-D", "2"])
                        return
                    }
                    // Use AppleScript for common shortcuts
                    if let (keystroke, modifiers) = self.appleScriptShortcut(for: keys) {
                        self.runAppleScriptKeystroke(keystroke: keystroke, modifiers: modifiers)
                        return
                    }
                    // Fallback: Use CGEvent for all other shortcuts
                    var modifiers: [CGKeyCode] = []
                    var nonModifiers: [CGKeyCode] = []
                    for key in shortcut.keys {
                        switch key {
                        case "COMMAND": modifiers.append(0x37)
                        case "SHIFT": modifiers.append(0x38)
                        case "OPTION": modifiers.append(0x3A)
                        case "CONTROL": modifiers.append(0x3B)
                        default:
                            if let keyCode = self.getKeyCode(for: key) {
                                nonModifiers.append(keyCode)
                            }
                        }
                    }
                    let source = CGEventSource(stateID: .hidSystemState)
                    for mod in modifiers {
                        let down = CGEvent(keyboardEventSource: source, virtualKey: mod, keyDown: true)
                        down?.post(tap: .cghidEventTap)
                    }
                    for keyCode in nonModifiers {
                        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
                        down?.post(tap: .cghidEventTap)
                        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
                        up?.post(tap: .cghidEventTap)
                    }
                    for mod in modifiers.reversed() {
                        let up = CGEvent(keyboardEventSource: source, virtualKey: mod, keyDown: false)
                        up?.post(tap: .cghidEventTap)
                    }
                }
            }
        }
    }
    
    private func runScreencapture(args: [String]) {
        let process = Process()
        process.launchPath = "/usr/sbin/screencapture"
        process.arguments = args
        process.launch()
    }
    
    private func runScreenshotUI() {
        // Open the screenshot UI (⌘⇧5)
        let script = "tell application \"System Events\" to key code 60 using {command down, shift down}"
        let appleScript = NSAppleScript(source: script)
        appleScript?.executeAndReturnError(nil)
    }
    
    private func getKeyCode(for key: String) -> CGKeyCode? {
        switch key {
        case "SPACE": return 0x31
        case "A": return 0x00
        case "B": return 0x0B
        case "C": return 0x08
        case "D": return 0x02
        case "E": return 0x0E
        case "F": return 0x03
        case "G": return 0x05
        case "H": return 0x04
        case "I": return 0x22
        case "J": return 0x26
        case "K": return 0x28
        case "L": return 0x25
        case "M": return 0x2E
        case "N": return 0x2D
        case "O": return 0x1F
        case "P": return 0x23
        case "Q": return 0x0C
        case "R": return 0x0F
        case "S": return 0x01
        case "T": return 0x11
        case "U": return 0x20
        case "V": return 0x09
        case "W": return 0x0D
        case "X": return 0x07
        case "Y": return 0x10
        case "Z": return 0x06
        case "1": return 0x12
        case "2": return 0x13
        case "3": return 0x14
        case "4": return 0x15
        case "5": return 0x17
        case "6": return 0x16
        case "7": return 0x1A
        case "8": return 0x1C
        case "9": return 0x19
        case "0": return 0x1D
        case "F4": return 0x76
        default: return nil
        }
    }
    
    // Map common shortcuts to AppleScript keystroke and modifiers
    private func appleScriptShortcut(for keys: [String]) -> (String, [String])? {
        // Only support single non-modifier key
        let mods = keys.filter { ["COMMAND", "SHIFT", "OPTION", "CONTROL"].contains($0) }
        let nonMods = keys.filter { !["COMMAND", "SHIFT", "OPTION", "CONTROL"].contains($0) }
        guard nonMods.count == 1, let key = nonMods.first else { return nil }
        var modifiers: [String] = []
        if mods.contains("COMMAND") { modifiers.append("command down") }
        if mods.contains("SHIFT") { modifiers.append("shift down") }
        if mods.contains("OPTION") { modifiers.append("option down") }
        if mods.contains("CONTROL") { modifiers.append("control down") }
        // Supported keys
        let supported: Set<String> = [
            "A", "C", "V", "X", "Z", "F", "G", "J", "B", "I", "U", "Y", "P", "S", "O", "N", "M", "L", "D", "E", "W", "Q", "T", "K", "R", "H", "J", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", ",", ".", ";", "'", "/", "\\", "[", "]", "-", "=", "`"
        ]
        if supported.contains(key) {
            return (key.lowercased(), modifiers)
        }
        return nil
    }

    private func runAppleScriptKeystroke(keystroke: String, modifiers: [String]) {
        let modsString = modifiers.isEmpty ? "" : " using {" + modifiers.joined(separator: ", ") + "}"
        let script = "tell application \"System Events\" to keystroke \"\(keystroke)\"\(modsString)"
        let appleScript = NSAppleScript(source: script)
        appleScript?.executeAndReturnError(nil)
    }
    
    private func copyBundledShortcutsIfNeeded() {
        let bundle = Bundle.main
        guard let resourceURLs = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) else { return }
        for url in resourceURLs {
            let destURL = shortcutsDirectory.appendingPathComponent(url.lastPathComponent)
            if !fileManager.fileExists(atPath: destURL.path) {
                do {
                    try fileManager.copyItem(at: url, to: destURL)
                    print("Copied \(url.lastPathComponent) to shortcuts directory.")
                } catch {
                    print("Error copying \(url.lastPathComponent): \(error)")
                }
            }
        }
    }
} 