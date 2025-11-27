#import "DashboardViewController.h"
#import "HAAPIClient.h"
#import "HAEntity.h"
#import "EntityCell.h"
#import "SettingsViewController.h"
#import "LightControlViewController.h"
#import "CameraViewController.h"

@interface DashboardViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<HAEntity *> *entities;
@property (nonatomic, strong) NSArray<HAEntity *> *filteredEntities;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UISegmentedControl *filterControl;

@end

@implementation DashboardViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Home Butler";
    self.view.backgroundColor = [UIColor whiteColor];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Settings" style:UIBarButtonItemStylePlain target:self action:@selector(settingsTapped)];

    [self setupFilterControl];
    [self setupTableView];
    [self loadEntities];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadEntities];
}

- (void)setupFilterControl {
    NSArray *items = @[@"All", @"Lights", @"Switches", @"Sensors", @"Cameras"];
    self.filterControl = [[UISegmentedControl alloc] initWithItems:items];
    self.filterControl.selectedSegmentIndex = 0;
    [self.filterControl addTarget:self action:@selector(filterChanged) forControlEvents:UIControlEventValueChanged];

    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 50)];
    self.filterControl.frame = CGRectMake(10, 10, self.view.bounds.size.width - 20, 30);
    self.filterControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [headerView addSubview:self.filterControl];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.tableHeaderView = headerView;
}

- (void)setupTableView {
    self.tableView.frame = self.view.bounds;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 50;
    [self.tableView registerClass:[EntityCell class] forCellReuseIdentifier:@"EntityCell"];
    [self.view addSubview:self.tableView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(loadEntities) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refreshControl];
}

- (void)loadEntities {
    [[HAAPIClient sharedClient] fetchStatesWithCompletion:^(NSArray<HAEntity *> *entities, NSError *error) {
        [self.refreshControl endRefreshing];

        if (error) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                           message:error.localizedDescription
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }

        self.entities = entities;
        [self filterChanged];
    }];
}

- (void)filterChanged {
    NSInteger selectedIndex = self.filterControl.selectedSegmentIndex;

    if (selectedIndex == 0) {
        self.filteredEntities = self.entities;
    } else {
        HAEntityType filterType;
        switch (selectedIndex) {
            case 1: filterType = HAEntityTypeLight; break;
            case 2: filterType = HAEntityTypeSwitch; break;
            case 3: filterType = HAEntityTypeSensor; break;
            case 4: filterType = HAEntityTypeCamera; break;
            default: filterType = HAEntityTypeUnknown; break;
        }

        NSMutableArray *filtered = [NSMutableArray array];
        for (HAEntity *entity in self.entities) {
            if (entity.entityType == filterType) {
                [filtered addObject:entity];
            }
        }
        self.filteredEntities = filtered;
    }

    [self.tableView reloadData];
}

- (void)settingsTapped {
    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    settingsVC.isInitialSetup = NO;
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    navController.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:navController animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredEntities.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    EntityCell *cell = [tableView dequeueReusableCellWithIdentifier:@"EntityCell" forIndexPath:indexPath];
    HAEntity *entity = self.filteredEntities[indexPath.row];
    [cell configureWithEntity:entity];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    HAEntity *entity = self.filteredEntities[indexPath.row];

    if (entity.entityType == HAEntityTypeLight) {
        LightControlViewController *lightVC = [[LightControlViewController alloc] init];
        lightVC.entity = entity;
        [self.navigationController pushViewController:lightVC animated:YES];
    } else if (entity.entityType == HAEntityTypeSwitch) {
        [self toggleSwitch:entity];
    } else if (entity.entityType == HAEntityTypeCamera) {
        CameraViewController *cameraVC = [[CameraViewController alloc] init];
        cameraVC.entity = entity;
        [self.navigationController pushViewController:cameraVC animated:YES];
    } else if (entity.entityType == HAEntityTypeSensor) {
        [self showSensorDetails:entity];
    }
}

- (void)toggleSwitch:(HAEntity *)entity {
    if (entity.isOn) {
        [[HAAPIClient sharedClient] turnOffEntity:entity.entityId completion:^(BOOL success, id result, NSError *error) {
            if (success) {
                [self loadEntities];
            }
        }];
    } else {
        [[HAAPIClient sharedClient] turnOnEntity:entity.entityId completion:^(BOOL success, id result, NSError *error) {
            if (success) {
                [self loadEntities];
            }
        }];
    }
}

- (void)showSensorDetails:(HAEntity *)entity {
    NSMutableString *details = [NSMutableString stringWithFormat:@"State: %@\n\n", entity.state];

    if (entity.attributes.count > 0) {
        [details appendString:@"Attributes:\n"];
        for (NSString *key in entity.attributes) {
            id value = entity.attributes[key];
            [details appendFormat:@"%@: %@\n", key, value];
        }
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:entity.friendlyName
                                                                   message:details
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
