import Foundation
import SwiftUI

enum SettingsSection: String, Hashable {
    case output, sbx, equalizer, speakers, cinematic, advanced, mixer
}

@MainActor
final class X7Controller: ObservableObject {
    @Published var connected=false
    @Published var lastError:String?
    @Published var output:X7Output? = .speakers
    @Published private(set) var headphonesConnected = false
    @Published var headphoneHighGain = false
    @Published var sbxMasterEnabled = true
    @Published var surround = true
    @Published var surroundAmount: Double = 0.12
    @Published var crystalizer = true
    @Published var crystalizerAmount: Double = 0.5
    @Published var dialog = false
    @Published var dialogAmount: Double = 0.5
    @Published var smartVolume = false
    @Published var smartVolumeAmount: Double = 0.74
    @Published var smartMode: SmartVolumeMode = .normal
    @Published var sbxBass = true
    @Published var sbxBassAmount: Double = 0.3
    @Published var sbxBassCrossover: Double = 80
    @Published var eqEnabled = false
    @Published var eqLevel: Double = 0
    @Published var eqPreset: EQPreset = .flat
    @Published var eq:[EQBand:Double] = Dictionary(uniqueKeysWithValues: EQBand.allCases.map{($0,0)})
    @Published var layout:SpeakerLayout = .stereo
    @Published var speakerOutputTarget: SpeakerOutputTarget = .line
    @Published var bassRedirection = false
    @Published var crossover: Double = 80
    @Published var subwooferGain = false
    @Published var directMode = false
    @Published var spdifDirect = false
    @Published var dolby: DolbyDRC = .normal
    @Published var scout = false
    @Published var autoStandby = false
    @Published var speakerModel: SpeakerModel = .other
    @Published var speakerVoicing: SpeakerVoicing = .neutral
    @Published var calibrationLevel:[CalibrationChannel:Double] = Dictionary(uniqueKeysWithValues: CalibrationChannel.allCases.map{($0,0)})
    @Published var invertedPolarity: [CalibrationChannel:Bool] = Dictionary(uniqueKeysWithValues: CalibrationChannel.allCases.map{($0,false)})
    @Published var calibrationDistanceCM:[CalibrationChannel:Double] = Dictionary(uniqueKeysWithValues: CalibrationChannel.allCases.map{($0,50)})
    @Published var frontFullRange = false
    @Published var rearFullRange = false
    @Published var highPowerAmplification = false
    @Published var headphoneSurroundOverSpeakerOutput = false
    @Published var masterVolume: Double = 0.5
    @Published var masterMute = false
    @Published var masterStateAvailable = false
    @Published var playbackSources: [PlaybackSource: PlaybackSourceState] = Dictionary(
        uniqueKeysWithValues: PlaybackSource.allCases.map { ($0, PlaybackSourceState()) }
    )

    @Published private(set) var storedSections = Set<SettingsSection>()
    private var deviceIdentifier = "041e-323a"
    private var suppressUIWrites = false
    private var jackQueryInFlight = false
    private var savedMasterMute: Bool?
    private var savedPlaybackMutes: [PlaybackSource: Bool] = [:]

    init(){
        restorePreferredAudioDevices()
        refreshConnection()
    }

    private func restorePreferredAudioDevices() {
        let defaults = UserDefaults.standard
        for (input, key) in [(false, "audio.preferredOutputUID"), (true, "audio.preferredInputUID")] {
            guard let preferredUID = defaults.string(forKey: key) else { continue }
            guard let device = X7AudioDevices(input).first(where: {
                ($0["uid"] as? String) == preferredUID
            }), let number = device["id"] as? NSNumber else { continue }
            _ = X7SetDefaultAudioDevice(number.uint32Value, input)
        }
    }
    func refreshConnection(){
        let wasConnected = connected
        connected = X7IsConnected()
        // Read hardware state once per connection transition. The two-second
        // timer otherwise checks presence and jack state only; opening Mixer or
        // pressing the header refresh button requests fresh audio values.
        if connected && !wasConnected {
            suppressWritesUntilNextRunLoop()
            deviceIdentifier = X7DeviceIdentifier() ?? "041e-323a"
            loadPersistedState()
            refreshMasterState()
            restoreSavedMasterMute()
            refreshPlaybackMixer(restoreSavedMutes: true)
        }
        if connected { refreshHeadphoneJack() }
        if !connected {
            headphonesConnected = false
            masterStateAvailable = false
            for source in PlaybackSource.allCases { playbackSources[source]?.available = false }
        }
    }

