#import <Foundation/Foundation.h>

// Compatibility definitions for Cronet / Libbox ScopedCriticalAction in App Extensions
@interface UIApplication : NSObject
+ (id)sharedApplication;
- (NSUInteger)beginBackgroundTaskWithName:(NSString *)name expirationHandler:(void(^)(void))handler;
- (void)endBackgroundTask:(NSUInteger)identifier;
@end

@implementation UIApplication
+ (id)sharedApplication {
    return nil;
}
- (NSUInteger)beginBackgroundTaskWithName:(NSString *)name expirationHandler:(void(^)(void))handler {
    return 0;
}
- (void)endBackgroundTask:(NSUInteger)identifier {
}
@end

const NSUInteger UIBackgroundTaskInvalid = 0;
