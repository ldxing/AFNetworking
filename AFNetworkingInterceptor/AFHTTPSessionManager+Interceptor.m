// AFHTTPSessionManager+Interceptor.m
// Created by Your Name on 2023/10/10.
//

#import "AFHTTPSessionManager+Interceptor.h"
#import "AFURLSessionManager+Interceptor.h"

@implementation AFHTTPSessionManager (Interceptor)

- (nullable NSURLSessionDataTask *)GET:(NSString *)URLString
                            parameters:(nullable id)parameters
                               headers:(nullable NSDictionary <NSString *, NSString *> *)headers
                             modelClass:(nullable Class)modelClass
                              progress:(nullable void (^)(NSProgress *downloadProgress))downloadProgress
                               success:(nullable void (^)(NSURLSessionDataTask *task, id _Nullable responseObject))success
                               failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError *error))failure {
    
    // 创建修改后的success回调，支持自动转模型
    void (^modifiedSuccess)(NSURLSessionDataTask *task, id _Nullable responseObject) = ^(NSURLSessionDataTask *task, id _Nullable responseObject) {
        id modelObject = responseObject;
        
        // 如果指定了模型类，则尝试转换
        if (modelClass && responseObject) {
            modelObject = [self convertResponseObject:responseObject toModelClass:modelClass];
        }
        
        // 调用原始的success回调
        if (success) {
            success(task, modelObject);
        }
    };
    
    // 调用原始的GET方法
    return [self GET:URLString parameters:parameters headers:headers progress:downloadProgress success:modifiedSuccess failure:failure];
}

- (nullable NSURLSessionDataTask *)POST:(NSString *)URLString
                             parameters:(nullable id)parameters
                                headers:(nullable NSDictionary <NSString *, NSString *> *)headers
                              modelClass:(nullable Class)modelClass
                               progress:(nullable void (^)(NSProgress *uploadProgress))uploadProgress
                                success:(nullable void (^)(NSURLSessionDataTask *task, id _Nullable responseObject))success
                                failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError *error))failure {
    
    // 创建修改后的success回调，支持自动转模型
    void (^modifiedSuccess)(NSURLSessionDataTask *task, id _Nullable responseObject) = ^(NSURLSessionDataTask *task, id _Nullable responseObject) {
        id modelObject = responseObject;
        
        // 如果指定了模型类，则尝试转换
        if (modelClass && responseObject) {
            modelObject = [self convertResponseObject:responseObject toModelClass:modelClass];
        }
        
        // 调用原始的success回调
        if (success) {
            success(task, modelObject);
        }
    };
    
    // 调用原始的POST方法
    return [self POST:URLString parameters:parameters headers:headers progress:uploadProgress success:modifiedSuccess failure:failure];
}

@end