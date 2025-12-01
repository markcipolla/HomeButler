#import "HBBatteryReporter.h"
#import "HAAPIClient.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>

@interface HBBatteryReporter ()

@property (nonatomic, strong) NSTimer *reportTimer;
@property (nonatomic, strong) NSURLSession *session;

@end

@implementation HBBatteryReporter

+ (instancetype)sharedReporter {
    static HBBatteryReporter *sharedReporter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedReporter = [[self alloc] init];
    });
    return sharedReporter;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 10.0;
        _session = [NSURLSession sessionWithConfiguration:config];

        // Enable battery monitoring
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    }
    return self;
}

- (void)startReporting {
    [self stopReporting];

    // Report immediately
    [self reportNow];

    // Then report every 60 seconds
    self.reportTimer = [NSTimer scheduledTimerWithTimeInterval:60.0
                                                        target:self
                                                      selector:@selector(reportNow)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)stopReporting {
    [self.reportTimer invalidate];
    self.reportTimer = nil;
}

- (void)reportNow {
    HAAPIClient *client = [HAAPIClient sharedClient];
    if (!client.batteryReportingEnabled || !client.baseURL || client.baseURL.length == 0) {
        return;
    }

    // Build webhook URL from base URL
    NSString *webhookURL = [NSString stringWithFormat:@"%@/api/webhook/homebutler_battery", client.baseURL];

    UIDevice *device = [UIDevice currentDevice];

    // Ensure battery monitoring is enabled (must be on main thread for some devices)
    if (!device.batteryMonitoringEnabled) {
        device.batteryMonitoringEnabled = YES;
    }

    // Battery level: 0.0 to 1.0, or -1.0 if unknown
    float batteryLevel = device.batteryLevel;
    UIDeviceBatteryState state = device.batteryState;

    // If battery is full, report 100% even if batteryLevel returns -1
    NSInteger batteryPercent;
    if (state == UIDeviceBatteryStateFull) {
        batteryPercent = 100;
    } else if (batteryLevel >= 0) {
        batteryPercent = (NSInteger)(batteryLevel * 100);
    } else {
        batteryPercent = -1;
    }

    NSLog(@"[BatteryReporter] Raw battery level: %.2f, state: %ld, calculated percent: %ld",
          batteryLevel, (long)state, (long)batteryPercent);

    // Battery state
    NSString *batteryState;
    switch (state) {
        case UIDeviceBatteryStateCharging:
            batteryState = @"charging";
            break;
        case UIDeviceBatteryStateFull:
            batteryState = @"full";
            break;
        case UIDeviceBatteryStateUnplugged:
            batteryState = @"unplugged";
            break;
        default:
            batteryState = @"unknown";
            break;
    }

    // Device info
    NSString *deviceName = device.name;
    NSString *systemVersion = device.systemVersion;

    // Get hardware model (e.g., "iPad4,1" for iPad Air)
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *hardwareModel = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];

    NSDictionary *payload = @{
        @"battery_level": @(batteryPercent),
        @"battery_state": batteryState,
        @"device_name": deviceName ?: @"HomeButler",
        @"device_model": hardwareModel ?: @"unknown",
        @"ios_version": systemVersion ?: @"unknown",
        @"app": @"HomeButler"
    };

    NSError *jsonError;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonError];
    if (jsonError) {
        NSLog(@"[BatteryReporter] JSON error: %@", jsonError);
        return;
    }

    NSURL *url = [NSURL URLWithString:webhookURL];
    if (!url) {
        NSLog(@"[BatteryReporter] Invalid webhook URL: %@", webhookURL);
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.HTTPBody = jsonData;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"[BatteryReporter] Webhook error: %@", error.localizedDescription);
        } else {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
                NSLog(@"[BatteryReporter] Reported battery: %ld%% (%@)", (long)batteryPercent, batteryState);
            } else {
                NSLog(@"[BatteryReporter] Webhook returned status: %ld", (long)httpResponse.statusCode);
            }
        }
    }];

    [task resume];
}

@end
