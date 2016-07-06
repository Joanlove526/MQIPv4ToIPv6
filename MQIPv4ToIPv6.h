//
//  MQIPv4ToIPv6.h
//  IPv4ToIPv6
//
//  Created by li on 16/7/6.
//  Copyright © 2016年 li. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MQIPv4ToIPv6 : NSObject

/**
 *  刷新网络环境 在网络改变的时候应该调用此方法
 */
+ (void)refreshNetworkEnvironment;

/**
 *  转换HTTP链接 如果HTTP链接是用域名的或者是iOS9以上的系统都不需要转了
 *
 *  @param convertHttpURL 待转换HTTP链接
 *
 *  @return
 */
+ (NSString *)convertHttpURL:(NSString *)convertHttpURL;

/**
 *  把IPv4 IP地址转换为 IPv6地址 使用NAT64转换
 *
 *  @param ipAddresses 待转换IP
 *
 *  @return
 */
+ (NSString *)convertIpAddresses:(NSString *)ipAddresses;

/**
 *  判断是否处于IPv6网络环境
 *  判断方法是根据当前IP的开头是不是169.254 所以在某种情况下是不准确
 *
 *  @return
 */
+ (BOOL)isIPv6Environment;

/**
 *  获取本机IP地址
 *  如果处于IPv6网络 返回的IP都是169.254开头 如果没有网络则返回127.0.0.1
 *
 *  @return
 */
+ (NSString *)getDeviceIpAddresses;
@end
