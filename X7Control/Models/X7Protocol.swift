import Foundation

enum X7Output: String, CaseIterable, Identifiable { case speakers = "Speakers", headphones = "Headphones"; var id: String { rawValue } }
enum SmartVolumeMode: String, CaseIterable, Identifiable { case normal = "Normal", loud = "Loud", night = "Night"; var id:String{rawValue} }
enum DolbyDRC: String, CaseIterable, Identifiable { case full = "Full", normal = "Normal", night = "Night"; var id:String{rawValue} }
enum SpeakerModel: UInt8, CaseIterable, Identifiable {
    case other = 0, emuXM7 = 1
    var id: UInt8 { rawValue }
    var label: String { self == .other ? "Other Speakers" : "E-MU XM7" }
}
enum SpeakerVoicing: UInt8, CaseIterable, Identifiable {
    case energetic = 0, neutral = 1, warm = 2
    var id: UInt8 { rawValue }
    var label: String { switch self { case .energetic: "Energetic"; case .neutral: "Neutral"; case .warm: "Warm" } }
}
enum SpeakerOutputTarget: UInt32, CaseIterable, Identifiable {
    case line = 1, amplifier = 2, both = 3
    var label: String { switch self { case .line: "Line Out"; case .amplifier: "Amplifier Out"; case .both: "Line + Amplifier Out" } }
    var id: UInt32 { rawValue }
}
enum FrontCenterPosition: String, CaseIterable, Identifiable {
    case above = "Above Screen"
    case below = "Below Screen"
    var id: String { rawValue }
    var deviceValue: Float { self == .above ? 1 : 0 }
}
enum SpeakerLayout: Double, CaseIterable, Identifiable {
    case stereo=1, twoOne=2, threeZero=3, threeOne=4, fourZero=5, fourOne=6, fiveZero=7, fiveOne=8
    var id: Double { rawValue }
    var label: String { switch self { case .stereo:"2.0"; case .twoOne:"2.1"; case .threeZero:"3.0"; case .threeOne:"3.1"; case .fourZero:"4.0"; case .fourOne:"4.1"; case .fiveZero:"5.0"; case .fiveOne:"5.1" } }
    var speakers: String { switch self {
    case .stereo: "Front L/R"
    case .twoOne: "Front L/R + Subwoofer"
    case .threeZero: "Front L/R + Center"
    case .threeOne: "Front L/R + Center + Subwoofer"
    case .fourZero: "Front L/R + Rear L/R"
    case .fourOne: "Front L/R + Rear L/R + Subwoofer"
    case .fiveZero: "Front L/R + Center + Rear L/R"
    case .fiveOne: "Front L/R + Center + Rear L/R + Subwoofer"
    } }
    var descriptiveLabel: String { "\(label) — \(speakers)" }
    var hasRear: Bool { self == .fourZero || self == .fourOne || self == .fiveZero || self == .fiveOne }
    var hasCenter: Bool { self == .threeZero || self == .threeOne || self == .fiveZero || self == .fiveOne }
    var hasSubwoofer: Bool { self == .twoOne || self == .threeOne || self == .fourOne || self == .fiveOne }
    var hardwareMask: UInt32 { switch self {
    case .stereo: 0x00003003
    case .twoOne: 0x0000B007
    case .threeZero: 0x00007007
    case .threeOne: 0x0000F00F
    case .fourZero: 0x00033033
    case .fourOne: 0x0003B03B
    case .fiveZero: 0x00037037
    case .fiveOne: 0x0003F03F
    } }
}
enum EQBand: String, CaseIterable, Identifiable {
    case hz31="31", hz62="62", hz125="125", hz250="250", hz500="500", k1="1K", k2="2K", k4="4K", k8="8K", k16="16K"
    var id:String{rawValue}
    var parameter: UInt8 { UInt8(0x16 + EQBand.allCases.firstIndex(of:self)! * 2) }
}
enum EQPreset: String, CaseIterable, Identifiable {
    case flat="Flat", acoustic="Acoustic", classical="Classical", country="Country", dance="Dance", jazz="Jazz", newAge="New Age", pop="Pop", rock="Rock", vocal="Vocal"
    var id:String{rawValue}
    var values:[Float] { switch self {
    case .flat: [0,0,0,0,0,0,0,0,0,0,0]
    case .acoustic: [0,0,1,2,0,0,0,0,2,2,2]
    case .classical: [0,0,6,6,3,0,0,0,0,3,3]
    case .country: [0,-1,0,1,1,1,0,0,2,3,4]
    case .dance: [0,-1,2,3,4,-1,-1,0,0,4,4]
    case .jazz: [0,0,0,1,4,4,4,0,1,3,3]
    case .newAge: [0,0,2,2,0,0,0,1,2,2,2]
    case .pop: [0,-2,0,2,2,0,-1,-1,0,3,6]
    case .rock: [0,-1,-1,1,2,-1,-1,0,0,4,4]
    case .vocal: [0,-2,-1,-1,0,3,4,3,0,0,1]
    } }
}

