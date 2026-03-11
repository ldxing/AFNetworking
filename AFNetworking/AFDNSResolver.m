//
//  AFDNSResolver.m
//  AFNetworking
//
//  Created by DNS Resolver Extension on 2026/3/11.
//  Copyright © 2026 Alamofire Software Foundation. All rights reserved.
//

#import "AFDNSResolver.h"
#import <arpa/inet.h>
#import <netdb.h>
#import <sys/socket.h>

@interface AFDNSRecord ()
@property (nonatomic, copy, readwrite) NSString *domain;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *ipAddresses;
@property (nonatomic, assign, readwrite) NSTimeInterval timestamp;
@property (nonatomic, assign, readwrite) NSTimeInterval ttl;
@end

@implementation AFDNSRecord

- (instancetype)initWithDomain:(NSString *)domain
                   ipAddresses:(NSArray<NSString *> *)ipAddresses
                           ttl:(NSTimeInterval)ttl {
    self = [super init];
    if (self) {
        _domain = [domain copy];
        _ipAddresses = [ipAddresses copy];
        _timestamp = [[NSDate date] timeIntervalSince1970];
        _ttl = ttl;
    }
    return self;
}

- (BOOL)isExpired {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    return (now - self.timestamp) > self.ttl;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _domain = [coder decodeObjectForKey:@"domain"];
        _ipAddresses = [coder decodeObjectForKey:@"ipAddresses"];
        _timestamp = [coder decodeDoubleForKey:@"timestamp"];
        _ttl = [coder decodeDoubleForKey:@"ttl"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.domain forKey:@"domain"];
    [coder encodeObject:self.ipAddresses forKey:@"ipAddresses"];
    [coder encodeDouble:self.timestamp forKey:@"timestamp"];
    [coder encodeDouble:self.ttl forKey:@"ttl"];
}

@end

@interface AFSystemDNSResolver ()
@end

@implementation AFSystemDNSResolver

- (instancetype)init {
    self = [super init];
    if (self) {
        _defaultTTL = 300; // 默认5分钟TTL
    }
    return self;
}

- (void)resolveDomain:(NSString *)domain
           completion:(void (^)(AFDNSRecord * _Nullable record, NSError * _Nullable error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        struct hostent *host = gethostbyname([domain UTF8String]);
        if (host == NULL) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *error = [NSError errorWithDomain:@"AFDNSResolverErrorDomain"
                                                     code:-1
                                                 userInfo:@{NSLocalizedDescriptionKey: @"DNS解析失败"}];
                completion(nil, error);
            });
            return;
        }
        
        NSMutableArray *ipAddresses = [NSMutableArray array];
        for (int i = 0; host->h_addr_list[i] != NULL; i++) {
            struct in_addr *addr = (struct in_addr *)host->h_addr_list[i];
            NSString *ipString = [NSString stringWithUTF8String:inet_ntoa(*addr)];
            if (ipString) {
                [ipAddresses addObject:ipString];
            }
        }
        
        if (ipAddresses.count == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *error = [NSError errorWithDomain:@"AFDNSResolverErrorDomain"
                                                     code:-2
                                                 userInfo:@{NSLocalizedDescriptionKey: @"未找到有效的IP地址"}];
                completion(nil, error);
            });
            return;
        }
        
        AFDNSRecord *record = [[AFDNSRecord alloc] initWithDomain:domain
                                                      ipAddresses:ipAddresses
                                                              ttl:self.defaultTTL];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(record, nil);
        });
    });
}

@end

@interface AFDNSCacheManager ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, AFDNSRecord *> *cache;
@property (nonatomic, strong) dispatch_queue_t cacheQueue;
@end

@implementation AFDNSCacheManager

