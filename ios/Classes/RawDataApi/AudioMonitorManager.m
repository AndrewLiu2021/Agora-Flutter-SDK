//
//  AudioMonitorManager.m
//  agora_rtc_engine
//
//  Created by Leo on 16/7/22.
//

#import "AudioMonitorManager.h"
#if __has_include(<agora_rtc_engine/agora_rtc_engine-Swift.h>)
#import <agora_rtc_engine/agora_rtc_engine-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "agora_rtc_engine-Swift.h"
#endif

@interface AudioMonitorManager()<AgoraAudioDataPluginDelegate>

@end

static AudioMonitorManager *manager = nil;

@implementation AudioMonitorManager

+ (instancetype)shared{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    return manager;
}

- (void)setupRawPlugin:(AgoraRtcEngineKit *)agoraKit {
    _agoraMediaDataPlugin = [AgoraMediaDataPlugin mediaDataPluginWithAgoraKit: agoraKit];
    
    ObserverAudioType type = ObserverAudioTypeRecordAudio | ObserverAudioTypePlaybackAudio | ObserverAudioTypePlaybackAudioFrameBeforeMixing | ObserverAudioTypeMixedAudio;
    
    [_agoraMediaDataPlugin registerAudioRawDataObserver:type];
    
    _agoraMediaDataPlugin.audioDelegate = self;
}

// audio data plugin, here you can process raw audio data
// note this all happens in CPU so it comes with a performance cost

/// Retrieves the recorded audio frame.
- (AgoraAudioRawData *)mediaDataPlugin:(AgoraMediaDataPlugin *)mediaDataPlugin didRecordAudioRawData:(AgoraAudioRawData *)audioRawData {
//    [audioRawData toFlutterRawDataWithIsPlayback: NO];
    [self setUpAudioEncoder:audioRawData];
    self.emitter(RtcChannelEvents.RecordFrameEvent, @{@"data" : [audioRawData toFlutterRawDataWithIsPlayback: NO encoder:self.encoder]});
    return audioRawData;
}

/// Retrieves the audio playback frame for getting the audio.
- (AgoraAudioRawData *)mediaDataPlugin:(AgoraMediaDataPlugin *)mediaDataPlugin willPlaybackAudioRawData:(AgoraAudioRawData *)audioRawData {
    return audioRawData;
}

/// Retrieves the audio frame of a specified user before mixing.
/// The SDK triggers this callback if isMultipleChannelFrameWanted returns false.
- (AgoraAudioRawData *)mediaDataPlugin:(AgoraMediaDataPlugin *)mediaDataPlugin willPlaybackBeforeMixingAudioRawData:(AgoraAudioRawData *)audioRawData ofUid:(uint)uid {
    return audioRawData;
}

/// Retrieves the mixed recorded and playback audio frame.
- (AgoraAudioRawData *)mediaDataPlugin:(AgoraMediaDataPlugin *)mediaDataPlugin didMixedAudioRawData:(AgoraAudioRawData *)audioRawData {
    return audioRawData;
}

static int const encoderKey = 0x10000000;
static YJAudioEncoder *audioEncoder;

- (void)setUpAudioEncoder:(AgoraAudioRawData *)audioRawData {
    if (self.encoder) {
        return;
    }
    [self setAudioEncoder:[[YJAudioEncoder alloc] initWithSampleRate:audioRawData.samplesPerSec sample:audioRawData.samples channelNum:audioRawData.channels bytesPerFrame:audioRawData.bytesPerSample]];
}

-(YJAudioEncoder *)encoder {
    return objc_getAssociatedObject(self, &encoderKey);
}

- (void)setAudioEncoder:(YJAudioEncoder *)audioEncoder {
    objc_setAssociatedObject(self, &encoderKey, audioEncoder, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
