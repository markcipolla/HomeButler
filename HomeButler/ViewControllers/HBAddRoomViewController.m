#import "HBAddRoomViewController.h"
#import "HBRoom.h"
#import "HBThemeManager.h"
#import "HAEntity.h"
#import "HBIconView.h"

typedef NS_ENUM(NSInteger, EntityFilterType) {
    EntityFilterTypeAll,
    EntityFilterTypeLights,
    EntityFilterTypeSwitches,
    EntityFilterTypeSensors,
    EntityFilterTypeCameras
};

@interface HBAddRoomViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIScrollView *filterScrollView;
@property (nonatomic, strong) NSMutableArray<UIButton *> *filterButtons;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<HAEntity *> *filteredEntities;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedEntityIds;
@property (nonatomic, strong) UIScrollView *iconScrollView;
@property (nonatomic, strong) NSMutableArray<UIButton *> *iconButtons;
@property (nonatomic, assign) NSInteger selectedIconType;
@property (nonatomic, assign) EntityFilterType currentFilter;
@property (nonatomic, strong) NSString *searchText;
@property (nonatomic, assign) BOOL isEditing;

@end

// Room-selectable icon types (excluding gear, plus, pencil which are UI-only)
static NSArray *kRoomIconTypes;

@implementation HBAddRoomViewController

+ (void)initialize {
    if (self == [HBAddRoomViewController class]) {
        kRoomIconTypes = @[
            @(HBIconTypeLivingRoom),
            @(HBIconTypeBed),
            @(HBIconTypeKitchen),
            @(HBIconTypeBathTub),
            @(HBIconTypeHouse),
            @(HBIconTypeGarage),
            @(HBIconTypeWork),
            @(HBIconTypeBabyCrib)
        ];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.isEditing = (self.room != nil);
    self.title = self.isEditing ? @"Edit Room" : @"Add Room";

    HBThemeManager *theme = [HBThemeManager sharedManager];
    self.view.backgroundColor = [theme backgroundColor];

    // Initialize filter state
    self.currentFilter = EntityFilterTypeAll;
    self.searchText = @"";

    // Selected entities
    if (self.isEditing) {
        self.selectedEntityIds = [NSMutableSet setWithArray:self.room.entityIds];
    } else {
        self.selectedEntityIds = [NSMutableSet set];
    }

    // Apply initial filter
    [self applyFilters];

    // Navigation buttons
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                          target:self
                                                                                          action:@selector(cancelTapped)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                                           target:self
                                                                                           action:@selector(saveTapped)];

    [self setupHeader];
    [self setupSearchAndFilters];
    [self setupTableView];

    if (self.isEditing) {
        [self setupDeleteButton];
    }
}