+ (instancetype)sharedManager {
    static AFDNSCacheManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cache = [NSMutableDictionary dictionary];
        _cacheQueue = dispatch_queue_create("com.alamofire.AFDNSCacheQueue", DISPATCH_QUEUE_SERIAL);
        _maxCacheCount = 100;
        
        // 从磁盘加载缓存
        [self loadCacheFromDisk];
        
        // 监听内存警告
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleMemoryWarning:)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)cacheDNSRecord:(AFDNSRecord *)record {
    if (!record.domain || record.ipAddresses.count == 0) {
        return;
    }
    
    dispatch_async(self.cacheQueue, ^{
        self.cache[record.domain] = record;
        
        // 限制缓存数量
        if (self.cache.count > self.maxCacheCount) {
            // 删除最早的记录
            NSArray *sortedKeys = [self.cache keysSortedByValueUsingComparator:^NSComparisonResult(AFDNSRecord *obj1, AFDNSRecord *obj2) {
                return [@(obj1.timestamp) compare:@(obj2.timestamp)];
            }];
            
            if (sortedKeys.count > 0) {
                [self.cache removeObjectForKey:sortedKeys[0]];
            }
        }
        
        // 异步保存到磁盘
        [self saveCacheToDisk];
    });
}

- (AFDNSRecord *)cachedRecordForDomain:(NSString *)domain {
    if (!domain) {
        return nil;
    }
    
    __block AFDNSRecord *record = nil;
    dispatch_sync(self.cacheQueue, ^{
        record = self.cache[domain];
    });
    
    // 检查是否过期
    if (record && [record isExpired]) {
        dispatch_async(self.cacheQueue, ^{
            [self.cache removeObjectForKey:domain];
        });
        return nil;
    }
    
    return record;
}

- (void)removeCacheForDomain:(NSString *)domain {
    if (!domain) {
        return;
    }
    
    dispatch_async(self.cacheQueue, ^{
        [self.cache removeObjectForKey:domain];
        [self saveCacheToDisk];
    });
}

- (void)clearAllCache {
    dispatch_async(self.cacheQueue, ^{
        [self.cache removeAllObjects];
        [self saveCacheToDisk];
    });
}

- (void)clearExpiredCache {
    dispatch_async(self.cacheQueue, ^{
        NSMutableArray *expiredDomains = [NSMutableArray array];
        for (NSString *domain in self.cache) {
            AFDNSRecord *record = self.cache[domain];
            if ([record isExpired]) {
                [expiredDomains addObject:domain];
            }
        }
        
        if (expiredDomains.count > 0) {
            [self.cache removeObjectsForKeys:expiredDomains];
            [self saveCacheToDisk];
        }
    });
}

- (void)handleMemoryWarning:(NSNotification *)notification {
    [self clearExpiredCache];
}

#pragma mark - 磁盘持久化

- (NSString *)cacheFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDir = [paths firstObject];
    return [cacheDir stringByAppendingPathComponent:@"AFDNSCache.plist"];
}

- (void)saveCacheToDisk {
    dispatch_async(self.cacheQueue, ^{
        NSMutableDictionary *cacheData = [NSMutableDictionary dictionary];
        for (NSString *domain in self.cache) {
            AFDNSRecord *record = self.cache[domain];
            NSData *encodedData = [NSKeyedArchiver archivedDataWithRootObject:record];
            if (encodedData) {
                cacheData[domain] = encodedData;
            }
        }
        
        [cacheData writeToFile:[self cacheFilePath] atomically:YES];
    });
}

- (void)loadCacheFromDisk {
    dispatch_async(self.cacheQueue, ^{
        NSDictionary *cacheData = [NSDictionary dictionaryWithContentsOfFile:[self cacheFilePath]];
        if (!cacheData) {
            return;
        }
        
        NSMutableDictionary *loadedCache = [NSMutableDictionary dictionary];
        for (NSString *domain in cacheData) {
            NSData *encodedData = cacheData[domain];
            AFDNSRecord *record = [NSKeyedUnarchiver unarchiveObjectWithData:encodedData];
            if (record && ![record isExpired]) {
                loadedCache[domain] = record;
            }
        }
        
        self.cache = loadedCache;
    });
}

@end

@interface AFDNSResolutionManager ()
@property (nonatomic, strong) dispatch_queue_t resolutionQueue;
@end

@implementation AFDNSResolutionManager

