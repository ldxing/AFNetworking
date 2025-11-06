// AFNetworkingInterceptor.h
// Created by Your Name on 2023/10/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AFRequestInterceptor <NSObject>
@optional

/**
 * 在请求发送前调用，可以修改请求参数
 * @param request 原始请求
 * @return 修改后的请求，如果返回nil则取消请求
 */
- (nullable NSURLRequest *)interceptRequest:(NSURLRequest *)request;

/**
 * 在请求发送前调用，可以添加或修改HTTP头
 * @param headers 原始HTTP头
 * @return 修改后的HTTP头
 */
- (nullable NSDictionary<NSString *, NSString *> *)interceptRequestHeaders:(NSDictionary<NSString *, NSString *> *)headers;

/**
 * 在请求发送前进行前置检查
 * @param request 请求
 * @return 是否继续发送请求
 */
- (BOOL)shouldSendRequest:(NSURLRequest *)request;

@end

@protocol AFResponseInterceptor <NSObject>
@optional

/**
 * 在响应返回后，completionHandler执行前调用
 * @param response 响应
 * @param responseObject 响应数据
 * @param error 错误信息
 * @return 修改后的响应数据，如果返回nil则使用原始数据
 */
- (nullable id)interceptResponse:(NSURLResponse *)response responseObject:(nullable id)responseObject error:(NSError * _Nullable __autoreleasing *)error;

/**
 * 统一的JSON数据转模型处理
 * @param responseObject JSON数据
 * @param modelClass 模型类
 * @return 转换后的模型对象
 */
- (nullable id)convertResponseObject:(id)responseObject toModelClass:(Class)modelClass;

@end

@interface AFNetworkingInterceptor : NSObject

@property (class, nonatomic, strong, readonly) AFNetworkingInterceptor *sharedInstance;

/**
 * 请求拦截器数组
 */
@property (nonatomic, strong, readonly) NSArray<id<AFRequestInterceptor>> *requestInterceptors;

/**
 * 响应拦截器数组
 */
@property (nonatomic, strong, readonly) NSArray<id<AFResponseInterceptor>> *responseInterceptors;

/**
 * 添加请求拦截器
 * @param interceptor 请求拦截器
 */
- (void)addRequestInterceptor:(id<AFRequestInterceptor>)interceptor;

/**
 * 移除请求拦截器
 * @param interceptor 请求拦截器
 */
- (void)removeRequestInterceptor:(id<AFRequestInterceptor>)interceptor;

/**
 * 添加响应拦截器
 * @param interceptor 响应拦截器
 */
- (void)addResponseInterceptor:(id<AFResponseInterceptor>)interceptor;

/**
 * 移除响应拦截器
 * @param interceptor 响应拦截器
 */
- (void)removeResponseInterceptor:(id<AFResponseInterceptor>)interceptor;

@end

NS_ASSUME_NONNULL_END