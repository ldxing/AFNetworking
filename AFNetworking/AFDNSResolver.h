#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^AFDNSResolverCompletionBlock)(NSArray<NSString *> * _Nullable ipAddresses, NSError * _Nullable error);

@interface AFDNSResolver : NSObject

@property (nonatomic, copy, nullable) NSArray<NSString *> *dnsServers;

+ (instancetype)sharedResolver;

- (void)resolveDomain:(NSString *)domain completion:(nullable AFDNSResolverCompletionBlock)completion;

- (void)preResolveDomains:(NSArray<NSString *> *)domains;

@end

NS_ASSUME_NONNULL_END
