//
//  ViewController.m
//  简单信息采集-DEMO
//
//  Created by Yin Yi on 16/2/20.
//  Copyright © 2016年 yinyi. All rights reserved.
//

#import "ViewController.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>
#import <netdb.h>
#import <sys/socket.h>
#import <CoreLocation/CoreLocation.h>

typedef NS_ENUM(NSUInteger, NetworkStatus) {
    NotNetworkConnect = 0,   // 无连接
    NetworkStatus3G,  // 3G/GPRS
    NetworkStatusWifi   // WIFI
};

#pragma mark - Supporting functions

#define kShouldPrintReachabilityFlags 1

static void PrintReachabilityFlags(SCNetworkReachabilityFlags flags, const char* comment)
{
#if kShouldPrintReachabilityFlags
    NSLog(@"Reachability Flag Status: %c%c %c%c%c%c%c%c%c %s\n",
          (flags & kSCNetworkReachabilityFlagsIsWWAN)				? 'W' : '-',
          (flags & kSCNetworkReachabilityFlagsReachable)            ? 'R' : '-',
          
          (flags & kSCNetworkReachabilityFlagsTransientConnection)  ? 't' : '-',
          (flags & kSCNetworkReachabilityFlagsConnectionRequired)   ? 'c' : '-',
          (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic)  ? 'C' : '-',
          (flags & kSCNetworkReachabilityFlagsInterventionRequired) ? 'i' : '-',
          (flags & kSCNetworkReachabilityFlagsConnectionOnDemand)   ? 'D' : '-',
          (flags & kSCNetworkReachabilityFlagsIsLocalAddress)       ? 'l' : '-',
          (flags & kSCNetworkReachabilityFlagsIsDirect)             ? 'd' : '-',
          comment
          );
#endif
}


@interface ViewController ()<CLLocationManagerDelegate>
// 设备信息
@property (weak, nonatomic) IBOutlet UILabel *udidLabel;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *typeLabel;
@property (weak, nonatomic) IBOutlet UILabel *systemInfoLabel;
@property (weak, nonatomic) IBOutlet UILabel *deviceStateLabel;
@property (weak, nonatomic) IBOutlet UILabel *batteryStateLabel;
// 地理信息
@property (weak, nonatomic) IBOutlet UILabel *geographicInfoLabel;

// 指纹验证信息
@property (weak, nonatomic) IBOutlet UILabel *touchIDInfoLabel;
// 网络信息
@property (weak, nonatomic) IBOutlet UILabel *networkInfoLabel;

@property (strong, nonatomic) UIAlertController *ac;
@end

@implementation ViewController
{
    BOOL _alwaysReturnLocalWiFiStatus; //default is NO
    SCNetworkReachabilityRef _reachabilityRef;
    CLLocationManager *_locationManager;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    // 初始化地理信息获取功能，并请求权限
    _locationManager = [[CLLocationManager alloc] init];
    [_locationManager requestWhenInUseAuthorization];
    _locationManager.delegate = self;
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    _locationManager.distanceFilter = kCLDistanceFilterNone;
}
#pragma mark - 按钮点击事件
/**
 *  获取设备信息按钮点击
 */
- (IBAction)deviceInformationButtonClick:(UIButton *)sender {
    [self deviceInformation];
}
/**
 *  获取地理信息按钮点击
 */
- (IBAction)geographicInformationButtonClick:(UIButton *)sender {
    [self geographicInformation];
}
/**
 *  获取用户指纹信息按钮点击
 */
- (IBAction)touchIDButtonClick:(UIButton *)sender {
    [self touchIDInformation];
}
/**
 *  获取用户网络信息按钮点击
 */
- (IBAction)netWorkingButtonClick:(UIButton *)sender {
    [self netWorkStates];
}

#pragma mark - 设备信息采集方法
/**
 *  设备信息
 */
