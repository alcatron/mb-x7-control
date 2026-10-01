import SwiftUI

struct AdvancedView: View {
    @ObservedObject var c: X7Controller

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Advanced Features") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Scout Mode", isOn: $c.scout)
                        .onChange(of: c.scout) { _, _ in c.setScout() }
                    Text("This proprietary technology allows you to hear enemies from farther away, giving you a distinct tactical advantage in combat.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)

                    Divider()

                    Toggle("Auto Standby", isOn: $c.autoStandby)
                        .onChange(of: c.autoStandby) { _, _ in c.setStandby() }
                    Text("Auto Standby switches the X7 to standby after approximately 20 minutes of inactivity.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }
            Spacer()
        }
        .padding()
    }
}
