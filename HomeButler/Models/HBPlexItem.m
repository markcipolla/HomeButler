#import "HBPlexItem.h"

@implementation HBPlexItem

+ (instancetype)itemFromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    HBPlexItem *item = [[HBPlexItem alloc] init];

    id ratingKey = dict[@"ratingKey"];
    if ([ratingKey isKindOfClass:[NSNumber class]]) {
        item.ratingKey = [(NSNumber *)ratingKey stringValue];
    } else if ([ratingKey isKindOfClass:[NSString class]]) {
        item.ratingKey = ratingKey;
    }

    item.key                  = [self stringFromDict:dict key:@"key"];
    item.guid                 = [self stringFromDict:dict key:@"guid"];
    item.typeString           = [self stringFromDict:dict key:@"type"];
    item.title                = [self stringFromDict:dict key:@"title"];
    item.parentTitle          = [self stringFromDict:dict key:@"parentTitle"];
    item.grandparentTitle     = [self stringFromDict:dict key:@"grandparentTitle"];
    item.summary              = [self stringFromDict:dict key:@"summary"];
    item.thumb                = [self stringFromDict:dict key:@"thumb"];
    item.art                  = [self stringFromDict:dict key:@"art"];
    item.parentThumb          = [self stringFromDict:dict key:@"parentThumb"];
    item.grandparentThumb     = [self stringFromDict:dict key:@"grandparentThumb"];
    item.librarySectionID     = [self stringFromDict:dict key:@"librarySectionID"];
    item.librarySectionTitle  = [self stringFromDict:dict key:@"librarySectionTitle"];

    item.durationMs      = [[self numberFromDict:dict key:@"duration"] integerValue];
    item.viewOffsetMs    = [[self numberFromDict:dict key:@"viewOffset"] integerValue];
    item.year            = [[self numberFromDict:dict key:@"year"] integerValue];
    item.index           = [[self numberFromDict:dict key:@"index"] integerValue];
    item.parentIndex     = [[self numberFromDict:dict key:@"parentIndex"] integerValue];
    item.leafCount       = [[self numberFromDict:dict key:@"leafCount"] integerValue];
    item.viewedLeafCount = [[self numberFromDict:dict key:@"viewedLeafCount"] integerValue];
    item.childCount      = [[self numberFromDict:dict key:@"childCount"] integerValue];

    item.type = [self typeFromString:item.typeString];

    return item;
}

+ (NSString *)stringFromDict:(NSDictionary *)dict key:(NSString *)key {
    id v = dict[key];
    if ([v isKindOfClass:[NSString class]]) return v;
    if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v stringValue];
    return nil;
}

+ (NSNumber *)numberFromDict:(NSDictionary *)dict key:(NSString *)key {
    id v = dict[key];
    if ([v isKindOfClass:[NSNumber class]]) return v;
    if ([v isKindOfClass:[NSString class]]) return @([(NSString *)v longLongValue]);
    return @(0);
}

+ (HBPlexItemType)typeFromString:(NSString *)s {
    if (!s) return HBPlexItemTypeUnknown;
    if ([s isEqualToString:@"movie"])   return HBPlexItemTypeMovie;
    if ([s isEqualToString:@"show"])    return HBPlexItemTypeShow;
    if ([s isEqualToString:@"season"])  return HBPlexItemTypeSeason;
    if ([s isEqualToString:@"episode"]) return HBPlexItemTypeEpisode;
    if ([s isEqualToString:@"clip"])    return HBPlexItemTypeClip;
    if ([s isEqualToString:@"artist"])  return HBPlexItemTypeArtist;
    if ([s isEqualToString:@"album"])   return HBPlexItemTypeAlbum;
    if ([s isEqualToString:@"track"])   return HBPlexItemTypeTrack;
    return HBPlexItemTypeUnknown;
}

- (NSString *)displayTitle {
    switch (self.type) {
        case HBPlexItemTypeEpisode:
            if (self.grandparentTitle.length > 0) return self.grandparentTitle;
            return self.title ?: @"";
        case HBPlexItemTypeSeason:
            if (self.parentTitle.length > 0) return self.parentTitle;
            return self.title ?: @"";
        default:
            return self.title ?: @"";
    }
}

- (NSString *)displaySubtitle {
    switch (self.type) {
        case HBPlexItemTypeEpisode: {
            NSString *se = [NSString stringWithFormat:@"S%ld · E%ld", (long)self.parentIndex, (long)self.index];
            if (self.title.length > 0) return [NSString stringWithFormat:@"%@ — %@", se, self.title];
            return se;
        }
        case HBPlexItemTypeSeason:
            return [NSString stringWithFormat:@"Season %ld", (long)self.index];
        case HBPlexItemTypeMovie:
            if (self.year > 0) return [NSString stringWithFormat:@"%ld", (long)self.year];
            return @"";
        case HBPlexItemTypeShow:
            if (self.year > 0) return [NSString stringWithFormat:@"%ld", (long)self.year];
            return @"";
        default:
            return @"";
    }
}

- (CGFloat)progressFraction {
    if (self.durationMs <= 0) return 0.0;
    CGFloat f = (CGFloat)self.viewOffsetMs / (CGFloat)self.durationMs;
    if (f < 0) f = 0;
    if (f > 1) f = 1;
    return f;
}

- (NSString *)preferredThumbKey {
    switch (self.type) {
        case HBPlexItemTypeEpisode:
            if (self.grandparentThumb.length > 0) return self.grandparentThumb;
            if (self.parentThumb.length > 0) return self.parentThumb;
            return self.thumb;
        case HBPlexItemTypeSeason:
            if (self.parentThumb.length > 0) return self.parentThumb;
            return self.thumb;
        default:
            return self.thumb;
    }
}

@end
