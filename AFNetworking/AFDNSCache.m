// AFDNSCache.m
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

#import "AFDNSCache.h"
#import <TargetConditionals.h>

#if TARGET_OS_IOS || TARGET_OS_TV
#import <UIKit/UIKit.h>
#endif

NSString * const AFDNSCacheDidUpdateNotification = @"com.afnetworking.dns.cache.didUpdate";
NSString * const AFDNSCacheDidRemoveExpiredRecordsNotification = @"com.afnetworking.dns.cache.didRemoveExpired";
NSString * const AFDNSCacheDidClearNotification = @"com.afnetworking.dns.cache.didClear";
NSString * const AFDNSCacheDomainKey = @"domain";
NSString * const AFDNSCacheRecordKey = @"record";
NSString * const AFDNSCacheRemovedCountKey = @"removedCount";

static NSString * const kAFDNSCacheDirectoryName = @"AFDNSCache";
static NSString * const kAFDNSCacheFileName = @"dns_cache.plist";

#pragma mark - AFDNSCacheConfiguration

@implementation AFDNSCacheConfiguration

- (instancetype)init {
    self = [super init];
    if (self) {
        _cachePolicy = AFDNSCachePolicyMemoryAndDisk;
        _memoryCacheCountLimit = 100;
        _memoryCacheTotalCostLimit = 10 * 1024 * 1024;
        _diskCacheSizeLimit = 50 * 1024 * 1024;
        _defaultTTLMultiplier = 1.0;
        _minimumTTL = 60;
        _maximumTTL = 86400;
        _autoCleanupInterval = 300;
        _enableBackgroundRefresh = YES;
        _backgroundRefreshAdvanceTime = 60;
    }
    return self;
}

+ (instancetype)defaultConfiguration {
    return [[self alloc] init];
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.cachePolicy forKey:@"cachePolicy"];
    [coder encodeInteger:self.memoryCacheCountLimit forKey:@"memoryCacheCountLimit"];
    [coder encodeInteger:self.memoryCacheTotalCostLimit forKey:@"memoryCacheTotalCostLimit"];
    [coder encodeInteger:self.diskCacheSizeLimit forKey:@"diskCacheSizeLimit"];
    [coder encodeFloat:self.defaultTTLMultiplier forKey:@"defaultTTLMultiplier"];
    [coder encodeDouble:self.minimumTTL forKey:@"minimumTTL"];
    [coder encodeDouble:self.maximumTTL forKey:@"maximumTTL"];
    [coder encodeDouble:self.autoCleanupInterval forKey:@"autoCleanupInterval"];
    [coder encodeBool:self.enableBackgroundRefresh forKey:@"enableBackgroundRefresh"];
    [coder encodeDouble:self.backgroundRefreshAdvanceTime forKey:@"backgroundRefreshAdvanceTime"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _cachePolicy = [coder decodeIntegerForKey:@"cachePolicy"];
        _memoryCacheCountLimit = [coder decodeIntegerForKey:@"memoryCacheCountLimit"];
        _memoryCacheTotalCostLimit = [coder decodeIntegerForKey:@"memoryCacheTotalCostLimit"];
        _diskCacheSizeLimit = [coder decodeIntegerForKey:@"diskCacheSizeLimit"];
        _defaultTTLMultiplier = [coder decodeFloatForKey:@"defaultTTLMultiplier"];
        _minimumTTL = [coder decodeDoubleForKey:@"minimumTTL"];
        _maximumTTL = [coder decodeDoubleForKey:@"maximumTTL"];
        _autoCleanupInterval = [coder decodeDoubleForKey:@"autoCleanupInterval"];
        _enableBackgroundRefresh = [coder decodeBoolForKey:@"enableBackgroundRefresh"];
        _backgroundRefreshAdvanceTime = [coder decodeDoubleForKey:@"backgroundRefreshAdvanceTime"];
    }
    return self;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    AFDNSCacheConfiguration *copy = [[AFDNSCacheConfiguration alloc] init];
    copy.cachePolicy = self.cachePolicy;
    copy.memoryCacheCountLimit = self.memoryCacheCountLimit;
    copy.memoryCacheTotalCostLimit = self.memoryCacheTotalCostLimit;
    copy.diskCacheSizeLimit = self.diskCacheSizeLimit;
    copy.defaultTTLMultiplier = self.defaultTTLMultiplier;
    copy.minimumTTL = self.minimumTTL;
    copy.maximumTTL = self.maximumTTL;
    copy.autoCleanupInterval = self.autoCleanupInterval;
    copy.enableBackgroundRefresh = self.enableBackgroundRefresh;
    copy.backgroundRefreshAdvanceTime = self.backgroundRefreshAdvanceTime;
    return copy;
}

