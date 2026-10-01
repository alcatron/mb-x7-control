import SwiftUI

struct SectionCard<Content:View>: View {
    let title:String; @ViewBuilder var content:Content
    init(_ title:String,@ViewBuilder content:()->Content){self.title=title;self.content=content()}
    var body:some View { GroupBox { VStack(alignment:.leading,spacing:14){content}.frame(maxWidth:.infinity,alignment:.leading).padding(6) } label: { Text(title).font(.headline) } }
}
struct LabeledSlider:View {
    let title:String; @Binding var value:Double; let range:ClosedRange<Double>; var suffix="%"; var step:Double?=nil; var defaultValue:Double?=nil; let action:()->Void
    var body:some View {
        HStack {
            Text(title).frame(width:120,alignment:.leading)
            Slider(value:$value,in:range,step:step ?? (range.upperBound-range.lowerBound)/100,onEditingChanged:{if !$0{action()}})
            Text(display).monospacedDigit().frame(width:70,alignment:.trailing)
            if let defaultValue {
                Button {
                    value = defaultValue
                    action()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .help("Restore Creative default")
                .accessibilityLabel("Restore \(title) default")
            }
        }
    }
    var display:String { suffix=="%" ? "\(Int((value*100).rounded()))%" : "\(value.formatted(.number.precision(.fractionLength(step == 1 ? 0:1)))) \(suffix)" }
}
struct UnsupportedRow:View { let title:String; let reason:String; var body:some View { HStack{Image(systemName:"exclamationmark.triangle").foregroundStyle(.secondary); VStack(alignment:.leading){Text(title);Text(reason).font(.caption).foregroundStyle(.secondary)}} } }

struct SafetyWarning: View {
    let text: String

    var body: some View {
        Label {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .font(.callout.weight(.medium))
        .foregroundStyle(.red)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel("Warning: \(text)")
    }
}

private struct AudioDeviceChoice: Identifiable {
    let id: UInt32
    let uid: String
    let name: String
    let isDefault: Bool
}

struct AudioDeviceSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var outputs: [AudioDeviceChoice] = []
    @State private var inputs: [AudioDeviceChoice] = []
    @State private var selectedOutput: UInt32?
    @State private var selectedInput: UInt32?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Audio Device Selection").font(.title2.bold())
            Text("Choose the macOS devices used for sound playback and recording.")
                .font(.callout).foregroundStyle(.secondary)

            Form {
                Picker("Playback Device", selection: $selectedOutput) {
                    ForEach(outputs) { Text($0.name).tag(Optional($0.id)) }
                }
                Picker("Recording Device", selection: $selectedInput) {
                    ForEach(inputs) { Text($0.name).tag(Optional($0.id)) }
                }
            }
            .formStyle(.grouped)

            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Apply") { apply() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedOutput == nil && selectedInput == nil)
            }
        }
        .padding(24)
        .frame(width: 520)
        .onAppear(perform: load)
    }

    private func choices(input: Bool) -> [AudioDeviceChoice] {
        X7AudioDevices(input).compactMap { dictionary in
            guard let number = dictionary["id"] as? NSNumber,
                  let name = dictionary["name"] as? String else { return nil }
            return AudioDeviceChoice(
                id: number.uint32Value,
                uid: dictionary["uid"] as? String ?? "device-\(number.uint32Value)",
                name: name,
                isDefault: (dictionary["default"] as? NSNumber)?.boolValue ?? false
            )
        }
    }

    private func load() {
        outputs = choices(input: false)
        inputs = choices(input: true)
        let defaults = UserDefaults.standard
        let preferredOutputUID = defaults.string(forKey: "audio.preferredOutputUID")
        let preferredInputUID = defaults.string(forKey: "audio.preferredInputUID")
        selectedOutput = outputs.first(where: { $0.uid == preferredOutputUID })?.id
            ?? outputs.first(where: \.isDefault)?.id
        selectedInput = inputs.first(where: { $0.uid == preferredInputUID })?.id
            ?? inputs.first(where: \.isDefault)?.id
    }

    private func apply() {
        let defaults = UserDefaults.standard
        var failures: [String] = []

        if let selectedOutput, let device = outputs.first(where: { $0.id == selectedOutput }) {
            if X7SetDefaultAudioDevice(selectedOutput, false) {
                defaults.set(device.uid, forKey: "audio.preferredOutputUID")
            } else {
                failures.append("playback")
            }
        }
        if let selectedInput, let device = inputs.first(where: { $0.id == selectedInput }) {
            if X7SetDefaultAudioDevice(selectedInput, true) {
                defaults.set(device.uid, forKey: "audio.preferredInputUID")
            } else {
                failures.append("recording")
            }
        }

        if failures.isEmpty {
            dismiss()
        } else {
            error = "macOS could not change the \(failures.joined(separator: " and ")) device."
        }
    }
}
