import Foundation
import AppKit

class CursorPaster {
    private static let pasteCompletionDelay: TimeInterval = 0.3
    
    static func pasteAtCursor(_ text: String) {
        guard AXIsProcessTrusted() else {
            return
        }
        
        let pasteboard = NSPasteboard.general
        
        var savedContents: [(NSPasteboard.PasteboardType, Data)] = []
        let currentItems = pasteboard.pasteboardItems ?? []
        
        for item in currentItems {
            for type in item.types {
                if let data = item.data(forType: type) {
                    savedContents.append((type, data))
                }
            }
        }
        
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        if UserDefaults.standard.bool(forKey: "UseAppleScriptPaste") {
            _ = pasteUsingAppleScript()
        } else {
            pasteUsingCommandV()
        }
        
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + pasteCompletionDelay) {
            if !savedContents.isEmpty {
                pasteboard.clearContents()
                for (type, data) in savedContents {
                    pasteboard.setData(data, forType: type)
                }
            }
        }
    }
    
    private static func pasteUsingAppleScript() -> Bool {
        let script = """
        tell application "System Events"
            keystroke "v" using command down
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            _ = scriptObject.executeAndReturnError(&error)
            return error == nil
        }
        return false
    }
    
    private static func pasteUsingCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
        
        cmdDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        
        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }
}