@end

#pragma mark - AFDNSCache

@interface AFDNSCache ()

@property (nonatomic, copy, readwrite) AFDNSCacheConfiguration *configuration;
@property (nonatomic, strong) NSCache<NSString *, AFDNSRecord *> *memoryCache;
@property (nonatomic, strong) dispatch_queue_t syncQueue;
@property (nonatomic, strong) dispatch_source_t cleanupTimer;
@property (nonatomic, strong) NSMutableDictionary<NSString *, AFDNSRecord *> *diskCacheBackup;

@end

@implementation AFDNSCache

+ (instancetype)sharedCache {
    static AFDNSCache *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] initWithConfiguration:[AFDNSCacheConfiguration defaultConfiguration]];
    });
    return sharedInstance;
}

- (instancetype)initWithConfiguration:(AFDNSCacheConfiguration *)configuration {
    self = [super init];
    if (self) {
        _configuration = [configuration copy];
        _syncQueue = dispatch_queue_create("com.afnetworking.dns.cache.sync", DISPATCH_QUEUE_SERIAL);
        _diskCacheBackup = [NSMutableDictionary dictionary];
        
        [self setupMemoryCache];
        [self setupCleanupTimer];
        [self loadFromDisk];
        
#if TARGET_OS_IOS || TARGET_OS_TV
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillTerminate:)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
#endif
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_cleanupTimer) {
        dispatch_source_cancel(_cleanupTimer);
    }
}

#pragma mark - Setup

- (void)setupMemoryCache {
    if (self.configuration.cachePolicy == AFDNSCachePolicyDiskOnly) {
        return;
    }
    
    _memoryCache = [[NSCache alloc] init];
    _memoryCache.countLimit = self.configuration.memoryCacheCountLimit;
    _memoryCache.totalCostLimit = self.configuration.memoryCacheTotalCostLimit;
    _memoryCache.name = @"com.afnetworking.dns.cache.memory";
}

- (void)setupCleanupTimer {
    if (self.configuration.autoCleanupInterval <= 0) {
        return;
    }
    
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.syncQueue);
    dispatch_source_set_timer(timer,
                              dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.configuration.autoCleanupInterval * NSEC_PER_SEC)),
                              (uint64_t)(self.configuration.autoCleanupInterval * NSEC_PER_SEC),
                              (int64_t)(1 * NSEC_PER_SEC));

    dispatch_source_set_event_handler(timer, ^{
        [self removeExpiredRecords];
    });
    
    dispatch_resume(timer);
    self.cleanupTimer = timer;
}

#pragma mark - Cache Operations

- (void)storeRecord:(AFDNSRecord *)record {
    if (!record || !record.domain) {
        return;
    }
    
    NSTimeInterval effectiveTTL = [self effectiveTTLForRecord:record];
    AFDNSRecord *cachedRecord = [[AFDNSRecord alloc] initWithDomain:record.domain
                                                        ipAddresses:record.ipAddresses
                                                                TTL:effectiveTTL];
    
    dispatch_async(self.syncQueue, ^{
        NSString *domain = cachedRecord.domain;
        
        if (self.configuration.cachePolicy != AFDNSCachePolicyDiskOnly) {
            NSUInteger cost = [NSKeyedArchiver archivedDataWithRootObject:cachedRecord].length;
            [self.memoryCache setObject:cachedRecord forKey:domain cost:cost];
        }
        
        if (self.configuration.cachePolicy != AFDNSCachePolicyMemoryOnly) {
            self.diskCacheBackup[domain] = cachedRecord;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:AFDNSCacheDidUpdateNotification
                                                                object:self
                                                              userInfo:@{AFDNSCacheDomainKey: domain,
                                                                        AFDNSCacheRecordKey: cachedRecord}];
        });
    });
}

- (void)storeRecords:(NSArray<AFDNSRecord *> *)records {
    if (!records || records.count == 0) {
        return;
    }
    
    for (AFDNSRecord *record in records) {
        [self storeRecord:record];
    }
}

- (nullable AFDNSRecord *)recordForDomain:(NSString *)domain {
    if (!domain) {
        return nil;
    }
    
    AFDNSRecord *record = [self recordForDomainIgnoringExpiration:domain];
    
    if (record && record.isExpired) {
        return nil;
    }
    
    return record;
}

