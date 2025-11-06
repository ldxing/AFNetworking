// AFURLSessionManager+Interceptor.m
// Created by Your Name on 2023/10/10.
//

#import "AFURLSessionManager+Interceptor.h"
#import <objc/runtime.h>

@implementation AFURLSessionManager (Interceptor)

// 保存原始方法的IMP
static IMP originalDataTaskWithRequestIMP = nil;

+ (void)load {
    // 交换dataTaskWithRequest:uploadProgress:downloadProgress:completionHandler:方法
    Method originalMethod = class_getInstanceMethod([self class], @selector(dataTaskWithRequest:uploadProgress:downloadProgress:completionHandler:));
    Method swizzledMethod = class_getInstanceMethod([self class], @selector(swizzled_dataTaskWithRequest:uploadProgress:downloadProgress:completionHandler:));
    
    // 保存原始方法的IMP
    originalDataTaskWithRequestIMP = method_getImplementation(originalMethod);
    
    // 交换方法实现
    method_exchangeImplementations(originalMethod, swizzledMethod);
}

- (NSURLSessionDataTask *)swizzled_dataTaskWithRequest:(NSURLRequest *)request
                                         uploadProgress:(nullable void (^)(NSProgress *uploadProgress))uploadProgressBlock
                                       downloadProgress:(nullable void (^)(NSProgress *downloadProgress))downloadProgressBlock
                                      completionHandler:(nullable void (^)(NSURLResponse *response, id _Nullable responseObject, NSError * _Nullable error))completionHandler {
    
    // 请求前拦截
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    
    // 1. 检查是否应该发送请求
    AFNetworkingInterceptor *interceptorManager = [AFNetworkingInterceptor sharedInstance];
    BOOL shouldSend = YES;
    for (id<AFRequestInterceptor> interceptor in interceptorManager.requestInterceptors) {
        if ([interceptor respondsToSelector:@selector(shouldSendRequest:)]) {
            shouldSend = [interceptor shouldSendRequest:request];
            if (!shouldSend) {
                break;
            }
        }
    }
    
    if (!shouldSend) {
        // 如果不应该发送请求，直接调用completionHandler并返回nil
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:@"AFNetworkingInterceptor" code:-1000 userInfo:@{NSLocalizedDescriptionKey: @"Request was cancelled by interceptor"}];
            completionHandler(nil, nil, error);
        }
        return nil;
    }
    
    // 2. 拦截并修改请求头
    NSMutableDictionary<NSString *, NSString *> *mutableHeaders = [mutableRequest.allHTTPHeaderFields mutableCopy];
    if (!mutableHeaders) {
        mutableHeaders = [NSMutableDictionary dictionary];
    }
    
    for (id<AFRequestInterceptor> interceptor in interceptorManager.requestInterceptors) {
        if ([interceptor respondsToSelector:@selector(interceptRequestHeaders:)]) {
            NSDictionary<NSString *, NSString *> *modifiedHeaders = [interceptor interceptRequestHeaders:mutableHeaders];
            if (modifiedHeaders) {
                mutableHeaders = [modifiedHeaders mutableCopy];
            }
        }
    }
    
    mutableRequest.allHTTPHeaderFields = mutableHeaders;
    
    // 3. 拦截并修改请求
    NSURLRequest *finalRequest = mutableRequest;
    for (id<AFRequestInterceptor> interceptor in interceptorManager.requestInterceptors) {
        if ([interceptor respondsToSelector:@selector(interceptRequest:)]) {
            NSURLRequest *modifiedRequest = [interceptor interceptRequest:finalRequest];
            if (modifiedRequest) {
                finalRequest = modifiedRequest;
            }
        }
    }
    
    // 4. 创建修改后的completionHandler，添加响应后拦截
    void (^modifiedCompletionHandler)(NSURLResponse *response, id _Nullable responseObject, NSError * _Nullable error) = ^(NSURLResponse *response, id _Nullable responseObject, NSError * _Nullable error) {
        
        NSError *modifiedError = error;
        id modifiedResponseObject = responseObject;
        
        // 响应后拦截
        for (id<AFResponseInterceptor> interceptor in interceptorManager.responseInterceptors) {
            if ([interceptor respondsToSelector:@selector(interceptResponse:responseObject:error:)]) {
                modifiedResponseObject = [interceptor interceptResponse:response responseObject:modifiedResponseObject error:&modifiedError];
            }
        }
        
        // 调用原始的completionHandler
        if (completionHandler) {
            completionHandler(response, modifiedResponseObject, modifiedError);
        }
    };
    
    // 调用原始方法
    return ((NSURLSessionDataTask *(*)(id, SEL, NSURLRequest *, void (^)(NSProgress *), void (^)(NSProgress *), void (^)(NSURLResponse *, id, NSError *)))originalDataTaskWithRequestIMP)(self, _cmd, finalRequest, uploadProgressBlock, downloadProgressBlock, modifiedCompletionHandler);
}

- (nullable id)convertResponseObject:(id)responseObject toModelClass:(Class)modelClass {
    // 统一的JSON数据转模型处理
    AFNetworkingInterceptor *interceptorManager = [AFNetworkingInterceptor sharedInstance];
    id modelObject = nil;
    
    for (id<AFResponseInterceptor> interceptor in interceptorManager.responseInterceptors) {
        if ([interceptor respondsToSelector:@selector(convertResponseObject:toModelClass:)]) {
            modelObject = [interceptor convertResponseObject:responseObject toModelClass:modelClass];
            if (modelObject) {
                break;
            }
        }
    }
    
    return modelObject;
}

@end