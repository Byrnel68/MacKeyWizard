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
        
        // Create default shortcuts if none exist
        DefaultShortcuts.createDefaultShortcutsIfNeeded(in: shortcutsDirectory)
        
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
            let fileURLs = try fileManager.contentsOfDirectory(at: shortcutsDirectory, includingPropertiesForKeys: nil)
            print("Found \(fileURLs.count) shortcut files")
            
            shortcutGroups = try fileURLs.compactMap { url in
                print("Loading shortcuts from: \(url.lastPathComponent)")
                let data = try Data(contentsOf: url)
                let group = try JSONDecoder().decode(ShortcutGroup.self, from: data)
                print("Loaded group: \(group.name) with \(group.shortcuts.count) shortcuts")
                print("Shortcuts in group: \(group.shortcuts.map { $0.description })")
                return group
            }
            
            print("Total shortcut groups: \(shortcutGroups.count)")
            let allShortcuts = shortcutGroups.flatMap { $0.shortcuts }
            print("Total shortcuts: \(allShortcuts.count)")
            print("All shortcut descriptions: \(allShortcuts.map { $0.description })")
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
    
    func executeShortcut(_ shortcut: Shortcut) {
        // Check if we have accessibility permission
        guard AXIsProcessTrusted() else {
            print("Accessibility permission not granted")
            return
        }
        
        // Get the window that was active before our app
        let workspace = NSWorkspace.shared
        let activeApp = workspace.frontmostApplication
        
        // Activate the previous application
        if let previousApp = activeApp {
            previousApp.activate(options: .activateIgnoringOtherApps)
            
            // Small delay to ensure the app is activated
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // Create the event source
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Convert string keys to CGKeyCode and flags
        var flags: CGEventFlags = []
        var keyCodes: [CGKeyCode] = []
        
        for key in shortcut.keys {
            switch key {
            case "COMMAND":
                flags.insert(.maskCommand)
            case "SHIFT":
                flags.insert(.maskShift)
            case "OPTION":
                flags.insert(.maskAlternate)
            case "CONTROL":
                flags.insert(.maskControl)
            default:
                if let keyCode = getKeyCode(for: key) {
                    keyCodes.append(keyCode)
                }
            }
        }
        
        // Send the key events
        for keyCode in keyCodes {
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
            keyDown?.flags = flags
            keyDown?.post(tap: .cghidEventTap)
            
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
            keyUp?.flags = flags
            keyUp?.post(tap: .cghidEventTap)
        }
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
        default: return nil
        }
    }
} 