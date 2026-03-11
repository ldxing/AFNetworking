// AFDNSResolver.m
// DNS解析器实现

#import "AFDNSResolver.h"
#import "AFDNSCache.h"
#import <netdb.h>
#import <arpa/inet.h>

NSString * const AFDNSResolverErrorDomain = @"com.afnetworking.dns.resolver";

@interface AFDNSResolver ()
@property (nonatomic, strong) dispatch_queue_t resolverQueue;
@property (nonatomic, strong) NSMutableSet<NSString *> *pendingHosts;
@property (nonatomic, strong) NSLock *pendingLock;
@end

@implementation AFDNSResolver

+ (instancetype)sharedResolver {
    static AFDNSResolver *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AFDNSResolver alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _resolverQueue = dispatch_queue_create("com.afnetworking.dns.resolver", DISPATCH_QUEUE_CONCURRENT);
        _pendingHosts = [NSMutableSet set];
        _pendingLock = [[NSLock alloc] init];
        _timeout = 5.0;
    }
    return self;
}

- (void)resolveHost:(NSString *)host
         completion:(void(^)(NSArray<NSString *> *ipAddresses, NSError * _Nullable error))completion {
    if (!host || host.length == 0) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:AFDNSResolverErrorDomain
                                                 code:AFDNSResolverErrorUnknownHost
                                             userInfo:@{NSLocalizedDescriptionKey: @"Invalid host"}];
            completion(nil, error);
        }
        return;
    }
    
    AFDNSCacheEntry *cachedEntry = [[AFDNSCache sharedCache] entryForHost:host];
    if (cachedEntry) {
        if (completion) {
            completion(cachedEntry.ipAddresses, nil);
        }
        return;
    }
    
    [self.pendingLock lock];
    BOOL wasPending = [self.pendingHosts containsObject:host];
    if (!wasPending) {
        [self.pendingHosts addObject:host];
    }
    [self.pendingLock unlock];
    
    if (wasPending) {
        return;
    }
    
    dispatch_async(self.resolverQueue, ^{
        NSArray<NSString *> *ipAddresses = [self performDNSResolution:host];
        NSError *error = nil;
        
        [self.pendingLock lock];
        [self.pendingHosts removeObject:host];
        [self.pendingLock unlock];
        
        if (ipAddresses.count == 0) {
            error = [NSError errorWithDomain:AFDNSResolverErrorDomain
                                        code:AFDNSResolverErrorNoIPAddress
                                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"No IP addresses found for host: %@", host]}];
        } else {
            AFDNSCacheEntry *entry = [[AFDNSCacheEntry alloc] initWithHost:host
                                                               ipAddresses:ipAddresses
                                                                       ttl:[AFDNSCache sharedCache].defaultTTL];
            [[AFDNSCache sharedCache] cacheEntry:entry];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(ipAddresses, error);
            }
            
            if (ipAddresses.count > 0) {
                if ([self.delegate respondsToSelector:@selector(dnsResolver:didResolveHost:ipAddresses:)]) {
                    [self.delegate dnsResolver:self didResolveHost:host ipAddresses:ipAddresses];
                }
            } else {
                if ([self.delegate respondsToSelector:@selector(dnsResolver:didFailToResolveHost:error:)]) {
                    [self.delegate dnsResolver:self didFailToResolveHost:host error:error];
                }
            }
        });
    });
}

- (void)resolveHosts:(NSArray<NSString *> *)hosts
          completion:(void(^)(NSDictionary<NSString *, NSArray<NSString *> *> *results))completion {
    if (!hosts || hosts.count == 0) {
        if (completion) {
            completion(@{});
        }
        return;
    }
    
    NSMutableDictionary<NSString *, NSArray<NSString *> *> *results = [NSMutableDictionary dictionary];
    dispatch_group_t group = dispatch_group_create();
    
    for (NSString *host in hosts) {
        dispatch_group_enter(group);
        [self resolveHost:host completion:^(NSArray<NSString *> *ipAddresses, NSError * _Nullable error) {
            if (ipAddresses) {
                results[host] = ipAddresses;
            }
            dispatch_group_leave(group);
        }];
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (completion) {
            completion([results copy]);
        }
    });
}

- (void)cancelAllResolutions {
    [self.pendingLock lock];
    [self.pendingHosts removeAllObjects];
    [self.pendingLock unlock];
}

- (NSString *)ipAddressForHost:(NSString *)host {
    AFDNSCacheEntry *entry = [[AFDNSCache sharedCache] entryForHost:host];
    if (entry && entry.ipAddresses.count > 0) {
        return entry.ipAddresses.firstObject;
    }
    return nil;
}

- (NSArray<NSString *> *)performDNSResolution:(NSString *)host {
    NSMutableArray<NSString *> *ipAddresses = [NSMutableArray array];
    
    struct addrinfo hints, *res, *res0;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = PF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_DEFAULT;
    
    int error = getaddrinfo([host UTF8String], "https", &hints, &res0);
    
    if (error) {
        return ipAddresses;
    }
    
    for (res = res0; res; res = res->ai_next) {
        char ipstr[INET6_ADDRSTRLEN];
        void *addr;
        
        if (res->ai_family == AF_INET) {
            struct sockaddr_in *ipv4 = (struct sockaddr_in *)res->ai_addr;
            addr = &(ipv4->sin_addr);
        } else if (res->ai_family == AF_INET6) {
            struct sockaddr_in6 *ipv6 = (struct sockaddr_in6 *)res->ai_addr;
            addr = &(ipv6->sin6_addr);
        } else {
            continue;
        }
        
        inet_ntop(res->ai_family, addr, ipstr, sizeof(ipstr));
        NSString *ipString = [NSString stringWithUTF8String:ipstr];
        if (ipString) {
            [ipAddresses addObject:ipString];
        }
    }
    
    freeaddrinfo(res0);
    
    return [ipAddresses copy];
}

@end