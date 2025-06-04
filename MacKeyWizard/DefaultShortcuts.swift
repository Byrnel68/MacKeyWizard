import Foundation

struct DefaultShortcuts {
    static let exampleShortcuts = """
    {
        "Name": "General",
        "Shortcuts": [
            {
                "Description": "Copy",
                "Keys": ["COMMAND", "C"]
            },
            {
                "Description": "Paste",
                "Keys": ["COMMAND", "V"]
            },
            {
                "Description": "Cut",
                "Keys": ["COMMAND", "X"]
            },
            {
                "Description": "Select All",
                "Keys": ["COMMAND", "A"]
            },
            {
                "Description": "Undo",
                "Keys": ["COMMAND", "Z"]
            },
            {
                "Description": "Redo",
                "Keys": ["COMMAND", "SHIFT", "Z"]
            },
            {
                "Description": "Screenshot Entire Screen",
                "Keys": ["COMMAND", "SHIFT", "3"]
            },
            {
                "Description": "Screenshot Selected Area",
                "Keys": ["COMMAND", "SHIFT", "4"]
            },
            {
                "Description": "Screenshot Window",
                "Keys": ["COMMAND", "SHIFT", "4", "SPACE"]
            }
        ]
    }
    """
    
    static func createDefaultShortcutsIfNeeded(in directory: URL) {
        let fileManager = FileManager.default
        let defaultFileURL = directory.appendingPathComponent("General.json")
        
        // Always create/update the default shortcuts file
        do {
            try exampleShortcuts.write(to: defaultFileURL, atomically: true, encoding: .utf8)
            print("Created/Updated default shortcuts file")
        } catch {
            print("Error creating default shortcuts file: \(error)")
        }
    }
} 