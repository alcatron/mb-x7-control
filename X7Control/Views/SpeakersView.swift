import SwiftUI

struct SpeakersView: View {
    @ObservedObject var c: X7Controller
    @State private var confirmingHighPower = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionCard("Speaker Hardware") {
                    Picker("Speaker Model", selection: $c.speakerModel) {
                        ForEach(SpeakerModel.allCases) { Text($0.label).tag($0) }
                    }
                    .onChange(of: c.speakerModel) { _, _ in c.setSpeakerModel() }

                    Picker("Speaker Voicing", selection: $c.speakerVoicing) {
                        ForEach(SpeakerVoicing.allCases) { Text($0.label).tag($0) }
                    }
                    .onChange(of: c.speakerVoicing) { _, _ in c.setSpeakerVoicing() }
                    .disabled(c.speakerModel != .emuXM7)

                    Text("Energetic, Neutral, and Warm are E-MU XM7 voicings.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                SectionCard("Speaker Output Target") {
                    Picker("Output", selection: $c.speakerOutputTarget) {
                        ForEach(SpeakerOutputTarget.allCases) { Text($0.label).tag($0) }
                    }
                    .onChange(of: c.speakerOutputTarget) { _, _ in c.setSpeakerOutputTarget() }
                }

                SectionCard("Other Speakers — Settings") {
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Configuration", selection: $c.layout) {
                                ForEach(SpeakerLayout.allCases) { Text($0.descriptiveLabel).tag($0) }
                            }
                            .onChange(of: c.layout) { _, _ in c.setSpeakerLayout() }
                            Text("Active speakers: \(c.layout.speakers)")
                                .font(.caption).foregroundStyle(.secondary)
                            Divider()
                            Toggle("Front L/R Full-Range", isOn: $c.frontFullRange)
                                .onChange(of: c.frontFullRange) { _, _ in c.setFrontFullRange() }
                            Toggle("Rear L/R Full-Range", isOn: $c.rearFullRange)
                                .disabled(!c.layout.hasRear)
                                .onChange(of: c.rearFullRange) { _, _ in c.setRearFullRange() }
                            if !c.layout.hasRear {
                                Text("Rear full-range becomes available with 4.x and 5.x layouts.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Text("Full-range means that speaker pair handles deep bass instead of relying on crossover redirection.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Divider()
                        SpeakerLayoutDiagram(
                            layout: c.layout,
                            frontFullRange: c.frontFullRange,
                            rearFullRange: c.rearFullRange,
                            bassRedirection: c.bassRedirection
                        )
                        .frame(width: 320, height: 270)
                    }
                }

                SectionCard("Bass Management") {
                    Toggle("Bass Redirection", isOn: $c.bassRedirection)
                        .onChange(of: c.bassRedirection) { _, _ in c.setBassRedirection() }
                    LabeledSlider(title: "Crossover", value: $c.crossover, range: 10...500, suffix: "Hz", step: 1, action: c.setCrossover)
                    Toggle("Subwoofer Gain", isOn: $c.subwooferGain)
                        .onChange(of: c.subwooferGain) { _, _ in c.setSubGain() }
                }

                SectionCard("Calibration") {
                    HStack(alignment: .top, spacing: 24) {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Speaker").frame(width: 105, alignment: .leading)
                                Text("Distance").frame(width: 150)
                                Text("Level").frame(width: 130)
                            }
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)

                            ForEach(c.layout.calibrationChannels) { channel in
                                CalibrationRow(channel: channel, c: c)
                                if channel != c.layout.calibrationChannels.last { Divider() }
                            }

                            Text("Distance is converted to the relative acoustic delay used by the X7; the farthest active speaker receives zero delay.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 10)

                            Divider()
                                .padding(.vertical, 10)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Front Center Channel Position")
                                    .font(.subheadline.weight(.semibold))
                                Picker("Front Center Channel Position", selection: $c.frontCenterPosition) {
                                    ForEach(FrontCenterPosition.allCases) { position in
                                        Text(position.rawValue).tag(position)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.radioGroup)
                                .onChange(of: c.frontCenterPosition) { _, _ in c.setFrontCenterPosition() }
                                .disabled(!c.layout.hasCenter)

                                if !c.layout.hasCenter {
                                    Text("Available with 3.x and 5.x speaker configurations.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Divider()

                        SpeakerLayoutDiagram(
                            layout: c.layout,
                            frontFullRange: c.frontFullRange,
                            rearFullRange: c.rearFullRange,
                            bassRedirection: c.bassRedirection
                        )
                        .frame(width: 320, height: 270)
                    }
                }

                SectionCard("Polarity") {
                    ForEach(c.layout.calibrationChannels) { channel in
                        Toggle("Invert \(channel.rawValue)", isOn: Binding(
                            get: { c.invertedPolarity[channel] ?? false },
                            set: { c.invertedPolarity[channel] = $0 }
                        ))
                        .onChange(of: c.invertedPolarity[channel] ?? false) { _, _ in c.setPolarity(channel) }
                    }
                }

                SectionCard("Audio Mode") {
                    Toggle("Direct Mode", isOn: $c.directMode)
                        .onChange(of: c.directMode) { _, _ in c.setDirect() }
                    Text("Direct Mode gives you audio in its purest form, directly from the source.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Divider()

                    Toggle("Direct Mode (SPDIF-In)", isOn: $c.spdifDirect)
                        .onChange(of: c.spdifDirect) { _, _ in c.setSPDIFDirect() }
                    Text("Allows a bit-for-bit input stream of up to 24-bit/96 kHz without processing. Other audio input sources are disabled while this mode is on.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                SectionCard("Amplification and Routing") {
                    Toggle("High Power Amplification", isOn: Binding(
                        get: { c.highPowerAmplification },
                        set: { enabled in
                            if enabled {
                                confirmingHighPower = true
                            } else {
                                c.highPowerAmplification = false
                                c.setHighPowerAmplification()
                            }
                        }
                    ))
                    Text("Increases amplifier output to as much as 50 W + 50 W for 4-ohm passive speakers. It requires the X7's impedance switch to be set to 4 ohms and a 24 V/6 A high-output power adapter.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Divider()

                    Toggle("Headphone Surround for Line/Optical Out", isOn: $c.headphoneSurroundOverSpeakerOutput)
                        .onChange(of: c.headphoneSurroundOverSpeakerOutput) { _, _ in c.setHeadphoneSurroundOverSpeakerOutput() }
                    Text("Applies headphone surround processing to the Line/Optical output.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    SafetyWarning(text: "Do not enable High Power Amplification with the standard power adapter supplied with the X7.")
                }
            }
            .padding()
        }
        .alert("Enable High Power Amplification?", isPresented: $confirmingHighPower) {
            Button("Cancel", role: .cancel) {}
            Button("Accept and Enable", role: .destructive) {
                c.highPowerAmplification = true
                c.setHighPowerAmplification()
            }
        } message: {
            Text("This mode can output up to 50 W + 50 W and is only for 4-ohm passive speakers with the X7 impedance switch set to 4 ohms and a 24 V/6 A high-output adapter. Do not enable it with the standard X7 power adapter.")
        }
    }

}

private struct CalibrationRow: View {
    let channel: CalibrationChannel
    @ObservedObject var c: X7Controller

    var body: some View {
        HStack(spacing: 12) {
            Text(channel.rawValue)
                .font(.subheadline.weight(.semibold))
                .frame(width: 105, alignment: .leading)

            HStack(spacing: 6) {
                calibrationButton("minus") { adjustDistance(by: -10) }
                    .disabled((c.calibrationDistanceCM[channel] ?? 210) <= 50)
                Text("\(((c.calibrationDistanceCM[channel] ?? 210) / 100).formatted(.number.precision(.fractionLength(1)))) m")
                    .monospacedDigit()
                    .frame(width: 58)
                calibrationButton("plus") { adjustDistance(by: 10) }
                    .disabled((c.calibrationDistanceCM[channel] ?? 210) >= 500)
            }
            .frame(width: 150)

            HStack(spacing: 6) {
                calibrationButton("minus") { adjustLevel(by: -1) }
                    .disabled((c.calibrationLevel[channel] ?? 0) <= -20)
                Text("\(Int((c.calibrationLevel[channel] ?? 0).rounded())) dB")
                    .monospacedDigit()
                    .frame(width: 42)
                calibrationButton("plus") { adjustLevel(by: 1) }
                    .disabled((c.calibrationLevel[channel] ?? 0) >= 20)
            }
            .frame(width: 130)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
    }

    private func calibrationButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func adjustDistance(by amount: Double) {
        let current = c.calibrationDistanceCM[channel] ?? 210
        c.calibrationDistanceCM[channel] = min(500, max(50, current + amount))
        c.setCalibrationDistances()
    }

    private func adjustLevel(by amount: Double) {
        let current = c.calibrationLevel[channel] ?? 0
        c.calibrationLevel[channel] = min(20, max(-20, current + amount))
        c.setCalibrationLevel(channel)
    }
}

private struct SpeakerLayoutDiagram: View {
    let layout: SpeakerLayout
    let frontFullRange: Bool
    let rearFullRange: Bool
    let bassRedirection: Bool

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                ForEach(0..<3, id: \.self) { ring in
                    Ellipse()
                        .stroke(
                            bassRedirection ? Color.accentColor.opacity(0.24 - Double(ring) * 0.05) : Color.secondary.opacity(0.12),
                            lineWidth: bassRedirection ? 2 : 1
                        )
                        .frame(width: width * (0.42 + Double(ring) * 0.20), height: height * (0.28 + Double(ring) * 0.16))
                }

                VStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 30))
                    Text("Listening position")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                .position(x: width * 0.5, y: height * 0.53)

                speaker("FL", active: true, fullRange: frontFullRange)
                    .position(x: width * 0.20, y: height * 0.18)
                speaker("FR", active: true, fullRange: frontFullRange)
                    .position(x: width * 0.80, y: height * 0.18)
                speaker("C", active: layout.hasCenter, fullRange: false)
                    .position(x: width * 0.50, y: height * 0.10)
                speaker("RL", active: layout.hasRear, fullRange: rearFullRange)
                    .position(x: width * 0.20, y: height * 0.83)
                speaker("RR", active: layout.hasRear, fullRange: rearFullRange)
                    .position(x: width * 0.80, y: height * 0.83)
                subwoofer(active: layout.hasSubwoofer)
                    .position(x: width * 0.91, y: height * 0.53)

                Text(layout.label)
                    .font(.headline.monospacedDigit())
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.regularMaterial, in: Capsule())
                    .position(x: width * 0.50, y: height * 0.92)
            }
            .animation(.easeInOut(duration: 0.2), value: layout)
            .animation(.easeInOut(duration: 0.2), value: frontFullRange)
            .animation(.easeInOut(duration: 0.2), value: rearFullRange)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(layout.descriptiveLabel). Front full-range \(frontFullRange ? "on" : "off"). Rear full-range \(layout.hasRear && rearFullRange ? "on" : "off").")
        }
    }

    private func speaker(_ name: String, active: Bool, fullRange: Bool) -> some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(active ? Color.accentColor.gradient : Color.secondary.opacity(0.12).gradient)
                    .frame(width: 34, height: 46)
                    .overlay {
                        VStack(spacing: 5) {
                            Circle().fill(.black.opacity(active ? 0.70 : 0.20)).frame(width: 12, height: 12)
                            Circle().fill(.black.opacity(active ? 0.70 : 0.20)).frame(width: 17, height: 17)
                        }
                    }
                    .shadow(color: active ? Color.accentColor.opacity(0.25) : .clear, radius: 5)
                if active && fullRange {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.green, .black)
                        .offset(x: 7, y: -6)
                }
            }
            Text(name).font(.caption2.bold())
        }
        .foregroundStyle(active ? .primary : .tertiary)
        .opacity(active ? 1 : 0.35)
        .scaleEffect(active ? 1 : 0.88)
    }

    private func subwoofer(active: Bool) -> some View {
        VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 6)
                .fill(active ? Color.orange.gradient : Color.secondary.opacity(0.12).gradient)
                .frame(width: 44, height: 52)
                .overlay {
                    Circle().stroke(.black.opacity(active ? 0.65 : 0.20), lineWidth: 4).frame(width: 25, height: 25)
                }
                .shadow(color: active && bassRedirection ? Color.orange.opacity(0.45) : .clear, radius: 8)
            Text("SUB").font(.caption2.bold())
        }
        .foregroundStyle(active ? .primary : .tertiary)
        .opacity(active ? 1 : 0.35)
        .scaleEffect(active ? 1 : 0.88)
    }
}
