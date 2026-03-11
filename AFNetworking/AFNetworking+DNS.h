// AFNetworking+DNS.h
// Copyright (c) 2025 AFNetworking Extension
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

/**
 AFNetworking DNS预解析扩展
 
 本扩展为AFNetworking框架提供DNS预解析功能，优化网络请求性能。
 
 主要功能：
 1. DNS预解析：在发起网络请求前，对目标域名进行DNS预解析，获取对应的IP地址列表
 2. DNS缓存：设计合理的缓存策略（包括缓存过期时间、更新机制），对解析结果进行本地存储
 3. 支持配置自定义DNS服务器地址
 
 使用方法：
 1. 导入本头文件
 2. 通过AFHTTPSessionManager的扩展方法使用DNS功能
 
 示例代码：
 ```objc
 AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
 
 // 预解析域名
 [manager preResolveDomain:@"api.example.com" completion:^(AFDNSRecord *record, NSError *error) {
     NSLog(@"IP Addresses: %@", record.ipAddresses);
 }];
 
 // 批量预解析
 [manager preResolveDomains:@[@"api1.example.com", @"api2.example.com"] completion:nil];
 
 // 预热缓存
 [manager warmUpDNSCacheWithDomains:@[@"api.example.com"]];
 ```
 */

#import "AFDNSResolver.h"
#import "AFDNSCache.h"
#import "AFDNSResolutionManager.h"
#import "AFHTTPSessionManager+DNS.h"
