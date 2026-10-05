#ifndef Libbox_h
#define Libbox_h
#import <Foundation/Foundation.h>

@interface LibboxCommandServer : NSObject
- (int64_t)totalUpload;
- (int64_t)totalDownload;
- (void)close;
@end

@interface LibboxBoxService : NSObject
- (BOOL)start:(NSError **)error;
- (void)close;
@end

FOUNDATION_EXPORT LibboxCommandServer* _Nullable LibboxNewCommandServer(id _Nullable handler, int32_t maxClients, NSError* _Nullable* _Nullable error);
FOUNDATION_EXPORT LibboxBoxService* _Nullable LibboxNewBoxService(NSString* _Nonnull configContent, id _Nullable platformInterface, NSError* _Nullable* _Nullable error);

#endif
