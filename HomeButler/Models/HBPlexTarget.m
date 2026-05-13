#import "HBPlexTarget.h"

@implementation HBPlexTarget

+ (instancetype)targetFromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    HBPlexTarget *t = [[HBPlexTarget alloc] init];
    t.name                 = dict[@"name"]              ?: dict[@"title"];
    t.machineIdentifier    = dict[@"machineIdentifier"] ?: dict[@"clientIdentifier"];
    t.host                 = dict[@"host"]              ?: dict[@"address"];
    id portVal             = dict[@"port"];
    if ([portVal isKindOfClass:[NSNumber class]]) {
        t.port = [(NSNumber *)portVal integerValue];
    } else if ([portVal isKindOfClass:[NSString class]]) {
        t.port = [(NSString *)portVal integerValue];
    } else {
        t.port = 32500;
    }
    if (t.port == 0) t.port = 32500;
    t.product              = dict[@"product"];
    t.deviceClass          = dict[@"deviceClass"];
    t.protocolCapabilities = dict[@"protocolCapabilities"];
    return t;
}

- (BOOL)supportsPlayback {
    if (!self.protocolCapabilities) return YES; // assume yes if not declared
    NSRange r = [self.protocolCapabilities rangeOfString:@"playback"];
    return r.location != NSNotFound;
}

@end
