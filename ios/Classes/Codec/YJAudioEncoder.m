//
//  YJAudioEncoder.m
//  Audio-HelloWord
//
//  Created by kern on 3/26/20.
//  Copyright © 2020 yangjie. All rights reserved.
//

#import "YJAudioEncoder.h"
@interface YJAudioEncoder()
{   //剩下未编码的pcm数据
    char *leftBuffer;
    char *aacBuffer;
    //剩下未编码的长度
    NSInteger leftLength;
}
@property (assign,nonatomic) BOOL isUseHardEncoder;
@property (assign,nonatomic) AudioConverterRef audioConvertRef;
@property (assign,nonatomic) UInt32 outputMaxSize;
@property (strong,nonatomic) NSData* currentPCMAudioData;
@property (assign,nonatomic) UInt32 bufferSise;
@end

@implementation YJAudioEncoder
- (instancetype)initWithInputDes:(AudioStreamBasicDescription)inputDes outputDes:(AudioStreamBasicDescription)outputDes sample:(NSInteger)sample isHardEncoder:(BOOL)isHardEncoder{
    if (self = [super init]) {
        self.inputDes = inputDes;
        self.outputDes = outputDes;
        self.sampleCount = inputDes.mSampleRate / sample;
        self.isUseHardEncoder = isHardEncoder;
        //pcm 数据1packet（帧）包含一个frame，而aac数据一个包含1024frame,所以进行编码的时候，最少要读取buffersize
        
        // 计算bufferSize
//        假设音频采样率 = 8000，采样通道 = 2，位深度 = 16，采样间隔 = 20ms
//    https://blog.csdn.net/li_wen01/article/details/81141085
//        首先我们计算一秒钟总的数据量，采样间隔采用20ms的话，说明每秒钟需采集50次，这个计算大家应该都懂，那么总的数据量计算为
//
//        一秒钟总的数据量 =8000 * 2*16/8 = 32000
//
//        所以每帧音频数据大小 = 32000/50 = 640
//
//        每个通道样本数 = 640/2 = 320
        UInt32 totalData = inputDes.mSampleRate * inputDes.mChannelsPerFrame * inputDes.mBitsPerChannel / 8;
        UInt32 frameData = totalData / _sampleCount;
        UInt32 sampleNum = frameData / inputDes.mChannelsPerFrame;
        
        self.bufferSise = inputDes.mChannelsPerFrame * sampleNum;
        self.bufferSise = 1024*inputDes.mBytesPerFrame*inputDes.mChannelsPerFrame;
        if (!leftBuffer) {
            leftBuffer = malloc(self.bufferSise);
        }
        if (!aacBuffer) {
            aacBuffer = malloc(self.bufferSise);
        }
        [self reset];
    }
    return self;
}

- (void)dealloc {
    [self dispose];
    if (leftBuffer) {
        free(leftBuffer);
    }
    if (aacBuffer) {
        free(aacBuffer);
    }
}

+ (instancetype)pcmToAACEncoder {
    AudioStreamBasicDescription inputDes = {};
    inputDes.mFormatID = kAudioFormatLinearPCM;
    inputDes.mSampleRate = 44100;
    inputDes.mChannelsPerFrame = 1;
    inputDes.mFormatFlags = kAudioFormatFlagsCanonical;
    inputDes.mFramesPerPacket = 1;
    inputDes.mBitsPerChannel = 16;
    inputDes.mBytesPerFrame = 1 * sizeof(SInt16);
    inputDes.mBytesPerPacket = 1*sizeof(SInt16);
    [self printAudioStreamBasicDescription:inputDes];
    AudioStreamBasicDescription outputDes = {};
    outputDes.mFormatID = kAudioFormatMPEG4AAC;
    outputDes.mSampleRate = 44100;
    outputDes.mChannelsPerFrame = 1;
    outputDes.mFormatFlags = kMPEG4Object_AAC_LC;
#if DEBUG
    [self printAudioStreamBasicDescription:outputDes];
#endif
    return [[YJAudioEncoder alloc] initWithInputDes:inputDes outputDes:outputDes sample:441 isHardEncoder:YES];
}


