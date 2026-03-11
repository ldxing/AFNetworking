//
//  AFDNSResolver.h
//  AFNetworking
//
//  Created by DNS Resolver Extension on 2026/3/11.
//  Copyright © 2026 Alamofire Software Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  DNS解析结果模型
 */
@interface AFDNSRecord : NSObject <NSCoding>

/** 域名 */
@property (nonatomic, copy, readonly) NSString *domain;

/** IP地址列表 */
@property (nonatomic, copy, readonly) NSArray<NSString *> *ipAddresses;

/** 解析时间戳 */
@property (nonatomic, assign, readonly) NSTimeInterval timestamp;

/** TTL(生存时间，秒) */
@property (nonatomic, assign, readonly) NSTimeInterval ttl;

/**
 *  初始化DNS记录
 *
 *  @param domain      域名
 *  @param ipAddresses IP地址列表
 *  @param ttl         生存时间
 *
 *  @return DNS记录实例
 */
- (instancetype)initWithDomain:(NSString *)domain
                   ipAddresses:(NSArray<NSString *> *)ipAddresses
                           ttl:(NSTimeInterval)ttl;

/**
 *  检查记录是否过期
 *
 *  @return 是否已过期
 */
- (BOOL)isExpired;

@end

/**
 *  DNS解析器协议
 */
@protocol AFDNSResolver <NSObject>

/**
 *  解析域名
 *
 *  @param domain    要解析的域名
 *  @param completion 解析完成回调
 */
- (void)resolveDomain:(NSString *)domain
           completion:(void (^)(AFDNSRecord * _Nullable record, NSError * _Nullable error))completion;

@end

/**
 *  系统DNS解析器实现
 */
@interface AFSystemDNSResolver : NSObject <AFDNSResolver>

/** 默认TTL时间(秒)，默认300秒 */
@property (nonatomic, assign) NSTimeInterval defaultTTL;

@end

/**
 *  DNS缓存管理器
 */
@interface AFDNSCacheManager : NSObject

/** 缓存最大数量，默认100条 */
@property (nonatomic, assign) NSUInteger maxCacheCount;

/**
 *  单例实例
 *
 *  @return 缓存管理器单例
 */
+ (instancetype)sharedManager;

/**
 *  缓存DNS记录
 *
 *  @param record DNS记录
 */
- (void)cacheDNSRecord:(AFDNSRecord *)record;

/**
 *  获取缓存的DNS记录
 *
 *  @param domain 域名
 *
 *  @return 缓存的记录，不存在返回nil
 */
- (AFDNSRecord * _Nullable)cachedRecordForDomain:(NSString *)domain;

/**
 *  移除指定域名的缓存
 *
 *  @param domain 域名
 */
- (void)removeCacheForDomain:(NSString *)domain;

/**
 *  清空所有缓存
 */
- (void)clearAllCache;

/**
 *  清理过期的缓存记录
 */
- (void)clearExpiredCache;

@end

/**
 *  DNS解析管理器 - 核心入口类
 */
@interface AFDNSResolutionManager : NSObject

/** DNS解析器，默认使用AFSystemDNSResolver */
@property (nonatomic, strong) id<AFDNSResolver> resolver;

/** 是否启用DNS解析，默认YES */
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;

/** 是否自动清理过期缓存，默认YES */
@property (nonatomic, assign) BOOL autoClearExpiredCache;

/**
 *  单例实例
 *
 *  @return DNS解析管理器单例
 */
+ (instancetype)sharedManager;

/**
 *  预解析域名
 *
 *  @param domain 要预解析的域名
 */
- (void)prefetchDomain:(NSString *)domain;

/**
 *  预解析多个域名
 *
 *  @param domains 域名列表
 */
- (void)prefetchDomains:(NSArray<NSString *> *)domains;

/**
 *  获取域名的IP地址（优先从缓存获取，无缓存则同步解析）
 *
 *  @param domain 域名
 *
 *  @return IP地址，解析失败返回nil
 */
- (NSString * _Nullable)ipAddressForDomain:(NSString *)domain;

/**
 *  获取域名的所有IP地址（优先从缓存获取，无缓存则同步解析）
 *
 *  @param domain 域名
 *
 *  @return IP地址列表，解析失败返回nil
 */
- (NSArray<NSString *> * _Nullable)ipAddressesForDomain:(NSString *)domain;

/**
 *  异步获取域名的IP地址
 *
 *  @param domain     域名
 *  @param completion 完成回调
 */
- (void)resolveDomain:(NSString *)domain
           completion:(void (^)(NSString * _Nullable ipAddress, NSError * _Nullable error))completion;

/**
 *  替换URL中的域名为IP地址
 *
 *  @param url 原始URL
 *
 *  @return 替换后的URL，解析失败返回原始URL
 */
- (NSURL * _Nullable)urlByReplacingDomainWithIP:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
