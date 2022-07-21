//
//  AudioSteamPlayer.swift
//  agora_rtc_engine
//
//  Created by Cyril on 2020/11/24.
//

import Foundation

struct AudioSteamPlayer {
    
    var playerEngine = AVAudioEngine()
    let player = AVAudioPlayerNode()
    
    lazy var pcmFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 44100, channels: 1, interleaved: true)!
    lazy var playFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: true)! // 不用 .pcmFormatFloat32, player 会 crash
    
    mutating func play(data: Data) {
        let buffer = data.makePCMBuffer(format: pcmFormat)!
        play(buffer: buffer)
    }
    
    mutating func play(buffer: AVAudioPCMBuffer) {
        startAudioTrack()
        self.player.scheduleBuffer(buffer, at: nil, options: .interrupts)
    }
    
    /// 开始播放
    private mutating func startAudioTrack() {
        if (!player.isPlaying) {
            try? setAudioSession()
            
            playerEngine.attach(player)
            playerEngine.connect(player, to: playerEngine.mainMixerNode, format: playFormat)
            try! playerEngine.start()
            player.play()
        }
    }
    public func setAudioSession() throws {
//        try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: .defaultToSpeaker)
//        try AVAudioSession.sharedInstance().setMode(.voiceChat) // 非 Speaker 时使用
//        try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
//        try AVAudioSession.sharedInstance().setActive(true)
    }
    
}


// MARK: - PCM
extension Data {
    
    init(buffer: AVAudioBuffer, time: AVAudioTime? = nil) {
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        self.init(bytes: audioBuffer.mData!, count: Int(audioBuffer.mDataByteSize))
    }
    
    func makePCMBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let streamDesc = format.streamDescription.pointee
        let frameCapacity = UInt32(count) / streamDesc.mBytesPerFrame
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else { return nil }
        
        buffer.frameLength = buffer.frameCapacity
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        
        withUnsafeBytes { (bufferPointer) in
            guard let addr = bufferPointer.baseAddress else { return }
            audioBuffer.mData?.copyMemory(from: addr, byteCount: Int(audioBuffer.mDataByteSize))
        }
        
        return buffer
    }
}
