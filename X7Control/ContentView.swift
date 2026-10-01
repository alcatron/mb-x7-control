import SwiftUI
import Combine

enum SidebarItem: String, CaseIterable, Identifiable {
    case sbx = "SBX Pro Studio", speakers = "Speakers", headphones = "Headphones"
    case cinematic = "Cinematic", mixer = "Mixer", equalizer = "Equalizer", advanced = "Advanced Features"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .sbx: "waveform"
        case .speakers: "hifispeaker.2"
        case .headphones: "headphones"
        case .cinematic: "film"
        case .mixer: "slider.horizontal.3"
        case .equalizer: "waveform.path.ecg"
        case .advanced: "gearshape.2"
        }
    }
}

struct ContentView: View {
    @StateObject private var controller = X7Controller()
    @State private var selection: SidebarItem? = .sbx
    @State private var confirmDefaults = false
    @State private var showAudioDevices = false
    private let connectionTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                Text("MB X7 Control")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 10)

                List(SidebarItem.allCases, selection: $selection) { item in
                    Label(item.rawValue, systemImage: item.icon)
                        .tag(item)
                        .padding(.vertical, 3)
                }
                .listStyle(.sidebar)
                .scrollDisabled(true)
                .frame(height: 250)

                Divider()

                Image("MBX7Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 124, height: 124)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.24), radius: 9, y: 3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)

                Spacer(minLength: 0)
            }
            .frame(width: 250)
            .background(.bar)

            Divider()

            VStack(spacing: 0) {
                header
                Divider()
                Group {
                    switch selection ?? .sbx {
                    case .sbx: SBXView(c: controller)
                    case .speakers: SpeakersView(c: controller)
                    case .headphones: HeadphonesView(c: controller)
                    case .cinematic: CinematicView(c: controller)
                    case .mixer: MixerView(c: controller)
                    case .equalizer: EqualizerView(c: controller)
                    case .advanced: AdvancedView(c: controller)
                    }
                }
                .disabled(!controller.connected)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1100, minHeight: 720)
        .onReceive(connectionTimer) { _ in controller.refreshConnection() }
        .confirmationDialog("Restore Creative Default Profile?", isPresented: $confirmDefaults, titleVisibility: .visible) {
            Button("Restore Default") { controller.applyCreativeDefaultProfile() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Restores the verified supported SBX, EQ and Dolby defaults. Speaker hardware settings are not changed.")
        }
        .sheet(isPresented: $showAudioDevices) { AudioDeviceSelectionView() }
        .alert("MB X7 Control", isPresented: Binding(
            get: { controller.lastError != nil },
            set: { if !$0 { controller.lastError = nil } }
        )) {
            Button("OK", role: .cancel) { controller.lastError = nil }
        } message: {
            Text(controller.lastError ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 18) {
            Image(systemName: controller.connected ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(controller.connected ? .green : .red)
            VStack(alignment: .leading, spacing: 2) {
                Text("Sound Blaster X7").font(.headline)
                Text(controller.connected ? "Connected via USB" : "Not connected")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 24)
            Text("Output").font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 2) {
                outputButton(.speakers, icon: "hifispeaker.2.fill")
                outputButton(.headphones, icon: "headphones")
            }
            .padding(3)
            .frame(width: 250)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
            .help(controller.headphonesConnected ? "Select the X7 output" : "Plug headphones into the X7 front headphone jack to enable Headphones")

            Menu {
                Button("Restore Default…") { confirmDefaults = true }
                    .disabled(!controller.connected)
                Button("Audio Device Selection…") { showAudioDevices = true }
                Divider()
                Button("About MB X7 Control…") { showMBX7AboutPanel() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 30)

            Button { controller.refreshCurrentState() } label: { Image(systemName: "arrow.clockwise") }
                .help("Refresh connection and current values")
        }
        .padding(.horizontal, 20).padding(.vertical, 14).background(.bar)
    }

    private func outputButton(_ output: X7Output, icon: String) -> some View {
        let available = controller.connected && (output == .speakers || controller.headphonesConnected)
        let selected = controller.output == output
        return Button {
            guard available else { return }
            controller.output = output
            controller.setOutput()
        } label: {
            Label(output.rawValue, systemImage: icon)
                .font(.callout)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(selected ? Color.accentColor : Color.clear,
                            in: RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .opacity(available ? 1 : 0.42)
    }

}
