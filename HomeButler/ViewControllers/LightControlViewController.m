#import "LightControlViewController.h"
#import "HAEntity.h"
#import "HAAPIClient.h"

@interface LightControlViewController ()

@property (nonatomic, strong) UISwitch *powerSwitch;
@property (nonatomic, strong) UISlider *brightnessSlider;
@property (nonatomic, strong) UILabel *brightnessLabel;
@property (nonatomic, strong) UISlider *redSlider;
@property (nonatomic, strong) UISlider *greenSlider;
@property (nonatomic, strong) UISlider *blueSlider;
@property (nonatomic, strong) UIView *colorPreview;
@property (nonatomic, strong) UILabel *stateLabel;

@property (nonatomic, assign) BOOL supportsColor;
@property (nonatomic, assign) BOOL supportsBrightness;

@end

@implementation LightControlViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = self.entity.friendlyName;
    self.view.backgroundColor = [UIColor whiteColor];

    [self checkCapabilities];
    [self setupUI];
    [self updateUI];
}

- (void)checkCapabilities {
    NSNumber *supportedFeatures = self.entity.attributes[@"supported_features"];
    if (supportedFeatures && [supportedFeatures isKindOfClass:[NSNumber class]]) {
        NSInteger features = [supportedFeatures integerValue];
        self.supportsBrightness = (features & 1) != 0;
        self.supportsColor = (features & 16) != 0;
    } else {
        self.supportsBrightness = self.entity.attributes[@"brightness"] != nil;
        self.supportsColor = self.entity.attributes[@"rgb_color"] != nil;
    }
}

- (void)setupUI {
    CGFloat yOffset = 80;
    CGFloat padding = 20;

    self.stateLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 30)];
    self.stateLabel.textAlignment = NSTextAlignmentCenter;
    self.stateLabel.font = [UIFont systemFontOfSize:18];
    [self.view addSubview:self.stateLabel];
    yOffset += 50;

    UIView *powerRow = [[UIView alloc] initWithFrame:CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 40)];
    UILabel *powerLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 40)];
    powerLabel.text = @"Power";
    powerLabel.font = [UIFont boldSystemFontOfSize:16];
    [powerRow addSubview:powerLabel];

    self.powerSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(powerRow.bounds.size.width - 51, 5, 51, 31)];
    [self.powerSwitch addTarget:self action:@selector(powerSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [powerRow addSubview:self.powerSwitch];
    [self.view addSubview:powerRow];
    yOffset += 60;

    if (self.supportsBrightness) {
        UILabel *brightnessTitle = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, 200, 30)];
        brightnessTitle.text = @"Brightness";
        brightnessTitle.font = [UIFont boldSystemFontOfSize:16];
        [self.view addSubview:brightnessTitle];

        self.brightnessLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - padding - 60, yOffset, 60, 30)];
        self.brightnessLabel.textAlignment = NSTextAlignmentRight;
        self.brightnessLabel.font = [UIFont systemFontOfSize:16];
        [self.view addSubview:self.brightnessLabel];
        yOffset += 35;

        self.brightnessSlider = [[UISlider alloc] initWithFrame:CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 30)];
        self.brightnessSlider.minimumValue = 3; // 1% minimum (use toggle to turn off)
        self.brightnessSlider.maximumValue = 255;
        [self.brightnessSlider addTarget:self action:@selector(brightnessChanged:) forControlEvents:UIControlEventValueChanged];
        [self.view addSubview:self.brightnessSlider];
        yOffset += 50;
    }

    if (self.supportsColor) {
        UILabel *colorTitle = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, 200, 30)];
        colorTitle.text = @"Color";
        colorTitle.font = [UIFont boldSystemFontOfSize:16];
        [self.view addSubview:colorTitle];
        yOffset += 35;

        self.colorPreview = [[UIView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width / 2 - 50, yOffset, 100, 100)];
        self.colorPreview.layer.cornerRadius = 50;
        self.colorPreview.layer.borderWidth = 2;
        self.colorPreview.layer.borderColor = [UIColor lightGrayColor].CGColor;
        [self.view addSubview:self.colorPreview];
        yOffset += 120;

        UILabel *redLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, 40, 30)];
        redLabel.text = @"R";
        redLabel.textColor = [UIColor redColor];
        redLabel.font = [UIFont boldSystemFontOfSize:16];
        [self.view addSubview:redLabel];

        self.redSlider = [[UISlider alloc] initWithFrame:CGRectMake(padding + 45, yOffset, self.view.bounds.size.width - 2 * padding - 45, 30)];
        self.redSlider.minimumValue = 0;
        self.redSlider.maximumValue = 255;
        self.redSlider.minimumTrackTintColor = [UIColor redColor];
        [self.redSlider addTarget:self action:@selector(colorChanged) forControlEvents:UIControlEventValueChanged];
        [self.view addSubview:self.redSlider];
        yOffset += 40;

        UILabel *greenLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, 40, 30)];
        greenLabel.text = @"G";
        greenLabel.textColor = [UIColor greenColor];
        greenLabel.font = [UIFont boldSystemFontOfSize:16];
        [self.view addSubview:greenLabel];

        self.greenSlider = [[UISlider alloc] initWithFrame:CGRectMake(padding + 45, yOffset, self.view.bounds.size.width - 2 * padding - 45, 30)];
        self.greenSlider.minimumValue = 0;
        self.greenSlider.maximumValue = 255;
        self.greenSlider.minimumTrackTintColor = [UIColor greenColor];
        [self.greenSlider addTarget:self action:@selector(colorChanged) forControlEvents:UIControlEventValueChanged];
        [self.view addSubview:self.greenSlider];
        yOffset += 40;

        UILabel *blueLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, 40, 30)];
        blueLabel.text = @"B";
        blueLabel.textColor = [UIColor blueColor];
        blueLabel.font = [UIFont boldSystemFontOfSize:16];
        [self.view addSubview:blueLabel];

        self.blueSlider = [[UISlider alloc] initWithFrame:CGRectMake(padding + 45, yOffset, self.view.bounds.size.width - 2 * padding - 45, 30)];
        self.blueSlider.minimumValue = 0;
        self.blueSlider.maximumValue = 255;
        self.blueSlider.minimumTrackTintColor = [UIColor blueColor];
        [self.blueSlider addTarget:self action:@selector(colorChanged) forControlEvents:UIControlEventValueChanged];
        [self.view addSubview:self.blueSlider];
        yOffset += 40;

        UIButton *applyColorButton = [UIButton buttonWithType:UIButtonTypeSystem];
        applyColorButton.frame = CGRectMake(padding, yOffset, self.view.bounds.size.width - 2 * padding, 44);
        [applyColorButton setTitle:@"Apply Color" forState:UIControlStateNormal];
        applyColorButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
        [applyColorButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        applyColorButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        applyColorButton.layer.cornerRadius = 8;
        [applyColorButton addTarget:self action:@selector(applyColorTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:applyColorButton];
    }
}

