#import <Foundation/Foundation.h>

@class HBPlexItem;
@class HBPlexStream;

typedef NS_ENUM(NSInteger, HBPlexSessionState) {
    HBPlexSessionStateUnknown,
    HBPlexSessionStatePlaying,
    HBPlexSessionStatePaused,
    HBPlexSessionStateBuffering,
    HBPlexSessionStateStopped
};

@interface HBPlexSession : NSObject

@property (nonatomic, strong) HBPlexItem *item;
@property (nonatomic, assign) HBPlexSessionState state;
@property (nonatomic, assign) NSInteger viewOffsetMs;
@property (nonatomic, assign) NSInteger durationMs;
@property (nonatomic, copy)   NSString *playerMachineIdentifier;
@property (nonatomic, copy)   NSString *playerTitle;
@property (nonatomic, strong) NSArray<HBPlexStream *> *audioStreams;
@property (nonatomic, strong) NSArray<HBPlexStream *> *subtitleStreams;
@property (nonatomic, copy)   NSString *selectedAudioStreamID;
@property (nonatomic, copy)   NSString *selectedSubtitleStreamID;
@property (nonatomic, assign) CGFloat volume; // 0..1

+ (instancetype)sessionFromDictionary:(NSDictionary *)dict;

@end
