// AFDNSCache.m
// DNS缓存管理器实现

#import "AFDNSCache.h"

@interface AFDNSCacheEntry ()
@property (nonatomic, copy, readwrite) NSString *host;
@property (nonatomic, strong, readwrite) NSArray<NSString *> *ipAddresses;
@property (nonatomic, strong, readwrite) NSDate *creationDate;
@property (nonatomic, assign, readwrite) NSTimeInterval ttl;
@end

@implementation AFDNSCacheEntry

- (instancetype)initWithHost:(NSString *)host
                 ipAddresses:(NSArray<NSString *> *)ipAddresses
                         ttl:(NSTimeInterval)ttl {
    self = [super init];
    if (self) {
        _host = [host copy];
        _ipAddresses = [ipAddresses copy];
        _creationDate = [NSDate date];
        _ttl = ttl;
    }
    return self;
}

- (BOOL)isExpired {
    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:self.creationDate];
    return elapsed >= self.ttl;
}

@end

@interface AFDNSCache ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, AFDNSCacheEntry *> *cache;
@property (nonatomic, strong) NSLock *lock;
@end

@implementation AFDNSCache

+ (instancetype)sharedCache {
    static AFDNSCache *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AFDNSCache alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cache = [NSMutableDictionary dictionary];
        _lock = [[NSLock alloc] init];
        _defaultTTL = 300.0;
        _maxCacheSize = 100;
    }
    return self;
}

- (void)cacheEntry:(AFDNSCacheEntry *)entry {
    if (!entry || !entry.host) return;
    
    [self.lock lock];
    
    if (self.cache.count >= self.maxCacheSize) {
        [self removeOldestEntry];
    }
    
    self.cache[entry.host] = entry;
    
    [self.lock unlock];
}

- (AFDNSCacheEntry *)entryForHost:(NSString *)host {
    if (!host) return nil;
    
    [self.lock lock];
    
    AFDNSCacheEntry *entry = self.cache[host];
    
    if (entry && [entry isExpired]) {
        [self.cache removeObjectForKey:host];
        entry = nil;
    }
    
    [self.lock unlock];
    
    return entry;
}

- (void)removeEntryForHost:(NSString *)host {
    if (!host) return;
    
    [self.lock lock];
    [self.cache removeObjectForKey:host];
    [self.lock unlock];
}

- (void)removeAllEntries {
    [self.lock lock];
    [self.cache removeAllObjects];
    [self.lock unlock];
}

- (NSArray<NSString *> *)allCachedHosts {
    [self.lock lock];
    NSArray *hosts = [self.cache.allKeys copy];
    [self.lock unlock];
    return hosts;
}

- (void)removeOldestEntry {
    NSString *oldestHost = nil;
    NSDate *oldestDate = [NSDate distantFuture];
    
    for (NSString *host in self.cache) {
        AFDNSCacheEntry *entry = self.cache[host];
        if ([entry.creationDate compare:oldestDate] == NSOrderedAscending) {
            oldestDate = entry.creationDate;
            oldestHost = host;
        }
    }
    
    if (oldestHost) {
        [self.cache removeObjectForKey:oldestHost];
    }
}

@end