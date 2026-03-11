// AFDNSResolver.m
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

#import "AFDNSResolver.h"
#import <arpa/inet.h>
#import <netdb.h>
#import <netinet/in.h>
#import <sys/socket.h>

NSString * const AFDNSResolverErrorDomain = @"com.afnetworking.dns.resolver.error";

#pragma mark - AFDNSRecord

@implementation AFDNSRecord

- (instancetype)initWithDomain:(NSString *)domain
                   ipAddresses:(NSArray<NSString *> *)ipAddresses
                           TTL:(NSTimeInterval)TTL {
    self = [super init];
    if (self) {
        _domain = [domain copy];
        _ipAddresses = [ipAddresses copy];
        _TTL = TTL;
        _createTime = [NSDate date];
    }
    return self;
}

- (BOOL)isExpired {
    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:self.createTime];
    return elapsed >= self.TTL;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.domain forKey:@"domain"];
    [coder encodeObject:self.ipAddresses forKey:@"ipAddresses"];
    [coder encodeDouble:self.TTL forKey:@"TTL"];
    [coder encodeObject:self.createTime forKey:@"createTime"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    NSString *domain = [coder decodeObjectOfClass:[NSString class] forKey:@"domain"];
    NSArray *ipAddresses = [coder decodeObjectOfClass:[NSArray class] forKey:@"ipAddresses"];
    NSTimeInterval TTL = [coder decodeDoubleForKey:@"TTL"];
    
    self = [self initWithDomain:domain ipAddresses:ipAddresses TTL:TTL];
    if (self) {
        _createTime = [coder decodeObjectOfClass:[NSDate class] forKey:@"createTime"];
    }
    return self;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    AFDNSRecord *copy = [[AFDNSRecord alloc] initWithDomain:self.domain
                                                ipAddresses:self.ipAddresses
                                                        TTL:self.TTL];
    return copy;
}

@end

#pragma mark - AFDNSResolverConfiguration

@implementation AFDNSResolverConfiguration

- (instancetype)init {
    self = [super init];
    if (self) {
        _timeoutInterval = 5.0;
        _enableIPv6 = YES;
        _preferIPv6 = NO;
        _retryCount = 2;
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
    [coder encodeObject:self.customDNSServers forKey:@"customDNSServers"];
    [coder encodeDouble:self.timeoutInterval forKey:@"timeoutInterval"];
    [coder encodeBool:self.enableIPv6 forKey:@"enableIPv6"];
    [coder encodeBool:self.preferIPv6 forKey:@"preferIPv6"];
    [coder encodeInteger:self.retryCount forKey:@"retryCount"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _customDNSServers = [coder decodeObjectOfClass:[NSArray class] forKey:@"customDNSServers"];
        _timeoutInterval = [coder decodeDoubleForKey:@"timeoutInterval"];
        if (_timeoutInterval == 0) _timeoutInterval = 5.0;
        _enableIPv6 = [coder decodeBoolForKey:@"enableIPv6"];
        _preferIPv6 = [coder decodeBoolForKey:@"preferIPv6"];
        _retryCount = [coder decodeIntegerForKey:@"retryCount"];
        if (_retryCount == 0) _retryCount = 2;
    }
    return self;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    AFDNSResolverConfiguration *copy = [[AFDNSResolverConfiguration alloc] init];
    copy.customDNSServers = [self.customDNSServers copy];
    copy.timeoutInterval = self.timeoutInterval;
    copy.enableIPv6 = self.enableIPv6;
    copy.preferIPv6 = self.preferIPv6;
    copy.retryCount = self.retryCount;
    return copy;
}

@end

#pragma mark - AFDNSResolver

@interface AFDNSResolver ()

@property (nonatomic, strong) NSOperationQueue *resolutionQueue;
@property (nonatomic, strong) NSMutableSet<NSString *> *resolvingDomains;
@property (nonatomic, strong) dispatch_queue_t syncQueue;

@end

@implementation AFDNSResolver

+ (instancetype)sharedResolver {
    static AFDNSResolver *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] initWithConfiguration:[AFDNSResolverConfiguration defaultConfiguration]];
    });
    return sharedInstance;
}

