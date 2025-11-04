// AFHTTPSSEManager.h
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

#import "AFHTTPSessionManager.h"

NS_ASSUME_NONNULL_BEGIN

/**
 `AFHTTPSSEManager` is a subclass of `AFHTTPSessionManager` with convenience methods for making SSE (Server-Sent Events) requests.
 */
@interface AFHTTPSSEManager : AFHTTPSessionManager

/**
 The name of the event to listen for. If nil, all events will be received.
 */
@property (nonatomic, strong, nullable) NSString *eventName;

/**
 The string that marks the beginning of a data field. Default is "data:".
 */
@property (nonatomic, strong) NSString *dataStartMarker;

/**
 The string that marks the end of a data field. Default is "\n\n".
 */
@property (nonatomic, strong) NSString *dataEndMarker;

/**
 The time interval in seconds to wait before attempting to reconnect after a disconnection. Default is 5.0.
 */
@property (nonatomic, assign) NSTimeInterval reconnectInterval;



///---------------------/// @name Initialization///---------------------/**
 Creates and returns an `AFHTTPSSEManager` object.
 */
+ (instancetype)manager;

/**
 Initializes an `AFHTTPSSEManager` object with the specified base URL.

 @param url The base URL for the HTTP client.

 @return The newly-initialized HTTP client
 */
- (instancetype)initWithBaseURL:(nullable NSURL *)url;

/**
 Initializes an `AFHTTPSSEManager` object with the specified base URL.

 This is the designated initializer.

 @param url The base URL for the HTTP client.
 @param configuration The configuration used to create the managed session.

 @return The newly-initialized HTTP client
 */
- (instancetype)initWithBaseURL:(nullable NSURL *)url
           sessionConfiguration:(nullable NSURLSessionConfiguration *)configuration NS_DESIGNATED_INITIALIZER;

///---------------------------/// @name Making SSE Requests///---------------------------/**
 Creates and runs an `NSURLSessionDataTask` with a `GET` request for SSE.

 @param URLString The URL string used to create the request URL.
 @param parameters The parameters to be encoded according to the client request serializer.
 @param headers The headers appended to the default headers for this request.
 @param progress A block object to be executed when the download progress is updated. Note this block is called on the session queue, not the main queue.
 @param eventReceived A block object to be executed when a new SSE event is received.
 @param connectionEstablished A block object to be executed when the SSE connection is established.
 @param connectionClosed A block object to be executed when the SSE connection is closed.
 @param reconnectAttempt A block object to be executed when an attempt to reconnect to the SSE server is made.
 @param reconnectSuccess A block object to be executed when the SSE connection is successfully reconnected.
 @param reconnectFailure A block object to be executed when the SSE connection fails to reconnect after multiple attempts.

 @return The newly-created NSURLSessionDataTask
 */
- (nullable NSURLSessionDataTask *)GETSSE:(NSString *)URLString
                               parameters:(nullable id)parameters
                                  headers:(nullable NSDictionary <NSString *, NSString *> *)headers
                                 progress:(nullable void (^)(NSProgress *downloadProgress))progress
                            eventReceived:(nullable void (^)(NSURLSessionDataTask *task, NSString *eventName, NSString *data))eventReceived
                     connectionEstablished:(nullable void (^)(NSURLSessionDataTask *task))connectionEstablished
                        connectionClosed:(nullable void (^)(NSURLSessionDataTask *task, NSError * _Nullable error))connectionClosed
                          reconnectAttempt:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSUInteger retryCount))reconnectAttempt
                           reconnectSuccess:(nullable void (^)(NSURLSessionDataTask *task, NSUInteger retryCount))reconnectSuccess
                           reconnectFailure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError *error, NSUInteger retryCount))reconnectFailure;

/**
 Stops the SSE connection and cancels the task.

 @param task The SSE task to stop.
 */
- (void)stopSSETask:(NSURLSessionDataTask *)task;

/**
 Abstract method to determine if a reconnect should be attempted after a disconnection.

 @param task The task that was disconnected.
 @param error The error that caused the disconnection.
 @param retryCount The number of times reconnect has been attempted.

 @return YES if a reconnect should be attempted, NO otherwise.
 */
- (BOOL)shouldReconnectForTask:(NSURLSessionDataTask * _Nullable)task error:(NSError * _Nullable)error retryCount:(NSUInteger)retryCount;

@end

NS_ASSUME_NONNULL_END