- (nullable AFDNSRecord *)recordForDomainIgnoringExpiration:(NSString *)domain {
    if (!domain) {
        return nil;
    }
    
    __block AFDNSRecord *record = nil;
    
    dispatch_sync(self.syncQueue, ^{
        if (self.configuration.cachePolicy != AFDNSCachePolicyDiskOnly) {
            record = [self.memoryCache objectForKey:domain];
        }
        
        if (!record && self.configuration.cachePolicy != AFDNSCachePolicyMemoryOnly) {
            record = self.diskCacheBackup[domain];
            
            if (record && self.configuration.cachePolicy != AFDNSCachePolicyDiskOnly) {
                NSUInteger cost = [NSKeyedArchiver archivedDataWithRootObject:record].length;
                [self.memoryCache setObject:record forKey:domain cost:cost];
            }
        }
    });
    
    return record;
}

- (BOOL)containsValidRecordForDomain:(NSString *)domain {
    AFDNSRecord *record = [self recordForDomain:domain];
    return record != nil;
}

- (NSDictionary<NSString *, AFDNSRecord *> *)allValidRecords {
    __block NSMutableDictionary *validRecords = [NSMutableDictionary dictionary];
    
    dispatch_sync(self.syncQueue, ^{
        NSArray *allRecords = nil;
        
        if (self.configuration.cachePolicy != AFDNSCachePolicyDiskOnly) {
            allRecords = [self allMemoryCacheRecords];
        } else {
            allRecords = [self.diskCacheBackup allValues];
        }
        
        for (AFDNSRecord *record in allRecords) {
            if (!record.isExpired) {
                validRecords[record.domain] = record;
            }
        }
    });
    
    return [validRecords copy];
}

- (void)removeRecordForDomain:(NSString *)domain {
    if (!domain) {
        return;
    }
    
    dispatch_async(self.syncQueue, ^{
        [self.memoryCache removeObjectForKey:domain];
        [self.diskCacheBackup removeObjectForKey:domain];
    });
}

- (NSUInteger)removeExpiredRecords {
    __block NSUInteger removedCount = 0;
    
    dispatch_sync(self.syncQueue, ^{
        NSMutableArray<NSString *> *expiredDomains = [NSMutableArray array];
        
        if (self.configuration.cachePolicy != AFDNSCachePolicyDiskOnly) {
            NSArray *allRecords = [self allMemoryCacheRecords];
            for (AFDNSRecord *record in allRecords) {
                if (record.isExpired) {
                    [expiredDomains addObject:record.domain];
                }
            }
        }
        
        for (NSString *domain in self.diskCacheBackup.allKeys) {
            AFDNSRecord *record = self.diskCacheBackup[domain];
            if (record.isExpired) {
                [expiredDomains addObject:domain];
            }
        }
        
        for (NSString *domain in expiredDomains) {
            [self.memoryCache removeObjectForKey:domain];
            [self.diskCacheBackup removeObjectForKey:domain];
            removedCount++;
        }
    });
    
    if (removedCount > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:AFDNSCacheDidRemoveExpiredRecordsNotification
                                                                object:self
                                                              userInfo:@{AFDNSCacheRemovedCountKey: @(removedCount)}];
        });
    }
    
    return removedCount;
}

- (void)removeAllRecords {
    dispatch_async(self.syncQueue, ^{
        [self.memoryCache removeAllObjects];
        [self.diskCacheBackup removeAllObjects];
        
        [self deleteDiskCache];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:AFDNSCacheDidClearNotification
                                                                object:self];
        });
    });
}

#pragma mark - Cache Persistence

- (void)synchronize {
    if (self.configuration.cachePolicy == AFDNSCachePolicyMemoryOnly) {
        return;
    }
    
    dispatch_async(self.syncQueue, ^{
        [self saveToDisk];
    });
}

- (void)loadFromDisk {
    if (self.configuration.cachePolicy == AFDNSCachePolicyMemoryOnly) {
        return;
    }
    
    dispatch_async(self.syncQueue, ^{
        NSString *cachePath = [self diskCachePath];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        if (![fileManager fileExistsAtPath:cachePath]) {
            return;
        }
        
        NSData *data = [NSData dataWithContentsOfFile:cachePath];
        if (!data) {
            return;
        }
        
        NSError *error = nil;
        NSDictionary *cachedData = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSDictionary class]
                                                                     fromData:data
                                                                        error:&error];
        
        if (error || !cachedData) {
            return;
        }
        
        for (NSString *domain in cachedData.allKeys) {
            AFDNSRecord *record = cachedData[domain];
            if ([record isKindOfClass:[AFDNSRecord class]]) {
                self.diskCacheBackup[domain] = record;
            }
        }
    });
}

