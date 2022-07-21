//
//  AACCodec.swift
//  agora_rtc_engine
//
//  Created by Cyril on 2020/11/24.
//

import Foundation
import AVFoundation

class AudioBufferFormatHelper {
    
    static func PCMFormat() -> AVAudioFormat? {
        return AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 44100, channels: 1, interleaved: true)
    }
    
    static func AACFormat() -> AVAudioFormat? {
        var outDesc = AudioStreamBasicDescription(
            mSampleRate: 44100,
            mFormatID: kAudioFormatMPEG4AAC,
            mFormatFlags: 0,
            mBytesPerPacket: 0,
            mFramesPerPacket: 0,
            mBytesPerFrame: 0,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 0,
            mReserved: 0)
        return AVAudioFormat(streamDescription: &outDesc)
    }
}

@objc public class AACCodec: NSObject {
    
    @objc public static func encode(data: Data, from format: AVAudioFormat) -> Data {
        let buffer = data.makePCMBuffer(format: format)!
        let aacBuffer = AACCodec.convertToAAC(from: buffer, error: nil)!
        let aacData = aacBuffer.toData()
        let packetDescriptions = Array(UnsafeBufferPointer(start: aacBuffer.packetDescriptions, count: Int(aacBuffer.packetCount)))
        let aacReverseBuffer = AACCodec.convertToAAC(from: aacData, packetDescriptions: packetDescriptions)!
        return aacReverseBuffer.toData()
//        // was aacBuffer2
//        let pcmReverseBuffer = AACCodec.convertToPCM(from: aacReverseBuffer, error: nil)
    }
    
    static var lpcmToAACConverter: AVAudioConverter! = nil
    
    static func convertToAAC(from buffer: AVAudioBuffer, error outError: NSErrorPointer) -> AVAudioCompressedBuffer? {
        let outputFormat = AudioBufferFormatHelper.AACFormat()
        // 初始化 Converter
        if lpcmToAACConverter == nil {
            let inputFormat = buffer.format
            lpcmToAACConverter = AVAudioConverter(from: inputFormat, to: outputFormat!)
            print("available rates \(lpcmToAACConverter.applicableEncodeBitRates ?? [])")
            lpcmToAACConverter.bitRate = 48000    // have end of stream problems with this, not sure why
        }
        
        let outBuffer = AVAudioCompressedBuffer(format: outputFormat!, packetCapacity: 8, maximumPacketSize: 768)
        self.convert(withConverter:lpcmToAACConverter, from: buffer, to: outBuffer, error: outError)
        
        return outBuffer
    }
    
    static var aacToLPCMConverter: AVAudioConverter! = nil
    
    static func convertToPCM(from buffer: AVAudioBuffer, error outError: NSErrorPointer) -> AVAudioPCMBuffer? {
        
        let outputFormat = AudioBufferFormatHelper.PCMFormat()
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat!, frameCapacity: 4410) else {
            return nil
        }
        
        //init converter once
        if aacToLPCMConverter == nil {
            let inputFormat = buffer.format
            
            aacToLPCMConverter = AVAudioConverter(from: inputFormat, to: outputFormat!)
        }
        
        self.convert(withConverter: aacToLPCMConverter, from: buffer, to: outBuffer, error: outError)
        
        return outBuffer
    }
    
    static func convertToAAC(from data: Data, packetDescriptions: [AudioStreamPacketDescription]) -> AVAudioCompressedBuffer? {
        
        let nsData = NSData(data: data)
        let inputFormat = AudioBufferFormatHelper.AACFormat()
        let maximumPacketSize = packetDescriptions.map { $0.mDataByteSize }.max()!
        let buffer = AVAudioCompressedBuffer(format: inputFormat!, packetCapacity: AVAudioPacketCount(packetDescriptions.count), maximumPacketSize: Int(maximumPacketSize))
        if #available(iOS 11.0, *) {
            buffer.byteLength = UInt32(data.count)
        } else {
            // Fallback on earlier versions
        }
        buffer.packetCount = AVAudioPacketCount(packetDescriptions.count)
        
        buffer.data.copyMemory(from: nsData.bytes, byteCount: nsData.length)
        buffer.packetDescriptions!.pointee.mDataByteSize = UInt32(data.count)
        buffer.packetDescriptions!.initialize(from: packetDescriptions, count: packetDescriptions.count)
        
        return buffer
    }
    
    
    private static func convert(withConverter: AVAudioConverter, from sourceBuffer: AVAudioBuffer, to destinationBuffer: AVAudioBuffer, error outError: NSErrorPointer) {
        // input each buffer only once
        var newBufferAvailable = true
        
        let inputBlock : AVAudioConverterInputBlock = {
            inNumPackets, outStatus in
            if newBufferAvailable {
                outStatus.pointee = .haveData
                newBufferAvailable = false
                return sourceBuffer
            } else {
                outStatus.pointee = .noDataNow
                return nil
            }
        }
        
        let status = withConverter.convert(to: destinationBuffer, error: outError, withInputFrom: inputBlock)
        // print("status: \(status.rawValue)")
    }
}

extension AVAudioCompressedBuffer {
    func toData() -> Data {
        let length: UInt32
        if #available(iOS 11.0, *) {
            length = byteLength
        } else {
            length = audioBufferList.pointee.mBuffers.mDataByteSize
        }
        return Data(bytes: data, count: Int(length))
    }
}
