import AudioToolbox
import AVFoundation
import Foundation

/// Where the sound of a station comes from.
protocol SoundSource: AnyObject {
    @MainActor func start()
    @MainActor func stop()
    @MainActor func hold(_ on: Bool)
}

/// Finds MP3 and AAC packets in a flow of bytes and turns them into sound. Used by one thread at a time.
final class SoundDecoder {
    struct Format { var kind = "", rate = 0.0, channels = 2, kbps: Double? }

    var onFormat: ((Format) -> Void)?
    var onSound: ((AVAudioPCMBuffer) -> Void)?
    /// Called once, after some seconds of sound: kilobits per second.
    var onMeasured: ((Double) -> Void)?
    private(set) var gotSound = false
    /// The flow cannot be understood.
    private(set) var failed = false

    private var stream: AudioFileStreamID?
    private var input: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var bytes = 0
    private var frames = 0
    private var measured = false

    /// `type` is what the server says: "audio/aac", "audio/mpeg"…
    init(type: String) {
        let hint: AudioFileTypeID = type.contains("aac") ? kAudioFileAAC_ADTSType : type.contains("mpeg") || type.contains("mp3") ? kAudioFileMP3Type : 0
        let me = Unmanaged.passUnretained(self).toOpaque()
        AudioFileStreamOpen(me, { me, _, property, _ in
            Unmanaged<SoundDecoder>.fromOpaque(me).takeUnretainedValue().property(property)
        }, { me, _, count, data, packets in
            Unmanaged<SoundDecoder>.fromOpaque(me).takeUnretainedValue().packets(Int(count), data, packets)
        }, hint, &stream)
        if stream == nil { failed = true }
    }

    deinit { if let stream { AudioFileStreamClose(stream) } }

    func parse(_ d: Data) {
        guard let stream, !d.isEmpty else { return }
        let status = d.withUnsafeBytes { p in
            p.baseAddress.map { AudioFileStreamParseBytes(stream, UInt32(d.count), $0, []) } ?? noErr
        }
        if status != noErr, !gotSound { failed = true }
    }

    private func property(_ id: AudioFileStreamPropertyID) {
        guard id == kAudioFileStreamProperty_ReadyToProducePackets, let stream else { return }
        var asbd = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout.size(ofValue: asbd))
        guard AudioFileStreamGetProperty(stream, kAudioFileStreamProperty_DataFormat, &size, &asbd) == noErr else { return failed = true }
        // AAC+ is described as plain AAC first; the list names the full version, the best one first
        var listSize: UInt32 = 0
        if AudioFileStreamGetPropertyInfo(stream, kAudioFileStreamProperty_FormatList, &listSize, nil) == noErr, listSize > 0 {
            var list = [AudioFormatListItem](repeating: AudioFormatListItem(), count: Int(listSize) / MemoryLayout<AudioFormatListItem>.stride)
            if AudioFileStreamGetProperty(stream, kAudioFileStreamProperty_FormatList, &listSize, &list) == noErr,
               let best = list.first(where: { [kAudioFormatMPEG4AAC_HE_V2, kAudioFormatMPEG4AAC_HE].contains($0.mASBD.mFormatID) }) {
                asbd = best.mASBD
            }
        }
        guard asbd.mSampleRate > 0, asbd.mFormatID != kAudioFormatLinearPCM,
              let from = AVAudioFormat(streamDescription: &asbd),
              let to = AVAudioFormat(standardFormatWithSampleRate: asbd.mSampleRate, channels: max(1, asbd.mChannelsPerFrame)),
              let c = AVAudioConverter(from: from, to: to) else { return failed = true }
        var cookieSize: UInt32 = 0
        if AudioFileStreamGetPropertyInfo(stream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, nil) == noErr, cookieSize > 0 {
            var cookie = Data(count: Int(cookieSize))
            let ok = cookie.withUnsafeMutableBytes { AudioFileStreamGetProperty(stream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, $0.baseAddress!) }
            if ok == noErr { c.magicCookie = cookie }
        }
        input = from
        converter = c
        var f = Format(kind: Self.name(asbd.mFormatID), rate: asbd.mSampleRate, channels: Int(asbd.mChannelsPerFrame))
        var rate: UInt32 = 0
        size = 4
        if AudioFileStreamGetProperty(stream, kAudioFileStreamProperty_BitRate, &size, &rate) == noErr, rate > 0 {
            f.kbps = rate < 1000 ? Double(rate) : (Double(rate) / 1000).rounded()
        }
        onFormat?(f)
    }

    private static func name(_ id: AudioFormatID) -> String {
        switch id {
        case kAudioFormatMPEGLayer3: "MP3"
        case kAudioFormatMPEGLayer2: "MP2"
        case kAudioFormatMPEG4AAC: "AAC"
        case kAudioFormatMPEG4AAC_HE, kAudioFormatMPEG4AAC_HE_V2: "AAC+"
        case kAudioFormatFLAC: "FLAC"
        default: "AUDIO"
        }
    }

    private func packets(_ count: Int, _ data: UnsafeRawPointer, _ descriptions: UnsafeMutablePointer<AudioStreamPacketDescription>?) {
        guard let converter, let input, let descriptions, count > 0 else { return }
        let sizes = (0..<count).map { Int(descriptions[$0].mDataByteSize) }
        let packed = AVAudioCompressedBuffer(format: input, packetCapacity: AVAudioPacketCount(count), maximumPacketSize: max(1, sizes.max() ?? 1))
        guard let to = packed.packetDescriptions else { return }
        var offset = 0
        for i in 0..<count {
            memcpy(packed.data + offset, data + Int(descriptions[i].mStartOffset), sizes[i])
            to[i] = AudioStreamPacketDescription(mStartOffset: Int64(offset), mVariableFramesInPacket: 0, mDataByteSize: UInt32(sizes[i]))
            offset += sizes[i]
        }
        packed.byteLength = UInt32(offset)
        packed.packetCount = AVAudioPacketCount(count)

        let perPacket = input.streamDescription.pointee.mFramesPerPacket
        if !measured, perPacket > 0 {
            bytes += offset
            frames += Int(perPacket) * count
            let seconds = Double(frames) / input.sampleRate
            if seconds > 4 {
                measured = true
                onMeasured?(StationFacts.standard(Double(bytes) * 8 / seconds / 1000))
            }
        }
        let capacity = AVAudioFrameCount(max(perPacket, 1152)) * AVAudioFrameCount(count + 2)
        var fed = false
        while let out = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: capacity) {
            var error: NSError?
            let status = converter.convert(to: out, error: &error) { _, state in
                if fed {
                    state.pointee = .noDataNow
                    return nil
                }
                fed = true
                state.pointee = .haveData
                return packed
            }
            if status == .error {
                converter.reset() // a damaged piece: go on with the next one
                return
            }
            if out.frameLength > 0 {
                gotSound = true
                onSound?(out)
            }
            if status != .haveData || out.frameLength == 0 { return }
        }
    }
}
