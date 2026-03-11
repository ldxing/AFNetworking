// AFDNSHTTPSessionManager.m
// 封装DNS预解析功能的HTTP Session Manager实现

#import "AFDNSHTTPSessionManager.h"

@interface AFDNSHTTPSessionManager ()
@property (nonatomic, strong) AFDNSResolver *dnsResolver;
@end

@implementation AFDNSHTTPSessionManager

+ (instancetype)manager {
    return [[self alloc] initWithBaseURL:nil];
}

+ (instancetype)managerWithBaseURL:(NSURL *)url {
    return [[self alloc] initWithBaseURL:url];
}

+ (instancetype)managerWithBaseURL:(NSURL *)url
               sessionConfiguration:(NSURLSessionConfiguration *)configuration {
    return [[self alloc] initWithBaseURL:url sessionConfiguration:configuration];
}

- (instancetype)initWithBaseURL:(NSURL *)url
           sessionConfiguration:(NSURLSessionConfiguration *)configuration {
    self = [super initWithBaseURL:url sessionConfiguration:configuration];
    if (self) {
        _dnsResolver = [AFDNSResolver sharedResolver];
        _dnsResolutionPolicy = AFDNSResolutionPolicyDefault;
        _dnsCacheTTL = 300.0;
        _enableDNSPrefetch = YES;
        
        [AFDNSCache sharedCache].defaultTTL = _dnsCacheTTL;
    }
    return self;
}

- (void)prefetchDNSForHosts:(NSArray<NSString *> *)hosts {
    if (!self.enableDNSPrefetch || !hosts || hosts.count == 0) {
        return;
    }
    
    [self.dnsResolver resolveHosts:hosts completion:nil];
}

- (void)prefetchDNSForURL:(NSURL *)url
                completion:(void(^)(NSArray<NSString *> *ipAddresses))completion {
    if (!url || !url.host) {
        if (completion) {
            completion(nil);
        }
        return;
    }
    
    [self.dnsResolver resolveHost:url.host completion:^(NSArray<NSString *> *ipAddresses, NSError * _Nullable error) {
        if (completion) {
            completion(ipAddresses);
        }
    }];
}

- (NSURLSessionDataTask *)GET:(NSString *)URLString
                   parameters:(id)parameters
                      headers:(NSDictionary<NSString *,NSString *> *)headers
                     progress:(void (^)(NSProgress *downloadProgress))downloadProgress
                preResolveDNS:(BOOL)preResolve
                      success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                      failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure {
    
    if (preResolve && self.enableDNSPrefetch) {
        NSURL *url = [NSURL URLWithString:URLString relativeToURL:self.baseURL];
        if (url.host) {
            AFDNSCacheEntry *cachedEntry = [[AFDNSCache sharedCache] entryForHost:url.host];
            if (!cachedEntry) {
                [self.dnsResolver resolveHost:url.host completion:nil];
            }
        }
    }
    
    return [super GET:URLString parameters:parameters headers:headers progress:downloadProgress success:success failure:failure];
}

- (NSURLSessionDataTask *)POST:(NSString *)URLString
                    parameters:(id)parameters
                       headers:(NSDictionary<NSString *,NSString *> *)headers
                      progress:(void (^)(NSProgress *uploadProgress))uploadProgress
                 preResolveDNS:(BOOL)preResolve
                       success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                       failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure {
    
    if (preResolve && self.enableDNSPrefetch) {
        NSURL *url = [NSURL URLWithString:URLString relativeToURL:self.baseURL];
        if (url.host) {
            AFDNSCacheEntry *cachedEntry = [[AFDNSCache sharedCache] entryForHost:url.host];
            if (!cachedEntry) {
                [self.dnsResolver resolveHost:url.host completion:nil];
            }
        }
    }
    
    return [super POST:URLString parameters:parameters headers:headers progress:uploadProgress success:success failure:failure];
}

- (void)invalidateDNSCache {
    [[AFDNSCache sharedCache] removeAllEntries];
}

- (void)setCustomDNSServers:(NSArray<NSString *> *)servers {
    self.dnsResolver.customDNSServers = servers;
}

- (void)setDnsCacheTTL:(NSTimeInterval)dnsCacheTTL {
    _dnsCacheTTL = dnsCacheTTL;
    [AFDNSCache sharedCache].defaultTTL = dnsCacheTTL;
}

@end