- (instancetype)initWithConfiguration:(AFDNSResolverConfiguration *)configuration {
    self = [super init];
    if (self) {
        _configuration = [configuration copy];
        _resolutionQueue = [[NSOperationQueue alloc] init];
        _resolutionQueue.name = @"com.afnetworking.dns.resolver.queue";
        _resolutionQueue.maxConcurrentOperationCount = 5;
        _resolvingDomains = [NSMutableSet set];
        _syncQueue = dispatch_queue_create("com.afnetworking.dns.resolver.sync", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark - Public Methods

- (void)resolveDomain:(NSString *)domain
           completion:(AFDNSResolutionCompletionBlock)completionBlock {
    if (!domain || domain.length == 0) {
        NSError *error = [self errorWithCode:AFDNSResolverErrorInvalidDomain
                                     message:@"Domain cannot be empty"];
        if (completionBlock) {
            completionBlock(nil, error);
        }
        return;
    }
    
    NSString *normalizedDomain = [self normalizedDomain:domain];
    
    dispatch_async(self.syncQueue, ^{
        if ([self.resolvingDomains containsObject:normalizedDomain]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completionBlock) {
                    NSError *error = [self errorWithCode:AFDNSResolverErrorUnknown
                                                 message:@"Domain is already being resolved"];
                    completionBlock(nil, error);
                }
            });
            return;
        }
        
        [self.resolvingDomains addObject:normalizedDomain];
    });
    
    [self.resolutionQueue addOperationWithBlock:^{
        AFDNSRecord *record = [self performDNSResolution:normalizedDomain];
        
        dispatch_async(self.syncQueue, ^{
            [self.resolvingDomains removeObject:normalizedDomain];
        });
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionBlock) {
                if (record && record.ipAddresses.count > 0) {
                    completionBlock(record, nil);
                } else {
                    NSError *error = [self errorWithCode:AFDNSResolverErrorNoIPAddressFound
                                                 message:@"No IP address found for domain"];
                    completionBlock(nil, error);
                }
            }
        });
    }];
}

- (nullable AFDNSRecord *)resolveDomainSynchronously:(NSString *)domain
                                               error:(NSError **)error {
    if (!domain || domain.length == 0) {
        if (error) {
            *error = [self errorWithCode:AFDNSResolverErrorInvalidDomain
                                 message:@"Domain cannot be empty"];
        }
        return nil;
    }
    
    NSString *normalizedDomain = [self normalizedDomain:domain];
    AFDNSRecord *record = [self performDNSResolution:normalizedDomain];
    
    if (!record || record.ipAddresses.count == 0) {
        if (error) {
            *error = [self errorWithCode:AFDNSResolverErrorNoIPAddressFound
                                 message:@"No IP address found for domain"];
        }
        return nil;
    }
    
    return record;
}

- (void)preResolveDomains:(NSArray<NSString *> *)domains
               completion:(nullable void (^)(NSDictionary<NSString *, AFDNSRecord *> *results))completionBlock {
    if (!domains || domains.count == 0) {
        if (completionBlock) {
            completionBlock(@{});
        }
        return;
    }
    
    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    dispatch_group_t group = dispatch_group_create();
    
    for (NSString *domain in domains) {
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

- (void)cancelAllResolutions {
    [self.resolutionQueue cancelAllOperations];
    dispatch_async(self.syncQueue, ^{
        [self.resolvingDomains removeAllObjects];
    });
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

- (nullable AFDNSRecord *)performDNSResolution:(NSString *)domain {
    NSMutableArray<NSString *> *ipAddresses = [NSMutableArray array];
    
    struct addrinfo hints;
    struct addrinfo *result = NULL;
    
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    
    const char *hostname = [domain UTF8String];
    int status = getaddrinfo(hostname, NULL, &hints, &result);
    
    if (status != 0) {
        return nil;
    }
    
    NSMutableArray<NSString *> *ipv4Addresses = [NSMutableArray array];
    NSMutableArray<NSString *> *ipv6Addresses = [NSMutableArray array];
    
    for (struct addrinfo *res = result; res != NULL; res = res->ai_next) {
        void *addr;
        char ipString[INET6_ADDRSTRLEN];
        
        if (res->ai_family == AF_INET) {
            struct sockaddr_in *ipv4 = (struct sockaddr_in *)res->ai_addr;
            addr = &(ipv4->sin_addr);
            inet_ntop(AF_INET, addr, ipString, sizeof(ipString));
            [ipv4Addresses addObject:@(ipString)];
        } else if (res->ai_family == AF_INET6 && self.configuration.enableIPv6) {
            struct sockaddr_in6 *ipv6 = (struct sockaddr_in6 *)res->ai_addr;
            addr = &(ipv6->sin6_addr);
            inet_ntop(AF_INET6, addr, ipString, sizeof(ipString));
            [ipv6Addresses addObject:@(ipString)];
        }
    }
    
    freeaddrinfo(result);
    
    if (self.configuration.preferIPv6) {
        [ipAddresses addObjectsFromArray:ipv6Addresses];
        [ipAddresses addObjectsFromArray:ipv4Addresses];
    } else {
        [ipAddresses addObjectsFromArray:ipv4Addresses];
        [ipAddresses addObjectsFromArray:ipv6Addresses];
    }
    
    if (ipAddresses.count == 0) {
        return nil;
    }
    
    NSTimeInterval defaultTTL = 300;
    AFDNSRecord *record = [[AFDNSRecord alloc] initWithDomain:domain
                                                  ipAddresses:[ipAddresses copy]
                                                          TTL:defaultTTL];
    return record;
}

- (NSError *)errorWithCode:(AFDNSResolverErrorCode)code message:(NSString *)message {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey: message};
    return [NSError errorWithDomain:AFDNSResolverErrorDomain code:code userInfo:userInfo];
}

@end
