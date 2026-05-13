#import "AppDelegate.h"
#import "HBDashboardViewController.h"
#import "SettingsViewController.h"
#import "HBThemeManager.h"
#import "API/HBBatteryReporter.h"
#import "API/HBPlexClient.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *baseURL = [defaults stringForKey:@"HABaseURL"];
    NSString *accessToken = [defaults stringForKey:@"HAAccessToken"];

    UIViewController *rootViewController;

    if (baseURL && accessToken && baseURL.length > 0 && accessToken.length > 0) {
        HBDashboardViewController *dashboardVC = [[HBDashboardViewController alloc] init];
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:dashboardVC];
        [[HBThemeManager sharedManager] applyThemeToNavigationBar:navController.navigationBar];
        rootViewController = navController;
    } else {
        SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
        settingsVC.isInitialSetup = YES;
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:settingsVC];
        [[HBThemeManager sharedManager] applyThemeToNavigationBar:navController.navigationBar];
        rootViewController = navController;
    }

    self.window.rootViewController = rootViewController;
    [self.window makeKeyAndVisible];

    // Start battery reporting (will only POST if webhook URL is configured)
    [[HBBatteryReporter sharedReporter] startReporting];

    // Ensure persistent Plex client identifier exists and warm-init the client.
    if ([defaults stringForKey:@"PlexClientIdentifier"].length == 0) {
        [defaults setObject:[[NSUUID UUID] UUIDString] forKey:@"PlexClientIdentifier"];
        [defaults synchronize];
    }
    (void)[HBPlexClient sharedClient];

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
}

- (void)applicationWillTerminate:(UIApplication *)application {
}

@end
