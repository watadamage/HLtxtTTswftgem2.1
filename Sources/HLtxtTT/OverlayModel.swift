import AppKit
import ApplicationServices
import Combine

@MainActor
final class OverlayModel: ObservableObject {
    @Published var text = ""
    @Published var countdownSeconds = 3.0
    @Published var delayMilliseconds = 12.0
    @Published var windowOpacity = 0.94 { didSet { applyOpacity() } }
    @Published var appearance: AppearanceChoice = .system { didSet { applyAppearance() } }
    @Published var usesGlass = true
    @Published var continueAfterFocusChange = false
    @Published private(set) var phase: Phase = .ready
    @Published private(set) var status = "Ready — paste or drag text into the field."
    @Published private(set) var inputHistory: [String]

    enum AppearanceChoice: String, CaseIterable, Identifiable {
        case system = "System", light = "Light", dark = "Dark"
        var id: String { rawValue }
        var nsAppearance: NSAppearance? {
            switch self { case .system: nil; case .light: NSAppearance(named: .aqua); case .dark: NSAppearance(named: .darkAqua) }
        }
    }

    enum Phase: Equatable { case ready, countingDown(Int), typing, paused, cancelled }

    private weak var window: NSWindow?
    private var typingTask: Task<Void, Never>?

    init() {
        inputHistory = UserDefaults.standard.stringArray(forKey: "HLtxtTTswft2.inputHistory") ?? []
    }

    func attach(window: NSWindow) {
        self.window = window
        
        // ==========================================
        // PROGRAMMATIC FIXES FOR THE UNCLICKABLE/UNRESIZABLE BUTTONS
        // ==========================================
        window.styleMask.insert([.titled, .closable, .miniaturizable, .resizable])
        window.ignoresMouseEvents = false
        window.contentView?.wantsLayer = true
        
        applyOpacity()
        applyAppearance()
    }

    var canStart: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isRunning }
    var isRunning: Bool { if case .ready = phase { false } else { true } }
    var isPaused: Bool { if case .paused = phase { true } else { false } }

    func pasteClipboard() {
        guard !isRunning else { return }
        guard let value = NSPasteboard.general.string(forType: .string), !value.isEmpty else {
            status = "Clipboard does not contain plain text."
            return
        }
        text = value
        status = "Loaded \(value.count) characters from the clipboard."
    }

    func selectHistory(_ value: String) {
        guard !isRunning else { return }
        text = value
        status = "Loaded an item from input history."
    }

    func historyTitle(for value: String) -> String {
        let oneLine = value.replacingOccurrences(of: "\n", with: " ↵ ")
        return oneLine.count > 42 ? String(oneLine.prefix(39)) + "…" : oneLine
    }

    func start() {
        guard canStart else { return }
        guard AXIsProcessTrusted() else {
            requestAccessibilityAccess()
            status = "Accessibility permission is required to type into other apps."
            return
        }

        let payload = text
        let countdown = Int(countdownSeconds)
        let keyDelay = UInt64(delayMilliseconds * 1_000_000)
        let allowsFocusChange = continueAfterFocusChange
        recordHistory(payload)
        typingTask?.cancel()
        typingTask = Task { [weak self] in
            await self?.run(payload: payload, countdown: countdown, keyDelay: keyDelay, allowsFocusChange: allowsFocusChange)
        }
    }

    func togglePause() {
        guard isRunning else { return }
        if isPaused { phase = .typing; status = "Typing…" }
        else { phase = .paused; status = "Paused. Resume when the cursor is ready." }
    }

    func cancel() {
        typingTask?.cancel()
        typingTask = nil
        phase = .ready
        status = "Cancelled."
    }

    private func run(payload: String, countdown: Int, keyDelay: UInt64, allowsFocusChange: Bool) async {
        for seconds in stride(from: countdown, through: 1, by: -1) {
            guard !Task.isCancelled else { finishCancelled(); return }
            phase = .countingDown(seconds)
            status = "Place the cursor in the destination — typing in \(seconds)…"
            try? await Task.sleep(for: .seconds(1))
        }
        guard !Task.isCancelled else { finishCancelled(); return }
        guard let target = NSWorkspace.shared.frontmostApplication,
              target.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            phase = .ready; status = "No external destination app was selected."; return
        }

        let targetPID = target.processIdentifier
        phase = .typing
        status = "Typing into \(target.localizedName ?? "destination")…"
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            phase = .ready; status = "Could not create a keyboard event source."; return
        }

        for character in payload {
            while isPaused {
                guard !Task.isCancelled else { finishCancelled(); return }
                try? await Task.sleep(for: .milliseconds(80))
            }
            guard !Task.isCancelled else { finishCancelled(); return }
            if !allowsFocusChange,
               NSWorkspace.shared.frontmostApplication?.processIdentifier != targetPID {
                phase = .paused
                status = "Focus changed; paused to protect your input."
                continue
            }
            post(character, source: source)
            try? await Task.sleep(nanoseconds: keyDelay)
        }
        phase = .ready
        status = "Finished typing \(payload.count) characters."
        typingTask = nil
    }

    private func finishCancelled() { phase = .ready; status = "Cancelled."; typingTask = nil }

    private func recordHistory(_ value: String) {
        inputHistory.removeAll { $0 == value }
        inputHistory.insert(value, at: 0)
        inputHistory = Array(inputHistory.prefix(3))
        UserDefaults.standard.set(inputHistory, forKey: "HLtxtTTswft2.inputHistory")
    }

    private func post(_ character: Character, source: CGEventSource) {
        if let stroke = ANSIKeyStroke(character) {
            if stroke.requiresShift { postKey(0x38, isDown: true, source: source) }
            postKey(stroke.keyCode, isDown: true, source: source)
            postKey(stroke.keyCode, isDown: false, source: source)
            if stroke.requiresShift { postKey(0x38, isDown: false, source: source) }
            return
        }

        let units = Array(String(character).utf16)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return }
        units.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            down.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: base)
            up.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: base)
        }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func postKey(_ keyCode: CGKeyCode, isDown: Bool, source: CGEventSource) {
        CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown)?.post(tap: .cghidEventTap)
    }

    private func applyOpacity() { window?.alphaValue = CGFloat(windowOpacity) }
    private func applyAppearance() { window?.appearance = appearance.nsAppearance }

    private func requestAccessibilityAccess() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }
}

