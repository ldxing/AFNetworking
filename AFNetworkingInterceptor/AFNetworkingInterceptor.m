// AFNetworkingInterceptor.m
// Created by Your Name on 2023/10/10.
//

#import "AFNetworkingInterceptor.h"

@interface AFNetworkingInterceptor () {
    NSMutableArray<id<AFRequestInterceptor>> *_requestInterceptors;
    NSMutableArray<id<AFResponseInterceptor>> *_responseInterceptors;
}
@end

@implementation AFNetworkingInterceptor

+ (instancetype)sharedInstance {
    static AFNetworkingInterceptor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ 
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _requestInterceptors = [NSMutableArray array];
        _responseInterceptors = [NSMutableArray array];
    }
    return self;
}

- (NSArray<id<AFRequestInterceptor>> *)requestInterceptors {
    return [_requestInterceptors copy];
}

- (NSArray<id<AFResponseInterceptor>> *)responseInterceptors {
    return [_responseInterceptors copy];
}

- (void)addRequestInterceptor:(id<AFRequestInterceptor>)interceptor {
    if (interceptor && ![_requestInterceptors containsObject:interceptor]) {
        [_requestInterceptors addObject:interceptor];
    }
}

- (void)removeRequestInterceptor:(id<AFRequestInterceptor>)interceptor {
    if (interceptor && [_requestInterceptors containsObject:interceptor]) {
        [_requestInterceptors removeObject:interceptor];
    }
}

- (void)addResponseInterceptor:(id<AFResponseInterceptor>)interceptor {
    if (interceptor && ![_responseInterceptors containsObject:interceptor]) {
        [_responseInterceptors addObject:interceptor];
    }
}

- (void)removeResponseInterceptor:(id<AFResponseInterceptor>)interceptor {
    if (interceptor && [_responseInterceptors containsObject:interceptor]) {
        [_responseInterceptors removeObject:interceptor];
    }
}

@end