import SwiftUI
struct EqualizerView:View { @ObservedObject var c:X7Controller
 var body:some View { ScrollView { VStack(spacing:16){
  SectionCard("Equalizer"){
   Toggle("Enable Equalizer",isOn:$c.eqEnabled).onChange(of:c.eqEnabled){_,_ in c.setEQEnabled()}
   HStack{Picker("Preset",selection:$c.eqPreset){ForEach(EQPreset.allCases){Text($0.rawValue).tag($0)}};Button("Apply Preset"){c.applyPreset()}}
   LabeledSlider(title:"Level",value:$c.eqLevel,range:-12...12,suffix:"dB",step:0.1,action:c.setEQLevel)
   Divider()
   ForEach(EQBand.allCases){b in LabeledSlider(title:b.rawValue + (b.rawValue.contains("K") ? "Hz":" Hz"),value:Binding(get:{c.eq[b] ?? 0},set:{c.eq[b]=$0}),range:-12...12,suffix:"dB",step:0.1,action:{c.setBand(b)})}
  }
 }.padding() } }
}
