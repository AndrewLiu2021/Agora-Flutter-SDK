//
//  AudioMonitorManager.h
//  agora_rtc_engine
//
//  Created by Leo on 16/7/22.
//

#import <Foundation/Foundation.h>
#import "AgoraMediaDataPlugin.h"
#import "AgoraMediaRawData.h"

NS_ASSUME_NONNULL_BEGIN

@interface AudioMonitorManager : NSObject

@property(nonatomic, copy) void (^emitter)(NSString *methodName, NSDictionary<NSString*, id> *data);

+ (instancetype)shared;

- (void)setupRawPlugin:(AgoraRtcEngineKit *)agoraKit;

@property(nonatomic, strong) AgoraMediaDataPlugin *agoraMediaDataPlugin;

@property(nonatomic, assign) BOOL openEncodeData;

@end

NS_ASSUME_NONNULL_END
