#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, HBPlexItemType) {
    HBPlexItemTypeUnknown,
    HBPlexItemTypeMovie,
    HBPlexItemTypeShow,
    HBPlexItemTypeSeason,
    HBPlexItemTypeEpisode,
    HBPlexItemTypeClip,
    HBPlexItemTypeArtist,
    HBPlexItemTypeAlbum,
    HBPlexItemTypeTrack
};

@interface HBPlexItem : NSObject

@property (nonatomic, copy) NSString *ratingKey;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *guid;
@property (nonatomic, assign) HBPlexItemType type;
@property (nonatomic, copy) NSString *typeString;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *parentTitle;
@property (nonatomic, copy) NSString *grandparentTitle;
@property (nonatomic, copy) NSString *summary;
@property (nonatomic, copy) NSString *thumb;
@property (nonatomic, copy) NSString *art;
@property (nonatomic, copy) NSString *parentThumb;
@property (nonatomic, copy) NSString *grandparentThumb;
@property (nonatomic, assign) NSInteger durationMs;
@property (nonatomic, assign) NSInteger viewOffsetMs;
@property (nonatomic, assign) NSInteger year;
@property (nonatomic, assign) NSInteger index;       // episode/season index
@property (nonatomic, assign) NSInteger parentIndex; // parent's index
@property (nonatomic, copy) NSString *librarySectionID;
@property (nonatomic, copy) NSString *librarySectionTitle;
@property (nonatomic, assign) NSInteger leafCount;
@property (nonatomic, assign) NSInteger viewedLeafCount;
@property (nonatomic, assign) NSInteger childCount;

+ (instancetype)itemFromDictionary:(NSDictionary *)dict;

- (NSString *)displayTitle;
- (NSString *)displaySubtitle;
- (CGFloat)progressFraction;     // 0.0 - 1.0
- (NSString *)preferredThumbKey; // best thumb for vertical poster

@end
