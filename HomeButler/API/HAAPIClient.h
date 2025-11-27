#import <Foundation/Foundation.h>

@class HAEntity;

NS_ASSUME_NONNULL_BEGIN

typedef void (^HACompletionBlock)(BOOL success, id _Nullable result, NSError * _Nullable error);
typedef void (^HAEntitiesBlock)(NSArray<HAEntity *> * _Nullable entities, NSError * _Nullable error);

@interface HAAPIClient : NSObject

+ (instancetype)sharedClient;

@property (nonatomic, strong, nullable) NSString *baseURL;
@property (nonatomic, strong, nullable) NSString *accessToken;

- (void)configureWithBaseURL:(NSString *)baseURL accessToken:(NSString *)accessToken;
- (BOOL)isConfigured;

- (void)fetchStatesWithCompletion:(HAEntitiesBlock)completion;
- (void)callService:(NSString *)domain
            service:(NSString *)service
           entityId:(NSString *)entityId
         parameters:(NSDictionary * _Nullable)parameters
         completion:(nullable HACompletionBlock)completion;

- (void)turnOnEntity:(NSString *)entityId completion:(nullable HACompletionBlock)completion;
- (void)turnOffEntity:(NSString *)entityId completion:(nullable HACompletionBlock)completion;
- (void)setLightBrightness:(NSString *)entityId brightness:(NSInteger)brightness completion:(nullable HACompletionBlock)completion;
- (void)setLightColor:(NSString *)entityId red:(NSInteger)red green:(NSInteger)green blue:(NSInteger)blue completion:(nullable HACompletionBlock)completion;

- (nullable NSString *)cameraStreamURLForEntity:(NSString *)entityId;

// Weather
- (void)fetchWeatherForecastForEntity:(NSString *)entityId completion:(nullable HACompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