- (instancetype)initWithSampleRate:(NSInteger)sampleRate sample:(NSUInteger)sample  channelNum:(NSInteger)channels bytesPerFrame:(NSInteger)bytesPerFrame {
    
    AudioStreamBasicDescription inputDes = {};
    inputDes.mFormatID = kAudioFormatLinearPCM;
    inputDes.mSampleRate = sampleRate;
    inputDes.mChannelsPerFrame = channels;
    inputDes.mFormatFlags = kAudioFormatFlagsCanonical;
    inputDes.mFramesPerPacket = 1;
    NSInteger mBitsPerChannel = 16;
    if (bytesPerFrame == 2) {
        mBitsPerChannel = 16;
    }else if (bytesPerFrame == 4){
        mBitsPerChannel = 32;
    }else if(bytesPerFrame == 8) {
        mBitsPerChannel = 64;
    }
    inputDes.mBitsPerChannel = mBitsPerChannel;
    inputDes.mBytesPerFrame = channels*bytesPerFrame;
    inputDes.mBytesPerPacket = channels*bytesPerFrame;
  
    AudioStreamBasicDescription outputDes = {};
    outputDes.mFormatID = kAudioFormatMPEG4AAC;
    outputDes.mSampleRate = sampleRate;
    outputDes.mChannelsPerFrame = channels;
    outputDes.mFormatFlags = kMPEG4Object_AAC_LC;
    YJAudioEncoder *encoder = [[YJAudioEncoder alloc] initWithInputDes:inputDes outputDes:outputDes sample:sample isHardEncoder:YES];
    return encoder;
}


- (void)setoutputBitrate:(UInt32)biterate {
    UInt32 outputBitrate = biterate;
    UInt32 propSize = sizeof(outputBitrate);
    
    OSStatus result = AudioConverterSetProperty(_audioConvertRef, kAudioConverterEncodeBitRate, propSize, &outputBitrate);
    
}

- (void)reset {

    const OSType subtype = kAudioFormatMPEG4AAC;
     AudioClassDescription requestedCodecs[2] = {
         {
             kAudioEncoderComponentType,
             subtype,
             kAppleSoftwareAudioCodecManufacturer
         },
         {
             kAudioEncoderComponentType,
             subtype,
             kAppleHardwareAudioCodecManufacturer
         }
     };
     
     OSStatus result = AudioConverterNewSpecific(&_inputDes, &_outputDes, 2, requestedCodecs, &_audioConvertRef);;
    
//    OSStatus result = AudioConverterNew(&_inputDes, &_outputDes, &_audioConvertRef);
    if (result != noErr) {
#if DEBUG
        NSLog(@"create audioEncoder error == %d",result);
#endif
        exit(1);
    }
    //3查询输出的最大值
    UInt32 maxOutputSize= sizeof(_outputMaxSize);
    AudioConverterGetProperty(_audioConvertRef, kAudioConverterPropertyMaximumOutputPacketSize, &maxOutputSize, &_outputMaxSize);
#if DEBUG
    NSLog(@"maxoutSize = %ld",_outputMaxSize);
#endif
    UInt32 outputBitrate = 96000;
    UInt32 propSize = sizeof(outputBitrate);
    
    result = AudioConverterSetProperty(_audioConvertRef, kAudioConverterEncodeBitRate, propSize, &outputBitrate);
    if(result == noErr) {
#if  DEBUG
        NSLog(@"设置码率成功");
#endif
    }
}

- (NSData*)convertSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    
    CFRetain(sampleBuffer);
    CMBlockBufferRef  blockBufferRef = CMSampleBufferGetDataBuffer(sampleBuffer);
    CFRetain(blockBufferRef);
    size_t length = CMBlockBufferGetDataLength(blockBufferRef);
    char *dataBytes = (char*)malloc(length);
    CMBlockBufferCopyDataBytes(blockBufferRef, 0, length, dataBytes);
    NSData *data = [NSData dataWithBytes:dataBytes length:length];
    
    CFRelease(sampleBuffer);
    CFRelease(blockBufferRef);
    return [self convertAudioFrameData:data];
}

