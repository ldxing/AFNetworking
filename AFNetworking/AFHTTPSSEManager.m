// AFHTTPSSEManager.m
// Copyright (c) 2011–2016 Alamofire Software Foundation ( http://alamofire.org/ )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "AFHTTPSSEManager.h"

@interface AFHTTPSSEManager ()
@property (nonatomic, strong) NSMutableDictionary <NSNumber *, NSMutableData *> *taskDataBuffers;
@property (nonatomic, strong) NSMutableDictionary <NSNumber *, NSUInteger> *taskRetryCounts;
@property (nonatomic, strong) NSMutableDictionary <NSNumber *, NSURLSessionDataTask *> *pendingReconnectTasks;
@property (nonatomic, strong) NSMutableDictionary <NSNumber *, NSDictionary *> *taskCallbacks;
@property (nonatomic, strong) dispatch_queue_t sseQueue;
@end

@implementation AFHTTPSSEManager

+ (instancetype)manager {
    return [[[self class] alloc] initWithBaseURL:nil];
}

- (instancetype)init {
    return [self initWithBaseURL:nil];
}

- (instancetype)initWithBaseURL:(NSURL *)url {
    return [self initWithBaseURL:url sessionConfiguration:nil];
}

- (instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration *)configuration {
    return [self initWithBaseURL:nil sessionConfiguration:configuration];
}

- (instancetype)initWithBaseURL:(NSURL *)url
           sessionConfiguration:(NSURLSessionConfiguration *)configuration {
    self = [super initWithBaseURL:url sessionConfiguration:configuration];
    if (!self) {
        return nil;
    }

    // 初始化默认值
    self.dataStartMarker = @"data:";
    self.dataEndMarker = @"\n\n";
    self.reconnectInterval = 5.0;
    
    // 初始化任务数据缓冲区
    self.taskDataBuffers = [NSMutableDictionary dictionary];
    self.taskRetryCounts = [NSMutableDictionary dictionary];
    self.pendingReconnectTasks = [NSMutableDictionary dictionary];
    self.taskCallbacks = [NSMutableDictionary dictionary];
    
    // 创建串行队列，用于保护任务数据缓冲区的线程安全
    self.sseQueue = dispatch_queue_create("com.alamofire.afnetworking.sse", DISPATCH_QUEUE_SERIAL);
    
    // 设置默认的响应序列化器为字符串序列化器，因为SSE返回的是文本数据
    self.responseSerializer = [AFHTTPResponseSerializer serializer];
    
    // 禁用请求缓存
    self.requestSerializer.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    
    return self;
}

