import SwiftUI
struct HeadphonesView: View {
    @ObservedObject var c: X7Controller
    @State private var confirmingHighGain = false

    var body: some View {
        VStack(spacing: 16) {
            SectionCard("Headphone Output") {
                Label("Use the Speakers / Headphones selector in the toolbar to switch the physical output.", systemImage: "headphones")
                Text("Headphones becomes available automatically when a plug is detected in the X7 front headphone jack.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SectionCard("Headphone Gain") {
                Text("Select the gain for headphone output:")

                gainOption(
                    title: "Normal Gain",
                    detail: "32–300 ohm headphones",
                    selected: !c.headphoneHighGain
                ) {
                    c.setHeadphoneHighGain(false)
                }

                gainOption(
                    title: "High Gain",
                    detail: "600 ohm headphones",
                    selected: c.headphoneHighGain
                ) {
                    confirmingHighGain = true
                }

                if !c.headphonesConnected {
                    Text("Connect headphones to the X7 front jack to change gain.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SafetyWarning(text: "High Gain may damage headphones whose impedance does not match the specified 600 ohm level.")
            }
            Spacer()
        }
        .padding()
        .alert("Enable High Gain?", isPresented: $confirmingHighGain) {
            Button("Cancel", role: .cancel) {}
            Button("Accept and Enable", role: .destructive) {
                c.setHeadphoneHighGain(true)
            }
        } message: {
            Text("High Gain is intended for 600 ohm headphones. Using it with headphones of a different impedance may cause damage.")
        }
    }

    private func gainOption(
        title: String,
        detail: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).fontWeight(.semibold)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!c.headphonesConnected)
    }
}
