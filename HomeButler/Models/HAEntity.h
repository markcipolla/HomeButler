#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, HAEntityType) {
    HAEntityTypeUnknown,
    HAEntityTypeLight,
    HAEntityTypeSwitch,
    HAEntityTypeSensor,
    HAEntityTypeCamera,
    HAEntityTypeBinarySensor,
    HAEntityTypeScript,
    HAEntityTypeInputBoolean,
    HAEntityTypeVacuum,
    HAEntityTypeButton,
    HAEntityTypeFan,
    HAEntityTypeClimate,
    HAEntityTypeNumber,
    HAEntityTypeSelect
};

@interface HAEntity : NSObject

@property (nonatomic, strong) NSString *entityId;
@property (nonatomic, strong) NSString *friendlyName;
@property (nonatomic, strong) NSString *state;
@property (nonatomic, strong) NSDictionary *attributes;
@property (nonatomic, assign) HAEntityType entityType;
@property (nonatomic, strong) NSString *areaName; // Home Assistant area/room name

+ (instancetype)entityFromDictionary:(NSDictionary *)dict;
- (BOOL)isOn;
- (NSString *)icon;
- (UIColor *)stateColor;
- (BOOL)supportsBrightness;
- (NSInteger)brightness; // 0-100 percentage

@end
