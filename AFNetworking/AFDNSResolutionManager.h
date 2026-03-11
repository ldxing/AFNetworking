// AFDNSResolutionManager.h
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

#import <Foundation/Foundation.h>
#import "AFDNSResolver.h"
#import "AFDNSCache.h"

NS_ASSUME_NONNULL_BEGIN

/**
 DNS解析管理器
 统筹DNS解析和缓存管理，提供统一的DNS预解析接口
 */
@interface AFDNSResolutionManager : NSObject

/**
 DNS解析器
 */
@property (nonatomic, strong) AFDNSResolver *resolver;

/**
 DNS缓存
 */
@property (nonatomic, strong) AFDNSCache *cache;

/**
 是否启用DNS预解析 (默认: YES)
 */
@property (nonatomic, assign) BOOL enabled;

/**
 创建单例实例
 */
+ (instancetype)sharedManager;

/**
 初始化方法

 @param resolver DNS解析器
 @param cache DNS缓存
 @return AFDNSResolutionManager实例
 */
- (instancetype)initWithResolver:(AFDNSResolver *)resolver
                           cache:(AFDNSCache *)cache NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

#pragma mark - DNS Resolution

/**
 解析域名（优先从缓存获取）

 @param domain 域名
 @param completionBlock 完成回调
 */
- (void)resolveDomain:(NSString *)domain
           completion:(AFDNSResolutionCompletionBlock)completionBlock;

/**
 强制刷新域名解析（忽略缓存）

 @param domain 域名
 @param completionBlock 完成回调
 */
- (void)refreshDomain:(NSString *)domain
           completion:(AFDNSResolutionCompletionBlock)completionBlock;

/**
 批量预解析域名

 @param domains 域名列表
 @param completionBlock 完成回调
 */
- (void)preResolveDomains:(NSArray<NSString *> *)domains
               completion:(nullable void (^)(NSDictionary<NSString *, AFDNSRecord *> *results))completionBlock;

/**
 获取域名的IP地址（同步方法，优先从缓存获取）

 @param domain 域名
 @return IP地址，如果没有缓存则返回nil
 */
- (nullable NSString *)ipAddressForDomain:(NSString *)domain;

/**
 获取域名的所有IP地址（同步方法，优先从缓存获取）

 @param domain 域名
 @return IP地址列表，如果没有缓存则返回nil
 */
- (nullable NSArray<NSString *> *)ipAddressesForDomain:(NSString *)domain;

#pragma mark - URL Processing

/**
 从URL中提取域名并解析

 @param url URL
 @param completionBlock 完成回调
 */
- (void)resolveURL:(NSURL *)url
        completion:(AFDNSResolutionCompletionBlock)completionBlock;

/**
 替换URL中的域名为IP地址

 @param url 原始URL
 @return 替换后的URL，如果无法解析则返回原始URL
 */
- (NSURL *)urlByReplacingDomainWithIP:(NSURL *)url;

#pragma mark - Cache Management

/**
 预热缓存（预解析并缓存常用域名）

 @param domains 域名列表
 */
- (void)warmUpCacheWithDomains:(NSArray<NSString *> *)domains;

/**
 检查域名是否需要刷新

 @param domain 域名
 @return YES表示需要刷新
 */
- (BOOL)shouldRefreshDomain:(NSString *)domain;

/**
 启动后台自动刷新
 */
- (void)startBackgroundRefresh;

/**
 停止后台自动刷新
 */
- (void)stopBackgroundRefresh;

@end

/**
 DNS解析管理器通知
 */
FOUNDATION_EXPORT NSString * const AFDNSResolutionManagerDidResolveDomainNotification;
FOUNDATION_EXPORT NSString * const AFDNSResolutionManagerDidFailToResolveDomainNotification;

/**
 通知UserInfo键
 */
FOUNDATION_EXPORT NSString * const AFDNSResolutionManagerDomainKey;
FOUNDATION_EXPORT NSString * const AFDNSResolutionManagerRecordKey;
FOUNDATION_EXPORT NSString * const AFDNSResolutionManagerErrorKey;

NS_ASSUME_NONNULL_END