- (void)updateUI {
    BOOL isOn = self.entity.isOn;
    self.powerSwitch.on = isOn;
    self.stateLabel.text = [NSString stringWithFormat:@"Light is %@", isOn ? @"ON" : @"OFF"];
    self.stateLabel.textColor = isOn ? [UIColor colorWithRed:0.0 green:0.7 blue:0.0 alpha:1.0] : [UIColor grayColor];

    if (self.supportsBrightness) {
        NSNumber *brightness = self.entity.attributes[@"brightness"];
        if (brightness) {
            self.brightnessSlider.value = [brightness floatValue];
            self.brightnessLabel.text = [NSString stringWithFormat:@"%d%%", (int)([brightness floatValue] / 255.0 * 100)];
        }
    }

    if (self.supportsColor) {
        NSArray *rgbColor = self.entity.attributes[@"rgb_color"];
        if (rgbColor && rgbColor.count == 3) {
            self.redSlider.value = [rgbColor[0] floatValue];
            self.greenSlider.value = [rgbColor[1] floatValue];
            self.blueSlider.value = [rgbColor[2] floatValue];
            [self updateColorPreview];
        }
    }
}

- (void)powerSwitchChanged:(UISwitch *)sender {
    if (sender.isOn) {
        [[HAAPIClient sharedClient] turnOnEntity:self.entity.entityId completion:^(BOOL success, id result, NSError *error) {
            if (!success) {
                sender.on = NO;
            }
        }];
    } else {
        [[HAAPIClient sharedClient] turnOffEntity:self.entity.entityId completion:^(BOOL success, id result, NSError *error) {
            if (!success) {
                sender.on = YES;
            }
        }];
    }
}

- (void)brightnessChanged:(UISlider *)sender {
    NSInteger brightness = (NSInteger)sender.value;
    if (brightness < 3) brightness = 3; // Clamp to 1% minimum
    self.brightnessLabel.text = [NSString stringWithFormat:@"%d%%", (int)(brightness / 255.0 * 100)];

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(applyBrightness) object:nil];
    [self performSelector:@selector(applyBrightness) withObject:nil afterDelay:0.5];
}

- (void)applyBrightness {
    NSInteger brightness = (NSInteger)self.brightnessSlider.value;
    if (brightness < 3) brightness = 3; // Clamp to 1% minimum
    [[HAAPIClient sharedClient] setLightBrightness:self.entity.entityId brightness:brightness completion:nil];
}

- (void)colorChanged {
    [self updateColorPreview];
}

- (void)updateColorPreview {
    UIColor *color = [UIColor colorWithRed:self.redSlider.value / 255.0
                                     green:self.greenSlider.value / 255.0
                                      blue:self.blueSlider.value / 255.0
                                     alpha:1.0];
    self.colorPreview.backgroundColor = color;
}

- (void)applyColorTapped {
    NSInteger red = (NSInteger)self.redSlider.value;
    NSInteger green = (NSInteger)self.greenSlider.value;
    NSInteger blue = (NSInteger)self.blueSlider.value;

    [[HAAPIClient sharedClient] setLightColor:self.entity.entityId red:red green:green blue:blue completion:^(BOOL success, id result, NSError *error) {
        if (success) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Success"
                                                                           message:@"Color applied"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }];
}

@end
