// AFDNSResolutionManager.m
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

#import "AFDNSResolutionManager.h"

NSString * const AFDNSResolutionManagerDidResolveDomainNotification = @"com.afnetworking.dns.manager.didResolve";
NSString * const AFDNSResolutionManagerDidFailToResolveDomainNotification = @"com.afnetworking.dns.manager.didFail";
NSString * const AFDNSResolutionManagerDomainKey = @"domain";
NSString * const AFDNSResolutionManagerRecordKey = @"record";
NSString * const AFDNSResolutionManagerErrorKey = @"error";

@interface AFDNSResolutionManager ()

@property (nonatomic, strong, readwrite) AFDNSResolver *resolver;
@property (nonatomic, strong, readwrite) AFDNSCache *cache;
@property (nonatomic, strong) NSMutableSet<NSString *> *refreshingDomains;
@property (nonatomic, strong) dispatch_queue_t syncQueue;
@property (nonatomic, strong) dispatch_source_t backgroundRefreshTimer;

@end

@implementation AFDNSResolutionManager

+ (instancetype)sharedManager {
    static AFDNSResolutionManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] initWithResolver:[AFDNSResolver sharedResolver]
                                                  cache:[AFDNSCache sharedCache]];
    });
    return sharedInstance;
}

- (instancetype)initWithResolver:(AFDNSResolver *)resolver
                           cache:(AFDNSCache *)cache {
    self = [super init];
    if (self) {
        _resolver = resolver;
        _cache = cache;
        _enabled = YES;
        _refreshingDomains = [NSMutableSet set];
        _syncQueue = dispatch_queue_create("com.afnetworking.dns.manager.sync", DISPATCH_QUEUE_SERIAL);
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cacheDidUpdate:)
                                                     name:AFDNSCacheDidUpdateNotification
                                                   object:cache];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopBackgroundRefresh];
}

#pragma mark - DNS Resolution

- (void)resolveDomain:(NSString *)domain
           completion:(AFDNSResolutionCompletionBlock)completionBlock {
    if (!self.enabled) {
        if (completionBlock) {
            completionBlock(nil, nil);
        }
        return;
    }
    
    if (!domain || domain.length == 0) {
        if (completionBlock) {
            NSError *error = [NSError errorWithDomain:AFDNSResolverErrorDomain
                                                 code:AFDNSResolverErrorInvalidDomain
                                             userInfo:@{NSLocalizedDescriptionKey: @"Domain cannot be empty"}];
            completionBlock(nil, error);
        }
        return;
    }
    
    NSString *normalizedDomain = [self normalizedDomain:domain];
    
    AFDNSRecord *cachedRecord = [self.cache recordForDomain:normalizedDomain];
    if (cachedRecord) {
        if (completionBlock) {
            completionBlock(cachedRecord, nil);
        }
        
        if ([self shouldRefreshDomain:normalizedDomain]) {
            [self refreshDomain:normalizedDomain completion:nil];
        }
        return;
    }
    
    [self.resolver resolveDomain:normalizedDomain completion:^(AFDNSRecord * _Nullable record, NSError * _Nullable error) {
        if (record) {
            [self.cache storeRecord:record];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:AFDNSResolutionManagerDidResolveDomainNotification
                                                                object:self
                                                              userInfo:@{AFDNSResolutionManagerDomainKey: normalizedDomain,
                                                                        AFDNSResolutionManagerRecordKey: record}];
        } else if (error) {
            [[NSNotificationCenter defaultCenter] postNotificationName:AFDNSResolutionManagerDidFailToResolveDomainNotification
                                                                object:self
                                                              userInfo:@{AFDNSResolutionManagerDomainKey: normalizedDomain,
                                                                        AFDNSResolutionManagerErrorKey: error}];
        }
        
        if (completionBlock) {
            completionBlock(record, error);
        }
    }];
}

- (void)refreshDomain:(NSString *)domain
           completion:(AFDNSResolutionCompletionBlock)completionBlock {
    if (!domain || domain.length == 0) {
        if (completionBlock) {
            NSError *error = [NSError errorWithDomain:AFDNSResolverErrorDomain
                                                 code:AFDNSResolverErrorInvalidDomain
                                             userInfo:@{NSLocalizedDescriptionKey: @"Domain cannot be empty"}];
            completionBlock(nil, error);
        }
        return;
    }
    
    NSString *normalizedDomain = [self normalizedDomain:domain];
    
    dispatch_async(self.syncQueue, ^{
        if ([self.refreshingDomains containsObject:normalizedDomain]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completionBlock) {
                    AFDNSRecord *existingRecord = [self.cache recordForDomain:normalizedDomain];
                    completionBlock(existingRecord, nil);
                }
            });
            return;
        }
        
        [self.refreshingDomains addObject:normalizedDomain];
    });
    
    [self.resolver resolveDomain:normalizedDomain completion:^(AFDNSRecord * _Nullable record, NSError * _Nullable error) {
        dispatch_async(self.syncQueue, ^{
            [self.refreshingDomains removeObject:normalizedDomain];
        });
        
        if (record) {
            [self.cache storeRecord:record];
        }
        
        if (completionBlock) {
            completionBlock(record, error);
        }
    }];
}

