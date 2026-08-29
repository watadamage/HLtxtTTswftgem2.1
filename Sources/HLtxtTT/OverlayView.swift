import SwiftUI

struct OverlayView: View {
    @ObservedObject var model: OverlayModel

    private var colorScheme: ColorScheme? {
        switch model.appearance { case .system: nil; case .light: .light; case .dark: .dark }
    }

    var body: some View {
        ZStack {
            WindowBackdrop(usesGlass: model.usesGlass)
            DraggableWindowBackground()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 14) {
                header
                input
                settings
                status
                controls
                help
            }
            .padding(18)
        }
        .frame(minWidth: 380, idealWidth: 440, minHeight: 570, idealHeight: 650)
        .preferredColorScheme(colorScheme)
    }

    private var header: some View {
        HStack {
            WindowDragHandle()
                .frame(width: 28, height: 28)
                .accessibilityLabel("Drag to move window")
            VStack(alignment: .leading, spacing: 2) {
                Text("HLtxtTTswft2.2").font(.system(size: 18, weight: .bold, design: .rounded))
                Text("On-screen accessibility input utility").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Appearance", selection: $model.appearance) {
                ForEach(OverlayModel.AppearanceChoice.allCases) { Text($0.rawValue).tag($0) }
            }.labelsHidden().frame(width: 106)
        }
    }

    private var input: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Text to type").font(.headline)
                Spacer()
                Button("Paste Clipboard", action: model.pasteClipboard).controlSize(.small).disabled(model.isRunning)
                Button("Clear", role: .destructive, action: model.clearText)
                    .controlSize(.small)
                    .disabled(model.isRunning || model.text.isEmpty)
                Menu {
                    if model.inputHistory.isEmpty {
                        Text("No previous inputs")
                    } else {
                        ForEach(model.inputHistory, id: \.self) { entry in
                            Button(model.historyTitle(for: entry)) { model.selectHistory(entry) }
                        }
                    }
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .controlSize(.small)
                .disabled(model.isRunning)
                .accessibilityLabel("Last three inputs")
            }
            SelectableTextEditor(text: $model.text, selectionRequest: model.inputSelectionRequest)
                .padding(7)
                .background(.primary.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.primary.opacity(0.14)))
                .frame(height: 125)
                .disabled(model.isRunning)
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 9) {
            Toggle("Keep typing if focus changes", isOn: $model.continueAfterFocusChange)
            Toggle("Use translucent glass", isOn: $model.usesGlass)
            slider(label: "Execute input delay", value: $model.countdownSeconds, range: 2...10, step: 1, valueText: "\(Int(model.countdownSeconds)) s")
            slider(label: "Key delay", value: $model.delayMilliseconds, range: 1...200, step: 1, valueText: "\(Int(model.delayMilliseconds)) ms")
            slider(label: "Window opacity", value: $model.windowOpacity, range: 0.25...1, step: 0.01, valueText: "\(Int(model.windowOpacity * 100))%")
        }
        .font(.subheadline)
    }

    private func slider(label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, valueText: String) -> some View {
        VStack(spacing: 3) {
            HStack { Text(label); Spacer(); Text(valueText).foregroundStyle(.secondary).monospacedDigit() }
            Slider(value: value, in: range, step: step)
        }
    }

    private var status: some View {
        Text(model.status)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(model.isRunning ? .orange : .secondary)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .center)
            .padding(.horizontal, 8)
            .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("Status: \(model.status)")
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Button(model.isRunning ? "Typing…" : "Execute Input (\(Int(model.countdownSeconds)) s delay)", action: model.start)
                .buttonStyle(.borderedProminent).tint(.green).frame(maxWidth: .infinity).disabled(!model.canStart)
            HStack {
                Button(model.isPaused ? "Resume" : "Pause", action: model.togglePause).frame(maxWidth: .infinity).disabled(!model.isRunning)
                Button("Cancel", role: .destructive, action: model.cancel).frame(maxWidth: .infinity).disabled(!model.isRunning)
            }
        }
    }

    private var help: some View {
        DisclosureGroup("Help & instructions") {
            VStack(alignment: .leading, spacing: 5) {
                Text("1. Copy text from any app, then choose Paste Clipboard or drag it into the text field.")
                Text("2. Set the execute delay (2–10 seconds), then select Execute Input.")
                Text("3. During the countdown, click the destination field. The app types each character there.")
                Text("4. Use History to restore any of your last three executed inputs. Pause or Cancel stops an active run.")
                Text("Accessibility permission is required: System Settings → Privacy & Security → Accessibility.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }
        .font(.subheadline.weight(.medium))
    }
}

/// A narrow native drag region moves the status-level window without making
/// the document editor or controls behave like a draggable background.
struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragHandleView { DragHandleView() }
    func updateNSView(_ view: DragHandleView, context: Context) {}

    final class DragHandleView: NSView {
        override var acceptsFirstResponder: Bool { false }

        override func draw(_ dirtyRect: NSRect) {
            NSColor.secondaryLabelColor.withAlphaComponent(0.45).setFill()
            let dotSize: CGFloat = 3
            let spacing: CGFloat = 5
            let startX = (bounds.width - (dotSize * 2 + spacing)) / 2
            let startY = (bounds.height - (dotSize * 3 + spacing * 2)) / 2
            for row in 0..<3 {
                for column in 0..<2 {
                    let rect = NSRect(
                        x: startX + CGFloat(column) * (dotSize + spacing),
                        y: startY + CGFloat(row) * (dotSize + spacing),
                        width: dotSize,
                        height: dotSize
                    )
                    NSBezierPath(ovalIn: rect).fill()
                }
            }
        }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }
    }
}

struct DraggableWindowBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> BackgroundDragView { BackgroundDragView() }
    func updateNSView(_ view: BackgroundDragView, context: Context) {}

    final class BackgroundDragView: NSView {
        override var acceptsFirstResponder: Bool { false }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }
    }
}

/// An AppKit text editor keeps macOS 14 compatibility while allowing pasted
/// and restored values to be selected programmatically.
struct SelectableTextEditor: NSViewRepresentable {
    @Binding var text: String
    let selectionRequest: UUID

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = EditableTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.isEditable = true
        textView.isSelectable = true
        textView.isFieldEditor = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.frame = NSRect(origin: .zero, size: NSSize(width: 1, height: 1))
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: .greatestFiniteMagnitude
        )
        textView.textContainerInset = NSSize(width: 3, height: 3)
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        if textView.string != text {
            textView.string = text
        }
        guard context.coordinator.lastSelectionRequest != selectionRequest else { return }
        context.coordinator.lastSelectionRequest = selectionRequest
        textView.setSelectedRange(NSRange(location: 0, length: (text as NSString).length))
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SelectableTextEditor
        var lastSelectionRequest: UUID?

        init(parent: SelectableTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }

    final class EditableTextView: NSTextView {
        override var acceptsFirstResponder: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.makeKey()
            window?.makeFirstResponder(self)
            super.mouseDown(with: event)
        }
    }
}

struct WindowBackdrop: NSViewRepresentable {
    let usesGlass: Bool

    func makeNSView(context: Context) -> NSVisualEffectView { makeView() }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.state = usesGlass ? .active : .inactive
        view.material = usesGlass ? .hudWindow : .windowBackground
        view.blendingMode = .behindWindow
    }
    private func makeView() -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = usesGlass ? .hudWindow : .windowBackground
        view.state = usesGlass ? .active : .inactive
        return view
    }
}
