#import "HAEntity.h"

@implementation HAEntity

+ (instancetype)entityFromDictionary:(NSDictionary *)dict {
    HAEntity *entity = [[HAEntity alloc] init];
    entity.entityId = dict[@"entity_id"];
    entity.state = dict[@"state"];
    entity.attributes = dict[@"attributes"];
    entity.friendlyName = entity.attributes[@"friendly_name"] ?: entity.entityId;
    entity.entityType = [self typeFromEntityId:entity.entityId];

    // Try to extract area/room name from various HA attributes
    // Check for common attribute names that contain area info
    NSDictionary *attrs = entity.attributes;
    if (attrs) {
        // Try various attribute names that Home Assistant might use for area
        NSString *area = attrs[@"area_name"];
        if (!area) area = attrs[@"room"];
        if (!area) area = attrs[@"location"];
        if (!area) {
            // Check if friendly_name contains a room prefix (e.g., "Living Room Light" -> "Living Room")
            NSString *friendlyName = attrs[@"friendly_name"];
            if (friendlyName && friendlyName.length > 0) {
                // Look for common room name patterns at the start
                NSArray *commonRooms = @[@"Kitchen", @"Living Room", @"Bedroom", @"Bathroom", @"Office",
                                         @"Dining Room", @"Garage", @"Basement", @"Attic", @"Porch",
                                         @"Patio", @"Hallway", @"Closet", @"Laundry", @"Nursery",
                                         @"Guest Room", @"Master Bedroom", @"Kids Room", @"Study"];
                for (NSString *roomName in commonRooms) {
                    if ([friendlyName hasPrefix:roomName] && friendlyName.length > roomName.length) {
                        area = roomName;
                        break;
                    }
                }
            }
        }
        entity.areaName = area;
    }

    return entity;
}

+ (HAEntityType)typeFromEntityId:(NSString *)entityId {
    if ([entityId hasPrefix:@"light."]) {
        return HAEntityTypeLight;
    } else if ([entityId hasPrefix:@"switch."]) {
        return HAEntityTypeSwitch;
    } else if ([entityId hasPrefix:@"sensor."]) {
        return HAEntityTypeSensor;
    } else if ([entityId hasPrefix:@"camera."]) {
        return HAEntityTypeCamera;
    } else if ([entityId hasPrefix:@"binary_sensor."]) {
        return HAEntityTypeBinarySensor;
    } else if ([entityId hasPrefix:@"script."]) {
        return HAEntityTypeScript;
    } else if ([entityId hasPrefix:@"input_boolean."]) {
        return HAEntityTypeInputBoolean;
    }
    return HAEntityTypeUnknown;
}

- (BOOL)isOn {
    if (!self.state || ![self.state isKindOfClass:[NSString class]]) {
        return NO;
    }
    return [self.state isEqualToString:@"on"];
}

- (NSString *)icon {
    switch (self.entityType) {
        case HAEntityTypeLight:
            return self.isOn ? @"💡" : @"⚪️";
        case HAEntityTypeSwitch:
            return self.isOn ? @"🔌" : @"⚫️";
        case HAEntityTypeSensor:
            return @"📊";
        case HAEntityTypeCamera:
            return @"📷";
        case HAEntityTypeBinarySensor:
            return self.isOn ? @"✓" : @"✗";
        case HAEntityTypeScript:
            return @"▶️";
        case HAEntityTypeInputBoolean:
            return self.isOn ? @"✓" : @"○";
        default:
            return @"❓";
    }
}

- (UIColor *)stateColor {
    if (self.isOn) {
        return [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
    } else {
        return [UIColor grayColor];
    }
}

- (BOOL)supportsBrightness {
    // Check if entity has brightness attribute or supported_features includes brightness
    if (self.entityType != HAEntityTypeLight) {
        return NO;
    }

    // Defensive check for attributes
    if (!self.attributes || ![self.attributes isKindOfClass:[NSDictionary class]]) {
        return NO;
    }

    // Check for brightness in attributes (indicates it supports it)
    id brightnessValue = self.attributes[@"brightness"];
    if (brightnessValue && ![brightnessValue isKindOfClass:[NSNull class]]) {
        return YES;
    }

    // Check supported_features bitmask (bit 0 = brightness)
    id supportedFeatures = self.attributes[@"supported_features"];
    if (supportedFeatures && [supportedFeatures isKindOfClass:[NSNumber class]]) {
        if ([supportedFeatures integerValue] & 1) {
            return YES;
        }
    }

    // Also check supported_color_modes
    id colorModesValue = self.attributes[@"supported_color_modes"];
    if (colorModesValue && [colorModesValue isKindOfClass:[NSArray class]]) {
        NSArray *colorModes = (NSArray *)colorModesValue;
        for (id modeObj in colorModes) {
            if ([modeObj isKindOfClass:[NSString class]]) {
                NSString *mode = (NSString *)modeObj;
                if ([mode isEqualToString:@"brightness"] ||
                    [mode isEqualToString:@"color_temp"] ||
                    [mode isEqualToString:@"hs"] ||
                    [mode isEqualToString:@"rgb"] ||
                    [mode isEqualToString:@"rgbw"] ||
                    [mode isEqualToString:@"xy"]) {
                    return YES;
                }
            }
        }
    }

    return NO;
}

- (NSInteger)brightness {
    // Home Assistant brightness is 0-255, convert to 0-100
    if (!self.attributes || ![self.attributes isKindOfClass:[NSDictionary class]]) {
        return self.isOn ? 100 : 0;
    }

    id brightnessValue = self.attributes[@"brightness"];
    if (brightnessValue && [brightnessValue isKindOfClass:[NSNumber class]]) {
        return (NSInteger)([brightnessValue floatValue] / 255.0 * 100.0);
    }
    return self.isOn ? 100 : 0;
}

@end
