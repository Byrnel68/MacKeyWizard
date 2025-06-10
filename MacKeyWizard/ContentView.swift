//
//  ContentView.swift
//  MacKeyWizard
//
//  Created by laurie byrne on 27/05/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var shortcutManager = ShortcutManager()
    @StateObject private var accessibilityManager = AccessibilityManager()
    @State private var searchText = ""
    @State private var isExpanded = false
    @State private var previousApp: NSRunningApplication?
    
    var filteredShortcuts: [Shortcut] {
        shortcutManager.searchShortcuts(query: searchText)
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if !accessibilityManager.isAccessibilityEnabled {
                    VStack(spacing: 16) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 48))
                            .foregroundColor(.purple)
                        
                        Text("Accessibility Permission Required")
                            .font(.headline)
                        
                        Text("MacKeyWizard needs accessibility permission to execute shortcuts globally.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("Grant Permission") {
                            accessibilityManager.requestAccessibilityPermission()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Open System Preferences") {
                            accessibilityManager.openSystemPreferences()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.windowBackgroundColor))
                } else {
                    // Search bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.purple)
                            .font(.system(size: 18, weight: .medium))
                        TextField("Search shortcuts...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 16))
                            .onAppear {
                                // Store the previous app when the search field appears
                                previousApp = NSWorkspace.shared.frontmostApplication
                            }
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(height: 50)
                    .background(Color(NSColor.windowBackgroundColor))
                    
                    // Results view
                    if !searchText.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredShortcuts) { shortcut in
                                    ShortcutRow(shortcut: shortcut)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color(NSColor.windowBackgroundColor))
                                        .onTapGesture {
                                            // Hide our window first
                                            if let window = NSApplication.shared.windows.first {
                                                window.orderOut(nil)
                                            }
                                            
                                            // Small delay to ensure window is hidden
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                // Execute the shortcut
                                                shortcutManager.executeShortcut(shortcut, previousApp: previousApp)
                                            }
                                        }
                                    
                                    if shortcut.id != filteredShortcuts.last?.id {
                                        Divider()
                                            .padding(.leading, 16)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 400)
                        .background(Color(NSColor.windowBackgroundColor))
                    }
                }
            }
            .frame(width: geometry.size.width)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(10)
            .shadow(radius: 10)
            .onAppear {
                // Store the previous app when the view appears
                previousApp = NSWorkspace.shared.frontmostApplication
            }
        }
    }
}

struct ShortcutRow: View {
    let shortcut: Shortcut
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(shortcut.description)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    ForEach(shortcut.keys, id: \.self) { key in
                        Text(key)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.system(size: 12))
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    ContentView()
}
