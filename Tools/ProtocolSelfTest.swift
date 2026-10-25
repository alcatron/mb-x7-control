import Foundation

@main
struct ProtocolSelfTest {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            FileHandle.standardError.write(Data("Protocol self-test failed: \(message)\n".utf8))
            exit(1)
        }
    }

    static func main() {
        let crossover = X7Packets.dsp(0x2E, value: 80)
        require(crossover.count == 14, "DSP packets must be 14 bytes")
        require(Array(crossover.prefix(10)) == [0x20,0x00,0x16,0x0A,0xD5,0x02,0x08,0x2E,0x20,0x96], "SBX Bass crossover header")
        require(Array(crossover.suffix(4)) == [0x42,0xA0,0x00,0x00], "SBX Bass crossover float")

        require(X7Packets.dsp(0x34, value: 0).count == 14, "Front Full-Range packet")
        require(X7Packets.dsp(0x38, value: 1).count == 14, "Rear Full-Range packet")
        require(X7Packets.speakerLayout(.twoOne) == [0x20,0x00,0x16,0x0A,0xD5,0x02,0x08,0x08,0x20,0x80,0x40,0x00,0x00,0x00], "2.1 layout packet")
        require(X7Packets.disableSpeakerLayoutForHeadphones() == [0x20,0x00,0x16,0x0A,0xD5,0x02,0x08,0x08,0x20,0x80,0x00,0x00,0x00,0x00], "headphone layout-disable packet")
        require(X7Packets.sbxMaster(true) == [0x23,0x23,0x01,0x01], "SBX master packet")
        require(X7Packets.scout(false) == [0x23,0x23,0x02,0x00], "Scout packet")
        require(X7Packets.longestSpeakerDistance(160) == [0x23,0x49,0x02,0x02,0x02,0x00,0xA0,0x00], "longest-distance packet")
        require(X7Packets.output(.speakers) == [0x23,0x4E,0x00,0x00,0x00,0x80], "speaker-output packet")
        require(X7Packets.output(.headphones) == [0x23,0x4E,0x01,0x00,0x00,0x00], "headphone-output packet")

        print("Protocol self-test passed.")
    }
}
