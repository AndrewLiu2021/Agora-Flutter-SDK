//
//  YJAudioEncoder.h
//  Audio-HelloWord
//
//  Created by kern on 3/26/20.
//  Copyright © 2020 yangjie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

//@import AudioToolbox;
//@import AVFoundation;

NS_ASSUME_NONNULL_BEGIN

@interface YJAudioEncoder : NSObject
@property (assign,nonatomic) AudioStreamBasicDescription inputDes;
@property (assign,nonatomic) AudioStreamBasicDescription outputDes;
@property (assign,nonatomic) NSInteger sampleCount; //每秒采样多少次

- (instancetype)initWithInputDes:(AudioStreamBasicDescription)inputDes outputDes:(AudioStreamBasicDescription)outputDes isHardEncoder:(BOOL)isHardEncoder;
- (instancetype)initWithSampleRate:(NSInteger)sampleRate sample:(NSUInteger)sample  channelNum:(NSInteger)channels bytesPerFrame:(NSInteger)bytesPerFrame;
+ (instancetype)pcmToAACEncoder;
// 转换方法
- (NSData*)convertSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (NSData*)convertAudioFrameData:(NSData*)audioFrameData;
- (void)reset;
// 设置输出码率
- (void)setoutputBitrate:(UInt32)biterate;
@end

NS_ASSUME_NONNULL_END
