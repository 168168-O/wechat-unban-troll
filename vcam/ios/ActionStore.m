// ActionStore：按「动作」预加载多段视频，随时切换，切换延迟 < 100ms
// 素材目录：/var/mobile/Documents/vcam/<action>.mov
// 动作名：front up down left right mouth blink nod shake digits

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

static NSString *const kVCamDir = @"/var/mobile/Documents/vcam";
static NSString *const kActionFile = @"/var/mobile/Documents/vcam/current.txt";

@interface ActionClip : NSObject
@property (nonatomic, strong) AVAssetReader *reader;
@property (nonatomic, strong) AVAssetReaderTrackOutput *output;
@property (nonatomic, assign) BOOL running;
@end

@implementation ActionClip
@end

@interface ActionStore : NSObject
+ (instancetype)shared;
- (BOOL)enabled;
- (void)start;
- (void)restart;
- (void)setAction:(NSString *)name;
- (NSString *)currentAction;
- (NSArray<NSString *> *)actions;
- (CVPixelBufferRef)nextPixelBufferCopy CF_RETURNS_RETAINED;
@end

@implementation ActionStore {
    NSMutableDictionary<NSString *, ActionClip *> *_clips;
    NSString *_current;
    dispatch_queue_t _q;
}

+ (instancetype)shared {
    static ActionStore *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [ActionStore new]; });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        _clips = [NSMutableDictionary dictionary];
        _q = dispatch_queue_create("vcam.actions", DISPATCH_QUEUE_SERIAL);
        _current = @"front";
    }
    return self;
}

- (BOOL)enabled {
    return [[NSFileManager defaultManager] fileExistsAtPath:kVCamDir];
}

- (NSArray<NSString *> *)actions {
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:kVCamDir error:nil];
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *f in files) {
        if ([f.pathExtension.lowercaseString isEqualToString:@"mov"] ||
            [f.pathExtension.lowercaseString isEqualToString:@"mp4"]) {
            [out addObject:f.stringByDeletingPathExtension];
        }
    }
    return [out sortedArrayUsingSelector:@selector(compare:)];
}

- (ActionClip *)clipFor:(NSString *)name {
    ActionClip *c = _clips[name];
    if (c && c.running) return c;

    NSString *path = [kVCamDir stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"mov"]];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        path = [kVCamDir stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"mp4"]];
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return nil;

    AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:path]];
    AVAssetTrack *track = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    if (!track) return nil;

    NSError *err = nil;
    AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:asset error:&err];
    if (err) return nil;

    NSDictionary *opts = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
        (id)kCVPixelBufferIOSurfacePropertiesKey: @{}
    };
    AVAssetReaderTrackOutput *out = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:opts];
    out.alwaysCopiesSampleData = NO;
    if ([reader canAddOutput:out]) [reader addOutput:out];
    [reader startReading];

    c = [ActionClip new];
    c.reader = reader;
    c.output = out;
    c.running = YES;
    _clips[name] = c;
    NSLog(@"[vcam] 载入动作 %@ %.0fx%.0f", name, track.naturalSize.width, track.naturalSize.height);
    return c;
}

- (void)preloadAll {
    for (NSString *a in [self actions]) [self clipFor:a];
    NSLog(@"[vcam] 预载完成：%@", [[self actions] componentsJoinedByString:@","]);
}

- (void)start {
    if (![self enabled]) return;
    [self preloadAll];
    NSString *want = [NSString stringWithContentsOfFile:kActionFile encoding:NSUTF8StringEncoding error:nil];
    want = [want stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (want.length) _current = want;
}

- (void)restart {
    @synchronized (self) {
        for (ActionClip *c in _clips.allValues) {
            [c.reader cancelReading];
            c.running = NO;
        }
        [_clips removeAllObjects];
    }
    [self start];
}

- (void)setAction:(NSString *)name {
    if (!name.length) return;
    @synchronized (self) {
        if ([name isEqualToString:_current]) {
            // 同一动作重复按：从头再来，保证张嘴/眨眼这类短动作每次都能看到
            ActionClip *c = _clips[name];
            if (c) { [c.reader cancelReading]; c.running = NO; }
        }
        _current = name;
        [_clips removeObjectForKey:name];
        [self clipFor:name];
        [name writeToFile:kActionFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    NSLog(@"[vcam] 切动作 -> %@", name);
}

- (NSString *)currentAction { return _current; }

- (CVPixelBufferRef)nextPixelBufferCopy CF_RETURNS_RETAINED {
    if (!self.enabled) return NULL;
    if (_clips.count == 0) [self start];

    NSString *name = _current;
    ActionClip *clip = [self clipFor:name];
    if (!clip) {
        clip = [self clipFor:@"front"];
        if (!clip) return NULL;
    }

    CMSampleBufferRef sb = [clip.output copyNextSampleBuffer];
    if (!sb) {
        // 该段播完：回正脸，等下一条指令
        if (![name isEqualToString:@"front"]) {
            [self setAction:@"front"];
            clip = [self clipFor:@"front"];
            if (clip) sb = [clip.output copyNextSampleBuffer];
        }
        if (!sb) { [self restart]; return NULL; }
    }

    CVImageBufferRef pb = CMSampleBufferGetImageBuffer(sb);
    CVPixelBufferRef copy = NULL;
    if (pb) { CVPixelBufferRetain(pb); copy = pb; }
    CFRelease(sb);
    return copy;
}

@end
