//
//  MacKeyWizardApp.swift
//  MacKeyWizard
//
//  Created by laurie byrne on 27/05/2025.
//  

import SwiftUI
import AppKit

@main
struct MacKeyWizardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(maxWidth: 500, minHeight: 50)
                .background(Color.clear)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Remove default menu items we don't need
            CommandGroup(replacing: .newItem) { }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var window: NSWindow?
    var globalMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupGlobalShortcut()
        setupWindow()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Key Wizard")
        }
    }
    
    private func setupWindow() {
        if let window = NSApplication.shared.windows.first {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask = [.borderless, .fullSizeContentView]
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.level = .floating
            window.hasShadow = false
            window.isOpaque = false
            window.contentMinSize = NSSize(width: 600, height: 50)
            window.contentMaxSize = NSSize(width: 600, height: 500)
            
            // Position window in the center of the screen
            if let screen = NSScreen.main {
                let screenRect = screen.visibleFrame
                let windowRect = window.frame
                let newOrigin = NSPoint(
                    x: screenRect.midX - windowRect.width / 2,
                    y: screenRect.maxY - windowRect.height - 100
                )
                window.setFrameOrigin(newOrigin)
            }
        }
    }
    
    private func setupGlobalShortcut() {
        // Monitor for Command + Option + K
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .option]) && event.charactersIgnoringModifiers == "k" {
                self?.toggleWindow()
            }
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
}
