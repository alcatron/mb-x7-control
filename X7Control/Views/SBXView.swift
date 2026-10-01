import SwiftUI

struct SBXView: View {
    @ObservedObject var c: X7Controller

    private var headphoneBassAvailable: Bool {
        c.headphonesConnected && c.output == .headphones
    }

    private var displayedBassEnabled: Binding<Bool> {
        Binding(
            get: { headphoneBassAvailable && c.sbxBass },
            set: { c.sbxBass = $0 }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionCard("SBX Pro Studio") {
                    Button(action: c.toggleSBXMaster) {
                        HStack(spacing: 10) {
                            Image(systemName: "power")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(c.sbxMasterEnabled ? Color.orange : Color.secondary)
                            Text("SBX Pro Studio")
                                .font(.headline)
                            Spacer()
                            Text(c.sbxMasterEnabled ? "On" : "Off")
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider()

                    Group {
                        Toggle("Surround", isOn: $c.surround)
                            .onChange(of: c.surround) { _, _ in c.setSurround() }
                        LabeledSlider(title: "Amount", value: $c.surroundAmount, range: 0...1, defaultValue: 0.12, action: c.setSurroundAmount)
                        Divider()
                        Toggle("Crystalizer", isOn: $c.crystalizer)
                            .onChange(of: c.crystalizer) { _, _ in c.setCrystalizer() }
                        LabeledSlider(title: "Amount", value: $c.crystalizerAmount, range: 0...1, defaultValue: 0.5, action: c.setCrystalizerAmount)
                        Divider()
                        Toggle("Dialog Plus", isOn: $c.dialog)
                            .onChange(of: c.dialog) { _, _ in c.setDialog() }
                        LabeledSlider(title: "Amount", value: $c.dialogAmount, range: 0...1, defaultValue: 0.5, action: c.setDialogAmount)
                        Divider()
                        Toggle("Smart Volume", isOn: $c.smartVolume)
                            .onChange(of: c.smartVolume) { _, _ in c.setSmart() }
                        Picker("Mode", selection: $c.smartMode) {
                            ForEach(SmartVolumeMode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: c.smartMode) { _, _ in c.setSmartMode() }
                        LabeledSlider(title: "Amount", value: $c.smartVolumeAmount, range: 0...1, defaultValue: 0.74, action: c.setSmartAmount)
                            .disabled(c.smartMode != .normal)
                    }
                    .disabled(!c.sbxMasterEnabled)
                }

                SectionCard("Bass") {
                    Toggle("Bass", isOn: displayedBassEnabled)
                        .onChange(of: c.sbxBass) { _, _ in c.setSBXBass() }
                    LabeledSlider(title: "Amount", value: $c.sbxBassAmount, range: 0...1, defaultValue: 0.3, action: c.setSBXBassAmount)
                        .disabled(!c.sbxBass)
                    LabeledSlider(title: "Crossover Frequency", value: $c.sbxBassCrossover, range: 10...500, suffix: "Hz", step: 1, defaultValue: 80, action: c.setSBXBassCrossover)
                        .disabled(!c.sbxBass)

                    if !c.headphonesConnected {
                        Text("Available when headphones are connected to either front headphone socket.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if c.output != .headphones {
                        Text("Select Headphones in the output control to use SBX Bass.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!c.sbxMasterEnabled || !headphoneBassAvailable)

                SectionCard("Unavailable on this Mac configuration") {
                    UnsupportedRow(title: "CrystalVoice", reason: "The legacy macOS panel exposes these controls disabled; they are intentionally not emulated.")
                }
            }
            .padding()
        }
    }
}
