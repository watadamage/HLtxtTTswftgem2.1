import SwiftUI

struct OverlayView: View {
    @ObservedObject var model: OverlayModel

    private var colorScheme: ColorScheme? {
        switch model.appearance { case .system: nil; case .light: .light; case .dark: .dark }
    }

    var body: some View {
        ZStack {
            WindowBackdrop(usesGlass: model.usesGlass)
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
            VStack(alignment: .leading, spacing: 2) {
                Text("HLtxtTTswft2.0").font(.system(size: 18, weight: .bold, design: .rounded))
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
            TextEditor(text: $model.text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
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
