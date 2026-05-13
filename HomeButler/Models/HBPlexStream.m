#import "HBPlexStream.h"

@implementation HBPlexStream

+ (instancetype)streamFromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    HBPlexStream *s = [[HBPlexStream alloc] init];
    id sid = dict[@"id"];
    if ([sid isKindOfClass:[NSNumber class]]) {
        s.streamID = [(NSNumber *)sid stringValue];
    } else if ([sid isKindOfClass:[NSString class]]) {
        s.streamID = sid;
    }
    id type = dict[@"streamType"];
    s.streamType = [type isKindOfClass:[NSNumber class]] ? [type integerValue] : HBPlexStreamTypeUnknown;
    s.language     = dict[@"language"] ?: dict[@"languageTag"];
    s.displayTitle = dict[@"displayTitle"] ?: dict[@"extendedDisplayTitle"] ?: s.language ?: @"";
    s.codec        = dict[@"codec"];
    id sel = dict[@"selected"];
    s.selected = [sel isKindOfClass:[NSNumber class]] ? [sel boolValue] : NO;
    return s;
}

@end
