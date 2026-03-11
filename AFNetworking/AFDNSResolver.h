// AFDNSResolver.h
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

NS_ASSUME_NONNULL_BEGIN

/**
 DNS解析结果模型
 */
@interface AFDNSRecord : NSObject <NSSecureCoding, NSCopying>

/**
 域名
 */
@property (readonly, nonatomic, copy) NSString *domain;

/**
 IP地址列表
 */
@property (readonly, nonatomic, copy) NSArray<NSString *> *ipAddresses;

/**
 TTL (生存时间，单位：秒)
 */
@property (readonly, nonatomic, assign) NSTimeInterval TTL;

/**
 记录创建时间
 */
@property (readonly, nonatomic, strong) NSDate *createTime;

/**
 是否已过期
 */
@property (readonly, nonatomic, assign, getter=isExpired) BOOL expired;

/**
 初始化方法

 @param domain 域名
 @param ipAddresses IP地址列表
 @param TTL TTL值
 @return AFDNSRecord实例
 */
- (instancetype)initWithDomain:(NSString *)domain
                   ipAddresses:(NSArray<NSString *> *)ipAddresses
                           TTL:(NSTimeInterval)TTL NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

/**
 DNS解析器配置
 */
@interface AFDNSResolverConfiguration : NSObject <NSSecureCoding, NSCopying>

/**
 自定义DNS服务器地址列表 (例如: @["8.8.8.8", "114.114.114.114"])
 如果为nil，则使用系统默认DNS
 */
@property (nonatomic, copy, nullable) NSArray<NSString *> *customDNSServers;

/**
 解析超时时间 (默认: 5秒)
 */
@property (nonatomic, assign) NSTimeInterval timeoutInterval;

/**
 是否启用IPv6解析 (默认: YES)
 */
@property (nonatomic, assign) BOOL enableIPv6;

/**
 是否优先返回IPv6地址 (默认: NO)
 */
@property (nonatomic, assign) BOOL preferIPv6;

/**
 重试次数 (默认: 2)
 */
@property (nonatomic, assign) NSUInteger retryCount;

/**
 默认配置
 */
+ (instancetype)defaultConfiguration;

@end

typedef void (^AFDNSResolutionCompletionBlock)(AFDNSRecord * _Nullable record, NSError * _Nullable error);

/**
 DNS解析器
 负责执行DNS查询操作
 */
@interface AFDNSResolver : NSObject

/**
 解析器配置
 */
@property (nonatomic, copy) AFDNSResolverConfiguration *configuration;

/**
 创建单例实例
 */
+ (instancetype)sharedResolver;

/**
 初始化方法

 @param configuration 解析器配置
 @return AFDNSResolver实例
 */
- (instancetype)initWithConfiguration:(AFDNSResolverConfiguration *)configuration NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
 解析域名

 @param domain 要解析的域名
 @param completionBlock 完成回调
 */
- (void)resolveDomain:(NSString *)domain
           completion:(AFDNSResolutionCompletionBlock)completionBlock;

/**
 同步解析域名 (阻塞当前线程)

 @param domain 要解析的域名
 @param error 错误信息
 @return DNS解析结果
 */
- (nullable AFDNSRecord *)resolveDomainSynchronously:(NSString *)domain
                                               error:(NSError **)error;

/**
 批量预解析域名

 @param domains 域名列表
 @param completionBlock 完成回调
 */
- (void)preResolveDomains:(NSArray<NSString *> *)domains
               completion:(nullable void (^)(NSDictionary<NSString *, AFDNSRecord *> *results))completionBlock;

/**
 取消所有正在进行的解析任务
 */
- (void)cancelAllResolutions;

@end

/**
 错误域
 */
FOUNDATION_EXPORT NSString * const AFDNSResolverErrorDomain;

/**
 错误码
 */
typedef NS_ENUM(NSInteger, AFDNSResolverErrorCode) {
    AFDNSResolverErrorUnknown = 0,
    AFDNSResolverErrorInvalidDomain = 1,
    AFDNSResolverErrorResolutionTimeout = 2,
    AFDNSResolverErrorNoIPAddressFound = 3,
    AFDNSResolverErrorNetworkUnavailable = 4,
    AFDNSResolverErrorCancelled = 5
};

NS_ASSUME_NONNULL_END
