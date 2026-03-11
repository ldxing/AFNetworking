//
//  AFHTTPSessionManager+DNS.h
//  AFNetworking
//
//  Created by DNS Resolver Extension on 2026/3/11.
//  Copyright © 2026 Alamofire Software Foundation. All rights reserved.
//

#import "AFHTTPSessionManager.h"
#import "AFDNSResolver.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  AFHTTPSessionManager的DNS扩展类别
 *  通过类别方式扩展，不修改原框架代码
 */
@interface AFHTTPSessionManager (DNS)

/** 是否启用DNS预解析，默认YES */
@property (nonatomic, assign) BOOL af_enableDNSPrefetch;

/** 需要预解析的域名列表 */
@property (nonatomic, copy, nullable) NSArray<NSString *> *af_prefetchDomains;

/**
 *  预解析指定域名
 *
 *  @param domain 域名
 */
- (void)af_prefetchDomain:(NSString *)domain;

/**
 *  预解析多个域名
 *
 *  @param domains 域名列表
 */
- (void)af_prefetchDomains:(NSArray<NSString *> *)domains;

/**
 *  使用DNS解析后的IP地址发起请求
 *
 *  @param method     HTTP方法
 *  @param URLString  URL字符串
 *  @param parameters 请求参数
 *  @param success    成功回调
 *  @param failure    失败回调
 *
 *  @return NSURLSessionDataTask实例
 */
- (NSURLSessionDataTask *)af_dataTaskWithHTTPMethod:(NSString *)method
                                          URLString:(NSString *)URLString
                                         parameters:(nullable id)parameters
                                            success:(nullable void (^)(NSURLSessionDataTask *task, id _Nullable responseObject))success
                                            failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError *error))failure;

@end

NS_ASSUME_NONNULL_END
