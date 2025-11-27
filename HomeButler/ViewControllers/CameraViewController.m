#import "CameraViewController.h"
#import "HAEntity.h"
#import "HAAPIClient.h"

@interface CameraViewController ()

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, strong) UILabel *statusLabel;

@end

@implementation CameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = self.entity.friendlyName;
    self.view.backgroundColor = [UIColor blackColor];

    [self setupUI];
    [self loadCameraImage];

    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                         target:self
                                                       selector:@selector(loadCameraImage)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
}

- (void)setupUI {
    self.imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.imageView];

    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.activityIndicator.center = self.view.center;
    self.activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:self.activityIndicator];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 80, self.view.bounds.size.width - 40, 60)];
    self.statusLabel.textColor = [UIColor whiteColor];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    [self.view addSubview:self.statusLabel];
}

- (void)loadCameraImage {
    NSString *streamURL = [[HAAPIClient sharedClient] cameraStreamURLForEntity:self.entity.entityId];

    if (!streamURL) {
        self.statusLabel.text = @"Unable to get camera stream URL";
        return;
    }

    NSURL *url = [NSURL URLWithString:streamURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];

    NSString *accessToken = [HAAPIClient sharedClient].accessToken;
    if (accessToken) {
        [request setValue:[NSString stringWithFormat:@"Bearer %@", accessToken] forHTTPHeaderField:@"Authorization"];
    }

    [self.activityIndicator startAnimating];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.activityIndicator stopAnimating];

            if (error) {
                self.statusLabel.text = [NSString stringWithFormat:@"Error: %@", error.localizedDescription];
                return;
            }

            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode != 200) {
                self.statusLabel.text = [NSString stringWithFormat:@"HTTP Error: %ld", (long)httpResponse.statusCode];
                return;
            }

            if (data) {
                UIImage *image = [UIImage imageWithData:data];
                if (image) {
                    self.imageView.image = image;
                    self.statusLabel.text = @"";
                } else {
                    self.statusLabel.text = @"Unable to decode image";
                }
            }
        });
    }];

    [task resume];
}

@end