    func refreshCurrentState() {
        refreshConnection()
        guard connected else { return }
        refreshMasterState()
        refreshPlaybackMixer()
    }

    private func refreshHeadphoneJack() {
        guard !jackQueryInFlight else { return }
        jackQueryInFlight = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var inserted = ObjCBool(false)
            let available = X7ReadHeadphoneJackInserted(&inserted)
            let isInserted = available && inserted.boolValue
            DispatchQueue.main.async {
                guard let self else { return }
                self.jackQueryInFlight = false
                guard self.connected else {
                    self.headphonesConnected = false
                    return
                }
                self.headphonesConnected = isInserted
                if !isInserted && self.output == .headphones {
                    self.suppressWritesUntilNextRunLoop()
                    self.output = .speakers
                }
            }
        }
    }

    private func suppressWritesUntilNextRunLoop() {
        suppressUIWrites = true
        // Published readback/persistence updates can reach SwiftUI's onChange
        // handlers on a later render pass. Keep the guard through that pass so
        // opening, reconnecting, or pressing Read can never echo values back.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.suppressUIWrites = false }
    }
    func refreshMasterState(){
        suppressWritesUntilNextRunLoop()
        var volume: Float = 0
        let hasVolume = X7ReadMasterVolume(&volume)
        if hasVolume { masterVolume = Double(volume) }
        var muted = ObjCBool(false)
        let hasMute = X7ReadMasterMute(&muted)
        if hasMute { masterMute = muted.boolValue }
        masterStateAvailable = hasVolume && hasMute
    }
    @discardableResult func send(_ bytes:[UInt8])->Bool {
        guard connected else { lastError="Sound Blaster X7 is not connected."; return false }
        let rc=bytes.withUnsafeBufferPointer{ X7SendReport($0.baseAddress!, $0.count) }
        if rc != 0 { lastError=String(format:"X7 write failed (0x%08X)", rc); return false }
        lastError=nil; return true
    }
    private func write(_ packet: [UInt8], section: SettingsSection) {
        guard !suppressUIWrites else { return }
        if send(packet) { persist(section) }
    }
    func setOutput(){ guard let output else { return }; write(X7Packets.output(output), section: .output) }
    func setHeadphoneHighGain(_ enabled: Bool) {
        headphoneHighGain = enabled
        write(X7Packets.headphoneHighGain(enabled), section: .output)
    }
    func toggleSBXMaster() {
        guard !suppressUIWrites else { return }
        guard send(X7Packets.sbxMasterToggle()) else { return }
        sbxMasterEnabled.toggle()
        persist(.sbx)
    }
    func setSurround(){ write(X7Packets.dsp(0x00,value:surround ? 1:0), section:.sbx) }
    func setSurroundAmount(){ write(X7Packets.dsp(0x02,value:Float(surroundAmount)), section:.sbx) }
    func setCrystalizer(){ write(X7Packets.dsp(0x0E,value:crystalizer ? 1:0), section:.sbx) }
    func setCrystalizerAmount(){ write(X7Packets.dsp(0x10,value:Float(crystalizerAmount)), section:.sbx) }
    func setDialog(){ write(X7Packets.dsp(0x04,value:dialog ? 1:0), section:.sbx) }
    func setDialogAmount(){ write(X7Packets.dsp(0x06,value:Float(dialogAmount)), section:.sbx) }
    func setSmart(){ write(X7Packets.dsp(0x08,value:smartVolume ? 1:0), section:.sbx) }
    func setSmartAmount(){ write(X7Packets.dsp(0x0A,value:Float(smartVolumeAmount)), section:.sbx) }
    func setSmartMode(){ let v:Float = smartMode == .normal ? 0 : smartMode == .loud ? 1:2; write(X7Packets.dsp(0x0C,value:v), section:.sbx) }
    func setSBXBass(){ write(X7Packets.dsp(0x30,value:sbxBass ? 1:0), section:.sbx) }
    func setSBXBassAmount(){ write(X7Packets.dsp(0x32,value:Float(sbxBassAmount)), section:.sbx) }
    func setSBXBassCrossover(){ write(X7Packets.dsp(0x34,value:Float(sbxBassCrossover)), section:.sbx) }
    func setSpeakerLayout(){ write(X7Packets.speakerLayout(layout), section:.speakers) }
    func setSpeakerOutputTarget(){ write(X7Packets.speakerOutputTarget(speakerOutputTarget), section:.speakers) }
    func setFrontFullRange(){ write(X7Packets.dsp(0x1A,value:frontFullRange ? 0:1), section:.speakers) }
    func setRearFullRange(){ write(X7Packets.dsp(0x1C,value:rearFullRange ? 0:1), section:.speakers) }
    func setHighPowerAmplification(){ write(X7Packets.highPowerAmplification(highPowerAmplification), section:.speakers) }
    func setHeadphoneSurroundOverSpeakerOutput(){ write(X7Packets.headphoneSurroundOverSpeakerOutput(headphoneSurroundOverSpeakerOutput), section:.speakers) }
    func setBassRedirection(){ write(X7Packets.dsp(0x2A,value:bassRedirection ? 1:0), section:.speakers) }
    func setCrossover(){ write(X7Packets.dsp(0x2C,value:Float(crossover)), section:.speakers) }
    func setSubGain(){ write(X7Packets.dsp(0x3C,value:subwooferGain ? 1:0), section:.speakers) }
    func setDirect(){ write(X7Packets.direct(directMode), section:.speakers) }
    func setSPDIFDirect(){ write(X7Packets.spdifDirect(spdifDirect), section:.speakers) }
    func setDolby(){ let v:Float = dolby == .full ? 1 : dolby == .normal ? 2:3; write(X7Packets.dsp(0x04,namespace:0x97,value:v), section:.cinematic) }
    func setScout(){ write(X7Packets.scout(scout), section:.advanced) }
    func setStandby(){ write(X7Packets.standby(autoStandby), section:.advanced) }
    func setSpeakerModel(){ write(X7Packets.speakerModel(speakerModel), section:.speakers) }
    func setSpeakerVoicing(){ write(X7Packets.speakerVoicing(speakerVoicing), section:.speakers) }
    func setEQEnabled(){ write(X7Packets.dsp(0x12,value:eqEnabled ? 1:0), section:.equalizer) }
    func setEQLevel(){ write(X7Packets.dsp(0x14,value:Float(eqLevel)), section:.equalizer) }
    func setBand(_ b:EQBand){ write(X7Packets.dsp(b.parameter,value:Float(eq[b] ?? 0)), section:.equalizer) }
    func applyPreset(){
        let vals=eqPreset.values
        guard send(X7Packets.dsp(0x14,value:vals[0])) else { return }
        for (i,b) in EQBand.allCases.enumerated() {
            guard send(X7Packets.dsp(b.parameter,value:vals[i+1])) else { return }
        }
        eqLevel=Double(vals[0])
        for (i,b) in EQBand.allCases.enumerated(){ eq[b]=Double(vals[i+1]) }
        persist(.equalizer)
    }
    func setCalibrationLevel(_ c:CalibrationChannel){ write(X7Packets.dsp(c.levelParam,value:Float(calibrationLevel[c] ?? 0)), section:.speakers) }
    func setPolarity(_ channel: CalibrationChannel){ write(X7Packets.dsp(channel.polarityParam,value:(invertedPolarity[channel] ?? false) ? 1:0), section:.speakers) }
    func setCalibrationDistances(){
        // Creative stores distance as the acoustic delay from each speaker to the
        // farthest speaker. Its original panel uses 1 / 34342 seconds per cm.
        let channels = layout.calibrationChannels
        let longest = channels.map { calibrationDistanceCM[$0] ?? 50 }.max() ?? 50
        let secondsPerCentimeter: Double = 2.91188631995807e-5
        for channel in channels {
            let delay = Float((longest - (calibrationDistanceCM[channel] ?? 50)) * secondsPerCentimeter)
            guard send(X7Packets.dsp(channel.distanceParam,value:delay)) else { return }
        }
        persist(.speakers)
    }

    func applyCreativeDefaultProfile() {
        guard connected else { return }
        suppressUIWrites = true
        surround = true; surroundAmount = 0.12
        crystalizer = true; crystalizerAmount = 0.5
        dialog = false; dialogAmount = 0.5
        smartVolume = false; smartVolumeAmount = 0.74; smartMode = .normal
        sbxBass = true; sbxBassAmount = 0.3; sbxBassCrossover = 80
        eqEnabled = false; eqLevel = 0; eqPreset = .flat
        for band in EQBand.allCases { eq[band] = 0 }
        dolby = .normal

        var packets: [[UInt8]] = [
            X7Packets.dsp(0x00,value:1), X7Packets.dsp(0x02,value:0.12),
            X7Packets.dsp(0x0E,value:1), X7Packets.dsp(0x10,value:0.5),
            X7Packets.dsp(0x04,value:0), X7Packets.dsp(0x06,value:0.5),
            X7Packets.dsp(0x08,value:0), X7Packets.dsp(0x0A,value:0.74),
            X7Packets.dsp(0x0C,value:0), X7Packets.dsp(0x12,value:0),
            X7Packets.dsp(0x14,value:0)
        ] + EQBand.allCases.map { X7Packets.dsp($0.parameter,value:0) } + [
            X7Packets.dsp(0x04,namespace:0x97,value:2)
        ]
        // The original panel exposes this Bass block only on the headphone path.
        if headphonesConnected && output == .headphones {
            packets += [
                X7Packets.dsp(0x30,value:1), X7Packets.dsp(0x32,value:0.3),
                X7Packets.dsp(0x34,value:80)
            ]
        }
        var success = true
        for packet in packets where success { success = send(packet) }
        if success {
            persist(.sbx); persist(.equalizer); persist(.cinematic)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.suppressUIWrites = false }
    }

    private var defaultsPrefix: String { "device.\(deviceIdentifier)." }
    private func key(_ name: String) -> String { defaultsPrefix + name }

    private func persist(_ section: SettingsSection) {
        let defaults = UserDefaults.standard
        switch section {
        case .output:
            defaults.set(output?.rawValue, forKey:key("output"))
            defaults.set(headphoneHighGain, forKey:key("output.headphoneHighGain"))
        case .sbx:
            defaults.set(sbxMasterEnabled, forKey:key("sbx.master"))
            defaults.set(surround, forKey:key("sbx.surround"))
            defaults.set(surroundAmount, forKey:key("sbx.surroundAmount"))
            defaults.set(crystalizer, forKey:key("sbx.crystalizer"))
            defaults.set(crystalizerAmount, forKey:key("sbx.crystalizerAmount"))
            defaults.set(dialog, forKey:key("sbx.dialog"))
            defaults.set(dialogAmount, forKey:key("sbx.dialogAmount"))
            defaults.set(smartVolume, forKey:key("sbx.smartVolume"))
            defaults.set(smartVolumeAmount, forKey:key("sbx.smartVolumeAmount"))
            defaults.set(smartMode.rawValue, forKey:key("sbx.smartMode"))
            defaults.set(sbxBass, forKey:key("sbx.bass"))
            defaults.set(sbxBassAmount, forKey:key("sbx.bassAmount"))
            defaults.set(sbxBassCrossover, forKey:key("sbx.bassCrossover"))
        case .equalizer:
            defaults.set(eqEnabled, forKey:key("eq.enabled"))
            defaults.set(eqLevel, forKey:key("eq.level"))
            defaults.set(eqPreset.rawValue, forKey:key("eq.preset"))
            defaults.set(Dictionary(uniqueKeysWithValues:eq.map { ($0.key.rawValue, $0.value) }), forKey:key("eq.bands"))
        case .speakers:
            defaults.set(layout.rawValue, forKey:key("speakers.layout"))
            defaults.set(speakerOutputTarget.rawValue, forKey:key("speakers.outputTarget"))
            defaults.set(bassRedirection, forKey:key("speakers.bassRedirection"))
            defaults.set(crossover, forKey:key("speakers.crossover"))
            defaults.set(subwooferGain, forKey:key("speakers.subwooferGain"))
            defaults.set(directMode, forKey:key("speakers.directMode"))
            defaults.set(spdifDirect, forKey:key("speakers.spdifDirect"))
            defaults.set(speakerModel.rawValue, forKey:key("speakers.model"))
            defaults.set(speakerVoicing.rawValue, forKey:key("speakers.voicing"))
            defaults.set(frontFullRange, forKey:key("speakers.frontFullRange"))
            defaults.set(rearFullRange, forKey:key("speakers.rearFullRange"))
            defaults.set(highPowerAmplification, forKey:key("speakers.highPower"))
            defaults.set(headphoneSurroundOverSpeakerOutput, forKey:key("speakers.headphoneSurround"))
            defaults.set(Dictionary(uniqueKeysWithValues:calibrationLevel.map { ($0.key.rawValue, $0.value) }), forKey:key("speakers.levels"))
            defaults.set(Dictionary(uniqueKeysWithValues:invertedPolarity.map { ($0.key.rawValue, $0.value) }), forKey:key("speakers.polarity"))
            defaults.set(Dictionary(uniqueKeysWithValues:calibrationDistanceCM.map { ($0.key.rawValue, $0.value) }), forKey:key("speakers.distances"))
        case .cinematic:
            defaults.set(dolby.rawValue, forKey:key("cinematic.dolby"))
        case .advanced:
            defaults.set(scout, forKey:key("advanced.scout"))
            defaults.set(autoStandby, forKey:key("advanced.autoStandby"))
        case .mixer:
            if let savedMasterMute { defaults.set(savedMasterMute, forKey:key("mixer.masterMute")) }
            defaults.set(Dictionary(uniqueKeysWithValues: savedPlaybackMutes.map {
                (String(format: "%02X", $0.key.rawValue), $0.value)
            }), forKey:key("mixer.playbackMutes"))
        }
        storedSections.insert(section)
        defaults.set(storedSections.map(\.rawValue), forKey:key("storedSections"))
    }

    private func loadPersistedState() {
        let defaults = UserDefaults.standard
        storedSections = Set((defaults.stringArray(forKey:key("storedSections")) ?? []).compactMap(SettingsSection.init(rawValue:)))

        if storedSections.contains(.output) {
            if let raw = defaults.string(forKey:key("output")) { output = X7Output(rawValue:raw) }
            headphoneHighGain = defaults.bool(forKey:key("output.headphoneHighGain"))
        }
        if storedSections.contains(.sbx) {
            if defaults.object(forKey:key("sbx.master")) != nil { sbxMasterEnabled = defaults.bool(forKey:key("sbx.master")) }
            surround = defaults.bool(forKey:key("sbx.surround")); surroundAmount = defaults.double(forKey:key("sbx.surroundAmount"))
            crystalizer = defaults.bool(forKey:key("sbx.crystalizer")); crystalizerAmount = defaults.double(forKey:key("sbx.crystalizerAmount"))
            dialog = defaults.bool(forKey:key("sbx.dialog")); dialogAmount = defaults.double(forKey:key("sbx.dialogAmount"))
            smartVolume = defaults.bool(forKey:key("sbx.smartVolume")); smartVolumeAmount = defaults.double(forKey:key("sbx.smartVolumeAmount"))
            if let raw = defaults.string(forKey:key("sbx.smartMode")), let value = SmartVolumeMode(rawValue:raw) { smartMode = value }
            if defaults.object(forKey:key("sbx.bass")) != nil { sbxBass = defaults.bool(forKey:key("sbx.bass")) }
            if defaults.object(forKey:key("sbx.bassAmount")) != nil { sbxBassAmount = defaults.double(forKey:key("sbx.bassAmount")) }
            if defaults.object(forKey:key("sbx.bassCrossover")) != nil {
                let savedCrossover = defaults.double(forKey:key("sbx.bassCrossover"))
                // Builds before 1.0 stored this frequency incorrectly as 0...1.
                sbxBassCrossover = savedCrossover >= 10 ? savedCrossover : 80
            }
        }
        if storedSections.contains(.equalizer) {
            eqEnabled = defaults.bool(forKey:key("eq.enabled")); eqLevel = defaults.double(forKey:key("eq.level"))
            if let raw = defaults.string(forKey:key("eq.preset")), let value = EQPreset(rawValue:raw) { eqPreset = value }
            if let bands = defaults.dictionary(forKey:key("eq.bands")) as? [String:Double] {
                for band in EQBand.allCases { if let value = bands[band.rawValue] { eq[band] = value } }
            }
        }
        if storedSections.contains(.speakers) {
            if let value = SpeakerLayout(rawValue:defaults.double(forKey:key("speakers.layout"))) { layout = value }
            if let value = SpeakerOutputTarget(rawValue:UInt32(defaults.integer(forKey:key("speakers.outputTarget")))) { speakerOutputTarget = value }
            bassRedirection = defaults.bool(forKey:key("speakers.bassRedirection")); crossover = defaults.double(forKey:key("speakers.crossover"))
            subwooferGain = defaults.bool(forKey:key("speakers.subwooferGain")); directMode = defaults.bool(forKey:key("speakers.directMode"))
            spdifDirect = defaults.bool(forKey:key("speakers.spdifDirect"))
            if let value = SpeakerModel(rawValue:UInt8(defaults.integer(forKey:key("speakers.model")))) { speakerModel = value }
            if let value = SpeakerVoicing(rawValue:UInt8(defaults.integer(forKey:key("speakers.voicing")))) { speakerVoicing = value }
            frontFullRange = defaults.bool(forKey:key("speakers.frontFullRange")); rearFullRange = defaults.bool(forKey:key("speakers.rearFullRange"))
            highPowerAmplification = defaults.bool(forKey:key("speakers.highPower")); headphoneSurroundOverSpeakerOutput = defaults.bool(forKey:key("speakers.headphoneSurround"))
            if let values = defaults.dictionary(forKey:key("speakers.levels")) as? [String:Double] {
                for channel in CalibrationChannel.allCases { if let value = values[channel.rawValue] { calibrationLevel[channel] = value } }
            }
            if let values = defaults.dictionary(forKey:key("speakers.polarity")) as? [String:Bool] {
                for channel in CalibrationChannel.allCases { if let value = values[channel.rawValue] { invertedPolarity[channel] = value } }
            }
            if let values = defaults.dictionary(forKey:key("speakers.distances")) as? [String:Double] {
                for channel in CalibrationChannel.allCases { if let value = values[channel.rawValue] { calibrationDistanceCM[channel] = value } }
            }
        }
        if storedSections.contains(.cinematic), let raw = defaults.string(forKey:key("cinematic.dolby")), let value = DolbyDRC(rawValue:raw) { dolby = value }
        if storedSections.contains(.advanced) {
            scout = defaults.bool(forKey:key("advanced.scout")); autoStandby = defaults.bool(forKey:key("advanced.autoStandby"))
        }
        if storedSections.contains(.mixer) {
            if defaults.object(forKey:key("mixer.masterMute")) != nil {
                savedMasterMute = defaults.bool(forKey:key("mixer.masterMute"))
            }
            if let values = defaults.dictionary(forKey:key("mixer.playbackMutes")) as? [String:Bool] {
                for source in PlaybackSource.allCases {
                    savedPlaybackMutes[source] = values[String(format: "%02X", source.rawValue)]
                }
            }
        }
    }
    func setMasterVolume(){ guard !suppressUIWrites else { return }; if !X7SetMasterVolume(Float(masterVolume)){ masterStateAvailable=false; lastError="Could not set X7 CoreAudio master volume." } else { lastError=nil } }
    func setMasterMute(){
        guard !suppressUIWrites else { return }
        if !X7SetMasterMute(masterMute) {
            masterStateAvailable=false; lastError="Could not set X7 CoreAudio mute."
        } else {
            savedMasterMute = masterMute
            persist(.mixer)
            lastError=nil
        }
    }

    private func restoreSavedMasterMute() {
        guard let savedMasterMute, masterStateAvailable else { return }
        if X7SetMasterMute(savedMasterMute) { masterMute = savedMasterMute }
    }

    func refreshPlaybackMixer(restoreSavedMutes: Bool = false) {
        guard connected else { return }
        suppressWritesUntilNextRunLoop()
        for source in PlaybackSource.allCases {
            refreshPlaybackSource(source)
            guard restoreSavedMutes,
                  let muted = savedPlaybackMutes[source],
                  playbackSources[source]?.available == true else { continue }
            if X7SetPlaybackSourceMute(source.rawValue, muted) == 0 {
                playbackSources[source]?.muted = muted
            }
        }
    }

    func refreshPlaybackSource(_ source: PlaybackSource) {
        var minimum: Int16 = -80
        var maximum: Int16 = 0
        let limitsStatus = X7ReadPlaybackSourceVolumeLimits(source.rawValue, &minimum, &maximum)
        var left: Int16 = 0
        var right: Int16 = 0
        var muted = ObjCBool(false)
        let leftStatus = X7ReadPlaybackSourceVolume(source.rawValue, &left, 1)
        let rightStatus = X7ReadPlaybackSourceVolume(source.rawValue, &right, 2)
        let muteStatus = X7ReadPlaybackSourceMute(source.rawValue, &muted)
        guard limitsStatus == 0, leftStatus == 0, rightStatus == 0, muteStatus == 0 else {
            playbackSources[source]?.available = false
            return
        }

        let leftDB = Double(left)
        let rightDB = Double(right)
        let volumeDB = max(leftDB, rightDB)
        var balance = 0.0
        if leftDB < rightDB {
            balance = (rightDB - leftDB) / max(1, rightDB - Double(minimum))
        } else if rightDB < leftDB {
            balance = -(leftDB - rightDB) / max(1, leftDB - Double(minimum))
        }
        let normalizedBalance = abs(balance) < 0.0005 ? 0 : max(-1, min(1, balance))
        playbackSources[source] = PlaybackSourceState(
            volumeDB: volumeDB,
            balance: normalizedBalance,
            muted: muted.boolValue,
            minimumDB: Double(minimum),
            maximumDB: Double(maximum),
            available: true
        )
    }

    private func playbackChannelLevels(for source: PlaybackSource) -> (Int16, Int16)? {
        guard let state = playbackSources[source] else { return nil }
        let balance = max(-1, min(1, state.balance))
        var left = state.volumeDB
        var right = state.volumeDB
        if balance > 0 {
            left -= balance * (state.volumeDB - state.minimumDB)
        } else if balance < 0 {
            right -= -balance * (state.volumeDB - state.minimumDB)
        }
        return (Int16(left.rounded()), Int16(right.rounded()))
    }

    func setPlaybackVolume(_ source: PlaybackSource) {
        guard !suppressUIWrites else { return }
        guard let (left, right) = playbackChannelLevels(for: source) else { return }
        let leftStatus = X7SetPlaybackSourceVolume(source.rawValue, left, 1)
        let rightStatus = leftStatus == 0 ? X7SetPlaybackSourceVolume(source.rawValue, right, 2) : leftStatus
        handlePlaybackStatus(rightStatus, source: source, operation: "volume")
    }

    func setPlaybackMute(_ source: PlaybackSource) {
        guard !suppressUIWrites else { return }
        guard let state = playbackSources[source] else { return }
        let status = X7SetPlaybackSourceMute(source.rawValue, state.muted)
        handlePlaybackStatus(status, source: source, operation: "mute")
        if status == 0 {
            savedPlaybackMutes[source] = state.muted
            persist(.mixer)
        }
    }

    private func handlePlaybackStatus(_ status: Int32, source: PlaybackSource, operation: String) {
        if status == 0 {
            lastError = nil
        } else {
            playbackSources[source]?.available = false
            lastError = String(format: "Could not set %@ %@ (IOKit 0x%08X).", source.label, operation, status)
        }
    }
}