- (NSData*)convertAudioFrameData:(NSData*)audioFrameData {
  
    NSMutableData *resultData = [[NSMutableData alloc] init];
    if (leftLength + audioFrameData.length >= self.bufferSise) {
        //进行编码
        NSInteger totalSize = leftLength + audioFrameData.length;
        NSInteger encodeCount = totalSize /  self.bufferSise;
        char *totalBuf = malloc(totalSize);
        char *p = totalBuf;
        
        memset(totalBuf, 0, totalSize);
        memcpy(totalBuf, leftBuffer, leftLength);
        memcpy(totalBuf + leftLength, audioFrameData.bytes, audioFrameData.length);
        
        for (int i = 0; i< encodeCount; i++) {
            NSData *data = [self encodeBuffer:p length:self.bufferSise];
            [resultData appendData:data];
            p += self.bufferSise;
        }
        leftLength = totalSize % self.bufferSise;
        memset(leftBuffer, 0, self.bufferSise);
        memcpy(leftBuffer, totalBuf + (totalSize - leftLength), leftLength);
        free(totalBuf);
        
    }else {
        //不够就累计
        memcpy(leftBuffer + leftLength, audioFrameData.bytes, audioFrameData.length);
        leftLength = leftLength + audioFrameData.length;
    }
    return resultData;
}

- (NSData*)encodeBuffer:(char *)inputBuffer length:(UInt32)length {
    
    AudioBufferList inputAudioBufferList = {};
    inputAudioBufferList.mNumberBuffers = 1;
    inputAudioBufferList.mBuffers[0].mDataByteSize = length;
    inputAudioBufferList.mBuffers[0].mData = inputBuffer;
    inputAudioBufferList.mBuffers[0].mNumberChannels = _inputDes.mChannelsPerFrame;
    
    
    //1.初始化输出列表
    AudioBufferList outAudioBufferList = {0};
    outAudioBufferList.mNumberBuffers = 1;
    outAudioBufferList.mBuffers[0].mNumberChannels = inputAudioBufferList.mBuffers[0].mNumberChannels;
    outAudioBufferList.mBuffers[0].mDataByteSize = length;
    outAudioBufferList.mBuffers[0].mData = malloc(length);
    
    //2.喂数据
    // 改参数会影响ioNumberDataPackets的计算，如果为2 ioNumberDataPackets*2,但是不能大于最大输出值
    UInt32 outputDataPacketSize = 1;
    AudioStreamPacketDescription outPacketDescription = {};
    OSStatus status = AudioConverterFillComplexBuffer(_audioConvertRef, inputDataProc, &inputAudioBufferList, &outputDataPacketSize, &outAudioBufferList, &outPacketDescription);
    if (status != noErr) {
        exit(1);
    }
    
    NSData *rawAAC = [NSData dataWithBytes:outAudioBufferList.mBuffers[0].mData length:outAudioBufferList.mBuffers[0].mDataByteSize];
    NSData *headerData = [self adtsDataForPacketLength:rawAAC.length];
    NSMutableData *ret = [NSMutableData dataWithData:headerData];
    [ret appendData:rawAAC];
    return ret;
}


//inputData回调函数
OSStatus inputDataProc(AudioConverterRef inAudioConverter,
                        UInt32 *ioNumberDataPackets,
                        AudioBufferList *               ioData,
                        AudioStreamPacketDescription * __nullable * __nullable outDataPacketDescription,
                        void * __nullable               inUserData) {
    
    AudioBufferList list = *(AudioBufferList*)inUserData;
    
    ioData -> mNumberBuffers = 1;
    ioData -> mBuffers[0].mData = list.mBuffers[0].mData;
    ioData -> mBuffers[0].mDataByteSize = list.mBuffers[0].mDataByteSize;
    ioData -> mBuffers[0].mNumberChannels = list.mBuffers[0].mNumberChannels;
    
    return noErr;
 }



- (void)dispose {
    AudioConverterDispose(_audioConvertRef);
}


// 回调函数
 


+ (void)printAudioStreamBasicDescription:(AudioStreamBasicDescription)asbd {
    char formatID[5];
    UInt32 mFormatID = CFSwapInt32HostToBig(asbd.mFormatID);
    bcopy (&mFormatID, formatID, 4);
    formatID[4] = '\0';
    printf("Sample Rate:         %10.0f\n",  asbd.mSampleRate);
    printf("Format ID:           %10s\n",    formatID);
    printf("Format Flags:        %10X\n",    (unsigned int)asbd.mFormatFlags);
    printf("Bytes per Packet:    %10d\n",    (unsigned int)asbd.mBytesPerPacket);
    printf("Frames per Packet:   %10d\n",    (unsigned int)asbd.mFramesPerPacket);
    printf("Bytes per Frame:     %10d\n",    (unsigned int)asbd.mBytesPerFrame);
    printf("Channels per Frame:  %10d\n",    (unsigned int)asbd.mChannelsPerFrame);
    printf("Bits per Channel:    %10d\n",    (unsigned int)asbd.mBitsPerChannel);
    printf("\n");
}

