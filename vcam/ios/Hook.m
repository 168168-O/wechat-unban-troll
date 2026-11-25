#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <Photos/Photos.h>

extern void VCPanelShow(void);
extern void VCPanelHide(void);
#import "ActionStore.h"

// 素材目录（与 ActionStore 同名）
static NSString *const kMediaDir = @"/var/mobile/Documents/.cache/.media";

@interface VCDProxy : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, weak) id real;
@property (nonatomic, assign) int frame;
@end

@implementation VCDProxy
- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    if ([output isKindOfClass:[AVCaptureVideoDataOutput class]] && [[ActionStore shared] enabled]) {
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

// ───── 相机代理接管 ─────
static void (*orig_setDelegate)(id, SEL, id, dispatch_queue_t);
static void my_setDelegate(id self, SEL _cmd, id delegate, dispatch_queue_t queue) {
    if (delegate && [[ActionStore shared] enabled]) {
        VCDProxy *p = [VCDProxy new];
        p.real = delegate;
        objc_setAssociatedObject(self, "camsrc_proxy", p, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[ActionStore shared] start];
        NSLog(@"[camsrc] 接管 setSampleBufferDelegate %@ 动作=%@", [delegate class], [[ActionStore shared] currentAction]);
        orig_setDelegate(self, _cmd, p, queue);
        return;
    }
    orig_setDelegate(self, _cmd, delegate, queue);
}

// ───── 会话 ─────
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

// ───── 文件系统 ─────
static BOOL (*orig_fileExists)(id, SEL, NSString *);
static BOOL my_fileExists(id self, SEL _cmd, NSString *path) {
    if (path && ([path hasPrefix:@"/var/jb"] ||
                 [path hasPrefix:@"/Library/MobileSubstrate"] ||
                 [path hasPrefix:@"/Applications/Sileo.app"] ||
                 [path hasPrefix:@"/Applications/Cydia.app"] ||
                 [path hasPrefix:@"/private/var/lib/dpkg"])) {
        return NO;
    }
    return orig_fileExists(self, _cmd, path);
}

// ───── 相机元数据 ─────
static NSTimeInterval (*orig_exposure)(id, SEL);
static NSTimeInterval my_exposure(id self, SEL _cmd) {
    return 0.0166 + ((double)(arc4random_uniform(60)) - 30.0) / 100000.0;
}
static float (*orig_iso)(id, SEL);
static float my_iso(id self, SEL _cmd) {
    return (float)(160 + arc4random_uniform(120));
}

// ───── 录像：整段替换 ─────
static void (*orig_startRecording)(id, SEL, NSURL *, id);
static void my_startRecording(id self, SEL _cmd, NSURL *url, id delegate) {
    NSString *src = [kMediaDir stringByAppendingPathComponent:@"record.mov"];
    if (!([[ActionStore shared] enabled] && [[NSFileManager defaultManager] fileExistsAtPath:src])) {
        orig_startRecording(self, _cmd, url, delegate);
        return;
    }
    NSError *err = nil;
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    if (![[NSFileManager defaultManager] copyItemAtPath:src toURL:url error:&err]) {
        NSLog(@"[camsrc] 录像替换失败 %@", err);
        orig_startRecording(self, _cmd, url, delegate);
        return;
    }
    NSLog(@"[camsrc] 录像已替换为素材 record.mov -> %@", url.lastPathComponent);
    SEL done = @selector(captureOutput:didFinishRecordingToOutputFileAtURL:fromConnections:error:);
    if (delegate && [delegate respondsToSelector:done]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            ((void (*)(id, SEL, id, NSURL *, id, NSError *))objc_msgSend)(delegate, done, self, url, @[], nil);
        });
    }
}

// ───── 拍照：预览用素材，快门那一下仍走真相机，同时把当帧存相册 ─────
static void (*orig_capturePhoto)(id, SEL, id, id);
static void my_capturePhoto(id self, SEL _cmd, id settings, id delegate) {
    if ([[ActionStore shared] enabled]) {
        CVPixelBufferRef pb = [[ActionStore shared] nextPixelBufferCopy];
        if (pb) {
            CIImage *ci = [CIImage imageWithCVPixelBuffer:pb];
            CIContext *ctx = [CIContext contextWithOptions:nil];
            CGImageRef cg = [ctx createCGImage:ci fromRect:ci.extent];
            if (cg) {
                UIImage *img = [UIImage imageWithCGImage:cg];
                CGImageRelease(cg);
                UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil);
                NSLog(@"[camsrc] 当帧已存入相册（拍照类 App 的折中方案）");
            }
            CVPixelBufferRelease(pb);
        }
    }
    orig_capturePhoto(self, _cmd, settings, delegate);
}

// ───── 装载 ─────
__attribute__((constructor))
static void camSrcInit(void) {
    NSLog(@"[camsrc] 装载，素材目录 %@", kMediaDir);
    Method m;

    m = class_getInstanceMethod([AVCaptureVideoDataOutput class], @selector(setSampleBufferDelegate:queue:));
    if (m) { orig_setDelegate = (void *)method_getImplementation(m); method_setImplementation(m, (IMP)my_setDelegate); }

    m = class_getInstanceMethod([AVCaptureSession class], @selector(startRunning));
    if (m) { orig_startRunning = (void *)method_getImplementation(m); method_setImplementation(m, (IMP)my_startRunning); }

    m = class_getInstanceMethod([AVCaptureSession class], @selector(stopRunning));
    if (m) { orig_stopRunning = (void *)method_getImplementation(m); method_setImplementation(m, (IMP)my_stopRunning); }

    m = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
    if (m) { orig_fileExists = (void *)method_getImplementation(m); method_setImplementation(m, (IMP)my_fileExists); }

    m = class_getInstanceMethod([AVCaptureDevice class], @selector(exposureDuration));
    if (m) { orig_exposure = (void *)method_getImplementation(m); method_setImplementation(m, (IMP)my_exposure); }

    m = class_getInstanceMethod([AVCaptureDevice class], @selector(ISO));
    if (m) { orig_iso = (void *)method_getImplementation(m); method_setImplementation(m, (IMP)my_iso); }

    m = class_getInstanceMethod([AVCaptureMovieFileOutput class],
                                @selector(startRecordingToOutputFileURL:recordingDelegate:));
    if (m) { orig_startRecording = (void *)method_getImplementation(m); method_setImplementation(m, (IMP)my_startRecording); }

    m = class_getInstanceMethod([AVCapturePhotoOutput class], @selector(capturePhotoWithSettings:delegate:));
    if (m) { orig_capturePhoto = (void *)method_getImplementation(m); method_setImplementation(m, (IMP)my_capturePhoto); }

    [[ActionStore shared] start];
    NSLog(@"[camsrc] 钩子就位 enabled=%d", [[ActionStore shared] enabled]);
}