- (NSURLSessionDataTask *)GETSSE:(NSString *)URLString
                       parameters:(nullable id)parameters
                          headers:(nullable NSDictionary <NSString *, NSString *> *)headers
                         progress:(nullable void (^)(NSProgress *downloadProgress))progress
                    eventReceived:(nullable void (^)(NSURLSessionDataTask *task, NSString *eventName, NSString *data))eventReceived
             connectionEstablished:(nullable void (^)(NSURLSessionDataTask *task))connectionEstablished
                connectionClosed:(nullable void (^)(NSURLSessionDataTask *task, NSError * _Nullable error))connectionClosed
                  reconnectAttempt:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSUInteger retryCount))reconnectAttempt
                   reconnectSuccess:(nullable void (^)(NSURLSessionDataTask *task, NSUInteger retryCount))reconnectSuccess
                   reconnectFailure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError *error, NSUInteger retryCount))reconnectFailure {
    
    // 创建SSE请求
    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:@"GET" URLString:[[NSURL URLWithString:URLString relativeToURL:self.baseURL] absoluteString] parameters:parameters error:nil];
    
    // 设置SSE相关的HTTP头
    [request setValue:@"text/event-stream" forHTTPHeaderField:@"Accept"];
    [request setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];
    
    // 添加自定义头
    for (NSString *headerField in headers.keyEnumerator) {
        [request setValue:headers[headerField] forHTTPHeaderField:headerField];
    }
    
    // 创建数据任务
    __block NSURLSessionDataTask *task = nil;
    __weak __typeof(self) weakSelf = self;
    task = [self dataTaskWithRequest:request
                      uploadProgress:nil
                    downloadProgress:progress
                   completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            // 连接关闭时的处理
            [strongSelf handleConnectionClosedForTask:task error:error];
        }
    }];
    
    // 保存任务相关的回调
    __strong __typeof(weakSelf) strongSelf = weakSelf;
    if (strongSelf) {
        dispatch_async(strongSelf.sseQueue, ^{
            NSNumber *taskIdentifier = @(task.taskIdentifier);
            
            // 初始化任务数据
            strongSelf.taskDataBuffers[taskIdentifier] = [NSMutableData data];
            strongSelf.taskRetryCounts[taskIdentifier] = @0;
            strongSelf.pendingReconnectTasks[taskIdentifier] = task;
            
            // 保存回调
            NSDictionary *callbacks = @{
                @"eventReceived": eventReceived ? [eventReceived copy] : nil,
                @"connectionEstablished": connectionEstablished ? [connectionEstablished copy] : nil,
                @"connectionClosed": connectionClosed ? [connectionClosed copy] : nil,
                @"reconnectAttempt": reconnectAttempt ? [reconnectAttempt copy] : nil,
                @"reconnectSuccess": reconnectSuccess ? [reconnectSuccess copy] : nil,
                @"reconnectFailure": reconnectFailure ? [reconnectFailure copy] : nil
            };
            strongSelf.taskCallbacks[taskIdentifier] = callbacks;
        });
    }
    
    // 启动任务
    [task resume];
    
    return task;
}

- (void)stopSSETask:(NSURLSessionDataTask *)task {
    NSNumber *taskIdentifier = @(task.taskIdentifier);
    
    // 取消任务
    [task cancel];
    
    // 移除任务相关的数据
    __weak __typeof(self) weakSelf = self;
    dispatch_async(self.sseQueue, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf.taskDataBuffers removeObjectForKey:taskIdentifier];
            [strongSelf.taskRetryCounts removeObjectForKey:taskIdentifier];
            [strongSelf.pendingReconnectTasks removeObjectForKey:taskIdentifier];
            [strongSelf.taskCallbacks removeObjectForKey:taskIdentifier];
        }
    });
}

- (BOOL)shouldReconnectForTask:(NSURLSessionDataTask * _Nullable)task error:(NSError * _Nullable)error retryCount:(NSUInteger)retryCount {
    __weak __typeof(self) weakSelf = self;
    __strong __typeof(weakSelf) strongSelf = weakSelf;
    if (!strongSelf) {
        return NO;
    }
    
    // 默认实现：如果没有错误或者错误是网络错误，并且重试次数小于10次，则尝试重连
    if ((error == nil || [error.domain isEqualToString:NSURLErrorDomain]) && retryCount < 10) {
        return YES;
    }
    return NO;
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    NSNumber *taskIdentifier = @(dataTask.taskIdentifier);
    __weak __typeof(self) weakSelf = self;
    __strong __typeof(weakSelf) strongSelf = weakSelf;
    if (!strongSelf) {
        completionHandler(NSURLSessionResponseCancel);
        return;
    }
    
    // 重置任务的数据缓冲区和重试计数
    dispatch_async(strongSelf.sseQueue, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            strongSelf.taskDataBuffers[taskIdentifier] = [NSMutableData data];
            strongSelf.taskRetryCounts[taskIdentifier] = @0;
        }
    });
    
    // 调用连接建立的回调
    dispatch_async(strongSelf.sseQueue, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            NSDictionary *callbacks = strongSelf.taskCallbacks[taskIdentifier];
            void (^connectionEstablishedBlock)(NSURLSessionDataTask *) = callbacks[@"connectionEstablished"];
            if (connectionEstablishedBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    connectionEstablishedBlock(dataTask);
                });
            }
        }
    });

    // 允许响应
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    NSNumber *taskIdentifier = @(dataTask.taskIdentifier);
    __weak __typeof(self) weakSelf = self;
    
    dispatch_async(self.sseQueue, ^{ 
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        NSMutableData *dataBuffer = strongSelf.taskDataBuffers[taskIdentifier];
        
        if (dataBuffer) {
            // 将新接收的数据添加到缓冲区
            [dataBuffer appendData:data];
            
            // 解析SSE事件
            [strongSelf parseSSEEventsForTask:dataTask dataBuffer:dataBuffer];
        }
    });
}