enum CalibrationChannel: String, CaseIterable, Identifiable {
    case frontLeft="Front Left", frontRight="Front Right", center="Center", subwoofer="Subwoofer", rearLeft="Rear Left", rearRight="Rear Right"
    var id:String{rawValue}
    var levelParam:UInt8 { switch self { case .frontLeft:0x42; case .frontRight:0x44; case .center:0x46; case .subwoofer:0x48; case .rearLeft:0x4A; case .rearRight:0x4C } }
    var polarityParam:UInt8 { switch self { case .frontLeft:0x52; case .frontRight:0x54; case .center:0x56; case .subwoofer:0x58; case .rearLeft:0x5A; case .rearRight:0x5C } }
    var distanceParam:UInt8 { switch self { case .frontLeft:0x62; case .frontRight:0x64; case .center:0x66; case .subwoofer:0x68; case .rearLeft:0x6A; case .rearRight:0x6C } }
}

extension SpeakerLayout {
    var calibrationChannels: [CalibrationChannel] {
        var channels: [CalibrationChannel] = [.frontLeft]
        if hasCenter { channels.append(.center) }
        channels.append(.frontRight)
        if hasRear { channels.append(contentsOf: [.rearLeft, .rearRight]) }
        if hasSubwoofer { channels.append(.subwoofer) }
        return channels
    }
}

enum PlaybackSource: UInt8, CaseIterable, Identifiable {
    case mic = 0x0F, lineIn = 0x10, bluetooth = 0x11, spdifIn = 0x12, usbHost = 0x13
    var id: UInt8 { rawValue }
    var label: String { switch self {
    case .mic: "Mic-In/Mic Array"
    case .lineIn: "Line In"
    case .bluetooth: "Bluetooth"
    case .spdifIn: "SPDIF-In"
    case .usbHost: "USB Host"
    } }
}

struct PlaybackSourceState {
    var volumeDB: Double = 0
    var balance: Double = 0
    var muted = false
    var minimumDB: Double = -80
    var maximumDB: Double = 0
    var available = false
}

struct X7Packets {
    static func beFloat(_ v: Float) -> [UInt8] { var bits=v.bitPattern.bigEndian; return withUnsafeBytes(of:&bits){Array($0)} }
    static func dsp(_ parameter: UInt8, namespace: UInt8 = 0x96, value: Float) -> [UInt8] {
        [0x20,0x00,0x16,0x0A,0xD5,0x02,0x08,parameter,0x20,namespace] + beFloat(value) + [0x4D,0x00]
    }
    static func output(_ output:X7Output)->[UInt8] { output == .speakers ? [0x23,0x4E,0x00,0x00,0x00,0x80] : [0x23,0x4E,0x01,0x00,0x00,0x00] }
    // The X7 exposes SBX master as the same hardware toggle used by the
    // illuminated front-panel/panel power button; it is not a boolean DSP
    // parameter like the individual SBX effects.
    static func sbxMasterToggle() -> [UInt8] { [0x23,0x4D] }
    static func headphoneHighGain(_ on: Bool) -> [UInt8] { [0x23,0x45,on ? 1:0] }
    static func littleEndian(_ value: UInt32) -> [UInt8] { [UInt8(value & 0xff), UInt8((value >> 8) & 0xff), UInt8((value >> 16) & 0xff), UInt8((value >> 24) & 0xff)] }
    static func speakerLayout(_ layout: SpeakerLayout) -> [UInt8] { [0x23,0x4E] + littleEndian(layout.hardwareMask) }
    static func speakerOutputTarget(_ target: SpeakerOutputTarget) -> [UInt8] { [0x5A,0x2C,0x05,0x00] + littleEndian(target.rawValue) }
    static func highPowerAmplification(_ on: Bool) -> [UInt8] { [0x23,0x59,on ? 1:0] }
    static func headphoneSurroundOverSpeakerOutput(_ on: Bool) -> [UInt8] { [0x5A,0x39,0x03,0x00,0x0A,on ? 1:0] }
    static func direct(_ on:Bool)->[UInt8] { [0x23,0x43,on ? 1:0] }
    static func spdifDirect(_ on:Bool)->[UInt8] { [0x23,0x4B,on ? 1:0] }
    static func scout(_ on:Bool)->[UInt8] { [0x23,0x23,0x02,on ? 1:0,0x03,0,0,0x04] }
    static func standby(_ on:Bool)->[UInt8] { [0x5A,0x39,0x03,0,0x0B,on ? 1:0] }
    static func speakerModel(_ model:SpeakerModel)->[UInt8] { [0x5A,0x2A,0x03,0,model.rawValue,0] }
    static func speakerVoicing(_ voicing:SpeakerVoicing)->[UInt8] { [0x5A,0x2B,0x03,0,voicing.rawValue,0] }
}
