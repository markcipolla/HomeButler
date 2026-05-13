#import "SettingsViewController.h"
#import "HAAPIClient.h"
#import "HBDashboardViewController.h"
#import "HBThemeManager.h"
#import "HBPlexClient.h"
#import "HBPlexTarget.h"

@interface SettingsViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UITextField *baseURLField;
@property (nonatomic, strong) UITextField *accessTokenField;
@property (nonatomic, strong) UISwitch *batteryReportingSwitch;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UIButton *testConnectionButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;

// Plex
@property (nonatomic, strong) UISwitch    *plexEnabledSwitch;
@property (nonatomic, strong) UITextField *plexServerURLField;
@property (nonatomic, strong) UITextField *plexTokenField;
@property (nonatomic, strong) UIButton    *plexTargetButton;
@property (nonatomic, strong) UIButton    *plexTestButton;
@property (nonatomic, strong) UILabel     *plexStatusLabel;

@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Settings";

    HBThemeManager *theme = [HBThemeManager sharedManager];
    self.view.backgroundColor = [theme backgroundColor];

    if (!self.isInitialSetup) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelTapped)];
    }

    [self setupUI];
    [self loadSavedSettings];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupUI {
    HBThemeManager *theme = [HBThemeManager sharedManager];

    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
    [self.scrollView addSubview:self.contentView];

    CGFloat padding = 20.0;
    CGFloat yOffset = 80.0;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 30)];
    titleLabel.text = @"Home Assistant Setup";
    titleLabel.font = [UIFont boldSystemFontOfSize:24];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = [theme textColor];
    [self.contentView addSubview:titleLabel];
    yOffset += 50;

    UILabel *urlLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 20)];
    urlLabel.text = @"Base URL (e.g., http://192.168.1.x:8123)";
    urlLabel.font = [UIFont systemFontOfSize:14];
    urlLabel.textColor = [theme secondaryTextColor];
    [self.contentView addSubview:urlLabel];
    yOffset += 25;

    self.baseURLField = [[UITextField alloc] initWithFrame:CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 44)];
    self.baseURLField.backgroundColor = [theme cardBackgroundColor];
    self.baseURLField.textColor = [theme textColor];
    self.baseURLField.layer.cornerRadius = 8;
    self.baseURLField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 44)];
    self.baseURLField.leftViewMode = UITextFieldViewModeAlways;
    self.baseURLField.placeholder = @"http://192.168.1.x:8123";
    self.baseURLField.keyboardType = UIKeyboardTypeURL;
    self.baseURLField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.baseURLField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.baseURLField.delegate = self;
    [self.contentView addSubview:self.baseURLField];
    yOffset += 60;

    UILabel *tokenLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 20)];
    tokenLabel.text = @"Long-Lived Access Token";
    tokenLabel.font = [UIFont systemFontOfSize:14];
    tokenLabel.textColor = [theme secondaryTextColor];
    [self.contentView addSubview:tokenLabel];
    yOffset += 25;

    self.accessTokenField = [[UITextField alloc] initWithFrame:CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 44)];
    self.accessTokenField.backgroundColor = [theme cardBackgroundColor];
    self.accessTokenField.textColor = [theme textColor];
    self.accessTokenField.layer.cornerRadius = 8;
    self.accessTokenField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 44)];
    self.accessTokenField.leftViewMode = UITextFieldViewModeAlways;
    self.accessTokenField.placeholder = @"Enter access token";
    self.accessTokenField.secureTextEntry = YES;
    self.accessTokenField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.accessTokenField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.accessTokenField.delegate = self;
    [self.contentView addSubview:self.accessTokenField];
    yOffset += 60;

    // Battery reporting section
    UIView *batteryRow = [[UIView alloc] initWithFrame:CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 44)];
    batteryRow.backgroundColor = [theme cardBackgroundColor];
    batteryRow.layer.cornerRadius = 8;
    [self.contentView addSubview:batteryRow];

    UILabel *batteryLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, batteryRow.bounds.size.width - 70, 44)];
    batteryLabel.text = @"Battery Reporting";
    batteryLabel.font = [UIFont systemFontOfSize:16];
    batteryLabel.textColor = [theme textColor];
    [batteryRow addSubview:batteryLabel];

    self.batteryReportingSwitch = [[UISwitch alloc] init];
    self.batteryReportingSwitch.frame = CGRectMake(batteryRow.bounds.size.width - 60, 7, 51, 31);
    self.batteryReportingSwitch.onTintColor = [theme accentColor];
    [batteryRow addSubview:self.batteryReportingSwitch];
    yOffset += 50;

    UILabel *batteryHintLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 36)];
    batteryHintLabel.text = @"Reports battery level to Home Assistant for smart plug automation. See README for setup.";
    batteryHintLabel.font = [UIFont systemFontOfSize:12];
    batteryHintLabel.textColor = [theme secondaryTextColor];
    batteryHintLabel.numberOfLines = 0;
    [self.contentView addSubview:batteryHintLabel];
    yOffset += 40;

    // Debug: Show current battery status
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    UIDevice *device = [UIDevice currentDevice];
    float batteryLevel = device.batteryLevel;
    UIDeviceBatteryState state = device.batteryState;
    NSString *stateStr = @"unknown";
    if (state == UIDeviceBatteryStateCharging) stateStr = @"charging";
    else if (state == UIDeviceBatteryStateFull) stateStr = @"full";
    else if (state == UIDeviceBatteryStateUnplugged) stateStr = @"unplugged";

    NSInteger percent = (state == UIDeviceBatteryStateFull) ? 100 : (batteryLevel >= 0 ? (NSInteger)(batteryLevel * 100) : -1);

    UILabel *batteryDebugLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 20)];
    batteryDebugLabel.text = [NSString stringWithFormat:@"Battery: %ld%% (raw: %.2f, state: %@)", (long)percent, batteryLevel, stateStr];
    batteryDebugLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular];
    batteryDebugLabel.textColor = [theme secondaryTextColor];
    [self.contentView addSubview:batteryDebugLabel];
    yOffset += 30;

    self.testConnectionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.testConnectionButton.frame = CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 44);
    [self.testConnectionButton setTitle:@"Test Connection" forState:UIControlStateNormal];
    [self.testConnectionButton setTitleColor:[theme accentColor] forState:UIControlStateNormal];
    self.testConnectionButton.titleLabel.font = [UIFont systemFontOfSize:16];
    [self.testConnectionButton addTarget:self action:@selector(testConnectionTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.testConnectionButton];
    yOffset += 54;

    // --- Plex section ---
    UILabel *plexHeader = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 28)];
    plexHeader.text = @"Plex";
    plexHeader.font = [UIFont boldSystemFontOfSize:18];
    plexHeader.textColor = [theme textColor];
    [self.contentView addSubview:plexHeader];
    yOffset += 36;

    UIView *plexRow = [[UIView alloc] initWithFrame:CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 44)];
    UILabel *plexLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, plexRow.bounds.size.width - 70, 44)];
    plexLbl.text = @"Enable Plex";
    plexLbl.font = [UIFont systemFontOfSize:16];
    plexLbl.textColor = [theme textColor];
    [plexRow addSubview:plexLbl];
    self.plexEnabledSwitch = [[UISwitch alloc] init];
    self.plexEnabledSwitch.frame = CGRectMake(plexRow.bounds.size.width - 51, 6, 51, 31);
    [plexRow addSubview:self.plexEnabledSwitch];
    [self.contentView addSubview:plexRow];
    yOffset += 50;

    UILabel *plexURLLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 20)];
    plexURLLabel.text = @"Server URL";
    plexURLLabel.font = [UIFont systemFontOfSize:14];
    plexURLLabel.textColor = [theme secondaryTextColor];
    [self.contentView addSubview:plexURLLabel];
    yOffset += 25;

    self.plexServerURLField = [[UITextField alloc] initWithFrame:CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 44)];
    self.plexServerURLField.placeholder = @"http://192.168.1.x:32400";
    self.plexServerURLField.borderStyle = UITextBorderStyleRoundedRect;
    self.plexServerURLField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.plexServerURLField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.plexServerURLField.keyboardType = UIKeyboardTypeURL;
    self.plexServerURLField.delegate = self;
    [self.contentView addSubview:self.plexServerURLField];
    yOffset += 56;

    UILabel *plexTokenLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 20)];
    plexTokenLabel.text = @"Token";
    plexTokenLabel.font = [UIFont systemFontOfSize:14];
    plexTokenLabel.textColor = [theme secondaryTextColor];
    [self.contentView addSubview:plexTokenLabel];
    yOffset += 25;

    self.plexTokenField = [[UITextField alloc] initWithFrame:CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 44)];
    self.plexTokenField.placeholder = @"X-Plex-Token";
    self.plexTokenField.borderStyle = UITextBorderStyleRoundedRect;
    self.plexTokenField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.plexTokenField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.plexTokenField.secureTextEntry = YES;
    self.plexTokenField.delegate = self;
    [self.contentView addSubview:self.plexTokenField];
    yOffset += 56;

    self.plexTargetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.plexTargetButton.frame = CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 44);
    [self.plexTargetButton setTitle:@"Pick Target Client" forState:UIControlStateNormal];
    self.plexTargetButton.titleLabel.font = [UIFont systemFontOfSize:16];
    [self.plexTargetButton setTitleColor:[theme accentColor] forState:UIControlStateNormal];
    [self.plexTargetButton addTarget:self action:@selector(plexPickTargetTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.plexTargetButton];
    yOffset += 50;

    self.plexTestButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.plexTestButton.frame = CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 44);
    [self.plexTestButton setTitle:@"Test Plex" forState:UIControlStateNormal];
    [self.plexTestButton setTitleColor:[theme accentColor] forState:UIControlStateNormal];
    self.plexTestButton.titleLabel.font = [UIFont systemFontOfSize:16];
    [self.plexTestButton addTarget:self action:@selector(plexTestTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.plexTestButton];
    yOffset += 50;

    self.plexStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 40)];
    self.plexStatusLabel.numberOfLines = 0;
    self.plexStatusLabel.font = [UIFont systemFontOfSize:13];
    self.plexStatusLabel.textColor = [theme secondaryTextColor];
    [self.contentView addSubview:self.plexStatusLabel];
    yOffset += 50;
    // --- end Plex section ---

    self.saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.saveButton.frame = CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 50);
    [self.saveButton setTitle:@"Save & Continue" forState:UIControlStateNormal];
    self.saveButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.saveButton.backgroundColor = [theme accentColor];
    [self.saveButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.saveButton.layer.cornerRadius = 12.0;
    [self.saveButton addTarget:self action:@selector(saveTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.saveButton];
    yOffset += 60;

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 60)];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.textColor = [theme secondaryTextColor];
    [self.contentView addSubview:self.statusLabel];
    yOffset += 70;

    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    [self.view addGestureRecognizer:tapGesture];

    self.contentView.frame = CGRectMake(0, 0, self.view.bounds.size.width, yOffset);
    self.scrollView.contentSize = self.contentView.frame.size;
}

