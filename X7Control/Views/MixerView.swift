import SwiftUI

struct MixerView: View {
    @ObservedObject var c: X7Controller

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionCard("Speakers Master") {
                    LabeledSlider(title: "Volume", value: $c.masterVolume, range: 0...1, action: c.setMasterVolume)
                        .disabled(!c.masterStateAvailable)
                    Toggle("Mute", isOn: $c.masterMute)
                        .onChange(of: c.masterMute) { _, _ in c.setMasterMute() }
                        .disabled(!c.masterStateAvailable)
                    if !c.masterStateAvailable {
                        Text("The X7 CoreAudio output is not currently available for readback.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                SectionCard("Playback Sources") {
                    ForEach(PlaybackSource.allCases) { source in
                        PlaybackSourceStrip(c: c, source: source)
                        if source != PlaybackSource.allCases.last { Divider() }
                    }
                }
            }
            .padding()
        }
        .onAppear { c.refreshCurrentState() }
    }
}

private struct PlaybackSourceStrip: View {
 @ObservedObject var c: X7Controller
 let source: PlaybackSource
 private var state: PlaybackSourceState { c.playbackSources[source] ?? PlaybackSourceState() }
 private var volume: Binding<Double> { Binding(
  get:{state.volumeDB},
  set:{c.playbackSources[source]?.volumeDB=$0}
 ) }
 private var balance: Binding<Double> { Binding(
  get:{state.balance},
  set:{c.playbackSources[source]?.balance=$0}
 ) }
 private var muted: Binding<Bool> { Binding(
  get:{state.muted},
  set:{c.playbackSources[source]?.muted=$0}
 ) }
 var body: some View {
  VStack(alignment:.leading,spacing:10){
   HStack {
   Text(source.label).font(.headline)
   Spacer()
    Toggle("Mute",isOn:muted).onChange(of:state.muted){_,_ in c.setPlaybackMute(source)}
   }
   LabeledSlider(title:"Volume",value:volume,range:state.minimumDB...state.maximumDB,suffix:"dB",step:1){c.setPlaybackVolume(source)}
   LabeledSlider(title:"L/R Balance",value:balance,range:-1...1,suffix:"",step:0.01){c.setPlaybackVolume(source)}
   if !state.available { Text("Mixer readback is unavailable for this source.").font(.caption).foregroundStyle(.secondary) }
  }.disabled(!state.available)
 }
}
