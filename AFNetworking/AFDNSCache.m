#import "AFDNSCache.h"
#import <TargetConditionals.h>

#if TARGET_OS_IOS || TARGET_OS_TV
#import <UIKit/UIKit.h>
#elif TARGET_OS_MAC
#import <AppKit/AppKit.h>
#endif

NSTimeInterval const kAFDNSCacheDefaultExpirationTime = 300.0;
NSUInteger const kAFDNSCacheDefaultMaxCount = 100;

static NSString * const kAFDNSCacheFileName = @"AFDNSCache.plist";
static NSString * const kAFDNSCacheIPAddressesKey = @"ipAddresses";
static NSString * const kAFDNSCacheTimestampKey = @"timestamp";

@interface AFDNSCache ()

@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *memoryCache;
@property (nonatomic, strong) dispatch_queue_t cacheQueue;
@property (nonatomic, strong) NSString *cachePath;

@end

@implementation AFDNSCache

+ (instancetype)sharedCache {
    static AFDNSCache *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _expirationTime = kAFDNSCacheDefaultExpirationTime;
        _maxCacheCount = kAFDNSCacheDefaultMaxCount;
        _cacheQueue = dispatch_queue_create("com.alamofire.networking.dns.cache", DISPATCH_QUEUE_SERIAL);
        
        NSString *cachesDirectory = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
        _cachePath = [cachesDirectory stringByAppendingPathComponent:kAFDNSCacheFileName];
        
        [self loadCacheFromDisk];
        
#if TARGET_OS_IOS || TARGET_OS_TV
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clearExpiredCache) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clearExpiredCache) name:UIApplicationWillTerminateNotification object:nil];
#elif TARGET_OS_MAC
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clearExpiredCache) name:NSApplicationWillTerminateNotification object:nil];
#endif
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setIPAddresses:(NSArray<NSString *> *)ipAddresses forDomain:(NSString *)domain {
    if (!domain || !ipAddresses || ipAddresses.count == 0) {
        return;
    }
    
    dispatch_async(self.cacheQueue, ^{
        NSDictionary *entry = @{
            kAFDNSCacheIPAddressesKey: [ipAddresses copy],
            kAFDNSCacheTimestampKey: [NSDate date]
        };
        self.memoryCache[domain.lowercaseString] = entry;
        
        [self trimCacheIfNeeded];
        [self saveCacheToDisk];
    });
}

- (nullable NSArray<NSString *> *)ipAddressesForDomain:(NSString *)domain {
    if (!domain) {
        return nil;
    }
    
    __block NSArray<NSString *> *result = nil;
    dispatch_sync(self.cacheQueue, ^{
        NSString *lowerDomain = domain.lowercaseString;
        NSDictionary *entry = self.memoryCache[lowerDomain];
        if (entry) {
            NSDate *timestamp = entry[kAFDNSCacheTimestampKey];
            NSTimeInterval age = -[timestamp timeIntervalSinceNow];
            if (age < self.expirationTime) {
                result = entry[kAFDNSCacheIPAddressesKey];
            } else {
                [self.memoryCache removeObjectForKey:lowerDomain];
            }
        }
    });
    return result;
}

- (void)removeIPAddressesForDomain:(NSString *)domain {
    if (!domain) {
        return;
    }
    
    dispatch_async(self.cacheQueue, ^{
        [self.memoryCache removeObjectForKey:domain.lowercaseString];
        [self saveCacheToDisk];
    });
}

- (void)clearCache {
    dispatch_async(self.cacheQueue, ^{
        [self.memoryCache removeAllObjects];
        [self saveCacheToDisk];
    });
}

- (void)clearExpiredCache {
    dispatch_async(self.cacheQueue, ^{
        NSDate *now = [NSDate date];
        NSMutableArray<NSString *> *expiredKeys = [NSMutableArray array];
        
        for (NSString *domain in self.memoryCache) {
            NSDictionary *entry = self.memoryCache[domain];
            NSDate *timestamp = entry[kAFDNSCacheTimestampKey];
            NSTimeInterval age = -[timestamp timeIntervalSinceDate:now];
            if (age >= self.expirationTime) {
                [expiredKeys addObject:domain];
            }
        }
        
        [self.memoryCache removeObjectsForKeys:expiredKeys];
        [self saveCacheToDisk];
    });
}

#pragma mark - Private Methods

- (void)loadCacheFromDisk {
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.cachePath]) {
        NSDictionary *diskCache = [NSDictionary dictionaryWithContentsOfFile:self.cachePath];
        if (diskCache) {
            self.memoryCache = [diskCache mutableCopy];
        } else {
            self.memoryCache = [NSMutableDictionary dictionary];
        }
    } else {
        self.memoryCache = [NSMutableDictionary dictionary];
    }
}

- (void)saveCacheToDisk {
    [self.memoryCache writeToFile:self.cachePath atomically:YES];
}

- (void)trimCacheIfNeeded {
    if (self.memoryCache.count <= self.maxCacheCount) {
        return;
    }
    
    NSArray<NSString *> *sortedKeys = [self.memoryCache keysSortedByValueUsingComparator:^NSComparisonResult(NSDictionary *entry1, NSDictionary *entry2) {
        NSDate *date1 = entry1[kAFDNSCacheTimestampKey];
        NSDate *date2 = entry2[kAFDNSCacheTimestampKey];
        return [date1 compare:date2];
    }];
    
    NSUInteger removeCount = self.memoryCache.count - self.maxCacheCount;
    for (NSUInteger i = 0; i < removeCount && i < sortedKeys.count; i++) {
        [self.memoryCache removeObjectForKey:sortedKeys[i]];
    }
}

@end