/**
 *  Add ADTS header at the beginning of each and every AAC packet.
 *  This is needed as MediaCodec encoder generates a packet of raw
 *  AAC data.
 *
 *  Note the packetLen must count in the ADTS header itself.
 *  See: http://wiki.multimedia.cx/index.php?title=ADTS
 *  Also: http://wiki.multimedia.cx/index.php?title=MPEG-4_Audio#Channel_Configurations
 **/
- (NSData*) adtsDataForPacketLength:(NSUInteger)packetLength {
    int adtsLength = 7;
    char *packet = malloc(sizeof(char) * adtsLength);
    // Variables Recycled by addADTStoPacket
    int profile = 2;  //AAC LC
    //39=MediaCodecInfo.CodecProfileLevel.AACObjectELD;
    int freqIdx = [self getFreqIdx];  //44.1KHz
    int chanCfg = 1;  //MPEG-4 Audio Channel Configuration. 1 Channel front-center
    NSUInteger fullLength = adtsLength + packetLength;
    // fill in ADTS data
    packet[0] = (char)0xFF; // 11111111     = syncword
    packet[1] = (char)0xF9; // 1111 1 00 1  = syncword MPEG-2 Layer CRC
    packet[2] = (char)(((profile-1)<<6) + (freqIdx<<2) +(chanCfg>>2));
    packet[3] = (char)(((chanCfg&3)<<6) + (fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF) >> 3);
    packet[5] = (char)(((fullLength&7)<<5) + 0x1F);
    packet[6] = (char)0xFC;
    NSData *data = [NSData dataWithBytesNoCopy:packet length:adtsLength freeWhenDone:YES];
//    [self bytearrtostr:packet length:7];
    
    return data;
}

- (int)getFreqIdx {
    if (self.inputDes.mSampleRate == 32000) {
        return 5;
    }else if (self.inputDes.mSampleRate == 44100 ){
        return 4;
    }else if (self.inputDes.mSampleRate == 48000){
        return  3;
    }else if (self.inputDes.mSampleRate == 64000){
        return  2;
    }else if (self.inputDes.mSampleRate == 96000){
        return  0;
    }else if (self.inputDes.mSampleRate == 24000){
        return  6;
    }else if (self.inputDes.mSampleRate == 22050){
        return  7;
    }else if(self.inputDes.mSampleRate == 16000){
        return  8;
    }else if(self.inputDes.mSampleRate == 12000){
        return  9;
    }else if(self.inputDes.mSampleRate == 11025){
        return  10;
    }else if(self.inputDes.mSampleRate == 8000){
        return  11;
    }else if(self.inputDes.mSampleRate == 7350){
        return  12;
    }
    return  4;
}


-(void)bytearrtostr:(Byte *)data length:(int)length
{
    char char_1 = '1',char_0 = '0';
    char *chars = malloc(length*8+1);
    chars[length*8] = '\n';
    for(int i=0;i<length;i++)
    {
        Byte bb = data[i];
        for(int j=0;j<8;j++)
        {
            if(((bb>>j)&0x01) == 1)
            {
                chars[i*8+j] = char_1;
            }else{
                chars[i*8+j] = char_0;
            }
        }
        char temp = 0;
        temp =  chars[i*8+0];chars[i*8+0] = chars[i*8+7];chars[i*8+7] = temp;
        temp =  chars[i*8+1];chars[i*8+1] = chars[i*8+6];chars[i*8+6] = temp;
        temp =  chars[i*8+2];chars[i*8+2] = chars[i*8+5];chars[i*8+5] = temp;
        temp =  chars[i*8+3];chars[i*8+3] = chars[i*8+4];chars[i*8+4] = temp;
    }
    NSString *string = [NSString stringWithCString:chars encoding:NSUTF8StringEncoding];
    NSLog(@"binnary string = %@",string);
}

@end