+ (instancetype)sharedManager {
    static AFDNSResolutionManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _resolver = [[AFSystemDNSResolver alloc] init];
        _enabled = YES;
        _autoClearExpiredCache = YES;
        _resolutionQueue = dispatch_queue_create("com.alamofire.AFDNSResolutionQueue", DISPATCH_QUEUE_CONCURRENT);
        
        // 定期清理过期缓存
        if (_autoClearExpiredCache) {
            NSTimeInterval interval = 60; // 每分钟检查一次
            [NSTimer scheduledTimerWithTimeInterval:interval
                                             target:self
                                           selector:@selector(clearExpiredCacheTimerFired:)
                                           userInfo:nil
                                            repeats:YES];
        }
    }
    return self;
}

- (void)prefetchDomain:(NSString *)domain {
    if (!self.enabled || !domain) {
        return;
    }
    
    // 先检查缓存
    AFDNSRecord *cachedRecord = [[AFDNSCacheManager sharedManager] cachedRecordForDomain:domain];
    if (cachedRecord) {
        return;
    }
    
    dispatch_async(self.resolutionQueue, ^{
        [self.resolver resolveDomain:domain completion:^(AFDNSRecord *record, NSError *error) {
            if (record && !error) {
                [[AFDNSCacheManager sharedManager] cacheDNSRecord:record];
            }
        }];
    });
}

- (void)prefetchDomains:(NSArray<NSString *> *)domains {
    if (!self.enabled || domains.count == 0) {
        return;
    }
    
    for (NSString *domain in domains) {
        [self prefetchDomain:domain];
    }
}

- (NSString *)ipAddressForDomain:(NSString *)domain {
    NSArray *ipAddresses = [self ipAddressesForDomain:domain];
    return [ipAddresses firstObject];
}

- (NSArray<NSString *> *)ipAddressesForDomain:(NSString *)domain {
    if (!self.enabled || !domain) {
        return nil;
    }
    
    // 先从缓存获取
    AFDNSRecord *cachedRecord = [[AFDNSCacheManager sharedManager] cachedRecordForDomain:domain];
    if (cachedRecord) {
        return cachedRecord.ipAddresses;
    }
    
    // 同步解析
    __block NSArray *result = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [self.resolver resolveDomain:domain completion:^(AFDNSRecord *record, NSError *error) {
        if (record && !error) {
            [[AFDNSCacheManager sharedManager] cacheDNSRecord:record];
            result = record.ipAddresses;
        }
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return result;
}

- (void)resolveDomain:(NSString *)domain
           completion:(void (^)(NSString *ipAddress, NSError *error))completion {
    if (!self.enabled || !domain) {
        completion(nil, [NSError errorWithDomain:@"AFDNSResolverErrorDomain"
                                            code:-3
                                        userInfo:@{NSLocalizedDescriptionKey: @"DNS解析已禁用或域名无效"}]);
        return;
    }
    
    // 先检查缓存
    AFDNSRecord *cachedRecord = [[AFDNSCacheManager sharedManager] cachedRecordForDomain:domain];
    if (cachedRecord) {
        completion([cachedRecord.ipAddresses firstObject], nil);
        return;
    }
    
    // 异步解析
    dispatch_async(self.resolutionQueue, ^{
        [self.resolver resolveDomain:domain completion:^(AFDNSRecord *record, NSError *error) {
            if (record && !error) {
                [[AFDNSCacheManager sharedManager] cacheDNSRecord:record];
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion([record.ipAddresses firstObject], nil);
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, error);
                });
            }
        }];
    });
}

- (NSURL *)urlByReplacingDomainWithIP:(NSURL *)url {
    if (!self.enabled || !url) {
        return url;
    }
    
    NSString *domain = url.host;
    if (!domain) {
        return url;
    }
    
    NSString *ipAddress = [self ipAddressForDomain:domain];
    if (!ipAddress) {
        return url;
    }
    
    // 构建新的URL
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
    components.host = ipAddress;
    
    return [components URL];
}

- (void)clearExpiredCacheTimerFired:(NSTimer *)timer {
    if (self.autoClearExpiredCache) {
        [[AFDNSCacheManager sharedManager] clearExpiredCache];
    }
}

@end
