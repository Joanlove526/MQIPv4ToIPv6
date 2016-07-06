//
//  MQIPv4ToIPv6.m
//  IPv4ToIPv6
//
//  Created by li on 16/7/6.
//  Copyright © 2016年 li. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MQIPv4ToIPv6.h"

#import <ifaddrs.h>
#import <arpa/inet.h>
#import <sys/socket.h>
#import <sys/sockio.h>
#import <sys/ioctl.h>
#import <net/if.h>

@interface MQIPv4ToIPv6 ()

@property (nonatomic, strong) NSCache * cache;
@property (nonatomic, assign) BOOL isIPv6Environment;
@end
@implementation MQIPv4ToIPv6

+ (MQIPv4ToIPv6 *)sharedInstance {
    
    static MQIPv4ToIPv6 * ip = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ip = [[MQIPv4ToIPv6 alloc] init];
    });
    return ip;
}

- (id)init {
    self = [super init];
    if (self) {
        self.cache = [[NSCache alloc] init];
        self.isIPv6Environment = [MQIPv4ToIPv6 isIPv6Environment];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noti:) name:UIApplicationWillEnterForegroundNotification object:nil];
    }
    return self;
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.cache removeAllObjects];
}

- (void)noti:(NSNotification *)noti {
    if ([noti.name isEqualToString:UIApplicationWillEnterForegroundNotification]) {
        self.isIPv6Environment = [MQIPv4ToIPv6 isIPv6Environment];
    }
}

- (NSString *)convertHttpURL:(NSString *)convertHttpURL {
    
    if (!convertHttpURL) return nil;
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 9.0 || !self.isIPv6Environment) {
        return convertHttpURL;
    }
    NSArray * arr = [convertHttpURL componentsSeparatedByString:@"//"];
    arr = [[arr lastObject] componentsSeparatedByString:@"/"];
    
    NSString * host = [[[arr firstObject] componentsSeparatedByString:@":"] firstObject];
    
    NSString * newIpAddresses = [self.cache objectForKey:host];
    if (!newIpAddresses) {
        newIpAddresses = [self convertIpAddresses:host];
    }
    if (newIpAddresses) {
        [self.cache setObject:newIpAddresses forKey:host];
        return [convertHttpURL stringByReplacingOccurrencesOfString:host withString:[NSString stringWithFormat:@"[%@]", newIpAddresses]];
    }
    return convertHttpURL;
}

- (NSString *)convertIpAddresses:(NSString *)ipAddresses {
    if (!ipAddresses) return nil;
    if (!self.isIPv6Environment) return ipAddresses;
    
    NSString * newIpAddresses = [self.cache objectForKey:ipAddresses];
    if (newIpAddresses) {
        return newIpAddresses;
    }
    BOOL isIp = [MQIPv4ToIPv6 isIpAddresses:ipAddresses];
    if (isIp) {
        NSArray * arr = [ipAddresses componentsSeparatedByString:@"."];
        newIpAddresses = [NSString stringWithFormat:@"64:FF9B::%02X%02X:%02X%02X", [arr[0] intValue], [arr[1] intValue], [arr[2] intValue], [arr[3] intValue]];
        
        [self.cache setObject:newIpAddresses forKey:ipAddresses];
        return newIpAddresses;
    }
    return ipAddresses;
}

// MARK:  ---------------------------------------------------
/**
 *  刷新网络环境 在网络改变的时候应该调用此方法
 */
+ (void)refreshNetworkEnvironment {
    [self sharedInstance].isIPv6Environment = [self isIPv6Environment];
}
/**
 *  转换HTTP链接 如果HTTP链接是用域名的或者是iOS9以上的系统都不需要转了
 *
 *  @param convertHttpURL 待转换HTTP链接
 *
 *  @return
 */
+ (NSString *)convertHttpURL:(NSString *)convertHttpURL {
    return [[self sharedInstance] convertHttpURL:convertHttpURL];
}
/**
 *  把IPv4 IP地址转换为 IPv6地址 使用NAT64转换
 *
 *  @param ipAddresses 待转换IP
 *
 *  @return
 */
+ (NSString *)convertIpAddresses:(NSString *)ipAddresses {
    return [[self sharedInstance] convertIpAddresses:ipAddresses];
}

/**
 *  判断是否是IP地址
 *
 *  @param ipAddresses ip地址
 *
 *  @return
 */
+ (BOOL)isIpAddresses:(NSString *)ipAddresses {
    if (!ipAddresses) return NO;
    int pointNum = 0;
    const char * c_ip = [ipAddresses UTF8String];
    for (int i = 0; i < ipAddresses.length; i++) {
        if (c_ip[i] == '.') {
            pointNum++;
            continue;
        }
        
        if (c_ip[i] < 48 || c_ip[i] > 57) {
            return NO;
        }
    }
    return pointNum == 3;
}

/**
 *  判断是否处于IPv6网络环境
 *  判断方法是根据当前IP的开头是不是169.254 所以在某种情况下是不准确
 *
 *  @return
 */
+ (BOOL)isIPv6Environment {
    return [[self getDeviceIpAddresses] hasPrefix:@"169.254"];
}

/**
 *  获取本机IP地址
 *  如果处于IPv6网络 返回的IP都是169.254 开头 如果没有网络则返回127.0.0.1
 *
 *  @return
 */
+ (NSString *)getDeviceIpAddresses {
    
    int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    
    NSMutableArray *ips = [NSMutableArray array];
    
    int bufferSize = 4096;
    struct  ifconf ifc;
    
    char buffer[bufferSize], *ptr, lastname[IFNAMSIZ], *cptr;
    struct ifreq *ifr, ifrcopy;
    
    ifc.ifc_len = bufferSize;
    ifc.ifc_buf = buffer;
    
    if (ioctl(sockfd, SIOCGIFCONF, &ifc) >= 0) {
        
        for (ptr = buffer; ptr < buffer + ifc.ifc_len; ) {
            
            ifr = (struct ifreq *)ptr;
            
            int len = sizeof(struct sockaddr);
            if (ifr->ifr_addr.sa_len > len) {
                len = ifr->ifr_addr.sa_len;
            }
            
            ptr += sizeof(ifr->ifr_name) + len;
            if (ifr->ifr_addr.sa_family != AF_INET)
                continue;
            
            if ((cptr = (char *)strchr(ifr->ifr_name, ':')) != NULL)
                *cptr = 0;
            
            if (strncmp(lastname, ifr->ifr_name, IFNAMSIZ) == 0)
                continue;
            
            memcpy(lastname, ifr->ifr_name, IFNAMSIZ);
            ifrcopy = *ifr;
            
            ioctl(sockfd, SIOCGIFFLAGS, &ifrcopy);
            if ((ifrcopy.ifr_flags & IFF_UP) == 0)
                continue;
            
            NSString *ip = [NSString stringWithFormat:@"%s", inet_ntoa(((struct sockaddr_in *)&ifr->ifr_addr)->sin_addr)];
            [ips addObject:ip];
        }
    }
    close(sockfd);
    
    NSString *deviceIP = [ips lastObject];
    NSLog(@"deviceIP========%@",deviceIP);
    return deviceIP;
}

@end
