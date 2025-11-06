// AFNetworkingInterceptorDemo.m
// Created by Your Name on 2023/10/10.
//

#import <Foundation/Foundation.h>
#import <AFNetworking/AFNetworking.h>
#import "../AFNetworkingInterceptor.h"
#import "../AFHTTPSessionManager+Interceptor.h"

// 示例模型类
@interface UserModel : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *email;
@property (nonatomic, assign) NSInteger age;
@end

@implementation UserModel

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        _name = dictionary[@"name"];
        _email = dictionary[@"email"];
        _age = [dictionary[@"age"] integerValue];
    }
    return self;
}

@end

// 示例请求拦截器
@interface ExampleRequestInterceptor : NSObject <AFRequestInterceptor>
@end

@implementation ExampleRequestInterceptor

- (NSURLRequest *)interceptRequest:(NSURLRequest *)request {
    // 在请求中添加自定义参数
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    // 这里可以修改请求URL、参数等
    return mutableRequest;
}

- (NSDictionary<NSString *, NSString *> *)interceptRequestHeaders:(NSDictionary<NSString *, NSString *> *)headers {
    // 统一添加Authorization头
    NSMutableDictionary<NSString *, NSString *> *mutableHeaders = [headers mutableCopy];
    mutableHeaders[@"Authorization"] = @"Bearer token123456";
    return mutableHeaders;
}

- (BOOL)shouldSendRequest:(NSURLRequest *)request {
    // 可以在这里添加请求前检查，例如网络状态检查
    NSLog(@"Should send request to %@", request.URL);
    return YES;
}

@end

// 示例响应拦截器
@interface ExampleResponseInterceptor : NSObject <AFResponseInterceptor>
@end

@implementation ExampleResponseInterceptor

- (id)interceptResponse:(NSURLResponse *)response responseObject:(nullable id)responseObject error:(NSError * _Nullable __autoreleasing *)error {
    // 统一处理响应结果
    NSLog(@"Response received: %@", responseObject);
    
    // 可以在这里添加统一的错误处理
    if (*error) {
        NSLog(@"Response error: %@", *error);
    }
    
    return responseObject;
}

- (id)convertResponseObject:(id)responseObject toModelClass:(Class)modelClass {
    // 实现JSON转模型的逻辑
    if ([responseObject isKindOfClass:[NSDictionary class]]) {
        if ([modelClass isSubclassOfClass:[UserModel class]]) {
            return [[UserModel alloc] initWithDictionary:responseObject];
        }
    }
    return responseObject;
}

@end

// Demo入口
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        // 初始化AFHTTPSessionManager
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        manager.responseSerializer = [AFJSONResponseSerializer serializer];
        
        // 获取拦截器管理器
        AFNetworkingInterceptor *interceptorManager = [AFNetworkingInterceptor sharedInstance];
        
        // 添加请求拦截器
        ExampleRequestInterceptor *requestInterceptor = [[ExampleRequestInterceptor alloc] init];
        [interceptorManager addRequestInterceptor:requestInterceptor];
        
        // 添加响应拦截器
        ExampleResponseInterceptor *responseInterceptor = [[ExampleResponseInterceptor alloc] init];
        [interceptorManager addResponseInterceptor:responseInterceptor];
        
        // 发送GET请求（泛型方法，自动转模型）
        [manager GET:@"https://jsonplaceholder.typicode.com/users/1" 
           parameters:nil 
              headers:nil 
            modelClass:[UserModel class] 
             progress:nil 
              success:^(NSURLSessionDataTask *task, id _Nullable responseObject) {
                  if ([responseObject isKindOfClass:[UserModel class]]) {
                      UserModel *user = (UserModel *)responseObject;
                      NSLog(@"User: name=%@, email=%@, age=%ld", user.name, user.email, (long)user.age);
                  } else {
                      NSLog(@"Response: %@", responseObject);
                  }
              } 
              failure:^(NSURLSessionDataTask * _Nullable task, NSError *error) {
                  NSLog(@"Error: %@", error);
              }];
        
        // 发送普通POST请求
        [manager POST:@"https://jsonplaceholder.typicode.com/posts" 
            parameters:@{@"title": @"foo", @"body": @"bar", @"userId": @1} 
               headers:nil 
             progress:nil 
              success:^(NSURLSessionDataTask *task, id _Nullable responseObject) {
                  NSLog(@"POST Response: %@", responseObject);
              } 
              failure:^(NSURLSessionDataTask * _Nullable task, NSError *error) {
                  NSLog(@"POST Error: %@", error);
              }];
        
        // 保持程序运行
        [[NSRunLoop currentRunLoop] run];
        
    }
    return 0;
}
