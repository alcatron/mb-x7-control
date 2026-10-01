import SwiftUI
struct CinematicView:View { @ObservedObject var c:X7Controller
 var body:some View { VStack{SectionCard("Dolby Digital — Dynamic Range Control"){Picker("Dynamic Range",selection:$c.dolby){ForEach(DolbyDRC.allCases){Text($0.rawValue).tag($0)}}.pickerStyle(.segmented).onChange(of:c.dolby){_,_ in c.setDolby()}; Text("Full = maximum dynamic range, Normal = standard, Night = minimum.").font(.caption).foregroundStyle(.secondary)};Spacer()}.padding() }
}
