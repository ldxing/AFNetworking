// AFDNSResolver.h
// DNS解析器

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const AFDNSResolverErrorDomain;

typedef NS_ENUM(NSInteger, AFDNSResolverError) {
    AFDNSResolverErrorUnknownHost = 1001,
    AFDNSResolverErrorNetworkError = 1002,
    AFDNSResolverErrorTimeout = 1003,
    AFDNSResolverErrorNoIPAddress = 1004,
};

@class AFDNSResolver;

@protocol AFDNSResolverDelegate <NSObject>

@optional
- (void)dnsResolver:(AFDNSResolver *)resolver didResolveHost:(NSString *)host ipAddresses:(NSArray<NSString *> *)ipAddresses;
- (void)dnsResolver:(AFDNSResolver *)resolver didFailToResolveHost:(NSString *)host error:(NSError *)error;

@end

@interface AFDNSResolver : NSObject

@property (nonatomic, weak) id<AFDNSResolverDelegate> delegate;
@property (nonatomic, assign) NSTimeInterval timeout;
@property (nonatomic, strong, nullable) NSArray<NSString *> *customDNSServers;

+ (instancetype)sharedResolver;

- (void)resolveHost:(NSString *)host
         completion:(void(^)(NSArray<NSString *> *ipAddresses, NSError * _Nullable error))completion;

- (void)resolveHosts:(NSArray<NSString *> *)hosts
          completion:(void(^)(NSDictionary<NSString *, NSArray<NSString *> *> *results))completion;

- (void)cancelAllResolutions;

- (nullable NSString *)ipAddressForHost:(NSString *)host;

@end

NS_ASSUME_NONNULL_END