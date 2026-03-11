// AFDNSCache.h
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

NS_ASSUME_NONNULL_BEGIN

/**
 DNS缓存策略
 */
typedef NS_ENUM(NSInteger, AFDNSCachePolicy) {
    /**
     仅使用内存缓存
     */
    AFDNSCachePolicyMemoryOnly = 0,
    
    /**
     内存缓存 + 磁盘缓存
     */
    AFDNSCachePolicyMemoryAndDisk = 1,
    
    /**
     仅使用磁盘缓存
     */
    AFDNSCachePolicyDiskOnly = 2
};

/**
 DNS缓存配置
 */
@interface AFDNSCacheConfiguration : NSObject <NSSecureCoding, NSCopying>

/**
 缓存策略 (默认: AFDNSCachePolicyMemoryAndDisk)
 */
@property (nonatomic, assign) AFDNSCachePolicy cachePolicy;

/**
 内存缓存最大数量 (默认: 100)
 */
@property (nonatomic, assign) NSUInteger memoryCacheCountLimit;

/**
 内存缓存成本限制 (默认: 10MB)
 */
@property (nonatomic, assign) NSUInteger memoryCacheTotalCostLimit;

/**
 磁盘缓存最大大小 (默认: 50MB)
 */
@property (nonatomic, assign) NSUInteger diskCacheSizeLimit;

/**
 默认TTL倍数 (默认: 1.0，使用DNS返回的TTL)
 可以设置为小于1的值来提前刷新缓存
 */
@property (nonatomic, assign) CGFloat defaultTTLMultiplier;

/**
 最小TTL值 (默认: 60秒)
 */
@property (nonatomic, assign) NSTimeInterval minimumTTL;

/**
 最大TTL值 (默认: 86400秒，即24小时)
 */
@property (nonatomic, assign) NSTimeInterval maximumTTL;

/**
 自动清理间隔 (默认: 300秒，即5分钟)
 */
@property (nonatomic, assign) NSTimeInterval autoCleanupInterval;

/**
 是否启用后台自动更新 (默认: YES)
 */
@property (nonatomic, assign) BOOL enableBackgroundRefresh;

/**
 后台更新提前时间 (默认: 60秒)
 在TTL过期前多少秒开始后台更新
 */
@property (nonatomic, assign) NSTimeInterval backgroundRefreshAdvanceTime;

/**
 默认配置
 */
+ (instancetype)defaultConfiguration;

@end

/**
 DNS缓存管理器
 负责DNS解析结果的缓存管理，包括过期策略和更新机制
 */
@interface AFDNSCache : NSObject

/**
 缓存配置
 */
@property (nonatomic, copy, readonly) AFDNSCacheConfiguration *configuration;

/**
 创建单例实例
 */
+ (instancetype)sharedCache;

/**
 初始化方法

 @param configuration 缓存配置
 @return AFDNSCache实例
 */
- (instancetype)initWithConfiguration:(AFDNSCacheConfiguration *)configuration NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

#pragma mark - Cache Operations

/**
 存储DNS解析记录

 @param record DNS解析记录
 */
- (void)storeRecord:(AFDNSRecord *)record;

/**
 批量存储DNS解析记录

 @param records DNS解析记录数组
 */
- (void)storeRecords:(NSArray<AFDNSRecord *> *)records;

/**
 获取DNS解析记录

 @param domain 域名
 @return DNS解析记录，如果不存在或已过期则返回nil
 */
- (nullable AFDNSRecord *)recordForDomain:(NSString *)domain;

/**
 获取DNS解析记录（包含过期记录）

 @param domain 域名
 @return DNS解析记录，即使已过期也返回
 */
- (nullable AFDNSRecord *)recordForDomainIgnoringExpiration:(NSString *)domain;

/**
 检查域名是否在缓存中且未过期

 @param domain 域名
 @return YES表示缓存有效
 */
- (BOOL)containsValidRecordForDomain:(NSString *)domain;

/**
 获取所有有效的DNS解析记录

 @return 有效的DNS解析记录字典
 */
- (NSDictionary<NSString *, AFDNSRecord *> *)allValidRecords;

/**
 移除指定域名的缓存

 @param domain 域名
 */
- (void)removeRecordForDomain:(NSString *)domain;

/**
 移除所有过期记录

 @return 移除的记录数量
 */
- (NSUInteger)removeExpiredRecords;

/**
 清空所有缓存
 */
- (void)removeAllRecords;

#pragma mark - Cache Persistence

/**
 将缓存保存到磁盘
 */
- (void)synchronize;

/**
 从磁盘加载缓存
 */
- (void)loadFromDisk;

#pragma mark - Cache Statistics

/**
 获取缓存统计信息

 @return 统计信息字典
 */
- (NSDictionary *)cacheStatistics;

/**
 内存缓存数量
 */
@property (nonatomic, assign, readonly) NSUInteger memoryCacheCount;

/**
 磁盘缓存大小 (字节)
 */
@property (nonatomic, assign, readonly) unsigned long long diskCacheSize;

@end

/**
 DNS缓存通知
 */
FOUNDATION_EXPORT NSString * const AFDNSCacheDidUpdateNotification;
FOUNDATION_EXPORT NSString * const AFDNSCacheDidRemoveExpiredRecordsNotification;
FOUNDATION_EXPORT NSString * const AFDNSCacheDidClearNotification;

/**
 通知UserInfo键
 */
FOUNDATION_EXPORT NSString * const AFDNSCacheDomainKey;
FOUNDATION_EXPORT NSString * const AFDNSCacheRecordKey;
FOUNDATION_EXPORT NSString * const AFDNSCacheRemovedCountKey;

NS_ASSUME_NONNULL_END
