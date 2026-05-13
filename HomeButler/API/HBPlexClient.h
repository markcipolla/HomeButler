#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class HBPlexItem;
@class HBPlexTarget;
@class HBPlexSession;

NS_ASSUME_NONNULL_BEGIN

typedef void (^HBPlexCompletionBlock)(BOOL success, id _Nullable result, NSError * _Nullable error);
typedef void (^HBPlexItemsBlock)(NSArray<HBPlexItem *> * _Nullable items, NSError * _Nullable error);
typedef void (^HBPlexSectionsBlock)(NSArray<NSDictionary *> * _Nullable sections, NSError * _Nullable error);
typedef void (^HBPlexTargetsBlock)(NSArray<HBPlexTarget *> * _Nullable targets, NSError * _Nullable error);
typedef void (^HBPlexSessionsBlock)(NSArray<HBPlexSession *> * _Nullable sessions, NSError * _Nullable error);
typedef void (^HBPlexImageBlock)(UIImage * _Nullable image, NSError * _Nullable error);

extern NSString * const HBPlexClientConnectionStatusChangedNotification;
extern NSString * const PlexSettingsChangedNotification;

@interface HBPlexClient : NSObject

+ (instancetype)sharedClient;

@property (nonatomic, copy, nullable)   NSString *serverURL;
@property (nonatomic, copy, nullable)   NSString *token;
@property (nonatomic, copy, nullable)   NSString *clientIdentifier;
@property (nonatomic, copy, nullable)   NSString *serverMachineIdentifier;
@property (nonatomic, strong, nullable) HBPlexTarget *currentTarget;
@property (nonatomic, assign, readonly) BOOL isConnected;
@property (nonatomic, assign) BOOL enabled;

- (BOOL)isConfigured;
- (void)reloadFromDefaults;
- (void)saveTargetToDefaults:(nullable HBPlexTarget *)target;

// Browse
- (void)fetchSectionsWithCompletion:(HBPlexSectionsBlock)completion;
- (void)fetchItemsInSection:(NSString *)sectionId
                       sort:(nullable NSString *)sort
            containerStart:(NSInteger)start
             containerSize:(NSInteger)size
                completion:(HBPlexItemsBlock)completion;
- (void)fetchOnDeckWithCompletion:(HBPlexItemsBlock)completion;
- (void)fetchRecentlyAddedWithCompletion:(HBPlexItemsBlock)completion;
- (void)fetchMetadataForRatingKey:(NSString *)ratingKey completion:(void(^)(HBPlexItem * _Nullable item, NSError * _Nullable error))completion;
- (void)fetchChildrenForRatingKey:(NSString *)ratingKey completion:(HBPlexItemsBlock)completion;
- (void)searchQuery:(NSString *)query completion:(HBPlexItemsBlock)completion;

// Targets
- (void)fetchAvailableTargetsWithCompletion:(HBPlexTargetsBlock)completion;

// Sessions
- (void)fetchActiveSessionsWithCompletion:(HBPlexSessionsBlock)completion;

// Playback
- (void)playMediaItem:(HBPlexItem *)item offset:(NSInteger)offsetMs completion:(nullable HBPlexCompletionBlock)completion;
- (void)playWithCompletion:(nullable HBPlexCompletionBlock)completion;
- (void)pauseWithCompletion:(nullable HBPlexCompletionBlock)completion;
- (void)playPauseWithCompletion:(nullable HBPlexCompletionBlock)completion;
- (void)stopWithCompletion:(nullable HBPlexCompletionBlock)completion;
- (void)skipNextWithCompletion:(nullable HBPlexCompletionBlock)completion;
- (void)skipPreviousWithCompletion:(nullable HBPlexCompletionBlock)completion;
- (void)seekToOffsetMs:(NSInteger)offsetMs completion:(nullable HBPlexCompletionBlock)completion;
- (void)setVolume:(CGFloat)volume completion:(nullable HBPlexCompletionBlock)completion;
- (void)setSubtitleStreamID:(nullable NSString *)streamID completion:(nullable HBPlexCompletionBlock)completion;
- (void)setAudioStreamID:(NSString *)streamID completion:(nullable HBPlexCompletionBlock)completion;

// Images
- (nullable NSString *)imageURLForThumbKey:(NSString *)thumbKey width:(NSInteger)w height:(NSInteger)h;
- (nullable NSURLSessionDataTask *)loadImageForThumbKey:(NSString *)thumbKey
                                                   size:(CGSize)size
                                             completion:(HBPlexImageBlock)completion;

@end

NS_ASSUME_NONNULL_END
