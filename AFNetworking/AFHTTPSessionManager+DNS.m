//
//  AFHTTPSessionManager+DNS.m
//  AFNetworking
//
//  Created by DNS Resolver Extension on 2026/3/11.
//  Copyright © 2026 Alamofire Software Foundation. All rights reserved.
//

#import "AFHTTPSessionManager+DNS.h"
#import <objc/runtime.h>

static void *kAFEnableDNSPrefetchKey = &kAFEnableDNSPrefetchKey;
static void *kAFPrefetchDomainsKey = &kAFPrefetchDomainsKey;

@implementation AFHTTPSessionManager (DNS)

#pragma mark - 属性关联

- (BOOL)af_enableDNSPrefetch {
    NSNumber *value = objc_getAssociatedObject(self, kAFEnableDNSPrefetchKey);
    return value ? [value boolValue] : YES;
}

- (void)setAf_enableDNSPrefetch:(BOOL)af_enableDNSPrefetch {
    objc_setAssociatedObject(self, kAFEnableDNSPrefetchKey, @(af_enableDNSPrefetch), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray<NSString *> *)af_prefetchDomains {
    return objc_getAssociatedObject(self, kAFPrefetchDomainsKey);
}

- (void)setAf_prefetchDomains:(NSArray<NSString *> *)af_prefetchDomains {
    objc_setAssociatedObject(self, kAFPrefetchDomainsKey, af_prefetchDomains, OBJC_ASSOCIATION_COPY_NONATOMIC);
    
    // 自动预解析这些域名
    if (self.af_enableDNSPrefetch && af_prefetchDomains.count > 0) {
        [self af_prefetchDomains:af_prefetchDomains];
    }
}

#pragma mark - DNS预解析方法

- (void)af_prefetchDomain:(NSString *)domain {
    if (self.af_enableDNSPrefetch) {
        [[AFDNSResolutionManager sharedManager] prefetchDomain:domain];
    }
}

- (void)af_prefetchDomains:(NSArray<NSString *> *)domains {
    if (self.af_enableDNSPrefetch && domains.count > 0) {
        [[AFDNSResolutionManager sharedManager] prefetchDomains:domains];
    }
}

#pragma mark - 使用DNS解析的请求方法

- (NSURLSessionDataTask *)af_dataTaskWithHTTPMethod:(NSString *)method
                                          URLString:(NSString *)URLString
                                         parameters:(id)parameters
                                            success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                                            failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure {
    // 如果禁用DNS预解析，直接调用原方法
    if (!self.af_enableDNSPrefetch) {
        return [self dataTaskWithHTTPMethod:method URLString:URLString parameters:parameters success:success failure:failure];
    }
    
    // 解析URL中的域名
    NSURL *url = [NSURL URLWithString:URLString relativeToURL:self.baseURL];
    NSString *domain = url.host;
    
    // 预解析域名
    if (domain) {
        [self af_prefetchDomain:domain];
    }
    
    // 尝试替换域名为IP地址
    NSURL *resolvedURL = [[AFDNSResolutionManager sharedManager] urlByReplacingDomainWithIP:url];
    NSString *resolvedURLString = resolvedURL.absoluteString;
    
    // 调用原方法发起请求
    return [self dataTaskWithHTTPMethod:method URLString:resolvedURLString parameters:parameters success:success failure:failure];
}

@end