- (void)setupHeader {
    HBThemeManager *theme = [HBThemeManager sharedManager];

    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 64, self.view.bounds.size.width, 200)];
    headerView.backgroundColor = [theme secondaryBackgroundColor];
    [self.view addSubview:headerView];

    // Name field
    UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 16, 100, 24)];
    nameLabel.text = @"Room Name";
    nameLabel.textColor = [theme secondaryTextColor];
    nameLabel.font = [UIFont systemFontOfSize:14];
    [headerView addSubview:nameLabel];

    self.nameField = [[UITextField alloc] initWithFrame:CGRectMake(16, 44, headerView.bounds.size.width - 32, 44)];
    self.nameField.backgroundColor = [theme cardBackgroundColor];
    self.nameField.textColor = [theme textColor];
    self.nameField.layer.cornerRadius = 8;
    self.nameField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 44)];
    self.nameField.leftViewMode = UITextFieldViewModeAlways;
    // Use lighter grey placeholder text for dark theme
    self.nameField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"e.g., Living Room"
                                                                           attributes:@{NSForegroundColorAttributeName: [UIColor colorWithRed:100/255.0 green:100/255.0 blue:105/255.0 alpha:1.0]}];
    self.nameField.delegate = self;
    self.nameField.returnKeyType = UIReturnKeyDone;
    self.nameField.text = self.room.name ?: @"";
    [headerView addSubview:self.nameField];

    // Icon selector label
    UILabel *iconLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 96, 100, 24)];
    iconLabel.text = @"Icon";
    iconLabel.textColor = [theme secondaryTextColor];
    iconLabel.font = [UIFont systemFontOfSize:14];
    [headerView addSubview:iconLabel];

    // Icon scroll view with buttons
    self.iconScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(16, 124, headerView.bounds.size.width - 32, 64)];
    self.iconScrollView.showsHorizontalScrollIndicator = NO;
    [headerView addSubview:self.iconScrollView];

    self.iconButtons = [NSMutableArray array];
    CGFloat iconSize = 60.0;
    CGFloat spacing = 12.0;
    CGFloat xOffset = 0;

    // Set default selected icon
    self.selectedIconType = HBIconTypeLivingRoom;
    if (self.isEditing) {
        self.selectedIconType = self.room.iconType;
    }

    for (NSNumber *iconTypeNum in kRoomIconTypes) {
        HBIconType iconType = [iconTypeNum integerValue];

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(xOffset, 0, iconSize, iconSize);
        btn.tag = iconType;
        btn.layer.cornerRadius = 8;
        btn.layer.borderWidth = 2;

        // Create icon image
        UIImage *iconImage = [HBIconView imageWithIconType:iconType size:CGSizeMake(iconSize - 12, iconSize - 12) color:[theme textColor]];
        [btn setImage:iconImage forState:UIControlStateNormal];

        // Style based on selection
        if (iconType == self.selectedIconType) {
            btn.backgroundColor = [theme accentColor];
            btn.layer.borderColor = [theme accentColor].CGColor;
        } else {
            btn.backgroundColor = [theme cardBackgroundColor];
            btn.layer.borderColor = [theme separatorColor].CGColor;
        }

        [btn addTarget:self action:@selector(iconButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.iconScrollView addSubview:btn];
        [self.iconButtons addObject:btn];

        xOffset += iconSize + spacing;
    }

    self.iconScrollView.contentSize = CGSizeMake(xOffset, iconSize);
}

- (void)iconButtonTapped:(UIButton *)sender {
    HBThemeManager *theme = [HBThemeManager sharedManager];

    // Update selection
    self.selectedIconType = sender.tag;

    // Update button appearances
    for (UIButton *btn in self.iconButtons) {
        if (btn.tag == self.selectedIconType) {
            btn.backgroundColor = [theme accentColor];
            btn.layer.borderColor = [theme accentColor].CGColor;
        } else {
            btn.backgroundColor = [theme cardBackgroundColor];
            btn.layer.borderColor = [theme separatorColor].CGColor;
        }
    }
}

- (void)setupSearchAndFilters {
    HBThemeManager *theme = [HBThemeManager sharedManager];
    CGFloat yOffset = 264; // Below the header

    // Search field
    self.searchField = [[UITextField alloc] initWithFrame:CGRectMake(16, yOffset, self.view.bounds.size.width - 32, 40)];
    self.searchField.backgroundColor = [theme cardBackgroundColor];
    self.searchField.textColor = [theme textColor];
    self.searchField.layer.cornerRadius = 8;
    self.searchField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 40)];
    self.searchField.leftViewMode = UITextFieldViewModeAlways;
    self.searchField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Search entities..."
                                                                             attributes:@{NSForegroundColorAttributeName: [UIColor colorWithRed:100/255.0 green:100/255.0 blue:105/255.0 alpha:1.0]}];
    self.searchField.delegate = self;
    self.searchField.returnKeyType = UIReturnKeySearch;
    self.searchField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [self.searchField addTarget:self action:@selector(searchTextChanged:) forControlEvents:UIControlEventEditingChanged];
    [self.view addSubview:self.searchField];

    yOffset += 48;

    // Filter buttons scroll view
    self.filterScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, yOffset, self.view.bounds.size.width, 44)];
    self.filterScrollView.showsHorizontalScrollIndicator = NO;
    self.filterScrollView.backgroundColor = [theme backgroundColor];
    [self.view addSubview:self.filterScrollView];

    self.filterButtons = [NSMutableArray array];
    NSArray *filterTitles = @[@"All", @"Lights", @"Switches", @"Sensors", @"Cameras"];
    CGFloat xOffset = 16;
    CGFloat buttonHeight = 32;
    CGFloat buttonSpacing = 8;

    for (NSInteger i = 0; i < filterTitles.count; i++) {
        NSString *title = filterTitles[i];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];

        // Calculate button width based on title
        CGFloat textWidth = [title sizeWithAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:14 weight:UIFontWeightMedium]}].width;
        CGFloat buttonWidth = textWidth + 24;

        btn.frame = CGRectMake(xOffset, 6, buttonWidth, buttonHeight);
        btn.tag = i;
        btn.layer.cornerRadius = buttonHeight / 2;
        [btn setTitle:title forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];

        // Style based on selection
        if (i == self.currentFilter) {
            btn.backgroundColor = [theme accentColor];
            [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        } else {
            btn.backgroundColor = [theme cardBackgroundColor];
            [btn setTitleColor:[theme textColor] forState:UIControlStateNormal];
        }

        [btn addTarget:self action:@selector(filterButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.filterScrollView addSubview:btn];
        [self.filterButtons addObject:btn];

        xOffset += buttonWidth + buttonSpacing;
    }

    self.filterScrollView.contentSize = CGSizeMake(xOffset, 44);
}

