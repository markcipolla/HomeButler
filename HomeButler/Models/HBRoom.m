#import "HBRoom.h"

@implementation HBRoom

+ (instancetype)roomWithName:(NSString *)name iconType:(NSInteger)iconType {
    HBRoom *room = [[HBRoom alloc] init];
    room.roomId = [[NSUUID UUID] UUIDString];
    room.name = name;
    room.iconType = iconType;
    room.entityIds = [NSMutableArray array];
    room.sortOrder = 0;
    return room;
}

- (void)addEntityId:(NSString *)entityId {
    if (![self.entityIds containsObject:entityId]) {
        [self.entityIds addObject:entityId];
    }
}

- (void)removeEntityId:(NSString *)entityId {
    [self.entityIds removeObject:entityId];
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.roomId forKey:@"roomId"];
    [coder encodeObject:self.name forKey:@"name"];
    [coder encodeInteger:self.iconType forKey:@"iconType"];
    [coder encodeObject:self.entityIds forKey:@"entityIds"];
    [coder encodeInteger:self.sortOrder forKey:@"sortOrder"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        self.roomId = [coder decodeObjectForKey:@"roomId"];
        self.name = [coder decodeObjectForKey:@"name"];
        self.iconType = [coder decodeIntegerForKey:@"iconType"];
        self.entityIds = [[coder decodeObjectForKey:@"entityIds"] mutableCopy];
        self.sortOrder = [coder decodeIntegerForKey:@"sortOrder"];

        if (!self.entityIds) {
            self.entityIds = [NSMutableArray array];
        }
    }
    return self;
}

@end

#pragma mark - HBRoomManager

@interface HBRoomManager ()
@property (nonatomic, strong) NSMutableArray<HBRoom *> *mutableRooms;
@end

@implementation HBRoomManager

+ (instancetype)sharedManager {
    static HBRoomManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadRooms];
    }
    return self;
}

- (NSArray<HBRoom *> *)rooms {
    return [self.mutableRooms copy];
}

- (void)loadRooms {
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"HBRooms"];
    if (data) {
        // Suppress deprecation warning - we need iOS 9.3.5 compatibility
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSArray *rooms = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        #pragma clang diagnostic pop
        self.mutableRooms = [rooms mutableCopy];
    } else {
        self.mutableRooms = [NSMutableArray array];
    }
}

- (void)saveRooms {
    // Suppress deprecation warning - we need iOS 9.3.5 compatibility
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.mutableRooms];
    #pragma clang diagnostic pop
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"HBRooms"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)addRoom:(HBRoom *)room {
    room.sortOrder = self.mutableRooms.count;
    [self.mutableRooms addObject:room];
    [self saveRooms];
}

- (void)removeRoom:(HBRoom *)room {
    [self.mutableRooms removeObject:room];
    [self saveRooms];
}

- (void)updateRoom:(HBRoom *)room {
    [self saveRooms];
}

- (void)moveRoomFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex {
    if (fromIndex < 0 || fromIndex >= self.mutableRooms.count) return;
    if (toIndex < 0 || toIndex >= self.mutableRooms.count) return;

    HBRoom *room = self.mutableRooms[fromIndex];
    [self.mutableRooms removeObjectAtIndex:fromIndex];
    [self.mutableRooms insertObject:room atIndex:toIndex];

    for (NSInteger i = 0; i < self.mutableRooms.count; i++) {
        self.mutableRooms[i].sortOrder = i;
    }
    [self saveRooms];
}

- (HBRoom *)roomWithId:(NSString *)roomId {
    for (HBRoom *room in self.mutableRooms) {
        if ([room.roomId isEqualToString:roomId]) {
            return room;
        }
    }
    return nil;
}

@end
