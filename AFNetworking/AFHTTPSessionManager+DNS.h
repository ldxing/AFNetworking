// AFHTTPSessionManager+DNS.h
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
#import "AFHTTPSessionManager.h"
#import "AFDNSResolutionManager.h"

NS_ASSUME_NONNULL_BEGIN

/**
 AFHTTPSessionManager的DNS扩展
 提供DNS预解析功能，优化网络请求性能
 */
@interface AFHTTPSessionManager (DNS)

/**
 DNS解析管理器
 */
@property (nonatomic, strong, readonly) AFDNSResolutionManager *dnsResolutionManager;

/**
 是否启用DNS预解析 (默认: YES)
 */
@property (nonatomic, assign) BOOL dnsPreResolutionEnabled;

/**
 是否在请求时自动替换域名为IP地址 (默认: NO)
 注意: 开启此选项可能需要处理HTTPS证书验证问题
 */
@property (nonatomic, assign) BOOL autoReplaceDomainWithIP;

/**
 设置DNS解析配置

 @param configuration DNS解析配置
 */
- (void)setDNSResolverConfiguration:(AFDNSResolverConfiguration *)configuration;

/**
 设置DNS缓存配置

 @param configuration DNS缓存配置
 */
- (void)setDNSCacheConfiguration:(AFDNSCacheConfiguration *)configuration;

/**
 预解析指定域名

 @param domain 域名
 @param completionBlock 完成回调
 */
- (void)preResolveDomain:(NSString *)domain
              completion:(nullable AFDNSResolutionCompletionBlock)completionBlock;

/**
 批量预解析域名

 @param domains 域名列表
 @param completionBlock 完成回调
 */
- (void)preResolveDomains:(NSArray<NSString *> *)domains
               completion:(nullable void (^)(NSDictionary<NSString *, AFDNSRecord *> *results))completionBlock;

/**
 预热DNS缓存

 @param domains 需要预热的域名列表
 */
- (void)warmUpDNSCacheWithDomains:(NSArray<NSString *> *)domains;

/**
 获取域名的IP地址

 @param domain 域名
 @return IP地址
 */
- (nullable NSString *)ipAddressForDomain:(NSString *)domain;

/**
 清除DNS缓存
 */
- (void)clearDNSCache;

/**
 获取DNS缓存统计信息

 @return 统计信息字典
 */
- (NSDictionary *)dnsCacheStatistics;

@end

NS_ASSUME_NONNULL_END
