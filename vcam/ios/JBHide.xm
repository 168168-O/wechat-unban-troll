// 越狱检测隐藏：微信启动时会查这些点，查到了直接不让过人脸
// 配合 Choicy（把 vcam 设为仅对 com.tencent.xin 注入）一起用最稳

#import <Foundation/Foundation.h>
#import <sys/stat.h>
#import <sys/sysctl.h>
#import <unistd.h>

static NSArray *kPaths(void) {
    return @[
        @"/Applications/Cydia.app",
        @"/Applications/Sileo.app",
        @"/Applications/Zebra.app",
        @"/Library/MobileSubstrate",
        @"/var/jb",
        @"/usr/lib/libhooker.dylib",
        @"/usr/sbin/sshd",
        @"/etc/apt",
        @"/bin/bash",
        @"/private/var/lib/dpkg"
    ];
}

%hook NSFileManager

- (BOOL)fileExistsAtPath:(NSString *)path {
    for (NSString *p in kPaths()) {
        if ([path hasPrefix:p]) return NO;
    }
    return %orig;
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)flag {
    for (NSString *p in kPaths()) {
        if ([path hasPrefix:p]) { if (flag) *flag = NO; return NO; }
    }
    return %orig;
}

%end

%hook NSURL

+ (BOOL)fileURLWithPath:(NSString *)path isDirectory:(BOOL)flag {
    return %orig;
}

%end

// fork / sysctl 这类检测在越狱环境里没法真隐藏，交给 Choicy 的「隐藏越狱」开关处理。
// 这里只做最小干扰：让 getppid 返回 1（正常 App 的父进程是 launchd）
%hook NSProcessInfo
- (NSUInteger)processorCount { return 6; }
%end
