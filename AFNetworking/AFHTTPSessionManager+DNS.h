#import "AFHTTPSessionManager.h"
#import "AFDNSResolver.h"

NS_ASSUME_NONNULL_BEGIN

@interface AFHTTPSessionManager (DNS)

@property (nonatomic, assign, getter=isDNSResolutionEnabled) BOOL dnsResolutionEnabled;

@property (nonatomic, strong, nullable) AFDNSResolver *dnsResolver;

@end

NS_ASSUME_NONNULL_END
