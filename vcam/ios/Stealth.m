// Stealth：把"我是被改造过的"这几处痕迹抹掉
// 1) dyld 镜像列表里藏掉 vcam.dylib
// 2) 越狱路径全部报不存在
// 3) fork / getppid / 调试端口看起来像正常 App
// 4) 相机元数据带随机抖动，不像死数据
//
// 依赖 fishhook（github.com/facebook/fishhook），放 ios/vendor/fishhook.c 与 fishhook.h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <sys/sysctl.h>
#import <unistd.h>
#import <dlfcn.h>
#import "fishhook.h"

#pragma mark - dyld

static int (*orig_image_count)(void);
static const char *(*orig_image_name)(uint32_t);
static const struct mach_header *(*orig_image_header)(uint32_t);

static int st_image_count(void) {
    return orig_image_count() - 1;              // 列表里少一个（自己）
}

static const char *st_image_name(uint32_t idx) {
    const char *n = orig_image_name(idx);
    if (n && (strstr(n, "vcam") || strstr(n, "Stealth") || strstr(n, "fishhook")))
        return "/usr/lib/libSystem.B.dylib";
    return n;
}

static const struct mach_header *st_image_header(uint32_t idx) {
    return orig_image_header(idx);
}

#pragma mark - 越狱路径

static NSArray<NSString *> *st_paths(void) {
    return @[
        @"/var/jb", @"/var/xina", @"/Library/MobileSubstrate",
        @"/usr/lib/libhooker.dylib", @"/usr/lib/libsubstrate.dylib",
        @"/usr/lib/libellekit.dylib", @"/usr/lib/libellekit",
        @"/Applications/Sileo.app", @"/Applications/Zebra.app",
        @"/Applications/Cydia.app", @"/private/var/lib/dpkg",
        @"/etc/apt", @"/usr/sbin/sshd", @"/bin/bash", @"/usr/bin/ssh",
        @"/var/mobile/Documents/vcam", @"/var/mobile/Documents/vcam.on"
    ];
}

static BOOL st_blocked(NSString *p) {
    if (![p isKindOfClass:[NSString class]]) return NO;
    for (NSString *s in st_paths()) {
        if ([p hasPrefix:s]) return YES;
    }
    return NO;
}

%hook NSFileManager
- (BOOL)fileExistsAtPath:(NSString *)path { return st_blocked(path) ? NO : %orig; }
- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)flag {
    if (st_blocked(path)) { if (flag) *flag = NO; return NO; }
    return %orig;
}
- (BOOL)isReadableFileAtPath:(NSString *)path { return st_blocked(path) ? NO : %orig; }
- (BOOL)isExecutableFileAtPath:(NSString *)path { return st_blocked(path) ? NO : %orig; }
%end

%hook NSURL
+ (NSURL *)fileURLWithPath:(NSString *)path { return %orig; }
- (BOOL)checkResourceIsReachableAndReturnError:(NSError **)e {
    NSString *p = self.path;
    if (p && st_blocked(p)) return NO;
    return %orig;
}
%end

#pragma mark - 进程与调试

static pid_t (*orig_getppid)(void);
static pid_t st_getppid(void) { return 1; }        // 正常 App 的父进程是 launchd

static int (*orig_ptrace)(int, pid_t, caddr_t, int);
static int st_ptrace(int req, pid_t pid, caddr_t addr, int data) {
    return 0;                                        // 拒绝被附加
}

static int (*orig_fork)(void);
static pid_t st_fork(void) { return -1; }          // 越狱检测常查 fork 是否可用

#pragma mark - 相机元数据

%hook AVCaptureDevice

- (NSTimeInterval)exposureDuration {
    return 0.0166 + ((double)(arc4random_uniform(60)) - 30.0) / 100000.0;
}

- (float)ISO {
    return (float)(160 + arc4random_uniform(120));
}

- (AVCaptureWhiteBalanceGains)deviceWhiteBalanceGains {
    AVCaptureWhiteBalanceGains g = %orig;
    g.redGain   += ((float)arc4random_uniform(40) - 20.0f) / 10000.0f;
    g.greenGain += ((float)arc4random_uniform(40) - 20.0f) / 10000.0f;
    g.blueGain  += ((float)arc4random_uniform(40) - 20.0f) / 10000.0f;
    return g;
}

- (BOOL)isConnected { return YES; }
- (BOOL)hasTorch { return %orig; }

%end

#pragma mark - 装载

%ctor {
    struct rebinding r[] = {
        {"_dyld_image_count",    st_image_count,    (void **)&orig_image_count},
        {"_dyld_get_image_name", st_image_name,     (void **)&orig_image_name},
        {"_dyld_get_image_header", st_image_header, (void **)&orig_image_header},
        {"getppid",              st_getppid,        (void **)&orig_getppid},
        {"ptrace",               st_ptrace,         (void **)&orig_ptrace},
        {"fork",                 st_fork,           (void **)&orig_fork},
    };
    rebind_symbols(r, sizeof(r) / sizeof(r[0]));
    NSLog(@"[stealth] 装载完成：dyld 过滤 / 路径白名单 / 进程伪装 / 相机元数据抖动");
}
