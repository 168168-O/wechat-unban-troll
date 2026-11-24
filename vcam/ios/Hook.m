// Hook.m —— 不依赖 Substrate/ElleKit 的纯 runtime 版本
// TrollFools 注入到非越狱环境时，Logos 的 %hook 没有 substrate 支撑，什么都不会发生。
// 这里全部改用 method_setImplementation + objc_msgSend 手工接管。

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

extern void VCPanelShow(void);
extern void VCPanelHide(void);
#import "ActionStore.h"

@interface VCDProxy : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, weak) id real;
@property (nonatomic, strong) ActionStore *src;
@property (nonatomic, assign) int frame;
@end

@implementation VCDProxy

- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {

    if ([output isKindOfClass:[AVCaptureVideoDataOutput class]] &&
        [[ActionStore shared] enabled]) {
        CVPixelBufferRef pb = [[ActionStore shared] nextPixelBufferCopy];
        if (pb) {
            CMVideoFormatDescriptionRef fmt = NULL;
            if (CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pb, &fmt) == noErr && fmt) {
                CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                CMSampleTimingInfo timing = { CMTimeMake(1, 30), pts, kCMTimeInvalid };
                CMSampleBufferRef out = NULL;
                if (CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pb, true, NULL, NULL,
                                                       fmt, &timing, &out) == noErr && out) {
                    CFRelease(fmt);
                    CVPixelBufferRelease(pb);
                    if ([self.real respondsToSelector:_cmd]) {
                        [self.real captureOutput:output didOutputSampleBuffer:out fromConnection:connection];
                    }
                    CFRelease(out);
                    self.frame++;
                    return;
                }
                CFRelease(fmt);
            }
            CVPixelBufferRelease(pb);
        }
    }
    if ([self.real respondsToSelector:_cmd]) {
        [self.real captureOutput:output didOutputSampleBuffer:sampleBuffer fromConnection:connection];
    }
}

@end

// ───── 手工 swizzle ─────

static void VCSwizzle(Class cls, SEL sel, IMP newImp) {
    if (!cls) return;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    method_setImplementation(m, newImp);
}

// ── 相机输出代理 ──
static void (*orig_setDelegate)(id, SEL, id, dispatch_queue_t);

static void my_setDelegate(id self, SEL _cmd, id delegate, dispatch_queue_t queue) {
    if (delegate && [[ActionStore shared] enabled]) {
        VCDProxy *p = [VCDProxy new];
        p.real = delegate;
        p.src = [ActionStore shared];
        objc_setAssociatedObject(self, "camsrc_proxy", p, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[ActionStore shared] start];
        NSLog(@"[camsrc] 接管 setSampleBufferDelegate %@ 当前动作=%@",
              [delegate class], [[ActionStore shared] currentAction]);
        orig_setDelegate(self, _cmd, p, queue);
        return;
    }
    orig_setDelegate(self, _cmd, delegate, queue);
}

// ── 会话启停 ──
static void (*orig_startRunning)(id, SEL);
static void my_startRunning(id self, SEL _cmd) {
    orig_startRunning(self, _cmd);
    if ([[ActionStore shared] enabled]) VCPanelShow();
}

static void (*orig_stopRunning)(id, SEL);
static void my_stopRunning(id self, SEL _cmd) {
    orig_stopRunning(self, _cmd);
    VCPanelHide();
}

// ── 文件系统伪装 ──
static BOOL (*orig_fileExists)(id, SEL, NSString *);
static BOOL my_fileExists(id self, SEL _cmd, NSString *path) {
    if (path && ([path hasPrefix:@"/var/jb"] ||
                 [path hasPrefix:@"/Library/MobileSubstrate"] ||
                 [path hasPrefix:@"/Applications/Sileo.app"] ||
                 [path hasPrefix:@"/Applications/Cydia.app"] ||
                 [path hasPrefix:@"/private/var/lib/dpkg"] ||
                 [path hasPrefix:@"/var/mobile/Documents/.cache/.media"])) {
        return NO;
    }
    return orig_fileExists(self, _cmd, path);
}

// ── 相机元数据抖动 ──
static NSTimeInterval (*orig_exposure)(id, SEL);
static NSTimeInterval my_exposure(id self, SEL _cmd) {
    return 0.0166 + ((double)(arc4random_uniform(60)) - 30.0) / 100000.0;
}

static float (*orig_iso)(id, SEL);
static float my_iso(id self, SEL _cmd) {
    return (float)(160 + arc4random_uniform(120));
}

// ───── 装载 ─────

__attribute__((constructor))
static void camSrcInit(void) {
    NSLog(@"[camsrc] 装载，素材目录 /var/mobile/Documents/.cache/.media");

    Method m;

    m = class_getInstanceMethod([AVCaptureVideoDataOutput class],
                                @selector(setSampleBufferDelegate:queue:));
    if (m) { orig_setDelegate = (void *)method_getImplementation(m);
             method_setImplementation(m, (IMP)my_setDelegate); }

    m = class_getInstanceMethod([AVCaptureSession class], @selector(startRunning));
    if (m) { orig_startRunning = (void *)method_getImplementation(m);
             method_setImplementation(m, (IMP)my_startRunning); }

    m = class_getInstanceMethod([AVCaptureSession class], @selector(stopRunning));
    if (m) { orig_stopRunning = (void *)method_getImplementation(m);
             method_setImplementation(m, (IMP)my_stopRunning); }

    m = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
    if (m) { orig_fileExists = (void *)method_getImplementation(m);
             method_setImplementation(m, (IMP)my_fileExists); }

    m = class_getInstanceMethod([AVCaptureDevice class], @selector(exposureDuration));
    if (m) { orig_exposure = (void *)method_getImplementation(m);
             method_setImplementation(m, (IMP)my_exposure); }

    m = class_getInstanceMethod([AVCaptureDevice class], @selector(ISO));
    if (m) { orig_iso = (void *)method_getImplementation(m);
             method_setImplementation(m, (IMP)my_iso); }

    [[ActionStore shared] start];
    NSLog(@"[camsrc] 钩子就位，enabled=%d", [[ActionStore shared] enabled]);
}
