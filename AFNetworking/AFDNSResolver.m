#import "AFDNSResolver.h"
#import <arpa/inet.h>
#import <netdb.h>
#import <sys/socket.h>

@interface AFDNSResolver ()

@property (nonatomic, strong) dispatch_queue_t resolverQueue;

@end

@implementation AFDNSResolver

+ (instancetype)sharedResolver {
    static AFDNSResolver *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _resolverQueue = dispatch_queue_create("com.alamofire.networking.dns.resolver", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (void)resolveDomain:(NSString *)domain completion:(AFDNSResolverCompletionBlock)completion {
    if (!domain || domain.length == 0) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"com.alamofire.networking.dns" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Domain cannot be empty"}];
            completion(nil, error);
        }
        return;
    }
    
    dispatch_async(self.resolverQueue, ^{
        struct addrinfo hints, *res, *p;
        memset(&hints, 0, sizeof hints);
        hints.ai_family = AF_UNSPEC;
        hints.ai_socktype = SOCK_STREAM;
        
        int status = getaddrinfo([domain UTF8String], NULL, &hints, &res);
        if (status != 0) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *errorMsg = [NSString stringWithUTF8String:gai_strerror(status)] ?: @"DNS resolution failed";
                    NSError *error = [NSError errorWithDomain:@"com.alamofire.networking.dns" code:status userInfo:@{NSLocalizedDescriptionKey: errorMsg}];
                    completion(nil, error);
                });
            }
            return;
        }
        
        NSMutableArray<NSString *> *ipAddresses = [NSMutableArray array];
        char ipStr[INET6_ADDRSTRLEN];
        
        for (p = res; p != NULL; p = p->ai_next) {
            void *addr;
            if (p->ai_family == AF_INET) {
                struct sockaddr_in *ipv4 = (struct sockaddr_in *)p->ai_addr;
                addr = &(ipv4->sin_addr);
            } else {
                struct sockaddr_in6 *ipv6 = (struct sockaddr_in6 *)p->ai_addr;
                addr = &(ipv6->sin6_addr);
            }
            
            if (inet_ntop(p->ai_family, addr, ipStr, sizeof ipStr)) {
                NSString *ip = [NSString stringWithUTF8String:ipStr];
                if (ip) {
                    [ipAddresses addObject:ip];
                }
            }
        }
        
        freeaddrinfo(res);
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (ipAddresses.count > 0) {
                    completion([ipAddresses copy], nil);
                } else {
                    NSError *error = [NSError errorWithDomain:@"com.alamofire.networking.dns" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"No IP addresses found"}];
                    completion(nil, error);
                }
            });
        }
    });
}

- (void)preResolveDomains:(NSArray<NSString *> *)domains {
    for (NSString *domain in domains) {
        [self resolveDomain:domain completion:nil];
    }
}

@end
