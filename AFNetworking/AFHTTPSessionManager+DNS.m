#import "AFHTTPSessionManager+DNS.h"
#import "AFDNSCache.h"
#import <objc/runtime.h>

static void *kAFHTTPSessionManagerDNSResolutionEnabledKey = &kAFHTTPSessionManagerDNSResolutionEnabledKey;
static void *kAFHTTPSessionManagerDNSResolverKey = &kAFHTTPSessionManagerDNSResolverKey;

@implementation AFHTTPSessionManager (DNS)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        SEL originalSelector = @selector(dataTaskWithRequest:uploadProgress:downloadProgress:completionHandler:);
        SEL swizzledSelector = @selector(af_dns_dataTaskWithRequest:uploadProgress:downloadProgress:completionHandler:);
        
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        
        BOOL didAddMethod = class_addMethod(class,
                                            originalSelector,
                                            method_getImplementation(swizzledMethod),
                                            method_getTypeEncoding(swizzledMethod));
        
        if (didAddMethod) {
            class_replaceMethod(class,
                                swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

- (void)setDnsResolutionEnabled:(BOOL)dnsResolutionEnabled {
    objc_setAssociatedObject(self, &kAFHTTPSessionManagerDNSResolutionEnabledKey, @(dnsResolutionEnabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isDNSResolutionEnabled {
    NSNumber *value = objc_getAssociatedObject(self, &kAFHTTPSessionManagerDNSResolutionEnabledKey);
    if (value == nil) {
        return YES;
    }
    return [value boolValue];
}

- (void)setDnsResolver:(AFDNSResolver *)dnsResolver {
    objc_setAssociatedObject(self, &kAFHTTPSessionManagerDNSResolverKey, dnsResolver, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (AFDNSResolver *)dnsResolver {
    AFDNSResolver *resolver = objc_getAssociatedObject(self, &kAFHTTPSessionManagerDNSResolverKey);
    if (!resolver) {
        resolver = [AFDNSResolver sharedResolver];
    }
    return resolver;
}

- (NSURLSessionDataTask *)af_dns_dataTaskWithRequest:(NSURLRequest *)request
                                      uploadProgress:(nullable void (^)(NSProgress *uploadProgress))uploadProgressBlock
                                    downloadProgress:(nullable void (^)(NSProgress *downloadProgress))downloadProgressBlock
                                   completionHandler:(nullable void (^)(NSURLResponse *response, id _Nullable responseObject,  NSError * _Nullable error))completionHandler {
    if (!self.isDNSResolutionEnabled) {
        return [self af_dns_dataTaskWithRequest:request uploadProgress:uploadProgressBlock downloadProgress:downloadProgressBlock completionHandler:completionHandler];
    }
    
    NSURL *originalURL = request.URL;
    NSString *host = originalURL.host;
    if (!host) {
        return [self af_dns_dataTaskWithRequest:request uploadProgress:uploadProgressBlock downloadProgress:downloadProgressBlock completionHandler:completionHandler];
    }
    
    NSArray<NSString *> *cachedIPs = [[AFDNSCache sharedCache] ipAddressesForDomain:host];
    if (cachedIPs.count > 0) {
        NSMutableURLRequest *modifiedRequest = [request mutableCopy];
        modifiedRequest.URL = [self replaceHostInURL:originalURL withIP:cachedIPs.firstObject];
        [modifiedRequest setValue:host forHTTPHeaderField:@"Host"];
        return [self af_dns_dataTaskWithRequest:modifiedRequest uploadProgress:uploadProgressBlock downloadProgress:downloadProgressBlock completionHandler:completionHandler];
    }
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSArray<NSString *> *resultIPs = nil;
    
    [self.dnsResolver resolveDomain:host completion:^(NSArray<NSString *> * _Nullable ipAddresses, NSError * _Nullable error) {
        resultIPs = ipAddresses;
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)));
    
    if (resultIPs.count > 0) {
        [[AFDNSCache sharedCache] setIPAddresses:resultIPs forDomain:host];
        NSMutableURLRequest *modifiedRequest = [request mutableCopy];
        modifiedRequest.URL = [self replaceHostInURL:originalURL withIP:resultIPs.firstObject];
        [modifiedRequest setValue:host forHTTPHeaderField:@"Host"];
        return [self af_dns_dataTaskWithRequest:modifiedRequest uploadProgress:uploadProgressBlock downloadProgress:downloadProgressBlock completionHandler:completionHandler];
    }
    
    return [self af_dns_dataTaskWithRequest:request uploadProgress:uploadProgressBlock downloadProgress:downloadProgressBlock completionHandler:completionHandler];
}

- (NSURL *)replaceHostInURL:(NSURL *)url withIP:(NSString *)ip {
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    components.host = ip;
    return [components URL];
}

@end
