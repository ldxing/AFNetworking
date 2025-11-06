// AFHTTPSessionManager+Interceptor.h
// Created by Your Name on 2023/10/10.
//

#import <AFNetworking/AFNetworking.h>

NS_ASSUME_NONNULL_BEGIN

@interface AFHTTPSessionManager (Interceptor)

/**
 * 泛型GET请求方法
 * @param URLString URL字符串
 * @param parameters 请求参数
 * @param headers 请求头
 * @param modelClass 模型类
 * @param downloadProgress 下载进度回调
 * @param success 成功回调，返回模型对象
 * @param failure 失败回调
 * @return NSURLSessionDataTask
 */
- (nullable NSURLSessionDataTask *)GET:(NSString *)URLString
                            parameters:(nullable id)parameters
                               headers:(nullable NSDictionary <NSString *, NSString *> *)headers
                             modelClass:(nullable Class)modelClass
                              progress:(nullable void (^)(NSProgress *downloadProgress))downloadProgress
                               success:(nullable void (^)(NSURLSessionDataTask *task, id _Nullable responseObject))success
                               failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError *error))failure;

/**
 * 泛型POST请求方法
 * @param URLString URL字符串
 * @param parameters 请求参数
 * @param headers 请求头
 * @param modelClass 模型类
 * @param uploadProgress 上传进度回调
 * @param success 成功回调，返回模型对象
 * @param failure 失败回调
 * @return NSURLSessionDataTask
 */
- (nullable NSURLSessionDataTask *)POST:(NSString *)URLString
                             parameters:(nullable id)parameters
                                headers:(nullable NSDictionary <NSString *, NSString *> *)headers
                              modelClass:(nullable Class)modelClass
                               progress:(nullable void (^)(NSProgress *uploadProgress))uploadProgress
                                success:(nullable void (^)(NSURLSessionDataTask *task, id _Nullable responseObject))success
                                failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError *error))failure;

@end

NS_ASSUME_NONNULL_END