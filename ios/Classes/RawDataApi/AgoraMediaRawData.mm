//
//  AgoraVideoRawData.m
//  OpenVideoCall
//
//  Created by CavanSu on 26/02/2018.
//  Copyright © 2018 Agora. All rights reserved.
//

#import "AgoraMediaRawData.h"
#import <Flutter/Flutter.h>

//#import <objc/runtime.h>
//#if __has_include(<agora_rtc_engine/agora_rtc_engine-Swift.h>)
//#import <agora_rtc_engine/agora_rtc_engine-Swift.h>
//#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
//#import "agora_rtc_engine-Swift.h"
//#endif

@implementation AgoraVideoRawDataFormatter
- (instancetype)init {
    if (self = [super init]) {
        self.mirrorApplied = false;
        self.rotationApplied = false;
        self.type = 0;
    }
    return self;
}
@end

@implementation AgoraVideoRawData

@end

@implementation AgoraAudioRawData

-(NSArray *)toFlutterRawDataWithIsPlayback:(BOOL)isPlayback encoder:(YJAudioEncoder*)encoder {
    NSData *data = [NSData dataWithBytes: _buffer length: _bufferSize];
    if (isPlayback) {

    }else {
        data = [encoder convertAudioFrameData:data];
    }
    FlutterStandardTypedData *bytes = [FlutterStandardTypedData typedDataWithBytes: data];
    return @[bytes, @(_samples), @(_bytesPerSample), @(_channels), @(_samplesPerSec)];
}

//-(NSData *)encodeWithData:(NSData *)data {
//    return [AACCodec encodeWithData:data from:[self format]];
//}
//
//-(AVAudioFormat *)format {
//    AVAudioCommonFormat commonFormat;
//    switch (_bytesPerSample) {
//        case 2:
//            commonFormat = AVAudioPCMFormatInt16;
//            break;
//        case 4:
//            commonFormat = AVAudioPCMFormatInt32;
//            break;
//        case 8:
//            commonFormat = AVAudioPCMFormatFloat64;
//            break;
//        default:
//            commonFormat = AVAudioOtherFormat;
//            break;
//    }
//    return [[AVAudioFormat alloc] initWithCommonFormat:commonFormat sampleRate: (double)_samplesPerSec channels: (AVAudioChannelCount)_channels interleaved:true];
//}

@end

@implementation AgoraPacketRawData

@end

