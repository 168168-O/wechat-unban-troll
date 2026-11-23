// 虚拟摄像头 · iOS 巨魔（TrollStore）版
// 注入目标：com.tencent.xin（App Store 版微信）
// 注入方式：TrollFools 把 build 出来的 .dylib 注入微信，或直接给二进制加 LC_LOAD_DYLIB 后用 ldid 重签
//
// 干的事：把 AVCaptureVideoDataOutput 的 sample buffer 换成 /var/mobile/Documents/face.mov 的画面，
// 微信内部的活体 SDK 只看到"摄像头画面"，看不到真实摄像头。

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <objc/runtime.h>
#import <notify.h>
#import "ActionStore.h"

static NSString *const kVideoPath = @"/var/mobile/Documents/face.mov";
static NSString *const kSwitchPath = @"/var/mobile/Documents/vcam.on";
static const int kFPS = 30;

#pragma mark - 帧源

@interface VCFrameSource : NSObject
@property (nonatomic, strong) AVAssetReader *reader;
@property (nonatomic, strong) AVAssetReaderTrackOutput *output;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, assign) BOOL running;
@end

@implementation VCFrameSource

+ (instancetype)shared {
    static VCFrameSource *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [VCFrameSource new]; });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        _queue = dispatch_queue_create("vcam.reader", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (BOOL)enabled {
    return [[NSFileManager defaultManager] fileExistsAtPath:kSwitchPath];
}

- (void)start {
    if (self.running) return;
    if (![self enabled]) return;

    NSURL *url = [NSURL fileURLWithPath:kVideoPath];
    AVAsset *asset = [AVAsset assetWithURL:url];
    AVAssetTrack *track = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    if (!track) {
        NSLog(@"[vcam] 没有视频轨: %@", kVideoPath);
        return;
    }

    NSError *err = nil;
    self.reader = [AVAssetReader assetReaderWithAsset:asset error:&err];
    if (err) {
        NSLog(@"[vcam] reader 打开失败 %@", err);
        return;
    }

    NSDictionary *opts = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
        (id)kCVPixelBufferIOSurfacePropertiesKey: @{}
    };
    self.output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:opts];
    self.output.alwaysCopiesSampleData = NO;
    if ([self.reader canAddOutput:self.output]) {
        [self.reader addOutput:self.output];
    }
    [self.reader startReading];
    self.running = YES;
    NSLog(@"[vcam] 开始送帧 %@ %dx%d", kVideoPath,
          (int)track.naturalSize.width, (int)track.naturalSize.height);
}

- (void)restart {
    [self.reader cancelReading];
    self.reader = nil;
    self.output = nil;
    self.running = NO;
    [self start];
}

- (CVPixelBufferRef)nextPixelBufferCopy CF_RETURNS_RETAINED {
    if (!self.running) [self start];
    if (!self.running) return NULL;

    CMSampleBufferRef sb = [self.output copyNextSampleBuffer];
    if (!sb) {
        [self restart];
        sb = [self.output copyNextSampleBuffer];
        if (!sb) return NULL;
    }
    CVImageBufferRef pb = CMSampleBufferGetImageBuffer(sb);
    CVPixelBufferRef copy = NULL;
    if (pb) {
        CVPixelBufferRetain(pb);
        copy = pb;
    }
    CFRelease(sb);
    return copy;
}

@end

#pragma mark - 代理（偷梁换柱）

@protocol VCFrameSourceLike <NSObject>
- (BOOL)enabled;
- (void)start;
- (CVPixelBufferRef)nextPixelBufferCopy CF_RETURNS_RETAINED;
@end

@interface VCDDelegateProxy : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, weak) id real;
@property (nonatomic, strong) id<VCFrameSourceLike> src;
@property (nonatomic, assign) int frame;
@end

@implementation VCDDelegateProxy

- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {

    if ([output isKindOfClass:[AVCaptureVideoDataOutput class]] && [self.src enabled]) {
        CVPixelBufferRef pb = [self.src nextPixelBufferCopy];
        if (pb) {
            CMVideoFormatDescriptionRef fmt = NULL;
            OSStatus st = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pb, &fmt);
            if (st == noErr && fmt) {
                CMTime pts = CMClockGetTime(CMClockGetHostTimeClock());
                CMSampleTimingInfo timing = { CMTimeMake(1, kFPS), pts, kCMTimeInvalid };
                CMSampleBufferRef out = NULL;
                st = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pb, true, NULL, NULL,
                                                        fmt, &timing, &out);
                CFRelease(fmt);
                CVPixelBufferRelease(pb);
                if (st == noErr && out) {
                    if ([self.real respondsToSelector:_cmd]) {
                        [self.real captureOutput:output didOutputSampleBuffer:out fromConnection:connection];
                    }
                    CFRelease(out);
                    self.frame++;
                    return;
                }
            } else {
                CVPixelBufferRelease(pb);
            }
        }
    }

    if ([self.real respondsToSelector:_cmd]) {
        [self.real captureOutput:output didOutputSampleBuffer:sampleBuffer fromConnection:connection];
    }
}

@end

#pragma mark - Hook

%hook AVCaptureVideoDataOutput

- (void)setSampleBufferDelegate:(id)delegate queue:(dispatch_queue_t)queue {
    if (delegate && [[ActionStore shared] enabled]) {
        VCDDelegateProxy *p = [VCDDelegateProxy new];
        p.real = delegate;
        p.src = [ActionStore shared];
        objc_setAssociatedObject(self, "vcam_proxy", p, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[ActionStore shared] start];
        NSLog(@"[vcam] 接管 setSampleBufferDelegate %@ 当前动作=%@", [delegate class], [[ActionStore shared] currentAction]);
        %orig(p, queue);
        return;
    }
    %orig(delegate, queue);
}

%end

#pragma mark - 摄像头开跑就弹控制面板

extern void VCPanelShow(void);
extern void VCPanelHide(void);

%hook AVCaptureSession

- (void)startRunning {
    %orig;
    if ([[ActionStore shared] enabled]) VCPanelShow();
}

- (void)stopRunning {
    %orig;
    VCPanelHide();
}

%end

#pragma mark - 开关

static void vcam_reload(CFNotificationCenterRef c, void *obs, CFStringRef name,
                        const void *obj, CFDictionaryRef info) {
    [[VCFrameSource shared] restart];
}

%ctor {
    NSLog(@"[vcam] 载入完成，素材目录: %@", kVCamDir);
    [[ActionStore shared] start];
    [[ActionStore shared] startServer];
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL, vcam_reload,
                                    CFSTR("com.local.vcam.reload"), NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}
