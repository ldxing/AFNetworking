// AFDNSHTTPSessionManager.h
// 封装DNS预解析功能的HTTP Session Manager

#import "AFHTTPSessionManager.h"
#import "AFDNSResolver.h"
#import "AFDNSCache.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AFDNSResolutionPolicy) {
    AFDNSResolutionPolicyDefault = 0,
    AFDNSResolutionPolicyPreResolveOnly,
    AFDNSResolutionPolicyCacheOnly,
};

@interface AFDNSHTTPSessionManager : AFHTTPSessionManager

@property (nonatomic, assign) AFDNSResolutionPolicy dnsResolutionPolicy;
@property (nonatomic, assign) NSTimeInterval dnsCacheTTL;
@property (nonatomic, assign) BOOL enableDNSPrefetch;

+ (instancetype)manager;

+ (instancetype)managerWithBaseURL:(nullable NSURL *)url;

+ (instancetype)managerWithBaseURL:(nullable NSURL *)url
               sessionConfiguration:(nullable NSURLSessionConfiguration *)configuration;

- (void)prefetchDNSForHosts:(NSArray<NSString *> *)hosts;

- (void)prefetchDNSForURL:(NSURL *)url
                completion:(nullable void(^)(NSArray<NSString *> *ipAddresses))completion;

- (NSURLSessionDataTask *)GET:(NSString *)URLString
                   parameters:(nullable id)parameters
                      headers:(nullable NSDictionary <NSString *, NSString *> *)headers
                     progress:(nullable void (^)(NSProgress *downloadProgress))downloadProgress
            preResolveDNS:(BOOL)preResolve
                      success:(nullable void (^)(NSURLSessionDataTask *task, id _Nullable responseObject))success
                      failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError *error))failure;

- (NSURLSessionDataTask *)POST:(NSString *)URLString
                    parameters:(nullable id)parameters
                       headers:(nullable NSDictionary <NSString *, NSString *> *)headers
                      progress:(nullable void (^)(NSProgress *uploadProgress))uploadProgress
               preResolveDNS:(BOOL)preResolve
                       success:(nullable void (^)(NSURLSessionDataTask *task, id _Nullable responseObject))success
                       failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError *error))failure;

- (void)invalidateDNSCache;

- (void)setCustomDNSServers:(NSArray<NSString *> *)servers;

@end

NS_ASSUME_NONNULL_END