#pragma mark - SSE Parsing

- (void)parseSSEEventsForTask:(NSURLSessionDataTask *)dataTask dataBuffer:(NSMutableData *)dataBuffer {
    __weak __typeof(self) weakSelf = self;
    
    // 检查响应的Content-Type头，获取正确的编码
    NSString *encodingName = @"UTF-8";
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)dataTask.response;
    if (httpResponse) {
        NSString *contentType = httpResponse.allHeaderFields[@"Content-Type"];
        if (contentType) {
            NSArray *components = [contentType componentsSeparatedByString:@";"].firstObject;
            for (__strong NSString *component in [components componentsSeparatedByString:@","]) {
                component = [component stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if ([component hasPrefix:@"charset="]) {
                    encodingName = [component substringFromIndex:8];
                    break;
                }
            }
        }
    }
    
    // 使用正确的编码解析数据
    NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding((CFStringRef)encodingName));
    NSString *dataString = [[NSString alloc] initWithData:dataBuffer encoding:encoding];
    if (!dataString) {
        return;
    }
    
    // 查找数据结束标记
    __strong __typeof(weakSelf) strongSelf = weakSelf;
    if (!strongSelf) {
        return;
    }
    
    NSRange endMarkerRange = [dataString rangeOfString:strongSelf.dataEndMarker];
    
    while (endMarkerRange.location != NSNotFound) {
        // 提取完整的事件数据
        NSString *eventData = [dataString substringToIndex:endMarkerRange.location];
        
        // 从缓冲区中移除已处理的数据
        NSData *processedData = [[dataString substringToIndex:endMarkerRange.location + endMarkerRange.length] dataUsingEncoding:encoding];
        [dataBuffer replaceBytesInRange:NSMakeRange(0, processedData.length) withBytes:NULL length:0];
        
        // 解析事件
        [strongSelf parseSSEEventForTask:dataTask eventData:eventData];
        
        // 更新数据字符串
        dataString = [[NSString alloc] initWithData:dataBuffer encoding:encoding];
        if (!dataString) {
            break;
        }
        
        // 查找下一个数据结束标记
        endMarkerRange = [dataString rangeOfString:strongSelf.dataEndMarker];
    }
}

