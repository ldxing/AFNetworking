// AFURLSessionManager+Interceptor.h
// Created by Your Name on 2023/10/10.
//

#import <AFNetworking/AFNetworking.h>
#import "AFNetworkingInterceptor.h"

NS_ASSUME_NONNULL_BEGIN

@interface AFURLSessionManager (Interceptor)

/**
 * 泛型方法，用于将JSON响应转换为指定类型的模型对象
 * @param responseObject JSON响应数据
 * @param modelClass 模型类
 * @return 转换后的模型对象
 */
- (nullable id)convertResponseObject:(id)responseObject toModelClass:(Class)modelClass;

@end

NS_ASSUME_NONNULL_END