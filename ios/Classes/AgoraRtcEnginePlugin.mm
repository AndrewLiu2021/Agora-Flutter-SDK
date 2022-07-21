#import "AgoraRtcEnginePlugin.h"
#import <AgoraRtcWrapper/iris_rtc_engine.h>
#import <AgoraRtcWrapper/iris_video_processor.h>
#import "CallApiMethodCallHandler.h"
#import "FlutterIrisEventHandler.h"
#import "AgoraRtcChannelPlugin.h"
#import "AgoraSurfaceViewFactory.h"
#import "AgoraTextureViewFactory.h"
#import "FlutterIrisEventHandler.h"
#if __has_include(<agora_rtc_engine/agora_rtc_engine-Swift.h>)
#import <agora_rtc_engine/agora_rtc_engine-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "agora_rtc_engine-Swift.h"
#endif

@interface AgoraRtcEnginePlugin ()

@property(nonatomic) agora::iris::rtc::IrisRtcEngine *irisRtcEngine;

// TODO(littlegnal): Lazy init videoFrameBufferManager
@property(nonatomic) agora::iris::IrisVideoFrameBufferManager *videoFrameBufferManager;

@property(nonatomic) FlutterIrisEventHandler *flutterIrisEventHandler;

@property(nonatomic) CallApiMethodCallHandler *callApiMethodCallHandler;

@property(nonatomic) AgoraRtcChannelPlugin *agoraRtcChannelPlugin;

@property(nonatomic, strong) AgoraTextureViewFactory *factory;

@property(nonatomic) NSObject<FlutterPluginRegistrar> *registrar;

@end

@implementation AgoraRtcEnginePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    FlutterMethodChannel *methodChannel =
        [FlutterMethodChannel methodChannelWithName:@"agora_rtc_engine"
                                    binaryMessenger:[registrar messenger]];
    FlutterEventChannel *eventChannel =
        [FlutterEventChannel eventChannelWithName:@"agora_rtc_engine/events"
                                  binaryMessenger:[registrar messenger]];
    AgoraRtcEnginePlugin *instance = [[AgoraRtcEnginePlugin alloc] init];
    instance.registrar = registrar;
    [registrar addMethodCallDelegate:instance channel:methodChannel];
    
    instance.flutterIrisEventHandler = [[FlutterIrisEventHandler alloc] initWith:instance.irisRtcEngine];
    
    __weak FlutterIrisEventHandler *weakFlutterIrisEventHandler = instance.flutterIrisEventHandler;
    instance.callApiMethodCallHandler.emitter = ^(NSString *methodName, NSDictionary<NSString *,id> *data) {
        NSMutableDictionary *event = [NSMutableDictionary dictionaryWithDictionary:@{@"methodName": methodName}];
        if (data) {
            [event addEntriesFromDictionary:data];
        }
        weakFlutterIrisEventHandler.eventSink(event);
    };
    
    [eventChannel setStreamHandler:instance.flutterIrisEventHandler];
    
    instance.agoraRtcChannelPlugin = [[AgoraRtcChannelPlugin alloc] initWith:[instance irisRtcEngine] binaryMessenger:[registrar messenger]];
    
    [instance
        setFactory:[[AgoraTextureViewFactory alloc] initWithRegistrar:registrar]];

    [registrar registerViewFactory:[[AgoraSurfaceViewFactory alloc]
                                       initWith:[registrar messenger]
                                         engine:instance.irisRtcEngine]
                            withId:@"AgoraSurfaceView"];
}

- (instancetype)init {
  self = [super init];
  if (self) {
    self.irisRtcEngine = new agora::iris::rtc::IrisRtcEngine;
      self.videoFrameBufferManager = new agora::iris::IrisVideoFrameBufferManager;
      self.irisRtcEngine->raw_data()->Attach(self.videoFrameBufferManager);
      
      self.callApiMethodCallHandler = [[CallApiMethodCallHandler alloc] initWith:self.irisRtcEngine];
  }
  return self;
}

- (void)destroyIrisRtcEngine {
    self.irisRtcEngine->SetEventHandler(nil);
    self.irisRtcEngine->channel()->SetEventHandler(nil);
    delete self.irisRtcEngine;
    self.irisRtcEngine = nil;
}

- (void)dealloc {
    if (self.irisRtcEngine) {
        [self destroyIrisRtcEngine];
    }
    
    if (self.videoFrameBufferManager) {
        delete self.videoFrameBufferManager;
        self.videoFrameBufferManager = nil;
    }
}

- (void)handleMethodCall:(FlutterMethodCall *)call
                  result:(FlutterResult)result {
#if DEBUG
    if ([@"getIrisRtcEngineIntPtr" isEqualToString:call.method]) {
        result(@((intptr_t)self.irisRtcEngine));
        return;
    }
    if ([@"forceDestroyIrisRtcEngine" isEqualToString:call.method]) {
        [self destroyIrisRtcEngine];
        result(@(true));
        return;
    }
#endif
    
    if ([@"createTextureRender" isEqualToString:call.method]) {
        int64_t textureId = [self.factory
            createTextureRenderer:[self videoFrameBufferManager]];
        result(@(textureId));
    } else if ([@"destroyTextureRender" isEqualToString:call.method]) {
        NSNumber *textureId = call.arguments[@"id"];
        [self.factory destroyTextureRenderer:[textureId integerValue]];
        result(nil);
    } else if ([@"getAssetAbsolutePath" isEqualToString:call.method]) {
        [self getAssetAbsolutePath:call result:result];
    } else {
        [[self callApiMethodCallHandler] onMethodCall:call _:result];
    }
}

- (void)getAssetAbsolutePath:(FlutterMethodCall *)call
                      result:(FlutterResult)result {
    NSString *assetPath = (NSString *)[call arguments];
    if (assetPath) {
        NSString *assetKey = [[self registrar] lookupKeyForAsset:assetPath];
        if (assetKey) {
            NSString *realPath = [[NSBundle mainBundle] pathForResource:assetKey ofType:nil];
            result(realPath);
            return;
        }
        result([FlutterError
            errorWithCode:@"FileNotFoundException"
                  message:nil
                  details:nil]);
        return;
    }
    result([FlutterError
        errorWithCode:@"IllegalArgumentException"
              message:nil
              details:nil]);
}

@end
