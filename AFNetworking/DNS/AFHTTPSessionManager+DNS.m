// AFHTTPSessionManager+DNS.m
// AFHTTPSessionManager DNS扩展实现

#import "AFHTTPSessionManager+DNS.h"
#import "AFDNSCache.h"
#import "AFDNSResolver.h"
#import <objc/runtime.h>

static const void *kDNSPreResolutionEnabledKey = &kDNSPreResolutionEnabledKey;
static const void *kUseCachedDNSOnlyKey = &kUseCachedDNSOnlyKey;

@implementation AFHTTPSessionManager (DNS)

- (BOOL)dnsPreResolutionEnabled {
    return [objc_getAssociatedObject(self, kDNSPreResolutionEnabledKey) boolValue];
}

- (void)setDnsPreResolutionEnabled:(BOOL)dnsPreResolutionEnabled {
    objc_setAssociatedObject(self, kDNSPreResolutionEnabledKey, @(dnsPreResolutionEnabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)useCachedDNSOnly {
    return [objc_getAssociatedObject(self, kUseCachedDNSOnlyKey) boolValue];
}

- (void)setUseCachedDNSOnly:(BOOL)useCachedDNSOnly {
    objc_setAssociatedObject(self, kUseCachedDNSOnlyKey, @(useCachedDNSOnly), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)preResolveHost:(NSString *)host
            completion:(void(^)(NSArray<NSString *> *ipAddresses))completion {
    [[AFDNSResolver sharedResolver] resolveHost:host completion:^(NSArray<NSString *> *ipAddresses, NSError * _Nullable error) {
        if (completion) {
            completion(ipAddresses);
        }
    }];
}

- (void)preResolveHosts:(NSArray<NSString *> *)hosts
             completion:(void(^)(void))completion {
    [[AFDNSResolver sharedResolver] resolveHosts:hosts completion:^(NSDictionary<NSString *,NSArray<NSString *> *> * _Nonnull results) {
        if (completion) {
            completion();
        }
    }];
}

- (void)clearDNSCache {
    [[AFDNSCache sharedCache] removeAllEntries];
}

- (void)configureDNSServers:(NSArray<NSString *> *)servers
               defaultTTL:(NSTimeInterval)ttl {
    [AFDNSResolver sharedResolver].customDNSServers = servers;
    [AFDNSCache sharedCache].defaultTTL = ttl;
}

@end