- (void)deviceInformation {
    // 获取当前设备-单例
    UIDevice *currentDevice = [UIDevice currentDevice];
    
    // 设备名称
    NSString *name = currentDevice.name;
    self.nameLabel.text = name;
    
    // 设备类型  iPhone/iTouch/iPad
    NSString *model = currentDevice.model;
    self.typeLabel.text = model;
    
    // 本地模型版本
//    NSString *localizedModel = currentDevice.localizedModel;
    
    // 系统名称  iOS/OS/watch OS
    NSString *versionName = currentDevice.systemName;
    
    // 系统版本号
    NSString *version = currentDevice.systemVersion;
    NSString *systemInfo = [versionName stringByAppendingString:version];
    self.systemInfoLabel.text = systemInfo;
    
    // 设备当前状态   横屏/竖屏/背对/正对/倒立
    UIDeviceOrientation orientation = currentDevice.orientation;
    switch (orientation) {
        case UIDeviceOrientationUnknown:
            self.deviceStateLabel.text = @"未知状态";
            break;
        case UIDeviceOrientationPortrait:
            self.deviceStateLabel.text = @"垂直正立";
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            self.deviceStateLabel.text = @"垂直反立";
            break;
        case UIDeviceOrientationLandscapeLeft:
            self.deviceStateLabel.text = @"设备左旋";
            break;
        case UIDeviceOrientationLandscapeRight:
            self.deviceStateLabel.text = @"设备右旋";
            break;
        case UIDeviceOrientationFaceUp:
            self.deviceStateLabel.text = @"平放home键朝上";
            break;
        case UIDeviceOrientationFaceDown:
            self.deviceStateLabel.text = @"平放home键朝下";
            break;
        default:
            self.deviceStateLabel.text = @"获取失败";
            break;
    }
    
    // UDID 设备唯一标示  *越狱后，有可能更改这类信息,但是一般修改后都会被封号
    NSString *UDID = currentDevice.identifierForVendor.UUIDString;
    self.udidLabel.text = UDID;
    
    // 设备电池状态   正在充电/非正在充电/满电量
    currentDevice.batteryMonitoringEnabled = YES;
    UIDeviceBatteryState stae = currentDevice.batteryState;
    CGFloat batterLevel = currentDevice.batteryLevel;
    switch (stae) {
        case UIDeviceBatteryStateUnknown:
            self.batteryStateLabel.text = @"未知状态";
            break;
        case UIDeviceBatteryStateUnplugged:{
                NSString *batterStateStr = [NSString stringWithFormat:@"未充电  电量：%.f%%",batterLevel * 100];
                self.batteryStateLabel.text = batterStateStr;
            }
            break;
        case UIDeviceBatteryStateCharging:{
            NSString *batterStateStr = [NSString stringWithFormat:@"正在充电  电量：%.f%%",batterLevel * 100];
                self.batteryStateLabel.text = batterStateStr;
            }
            break;
        case UIDeviceBatteryStateFull:
            self.batteryStateLabel.text = @"满电";
            break;
        default:
            self.batteryStateLabel.text = @"获取失败";
            break;
    }
}

/**
 *  地理信息
 */
- (void)geographicInformation {
    [_locationManager startUpdatingLocation];
    
    self.ac = [[UIAlertController alloc] init];
    self.ac.message = @"正在获取";
    [self presentViewController:self.ac animated:YES completion:nil];
}

/**
 *  用户指纹信息
 */
- (void)touchIDInformation {
    LAContext *context = [[LAContext alloc] init];
    // 判断设备是否支持指纹识别
    if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:NULL]) {
        // 输入指纹，异步
        // 提示：指纹识别只是判断当前用户是否是手机的主人！程序原本的逻辑不会受到任何的干扰！
        [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:@"指纹验证测试" reply:^(BOOL success, NSError *error) {
            NSLog(@"%d %@", success, error);
            
            if (success) {
                // 验证成功
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    self.touchIDInfoLabel.text = @"指纹验证成功";
                }];
            }else {
                switch (error.code) {
                    case LAErrorSystemCancel:
                    {
                        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                            self.touchIDInfoLabel.text = @"切换到其他APP，系统取消验证Touch ID";
                        }];
                        break;
                    }
                    case LAErrorUserCancel:
                    {
                        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                            self.touchIDInfoLabel.text = @"用户取消验证Touch ID";
                        }];
                        break;
                    }
                    case LAErrorUserFallback:
                    {
                        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                            self.touchIDInfoLabel.text = @"用户选择其他验证方式，切换主线程处理";
                        }];
                        break;
                    }
                    default:
                    {
                        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                            self.touchIDInfoLabel.text = @"重复使用次数超出限制";
                        }];
                        break;
                    }
                }
            }
        }];
        
        NSLog(@"come here");
    } else {
        NSLog(@"不支持");
        self.touchIDInfoLabel.text = @"不支持指纹";
    }
}

