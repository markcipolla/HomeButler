#import <Foundation/Foundation.h>

@interface HBRoom : NSObject <NSCoding>

@property (nonatomic, strong) NSString *roomId;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, assign) NSInteger iconType; // HBIconType value
@property (nonatomic, strong) NSMutableArray<NSString *> *entityIds;
@property (nonatomic, assign) NSInteger sortOrder;

+ (instancetype)roomWithName:(NSString *)name iconType:(NSInteger)iconType;
- (void)addEntityId:(NSString *)entityId;
- (void)removeEntityId:(NSString *)entityId;

@end

// Room Storage Manager
@interface HBRoomManager : NSObject

+ (instancetype)sharedManager;

@property (nonatomic, readonly) NSArray<HBRoom *> *rooms;

- (void)addRoom:(HBRoom *)room;
- (void)removeRoom:(HBRoom *)room;
- (void)updateRoom:(HBRoom *)room;
- (void)moveRoomFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex;
- (void)saveRooms;
- (HBRoom *)roomWithId:(NSString *)roomId;

@end