- (void)setupTableView {
    HBThemeManager *theme = [HBThemeManager sharedManager];

    CGFloat headerHeight = 264 + 48 + 44; // Original header + search + filters
    CGRect tableFrame = CGRectMake(0, headerHeight, self.view.bounds.size.width, self.view.bounds.size.height - headerHeight);
    self.tableView = [[UITableView alloc] initWithFrame:tableFrame style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = [theme backgroundColor];
    self.tableView.separatorColor = [theme separatorColor];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:self.tableView];
}

- (void)setupDeleteButton {
    HBThemeManager *theme = [HBThemeManager sharedManager];

    UIButton *deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    deleteButton.frame = CGRectMake(16, 0, self.view.bounds.size.width - 32, 50);
    [deleteButton setTitle:@"Delete Room" forState:UIControlStateNormal];
    [deleteButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    deleteButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [deleteButton addTarget:self action:@selector(deleteTapped) forControlEvents:UIControlEventTouchUpInside];

    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 70)];
    footerView.backgroundColor = [theme backgroundColor];
    [footerView addSubview:deleteButton];
    self.tableView.tableFooterView = footerView;
}

#pragma mark - Actions

- (void)cancelTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)saveTapped {
    NSString *name = [self.nameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (name.length == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                       message:@"Please enter a room name"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    if (self.isEditing) {
        self.room.name = name;
        self.room.iconType = self.selectedIconType;
        self.room.entityIds = [[self.selectedEntityIds allObjects] mutableCopy];
        [[HBRoomManager sharedManager] updateRoom:self.room];
    } else {
        HBRoom *newRoom = [HBRoom roomWithName:name iconType:self.selectedIconType];
        newRoom.entityIds = [[self.selectedEntityIds allObjects] mutableCopy];
        [[HBRoomManager sharedManager] addRoom:newRoom];
    }

    [self dismissViewControllerAnimated:YES completion:^{
        // Post notification to refresh dashboard
        [[NSNotificationCenter defaultCenter] postNotificationName:@"HBRoomDidChangeNotification" object:nil];
    }];
}

- (void)deleteTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Delete Room"
                                                                   message:@"Are you sure you want to delete this room?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[HBRoomManager sharedManager] removeRoom:self.room];
        [self dismissViewControllerAnimated:YES completion:^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"HBRoomDidChangeNotification" object:nil];
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Search and Filter

- (void)searchTextChanged:(UITextField *)textField {
    self.searchText = textField.text ?: @"";
    [self applyFilters];
    [self.tableView reloadData];
}

- (void)filterButtonTapped:(UIButton *)sender {
    HBThemeManager *theme = [HBThemeManager sharedManager];

    self.currentFilter = (EntityFilterType)sender.tag;

    // Update button appearances
    for (UIButton *btn in self.filterButtons) {
        if (btn.tag == self.currentFilter) {
            btn.backgroundColor = [theme accentColor];
            [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        } else {
            btn.backgroundColor = [theme cardBackgroundColor];
            [btn setTitleColor:[theme textColor] forState:UIControlStateNormal];
        }
    }

    [self applyFilters];
    [self.tableView reloadData];
}

- (void)applyFilters {
    NSMutableArray *results = [NSMutableArray array];

    for (HAEntity *entity in self.allEntities) {
        // Apply type filter
        BOOL passesTypeFilter = NO;
        switch (self.currentFilter) {
            case EntityFilterTypeAll:
                // Show lights, switches, sensors, cameras, scripts, input_booleans (not unknown types)
                passesTypeFilter = (entity.entityType == HAEntityTypeLight ||
                                   entity.entityType == HAEntityTypeSwitch ||
                                   entity.entityType == HAEntityTypeSensor ||
                                   entity.entityType == HAEntityTypeBinarySensor ||
                                   entity.entityType == HAEntityTypeCamera ||
                                   entity.entityType == HAEntityTypeScript ||
                                   entity.entityType == HAEntityTypeInputBoolean);
                break;
            case EntityFilterTypeLights:
                passesTypeFilter = (entity.entityType == HAEntityTypeLight);
                break;
            case EntityFilterTypeSwitches:
                passesTypeFilter = (entity.entityType == HAEntityTypeSwitch);
                break;
            case EntityFilterTypeSensors:
                passesTypeFilter = (entity.entityType == HAEntityTypeSensor ||
                                   entity.entityType == HAEntityTypeBinarySensor);
                break;
            case EntityFilterTypeCameras:
                passesTypeFilter = (entity.entityType == HAEntityTypeCamera);
                break;
        }

        if (!passesTypeFilter) continue;

        // Apply search filter
        if (self.searchText.length > 0) {
            NSString *searchLower = [self.searchText lowercaseString];
            NSString *nameLower = [entity.friendlyName lowercaseString];
            NSString *idLower = [entity.entityId lowercaseString];
            NSString *areaLower = [entity.areaName lowercaseString] ?: @"";

            BOOL matchesSearch = ([nameLower containsString:searchLower] ||
                                 [idLower containsString:searchLower] ||
                                 [areaLower containsString:searchLower]);
            if (!matchesSearch) continue;
        }

        [results addObject:entity];
    }

    // Sort by friendly name
    [results sortUsingComparator:^NSComparisonResult(HAEntity *a, HAEntity *b) {
        return [a.friendlyName compare:b.friendlyName options:NSCaseInsensitiveSearch];
    }];

    self.filteredEntities = results;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredEntities.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"EntityCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
    }

    HBThemeManager *theme = [HBThemeManager sharedManager];
    HAEntity *entity = self.filteredEntities[indexPath.row];

    cell.backgroundColor = [theme cardBackgroundColor];
    cell.textLabel.text = entity.friendlyName;
    cell.textLabel.textColor = [theme textColor];

    // Show entity type, HA room name, and entity ID
    NSString *typeStr = [self stringForEntityType:entity.entityType];
    NSString *detailText;
    if (entity.areaName && entity.areaName.length > 0) {
        detailText = [NSString stringWithFormat:@"%@ · %@ · %@", typeStr, entity.areaName, entity.entityId];
    } else {
        detailText = [NSString stringWithFormat:@"%@ · %@", typeStr, entity.entityId];
    }
    cell.detailTextLabel.text = detailText;
    cell.detailTextLabel.textColor = [theme secondaryTextColor];

    BOOL isSelected = [self.selectedEntityIds containsObject:entity.entityId];
    cell.accessoryType = isSelected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.tintColor = [theme accentColor];

    return cell;
}

- (NSString *)stringForEntityType:(HAEntityType)type {
    switch (type) {
        case HAEntityTypeLight: return @"Light";
        case HAEntityTypeSwitch: return @"Switch";
        case HAEntityTypeSensor: return @"Sensor";
        case HAEntityTypeBinarySensor: return @"Binary Sensor";
        case HAEntityTypeCamera: return @"Camera";
        default: return @"Entity";
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    HAEntity *entity = self.filteredEntities[indexPath.row];

    if ([self.selectedEntityIds containsObject:entity.entityId]) {
        [self.selectedEntityIds removeObject:entity.entityId];
    } else {
        [self.selectedEntityIds addObject:entity.entityId];
    }

    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

@end
