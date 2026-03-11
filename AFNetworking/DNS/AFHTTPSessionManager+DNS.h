// AFHTTPSessionManager+DNS.h
// AFHTTPSessionManager DNS扩展

#import "AFHTTPSessionManager.h"
#import "AFDNSResolver.h"

NS_ASSUME_NONNULL_BEGIN

@interface AFHTTPSessionManager (DNS)

@property (nonatomic, assign) BOOL dnsPreResolutionEnabled;
@property (nonatomic, assign) BOOL useCachedDNSOnly;

- (void)preResolveHost:(NSString *)host
            completion:(nullable void(^)(NSArray<NSString *> *ipAddresses))completion;

- (void)preResolveHosts:(NSArray<NSString *> *)hosts
             completion:(nullable void(^)(void))completion;

- (void)clearDNSCache;

- (void)configureDNSServers:(NSArray<NSString *> *)servers
               defaultTTL:(NSTimeInterval)ttl;

@end

NS_ASSUME_NONNULL_END