- (void)loadSavedSettings {
    HAAPIClient *client = [HAAPIClient sharedClient];
    if (client.baseURL) {
        self.baseURLField.text = client.baseURL;
    }
    if (client.accessToken) {
        self.accessTokenField.text = client.accessToken;
    }
    self.batteryReportingSwitch.on = client.batteryReportingEnabled;

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    self.plexEnabledSwitch.on    = [d boolForKey:@"PlexEnabled"];
    self.plexServerURLField.text = [d stringForKey:@"PlexServerURL"];
    self.plexTokenField.text     = [d stringForKey:@"PlexToken"];
    NSString *targetName = [d stringForKey:@"PlexTargetClientName"];
    if (targetName.length > 0) {
        [self.plexTargetButton setTitle:[NSString stringWithFormat:@"Target: %@", targetName] forState:UIControlStateNormal];
    }
}

- (void)testConnectionTapped {
    [self dismissKeyboard];

    NSString *baseURL = [self.baseURLField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *accessToken = [self.accessTokenField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (baseURL.length == 0 || accessToken.length == 0) {
        self.statusLabel.text = @"Please enter both URL and access token";
        self.statusLabel.textColor = [UIColor redColor];
        return;
    }

    self.statusLabel.text = @"Testing connection...";
    self.statusLabel.textColor = [UIColor grayColor];
    self.testConnectionButton.enabled = NO;

    HAAPIClient *tempClient = [[HAAPIClient alloc] init];
    [tempClient configureWithBaseURL:baseURL accessToken:accessToken];

    [tempClient fetchStatesWithCompletion:^(NSArray<HAEntity *> *entities, NSError *error) {
        self.testConnectionButton.enabled = YES;

        if (error) {
            self.statusLabel.text = [NSString stringWithFormat:@"Connection failed: %@", error.localizedDescription];
            self.statusLabel.textColor = [UIColor redColor];
        } else {
            self.statusLabel.text = [NSString stringWithFormat:@"Success! Found %lu entities", (unsigned long)entities.count];
            self.statusLabel.textColor = [UIColor colorWithRed:0.0 green:0.7 blue:0.0 alpha:1.0];
        }
    }];
}

- (void)saveTapped {
    [self dismissKeyboard];

    NSString *baseURL = [self.baseURLField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *accessToken = [self.accessTokenField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (baseURL.length == 0 || accessToken.length == 0) {
        self.statusLabel.text = @"Please enter both URL and access token";
        self.statusLabel.textColor = [UIColor redColor];
        return;
    }

    [[HAAPIClient sharedClient] configureWithBaseURL:baseURL accessToken:accessToken];

    // Save battery reporting setting
    [HAAPIClient sharedClient].batteryReportingEnabled = self.batteryReportingSwitch.on;

    // Save Plex settings
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setBool:self.plexEnabledSwitch.on forKey:@"PlexEnabled"];
    NSString *plexURL   = [self.plexServerURLField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *plexToken = [self.plexTokenField.text     stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [d setObject:plexURL   forKey:@"PlexServerURL"];
    [d setObject:plexToken forKey:@"PlexToken"];
    [d synchronize];
    [[HBPlexClient sharedClient] reloadFromDefaults];
    [[NSNotificationCenter defaultCenter] postNotificationName:PlexSettingsChangedNotification object:nil];

    if (self.isInitialSetup) {
        HBDashboardViewController *dashboardVC = [[HBDashboardViewController alloc] init];
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:dashboardVC];
        [[HBThemeManager sharedManager] applyThemeToNavigationBar:navController.navigationBar];

        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        window.rootViewController = navController;

        [UIView transitionWithView:window
                          duration:0.3
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:nil
                        completion:nil];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)cancelTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.baseURLField) {
        [self.accessTokenField becomeFirstResponder];
    } else if (textField == self.accessTokenField) {
        [self dismissKeyboard];
        [self saveTapped];
    }
    return YES;
}

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    CGRect keyboardFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat keyboardHeight = keyboardFrame.size.height;

    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0, 0, keyboardHeight, 0);
    self.scrollView.contentInset = contentInsets;
    self.scrollView.scrollIndicatorInsets = contentInsets;
}

- (void)keyboardWillHide:(NSNotification *)notification {
    self.scrollView.contentInset = UIEdgeInsetsZero;
    self.scrollView.scrollIndicatorInsets = UIEdgeInsetsZero;
}

#pragma mark - Plex

- (void)plexTestTapped {
    [self dismissKeyboard];
    NSString *url   = [self.plexServerURLField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *token = [self.plexTokenField.text     stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (url.length == 0 || token.length == 0) {
        self.plexStatusLabel.text = @"Enter Plex URL and token";
        self.plexStatusLabel.textColor = [UIColor redColor];
        return;
    }
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:url   forKey:@"PlexServerURL"];
    [d setObject:token forKey:@"PlexToken"];
    [d synchronize];
    [[HBPlexClient sharedClient] reloadFromDefaults];

    self.plexStatusLabel.text = @"Testing Plex...";
    self.plexStatusLabel.textColor = [UIColor grayColor];
    [[HBPlexClient sharedClient] fetchSectionsWithCompletion:^(NSArray *sections, NSError *error) {
        if (error || sections == nil) {
            self.plexStatusLabel.text = [NSString stringWithFormat:@"Plex failed: %@", error.localizedDescription ?: @"no response"];
            self.plexStatusLabel.textColor = [UIColor redColor];
        } else {
            self.plexStatusLabel.text = [NSString stringWithFormat:@"Plex OK \u2014 %lu libraries", (unsigned long)sections.count];
            self.plexStatusLabel.textColor = [UIColor colorWithRed:0.0 green:0.7 blue:0.0 alpha:1.0];
        }
    }];
}

- (void)plexPickTargetTapped {
    [self dismissKeyboard];
    NSString *url   = [self.plexServerURLField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *token = [self.plexTokenField.text     stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (url.length == 0 || token.length == 0) {
        self.plexStatusLabel.text = @"Enter Plex URL and token first";
        self.plexStatusLabel.textColor = [UIColor redColor];
        return;
    }
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:url   forKey:@"PlexServerURL"];
    [d setObject:token forKey:@"PlexToken"];
    [d synchronize];
    [[HBPlexClient sharedClient] reloadFromDefaults];

    self.plexStatusLabel.text = @"Loading clients...";
    [[HBPlexClient sharedClient] fetchAvailableTargetsWithCompletion:^(NSArray<HBPlexTarget *> *targets, NSError *error) {
        if (error || targets == nil) {
            self.plexStatusLabel.text = [NSString stringWithFormat:@"No clients: %@", error.localizedDescription ?: @"unreachable"];
            self.plexStatusLabel.textColor = [UIColor redColor];
            return;
        }
        if (targets.count == 0) {
            self.plexStatusLabel.text = @"No Plex clients on network";
            self.plexStatusLabel.textColor = [UIColor redColor];
            return;
        }
        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Pick Target Client"
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        for (HBPlexTarget *t in targets) {
            NSString *title = [NSString stringWithFormat:@"%@ (%@)", t.name ?: @"Client", t.product ?: @"?"];
            HBPlexTarget *captured = t;
            [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
                NSUserDefaults *d2 = [NSUserDefaults standardUserDefaults];
                [d2 setObject:captured.name              ?: @"" forKey:@"PlexTargetClientName"];
                [d2 setObject:captured.host              ?: @"" forKey:@"PlexTargetClientIP"];
                [d2 setObject:@(captured.port)                forKey:@"PlexTargetClientPort"];
                [d2 setObject:captured.machineIdentifier ?: @"" forKey:@"PlexTargetClientMachineId"];
                [d2 synchronize];
                [[HBPlexClient sharedClient] reloadFromDefaults];
                [self.plexTargetButton setTitle:[NSString stringWithFormat:@"Target: %@", captured.name] forState:UIControlStateNormal];
            }]];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        if (sheet.popoverPresentationController) {
            sheet.popoverPresentationController.sourceView = self.plexTargetButton;
            sheet.popoverPresentationController.sourceRect = self.plexTargetButton.bounds;
        }
        [self presentViewController:sheet animated:YES completion:nil];
    }];
}

@end
