// AFHTTPSessionManager+DNS.m
// Copyright (c) 2025 AFNetworking Extension
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "AFHTTPSessionManager+DNS.h"
#import <objc/runtime.h>

static const char *kDNSResolutionManagerKey = "dnsResolutionManager";
static const char *kDNSPreResolutionEnabledKey = "dnsPreResolutionEnabled";
static const char *kAutoReplaceDomainWithIPKey = "autoReplaceDomainWithIP";

@implementation AFHTTPSessionManager (DNS)

#pragma mark - Associated Properties

- (AFDNSResolutionManager *)dnsResolutionManager {
    AFDNSResolutionManager *manager = objc_getAssociatedObject(self, kDNSResolutionManagerKey);
    if (!manager) {
        manager = [AFDNSResolutionManager sharedManager];
        objc_setAssociatedObject(self, kDNSResolutionManagerKey, manager, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return manager;
}

- (void)setDnsResolutionManager:(AFDNSResolutionManager *)dnsResolutionManager {
    objc_setAssociatedObject(self, kDNSResolutionManagerKey, dnsResolutionManager, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)dnsPreResolutionEnabled {
    NSNumber *enabled = objc_getAssociatedObject(self, kDNSPreResolutionEnabledKey);
    if (!enabled) {
        return YES;
    }
    return enabled.boolValue;
}

- (void)setDnsPreResolutionEnabled:(BOOL)dnsPreResolutionEnabled {
    objc_setAssociatedObject(self, kDNSPreResolutionEnabledKey, @(dnsPreResolutionEnabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.dnsResolutionManager.enabled = dnsPreResolutionEnabled;
}

- (BOOL)autoReplaceDomainWithIP {
    NSNumber *enabled = objc_getAssociatedObject(self, kAutoReplaceDomainWithIPKey);
    if (!enabled) {
        return NO;
    }
    return enabled.boolValue;
}

- (void)setAutoReplaceDomainWithIP:(BOOL)autoReplaceDomainWithIP {
    objc_setAssociatedObject(self, kAutoReplaceDomainWithIPKey, @(autoReplaceDomainWithIP), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Configuration

- (void)setDNSResolverConfiguration:(AFDNSResolverConfiguration *)configuration {
    self.dnsResolutionManager.resolver.configuration = configuration;
}

- (void)setDNSCacheConfiguration:(AFDNSCacheConfiguration *)configuration {
    self.dnsResolutionManager.cache.configuration = configuration;
}

#pragma mark - DNS Resolution Methods

- (void)preResolveDomain:(NSString *)domain
              completion:(nullable AFDNSResolutionCompletionBlock)completionBlock {
    if (!self.dnsPreResolutionEnabled) {
        if (completionBlock) {
            completionBlock(nil, nil);
        }
        return;
    }
    
    [self.dnsResolutionManager resolveDomain:domain completion:completionBlock];
}

- (void)preResolveDomains:(NSArray<NSString *> *)domains
               completion:(nullable void (^)(NSDictionary<NSString *, AFDNSRecord *> *results))completionBlock {
    if (!self.dnsPreResolutionEnabled) {
        if (completionBlock) {
            completionBlock(@{});
        }
        return;
    }
    
    [self.dnsResolutionManager preResolveDomains:domains completion:completionBlock];
}

- (void)warmUpDNSCacheWithDomains:(NSArray<NSString *> *)domains {
    if (!self.dnsPreResolutionEnabled) {
        return;
    }
    
    [self.dnsResolutionManager warmUpCacheWithDomains:domains];
}

- (nullable NSString *)ipAddressForDomain:(NSString *)domain {
    return [self.dnsResolutionManager ipAddressForDomain:domain];
}

- (void)clearDNSCache {
    [self.dnsResolutionManager.cache removeAllRecords];
}

- (NSDictionary *)dnsCacheStatistics {
    return [self.dnsResolutionManager.cache cacheStatistics];
}

#pragma mark - Method Swizzling

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self swizzleDataTaskMethod];
    });
}

+ (void)swizzleDataTaskMethod {
    Method originalMethod = class_getInstanceMethod(self, @selector(dataTaskWithHTTPMethod:URLString:parameters:headers:uploadProgress:downloadProgress:success:failure:));
    Method swizzledMethod = class_getInstanceMethod(self, @selector(dns_dataTaskWithHTTPMethod:URLString:parameters:headers:uploadProgress:downloadProgress:success:failure:));
    
    if (originalMethod && swizzledMethod) {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

- (nullable NSURLSessionDataTask *)dns_dataTaskWithHTTPMethod:(NSString *)method
                                                    URLString:(NSString *)URLString
                                                   parameters:(nullable id)parameters
                                                      headers:(nullable NSDictionary<NSString *, NSString *> *)headers
                                               uploadProgress:(nullable void (^)(NSProgress *uploadProgress))uploadProgress
                                             downloadProgress:(nullable void (^)(NSProgress *downloadProgress))downloadProgress
                                                      success:(nullable void (^)(NSURLSessionDataTask *task, id _Nullable responseObject))success
                                                      failure:(nullable void (^)(NSURLSessionDataTask *_Nullable task, NSError *error))failure {
    
    NSString *originalURLString = URLString;
    
    if (self.dnsPreResolutionEnabled && self.autoReplaceDomainWithIP && URLString) {
        NSURL *url = [NSURL URLWithString:URLString relativeToURL:self.baseURL];
        if (url && url.host) {
            NSString *ipAddress = [self.dnsResolutionManager ipAddressForDomain:url.host];
            if (ipAddress) {
                NSString *newURLString = URLString;
                newURLString = [newURLString stringByReplacingOccurrencesOfString:url.host withString:ipAddress];
                URLString = newURLString;
            } else {
                [self.dnsResolutionManager resolveDomain:url.host completion:nil];
            }
        }
    } else if (self.dnsPreResolutionEnabled && URLString) {
        NSURL *url = [NSURL URLWithString:URLString relativeToURL:self.baseURL];
        if (url && url.host) {
            if (![self.dnsResolutionManager.cache containsValidRecordForDomain:url.host]) {
                [self.dnsResolutionManager resolveDomain:url.host completion:nil];
            }
        }
    }
    
    NSURLSessionDataTask *task = [self dns_dataTaskWithHTTPMethod:method
                                                        URLString:URLString
                                                       parameters:parameters
                                                          headers:headers
                                                   uploadProgress:uploadProgress
                                                 downloadProgress:downloadProgress
                                                          success:success
                                                          failure:failure];
    
    return task;
}

@end