- (void)saveToDisk {
    if (self.diskCacheBackup.count == 0) {
        return;
    }
    
    NSString *cachePath = [self diskCachePath];
    NSString *cacheDirectory = [cachePath stringByDeletingLastPathComponent];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:cacheDirectory]) {
        [fileManager createDirectoryAtPath:cacheDirectory
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:nil];
    }
    
    NSMutableDictionary *recordsToSave = [NSMutableDictionary dictionary];
    unsigned long long currentSize = 0;
    
    NSArray *sortedDomains = [self.diskCacheBackup.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
        AFDNSRecord *record1 = self.diskCacheBackup[obj1];
        AFDNSRecord *record2 = self.diskCacheBackup[obj2];
        return [record1.createTime compare:record2.createTime];
    }];
    
    for (NSString *domain in sortedDomains) {
        AFDNSRecord *record = self.diskCacheBackup[domain];
        
        if (record.isExpired) {
            continue;
        }
        
        NSData *recordData = [NSKeyedArchiver archivedDataWithRootObject:record requiringSecureCoding:YES error:nil];
        if (recordData) {
            currentSize += recordData.length;
            
            if (currentSize > self.configuration.diskCacheSizeLimit && recordsToSave.count > 0) {
                break;
            }
            
            recordsToSave[domain] = record;
        }
    }
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:recordsToSave requiringSecureCoding:YES error:nil];
    if (data) {
        [data writeToFile:cachePath atomically:YES];
    }
}

- (void)deleteDiskCache {
    NSString *cachePath = [self diskCachePath];
    [[NSFileManager defaultManager] removeItemAtPath:cachePath error:nil];
}

- (NSString *)diskCachePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = [paths.firstObject stringByAppendingPathComponent:kAFDNSCacheDirectoryName];
    return [cacheDirectory stringByAppendingPathComponent:kAFDNSCacheFileName];
}

#pragma mark - Cache Statistics

- (NSDictionary *)cacheStatistics {
    __block NSUInteger memoryCount = 0;
    __block unsigned long long diskSize = 0;
    __block NSUInteger expiredCount = 0;
    
    dispatch_sync(self.syncQueue, ^{
        memoryCount = [self allMemoryCacheRecords].count;
        
        for (AFDNSRecord *record in self.diskCacheBackup.allValues) {
            if (record.isExpired) {
                expiredCount++;
            }
        }
        
        NSString *cachePath = [self diskCachePath];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:cachePath error:nil];
        diskSize = [attributes fileSize];
    });
    
    return @{
        @"memoryCacheCount": @(memoryCount),
        @"diskCacheCount": @(self.diskCacheBackup.count),
        @"expiredRecordCount": @(expiredCount),
        @"diskCacheSize": @(diskSize),
        @"configuration": @{
            @"cachePolicy": @(self.configuration.cachePolicy),
            @"memoryCacheCountLimit": @(self.configuration.memoryCacheCountLimit),
            @"diskCacheSizeLimit": @(self.configuration.diskCacheSizeLimit)
        }
    };
}

- (NSUInteger)memoryCacheCount {
    __block NSUInteger count = 0;
    dispatch_sync(self.syncQueue, ^{
        count = [self allMemoryCacheRecords].count;
    });
    return count;
}

- (unsigned long long)diskCacheSize {
    NSString *cachePath = [self diskCachePath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDictionary *attributes = [fileManager attributesOfItemAtPath:cachePath error:nil];
    return [attributes fileSize];
}

#pragma mark - Private Methods

- (NSArray<AFDNSRecord *> *)allMemoryCacheRecords {
    NSMutableArray *records = [NSMutableArray array];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    SEL selector = NSSelectorFromString(@"allObjects");
    if ([self.memoryCache respondsToSelector:selector]) {
        NSArray *objects = [self.memoryCache performSelector:selector];
        [records addObjectsFromArray:objects];
    }
#pragma clang diagnostic pop
    
    return records;
}

- (NSTimeInterval)effectiveTTLForRecord:(AFDNSRecord *)record {
    NSTimeInterval ttl = record.TTL * self.configuration.defaultTTLMultiplier;
    ttl = MAX(ttl, self.configuration.minimumTTL);
    ttl = MIN(ttl, self.configuration.maximumTTL);
    return ttl;
}

#pragma mark - Notifications

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    [self synchronize];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self synchronize];
}

@end