- (void)preResolveDomains:(NSArray<NSString *> *)domains
               completion:(nullable void (^)(NSDictionary<NSString *, AFDNSRecord *> *results))completionBlock {
    if (!self.enabled || !domains || domains.count == 0) {
        if (completionBlock) {
            completionBlock(@{});
        }
        return;
    }
    
    NSMutableArray *uniqueDomains = [NSMutableArray array];
    for (NSString *domain in domains) {
        NSString *normalized = [self normalizedDomain:domain];
        if (![uniqueDomains containsObject:normalized]) {
            [uniqueDomains addObject:normalized];
        }
    }
    
    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    dispatch_group_t group = dispatch_group_create();
    
    for (NSString *domain in uniqueDomains) {
        dispatch_group_enter(group);
        [self resolveDomain:domain completion:^(AFDNSRecord * _Nullable record, NSError * _Nullable error) {
            if (record) {
                results[domain] = record;
            }
            dispatch_group_leave(group);
        }];
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (completionBlock) {
            completionBlock([results copy]);
        }
    });
}

- (nullable NSString *)ipAddressForDomain:(NSString *)domain {
    NSArray *ipAddresses = [self ipAddressesForDomain:domain];
    return ipAddresses.firstObject;
}

- (nullable NSArray<NSString *> *)ipAddressesForDomain:(NSString *)domain {
    if (!self.enabled || !domain) {
        return nil;
    }
    
    NSString *normalizedDomain = [self normalizedDomain:domain];
    AFDNSRecord *record = [self.cache recordForDomain:normalizedDomain];
    
    if (!record && self.enabled) {
        record = [self.resolver resolveDomainSynchronously:normalizedDomain error:nil];
        if (record) {
            [self.cache storeRecord:record];
        }
    }
    
    return record.ipAddresses;
}

#pragma mark - URL Processing

- (void)resolveURL:(NSURL *)url
        completion:(AFDNSResolutionCompletionBlock)completionBlock {
    if (!url.host) {
        if (completionBlock) {
            completionBlock(nil, nil);
        }
        return;
    }
    
    [self resolveDomain:url.host completion:completionBlock];
}

- (NSURL *)urlByReplacingDomainWithIP:(NSURL *)url {
    if (!url.host) {
        return url;
    }
    
    NSString *ipAddress = [self ipAddressForDomain:url.host];
    if (!ipAddress) {
        return url;
    }
    
    NSString *urlString = url.absoluteString;
    urlString = [urlString stringByReplacingOccurrencesOfString:url.host withString:ipAddress];
    
    NSURL *newURL = [NSURL URLWithString:urlString];
    return newURL ?: url;
}

#pragma mark - Cache Management

- (void)warmUpCacheWithDomains:(NSArray<NSString *> *)domains {
    if (!self.enabled || !domains || domains.count == 0) {
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        for (NSString *domain in domains) {
            NSString *normalized = [self normalizedDomain:domain];
            if (![self.cache containsValidRecordForDomain:normalized]) {
                [self resolveDomain:normalized completion:nil];
            }
        }
    });
}

- (BOOL)shouldRefreshDomain:(NSString *)domain {
    if (!domain) {
        return NO;
    }
    
    NSString *normalizedDomain = [self normalizedDomain:domain];
    AFDNSRecord *record = [self.cache recordForDomainIgnoringExpiration:normalizedDomain];
    
    if (!record) {
        return YES;
    }
    
    if (record.isExpired) {
        return YES;
    }
    
    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:record.createTime];
    NSTimeInterval refreshThreshold = record.TTL * 0.8;
    
    return elapsed >= refreshThreshold;
}

- (void)startBackgroundRefresh {
    if (self.backgroundRefreshTimer) {
        return;
    }
    
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0));
    dispatch_source_set_timer(timer,
                              dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC)),
                              (uint64_t)(60 * NSEC_PER_SEC),
                              (int64_t)(10 * NSEC_PER_SEC));
    
    dispatch_source_set_event_handler(timer, ^{
        [self performBackgroundRefresh];
    });
    
    dispatch_resume(timer);
    self.backgroundRefreshTimer = timer;
}

- (void)stopBackgroundRefresh {
    if (self.backgroundRefreshTimer) {
        dispatch_source_cancel(self.backgroundRefreshTimer);
        self.backgroundRefreshTimer = nil;
    }
}

#pragma mark - Private Methods

- (NSString *)normalizedDomain:(NSString *)domain {
    NSString *normalized = [domain lowercaseString];
    normalized = [normalized stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    if ([normalized hasPrefix:@"http://"]) {
        normalized = [normalized substringFromIndex:7];
    } else if ([normalized hasPrefix:@"https://"]) {
        normalized = [normalized substringFromIndex:8];
    }
    
    NSRange pathRange = [normalized rangeOfString:@"/"];
    if (pathRange.location != NSNotFound) {
        normalized = [normalized substringToIndex:pathRange.location];
    }
    
    NSRange portRange = [normalized rangeOfString:@":"];
    if (portRange.location != NSNotFound) {
        normalized = [normalized substringToIndex:portRange.location];
    }
    
    return normalized;
}

- (void)performBackgroundRefresh {
    if (!self.enabled || !self.cache.configuration.enableBackgroundRefresh) {
        return;
    }
    
    NSDictionary *allRecords = [self.cache allValidRecords];
    NSTimeInterval advanceTime = self.cache.configuration.backgroundRefreshAdvanceTime;
    
    for (NSString *domain in allRecords.allKeys) {
        AFDNSRecord *record = allRecords[domain];
        NSTimeInterval remainingTime = record.TTL - [[NSDate date] timeIntervalSinceDate:record.createTime];
        
        if (remainingTime <= advanceTime) {
            [self refreshDomain:domain completion:nil];
        }
    }
}

- (void)cacheDidUpdate:(NSNotification *)notification {
}

@end