private struct ANSIKeyStroke {
    let keyCode: CGKeyCode
    let requiresShift: Bool

    init?(_ character: Character) {
        let values: [Character: (CGKeyCode, Bool)] = [
            "a": (0x00, false), "b": (0x0B, false), "c": (0x08, false), "d": (0x02, false),
            "e": (0x0E, false), "f": (0x03, false), "g": (0x05, false), "h": (0x04, false),
            "i": (0x22, false), "j": (0x26, false), "k": (0x28, false), "l": (0x25, false),
            "m": (0x2E, false), "n": (0x2D, false), "o": (0x1F, false), "p": (0x23, false),
            "q": (0x0C, false), "r": (0x0F, false), "s": (0x01, false), "t": (0x11, false),
            "u": (0x20, false), "v": (0x09, false), "w": (0x0D, false), "x": (0x07, false),
            "y": (0x10, false), "z": (0x06, false),
            "0": (0x1D, false), "1": (0x12, false), "2": (0x13, false), "3": (0x14, false),
            "4": (0x15, false), "5": (0x17, false), "6": (0x16, false), "7": (0x18, false),
            "8": (0x19, false), "9": (0x1A, false), "-": (0x1B, false), "=": (0x18, false),
            "[": (0x21, false), "]": (0x1E, false), "\\": (0x2A, false), ";": (0x29, false),
            "'": (0x27, false), "`": (0x32, false), ",": (0x2B, false), ".": (0x2F, false),
            "/": (0x2C, false), " ": (0x31, false), "\t": (0x30, false), "\n": (0x24, false),
            "~": (0x32, true), "!": (0x12, true), "@": (0x13, true), "#": (0x14, true),
            "$": (0x15, true), "%": (0x17, true), "^": (0x16, true), "&": (0x18, true),
            "*": (0x19, true), "(": (0x1A, true), ")": (0x1D, true), "_": (0x1B, true),
            "+": (0x18, true), "{": (0x21, true), "}": (0x1E, true), "|": (0x2A, true),
            ":": (0x29, true), "\"": (0x27, true), "<": (0x2B, true), ">": (0x2F, true),
            "?": (0x2C, true)
        ]
        if let lower = character.lowercased().first, let value = values[lower] {
            keyCode = value.0
            requiresShift = value.1 || character.isUppercase
        } else {
            return nil
        }
    }
}
