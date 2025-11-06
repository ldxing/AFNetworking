# AFNetworking Interceptor System

一个功能完整的AFNetworking拦截器系统，支持请求前拦截和响应后拦截，采用分类(Category)和装饰器(Decorator)模式实现，不修改AFNetworking源代码，确保框架的可维护性和升级兼容性。

## 功能特性

### 请求前拦截
- 支持在请求发送前对请求参数进行修改或添加操作
- 能够统一为所有请求添加指定的HTTP Header信息
- 提供在封装的请求方法中执行前置检查的机制，支持基于检查结果决定是否继续发送请求

### 响应后拦截
- 实现统一的JSON数据转模型对象的处理流程
- 支持泛型机制以适配不同类型的模型对象转换
- 允许自定义responseSerializer用于数据解析或错误处理
- 在completionHandler执行前提供统一的响应结果处理入口

## 安装与集成

### 手动集成

1. 将`AFNetworkingInterceptor`目录添加到您的项目中
2. 在需要使用拦截器的文件中导入头文件：

```objc
#import "AFNetworkingInterceptor.h"
#import "AFHTTPSessionManager+Interceptor.h"
```

## 使用方法

### 1. 创建拦截器

#### 请求拦截器

```objc
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
```

#### 响应拦截器

```objc
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
```

### 2. 注册拦截器

```objc
// 获取拦截器管理器
AFNetworkingInterceptor *interceptorManager = [AFNetworkingInterceptor sharedInstance];

// 添加请求拦截器
ExampleRequestInterceptor *requestInterceptor = [[ExampleRequestInterceptor alloc] init];
[interceptorManager addRequestInterceptor:requestInterceptor];

// 添加响应拦截器
ExampleResponseInterceptor *responseInterceptor = [[ExampleResponseInterceptor alloc] init];
[interceptorManager addResponseInterceptor:responseInterceptor];
```

### 3. 发送请求

#### 泛型请求（自动转模型）

```objc
AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
manager.responseSerializer = [AFJSONResponseSerializer serializer];

[manager GET:@"https://jsonplaceholder.typicode.com/users/1" 
   parameters:nil 
      headers:nil 
    modelClass:[UserModel class] 
     progress:nil 
      success:^(NSURLSessionDataTask *task, id _Nullable responseObject) {
          if ([responseObject isKindOfClass:[UserModel class]]) {
              UserModel *user = (UserModel *)responseObject;
              NSLog(@"User: name=%@, email=%@", user.name, user.email);
          }
      } 
      failure:^(NSURLSessionDataTask * _Nullable task, NSError *error) {
          NSLog(@"Error: %@", error);
      }];
```

#### 普通请求

```objc
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
```

## 核心类与协议

### AFNetworkingInterceptor
- 单例类，用于管理所有拦截器
- 提供添加/移除请求拦截器和响应拦截器的方法

### AFRequestInterceptor协议
- `interceptRequest:`: 拦截并修改请求
- `interceptRequestHeaders:`: 拦截并修改请求头
- `shouldSendRequest:`: 请求前检查

### AFResponseInterceptor协议
- `interceptResponse:responseObject:error:`: 拦截并修改响应
- `convertResponseObject:toModelClass:`: JSON转模型

### AFURLSessionManager+Interceptor分类
- 重写了`dataTaskWithRequest:uploadProgress:downloadProgress:completionHandler:`方法，添加了拦截逻辑
- 提供了`convertResponseObject:toModelClass:`方法，用于JSON转模型

### AFHTTPSessionManager+Interceptor分类
- 提供了泛型GET和POST方法，支持自动转模型

## 注意事项

1. 拦截器系统使用方法交换(Method Swizzling)技术，确保在`+load`方法中执行
2. 拦截器的执行顺序与添加顺序一致
3. 如果多个拦截器修改同一个请求或响应，后添加的拦截器会覆盖先添加的拦截器的修改
4. 泛型方法仅在AFHTTPSessionManager中可用，AFURLSessionManager需要手动调用`convertResponseObject:toModelClass:`方法
5. 确保在使用前导入所有必要的头文件

## 兼容性

- 支持AFNetworking 3.x和4.x版本
- 支持iOS 8.0+和macOS 10.10+
- 支持ARC环境

## License

MIT License