- (void)parseSSEEventForTask:(NSURLSessionDataTask *)dataTask eventData:(NSString *)eventData {
    NSNumber *taskIdentifier = @(dataTask.taskIdentifier);
    __weak __typeof(self) weakSelf = self;
    __strong __typeof(weakSelf) strongSelf = weakSelf;
    if (!strongSelf) {
        return;
    }
    
    // 分割事件数据为行
    NSArray *lines = [eventData componentsSeparatedByString:@"\n"];
    
    NSString *currentEventName = strongSelf.eventName ?: @"message"; // 默认事件名为"message"
    NSMutableString *currentData = [NSMutableString string];
    NSString *currentId = nil;
    
    for (NSString *line in lines) {
        if ([line hasPrefix:@"event:"]) {
            // 解析事件名
            NSString *eventName = [[line substringFromIndex:6] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (eventName.length > 0) {
                currentEventName = eventName;
            }
        } else if ([line hasPrefix:strongSelf.dataStartMarker]) {
            // 解析数据
            NSString *data = [[line substringFromIndex:strongSelf.dataStartMarker.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (data.length > 0) {
                [currentData appendString:data];
            }
        } else if ([line hasPrefix:@"id:"]) {
            // 解析id
            currentId = [[line substringFromIndex:3] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (currentId.length == 0) {
                currentId = nil;
            }
        } else if ([line hasPrefix:@"retry:"]) {
            // 解析retry
            NSString *retryString = [[line substringFromIndex:6] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSTimeInterval retryInterval = [retryString doubleValue];
            if (retryInterval > 0) {
                strongSelf.reconnectInterval = retryInterval;
            }
        }
        // 忽略空行和其他类型的行
    }
    
    // 如果设置了特定的事件名，只处理匹配的事件
    if (strongSelf.eventName && ![currentEventName isEqualToString:strongSelf.eventName]) {
        return;
    }
    
    // 调用事件接收的回调
    if (currentData.length > 0) {
        dispatch_async(strongSelf.sseQueue, ^{
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) {
                NSDictionary *callbacks = strongSelf.taskCallbacks[taskIdentifier];
                void (^eventReceivedBlock)(NSURLSessionDataTask *, NSString *, NSString *) = callbacks[@"eventReceived"];
                if (eventReceivedBlock) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        eventReceivedBlock(dataTask, currentEventName, currentData);
                    });
                }
            }
        });
    }
}

#pragma mark - Connection Management

- (void)handleConnectionClosedForTask:(NSURLSessionDataTask *)task error:(NSError * _Nullable)error {
    NSNumber *taskIdentifier = @(task.taskIdentifier);
    __weak __typeof(self) weakSelf = self;
    
    // 调用连接关闭的回调
    __strong __typeof(weakSelf) strongSelf = weakSelf;
    if (strongSelf) {
        dispatch_async(strongSelf.sseQueue, ^{
            NSDictionary *callbacks = strongSelf.taskCallbacks[taskIdentifier];
            void (^connectionClosedBlock)(NSURLSessionDataTask *, NSError *) = callbacks[@"connectionClosed"];
            if (connectionClosedBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    connectionClosedBlock(task, error);
                });
            }
        });
        
        // 移除任务的数据缓冲区
        dispatch_async(strongSelf.sseQueue, ^{
            [strongSelf.taskDataBuffers removeObjectForKey:taskIdentifier];
        });
        
        // 检查是否需要重连
        NSUInteger retryCount = 0;
        NSNumber *retryCountNumber = strongSelf.taskRetryCounts[taskIdentifier];
        if (retryCountNumber) {
            retryCount = [retryCountNumber unsignedIntegerValue];
        }
        
        if ([strongSelf shouldReconnectForTask:task error:error retryCount:retryCount]) {
            // 增加重试计数
            retryCount++;
            strongSelf.taskRetryCounts[taskIdentifier] = @(retryCount);
            
            // 调用重连尝试的回调
            NSDictionary *callbacks = strongSelf.taskCallbacks[taskIdentifier];
            void (^reconnectAttemptBlock)(NSURLSessionDataTask *, NSUInteger) = callbacks[@"reconnectAttempt"];
            if (reconnectAttemptBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    reconnectAttemptBlock(task, retryCount);
                });
            }
            
            // 延迟重连
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(strongSelf.reconnectInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [strongSelf handleReconnectForTask:task taskIdentifier:taskIdentifier retryCount:retryCount];
            });
        } else {
            // 不需要重连或重连失败
            NSDictionary *callbacks = strongSelf.taskCallbacks[taskIdentifier];
            void (^reconnectFailureBlock)(NSURLSessionDataTask *, NSError *, NSUInteger) = callbacks[@"reconnectFailure"];
            if (reconnectFailureBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    reconnectFailureBlock(task, error, retryCount);
                });
            }
            
            // 移除任务相关的数据
            [strongSelf.taskRetryCounts removeObjectForKey:taskIdentifier];
            [strongSelf.pendingReconnectTasks removeObjectForKey:taskIdentifier];
            [strongSelf.taskCallbacks removeObjectForKey:taskIdentifier];
        }
    }
}

