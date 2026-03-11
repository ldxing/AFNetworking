// AFDNSCache.h
// DNS缓存管理器

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AFDNSCacheEntry : NSObject

@property (nonatomic, copy, readonly) NSString *host;
@property (nonatomic, strong, readonly) NSArray<NSString *> *ipAddresses;
@property (nonatomic, strong, readonly) NSDate *creationDate;
@property (nonatomic, assign, readonly) NSTimeInterval ttl;

- (instancetype)initWithHost:(NSString *)host
                 ipAddresses:(NSArray<NSString *> *)ipAddresses
                         ttl:(NSTimeInterval)ttl;

- (BOOL)isExpired;

@end

@interface AFDNSCache : NSObject

+ (instancetype)sharedCache;

@property (nonatomic, assign) NSTimeInterval defaultTTL;
@property (nonatomic, assign) NSUInteger maxCacheSize;

- (void)cacheEntry:(AFDNSCacheEntry *)entry;
- (nullable AFDNSCacheEntry *)entryForHost:(NSString *)host;
- (void)removeEntryForHost:(NSString *)host;
- (void)removeAllEntries;
- (NSArray<NSString *> *)allCachedHosts;

@end

NS_ASSUME_NONNULL_END