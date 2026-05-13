#import <Foundation/Foundation.h>

@interface HBPlexTarget : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *machineIdentifier;
@property (nonatomic, copy) NSString *host;
@property (nonatomic, assign) NSInteger port;
@property (nonatomic, copy) NSString *product;
@property (nonatomic, copy) NSString *deviceClass;
@property (nonatomic, copy) NSString *protocolCapabilities;

+ (instancetype)targetFromDictionary:(NSDictionary *)dict;

- (BOOL)supportsPlayback;

@end
