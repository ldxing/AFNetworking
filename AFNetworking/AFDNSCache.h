#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSTimeInterval const kAFDNSCacheDefaultExpirationTime;
extern NSUInteger const kAFDNSCacheDefaultMaxCount;

@interface AFDNSCache : NSObject

@property (nonatomic, assign) NSTimeInterval expirationTime;
@property (nonatomic, assign) NSUInteger maxCacheCount;

+ (instancetype)sharedCache;

- (void)setIPAddresses:(NSArray<NSString *> *)ipAddresses forDomain:(NSString *)domain;

- (nullable NSArray<NSString *> *)ipAddressesForDomain:(NSString *)domain;

- (void)removeIPAddressesForDomain:(NSString *)domain;

- (void)clearCache;

- (void)clearExpiredCache;

@end

NS_ASSUME_NONNULL_END
