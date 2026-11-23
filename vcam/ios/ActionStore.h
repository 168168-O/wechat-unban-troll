#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

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

@interface ActionStore (Server)
- (void)startServer;
@end
