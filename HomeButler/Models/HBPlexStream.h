#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, HBPlexStreamType) {
    HBPlexStreamTypeUnknown  = 0,
    HBPlexStreamTypeVideo    = 1,
    HBPlexStreamTypeAudio    = 2,
    HBPlexStreamTypeSubtitle = 3
};

@interface HBPlexStream : NSObject

@property (nonatomic, copy)   NSString *streamID;       // Plex `id` field as string
@property (nonatomic, assign) HBPlexStreamType streamType;
@property (nonatomic, copy)   NSString *language;
@property (nonatomic, copy)   NSString *displayTitle;
@property (nonatomic, copy)   NSString *codec;
@property (nonatomic, assign) BOOL selected;

+ (instancetype)streamFromDictionary:(NSDictionary *)dict;

@end