/**
 *  用户网络信息
 */
- (void)netWorkStates {
    NSString *ipAddress = [self getIPAddress];
    NetworkStatus status = [self currentReachabilityStatus];
    switch (status) {
        case NotNetworkConnect:
            self.networkInfoLabel.text = [ipAddress stringByAppendingString:@"无网络连接"];
            break;
        case NetworkStatus3G:
            self.networkInfoLabel.text = [ipAddress stringByAppendingString:@"3G/GPRS网络连接"];
            break;
        case NetworkStatusWifi:
            self.networkInfoLabel.text = [ipAddress stringByAppendingString:@"Wifi网络连接"];
            break;
        default:
            break;
    }
}

#pragma 获取IP地址
- (NSString *)getIPAddress {
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                } else if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"pdp_ip0"]) {
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return address;
}
#pragma mark - 获取网络状态

- (NetworkStatus)currentReachabilityStatus
{
    NSString *hostName = @"www.baidu.com";
    _reachabilityRef = SCNetworkReachabilityCreateWithName(NULL, [hostName UTF8String]);
    _alwaysReturnLocalWiFiStatus = NO;
    NSAssert(_reachabilityRef != NULL, @"currentNetworkStatus called with NULL SCNetworkReachabilityRef");
    NetworkStatus returnValue = NotNetworkConnect;
    SCNetworkReachabilityFlags flags;
    
    if (SCNetworkReachabilityGetFlags(_reachabilityRef, &flags))
    {
        if (_alwaysReturnLocalWiFiStatus)
        {
            returnValue = [self localWiFiStatusForFlags:flags];
        }
        else
        {
            returnValue = [self networkStatusForFlags:flags];
        }
    }
    
    return returnValue;
}


- (NetworkStatus)networkStatusForFlags:(SCNetworkReachabilityFlags)flags
{
    PrintReachabilityFlags(flags, "networkStatusForFlags");
    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0)
    {
        return NotNetworkConnect;
    }
    
    NetworkStatus returnValue = NotNetworkConnect;
    
    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0)
    {
        returnValue = NetworkStatusWifi;
    }
    
    if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
         (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0))
    {
        
        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0)
        {
            returnValue = NetworkStatusWifi;
        }
    }
    
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
    {
        returnValue = NetworkStatus3G;
    }
    
    return returnValue;
}

- (NetworkStatus)localWiFiStatusForFlags:(SCNetworkReachabilityFlags)flags
{
    PrintReachabilityFlags(flags, "localWiFiStatusForFlags");
    NetworkStatus returnValue = NotNetworkConnect;
    
    if ((flags & kSCNetworkReachabilityFlagsReachable) && (flags & kSCNetworkReachabilityFlagsIsDirect))
    {
        returnValue = NetworkStatus3G;
    }
    
    return returnValue;
}

#pragma mark - CLLocationManagerDelegate
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(nonnull NSArray<CLLocation *> *)locations {
    CLLocation *location = [locations lastObject];
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        [self.ac dismissViewControllerAnimated:YES completion:nil];
        if (!error) {
            CLPlacemark *placemark = [placemarks lastObject];
            NSDictionary *placemarkDic = placemark.addressDictionary;
            self.geographicInfoLabel.text = [placemark.locality stringByAppendingString:placemarkDic[@"Name"]];
            [manager stopUpdatingLocation];
        } else {
            self.geographicInfoLabel.text = @"获取失败";
        }
    }];
    
}
#pragma mark - 内存警告
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - 对象销毁
- (void)dealloc {
    if (_reachabilityRef != NULL)
    {
        CFRelease(_reachabilityRef);
    }
}

@end
