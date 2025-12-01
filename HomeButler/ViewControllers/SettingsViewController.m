#import "SettingsViewController.h"
#import "HAAPIClient.h"
#import "HBDashboardViewController.h"
#import "HBThemeManager.h"

@interface SettingsViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UITextField *baseURLField;
@property (nonatomic, strong) UITextField *accessTokenField;
@property (nonatomic, strong) UISwitch *batteryReportingSwitch;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UIButton *testConnectionButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;

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

@end