- (void)handleReconnectForTask:(NSURLSessionDataTask *)task taskIdentifier:(NSNumber *)taskIdentifier retryCount:(NSUInteger)retryCount {
    __weak __typeof(self) weakSelf = self;
    __strong __typeof(weakSelf) strongSelf = weakSelf;
    if (!strongSelf) {
        return;
    }
    
    // 检查任务是否已经被手动停止
    __block BOOL isTaskPending = NO;
    dispatch_sync(strongSelf.sseQueue, ^{ 
        if (strongSelf) {
            isTaskPending = [strongSelf.pendingReconnectTasks objectForKey:taskIdentifier] != nil;
        }
    });
    
    if (!isTaskPending) {
        return;
    }
    
    // 重新创建任务
    NSURLSessionDataTask *newTask = [strongSelf recreateSSETaskForTask:task];
    if (newTask) {
        // 保存新任务
        dispatch_async(strongSelf.sseQueue, ^{
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) {
                strongSelf.pendingReconnectTasks[taskIdentifier] = newTask;
            }
        });

        // 启动新任务
        [newTask resume];

        // 调用重连成功的回调
        dispatch_async(strongSelf.sseQueue, ^{
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) {
                NSDictionary *callbacks = strongSelf.taskCallbacks[taskIdentifier];
                void (^reconnectSuccessBlock)(NSURLSessionDataTask *, NSUInteger) = callbacks[@"reconnectSuccess"];
                if (reconnectSuccessBlock) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        reconnectSuccessBlock(newTask, retryCount);
                    });
                }
            }
        });
    } else {
        // 重连失败
        dispatch_async(strongSelf.sseQueue, ^{
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) {
                NSDictionary *callbacks = strongSelf.taskCallbacks[taskIdentifier];
                void (^reconnectFailureBlock)(NSURLSessionDataTask *, NSError *, NSUInteger) = callbacks[@"reconnectFailure"];
                if (reconnectFailureBlock) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        reconnectFailureBlock(task, nil, retryCount);
                    });
                }
                
                // 移除任务相关的数据
                [strongSelf.taskRetryCounts removeObjectForKey:taskIdentifier];
                [strongSelf.pendingReconnectTasks removeObjectForKey:taskIdentifier];
                [strongSelf.taskCallbacks removeObjectForKey:taskIdentifier];
            }
        });
    }
}

- (NSURLSessionDataTask *)recreateSSETaskForTask:(NSURLSessionDataTask *)task {
    // 重新创建相同的请求
    NSURLRequest *originalRequest = task.originalRequest;
    if (!originalRequest) {
        return nil;
    }
    
    // 创建新的数据任务
    __block NSURLSessionDataTask *newTask = nil;
    __weak __typeof(self) weakSelf = self;
    __strong __typeof(weakSelf) strongSelf = weakSelf;
    if (!strongSelf) {
        return nil;
    }
    
    newTask = [strongSelf dataTaskWithRequest:originalRequest
                              uploadProgress:nil
                            downloadProgress:nil
                           completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            // 连接关闭时的处理
            __weak typeof(newTask) weakNewTask = newTask;
            [strongSelf handleConnectionClosedForTask:weakNewTask error:error];
        }
    }];
    
    return newTask;
}

- (void)dealloc {
    // 取消所有未完成的任务
    dispatch_async(self.sseQueue, ^{
        for (NSURLSessionDataTask *task in self.pendingReconnectTasks.allValues) {
            [task cancel];
        }
        
        // 清空所有任务数据
        [self.taskDataBuffers removeAllObjects];
        [self.taskRetryCounts removeAllObjects];
        [self.pendingReconnectTasks removeAllObjects];
        [self.taskCallbacks removeAllObjects];
    });
}

@end
