#import "HBPlexSession.h"
#import "HBPlexItem.h"
#import "HBPlexStream.h"

@implementation HBPlexSession

+ (instancetype)sessionFromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    HBPlexSession *s = [[HBPlexSession alloc] init];
    s.item = [HBPlexItem itemFromDictionary:dict];

    NSString *stateStr = dict[@"Player"][@"state"] ?: dict[@"state"];
    if ([stateStr isEqualToString:@"playing"])   s.state = HBPlexSessionStatePlaying;
    else if ([stateStr isEqualToString:@"paused"])    s.state = HBPlexSessionStatePaused;
    else if ([stateStr isEqualToString:@"buffering"]) s.state = HBPlexSessionStateBuffering;
    else if ([stateStr isEqualToString:@"stopped"])   s.state = HBPlexSessionStateStopped;
    else s.state = HBPlexSessionStateUnknown;

    id offset = dict[@"viewOffset"];
    s.viewOffsetMs = [offset isKindOfClass:[NSNumber class]] ? [offset integerValue] : [[offset description] integerValue];
    id duration = dict[@"duration"];
    s.durationMs = [duration isKindOfClass:[NSNumber class]] ? [duration integerValue] : [[duration description] integerValue];

    NSDictionary *player = dict[@"Player"];
    if ([player isKindOfClass:[NSDictionary class]]) {
        s.playerMachineIdentifier = player[@"machineIdentifier"];
        s.playerTitle             = player[@"title"];
    }

    // Streams from session's Media[0].Part[0].Stream[]
    NSMutableArray *audio = [NSMutableArray array];
    NSMutableArray *subs  = [NSMutableArray array];
    NSArray *mediaArr = dict[@"Media"];
    if ([mediaArr isKindOfClass:[NSArray class]] && mediaArr.count > 0) {
        NSDictionary *media = mediaArr[0];
        NSArray *parts = media[@"Part"];
        if ([parts isKindOfClass:[NSArray class]] && parts.count > 0) {
            NSDictionary *part = parts[0];
            NSArray *streams = part[@"Stream"];
            if ([streams isKindOfClass:[NSArray class]]) {
                for (NSDictionary *sd in streams) {
                    HBPlexStream *st = [HBPlexStream streamFromDictionary:sd];
                    if (st.streamType == HBPlexStreamTypeAudio) {
                        [audio addObject:st];
                        if (st.selected) s.selectedAudioStreamID = st.streamID;
                    } else if (st.streamType == HBPlexStreamTypeSubtitle) {
                        [subs addObject:st];
                        if (st.selected) s.selectedSubtitleStreamID = st.streamID;
                    }
                }
            }
        }
    }
    s.audioStreams    = audio;
    s.subtitleStreams = subs;

    id vol = dict[@"Player"][@"volume"];
    if ([vol isKindOfClass:[NSNumber class]]) {
        CGFloat v = [vol floatValue];
        if (v > 1.0) v = v / 100.0;
        s.volume = v;
    } else {
        s.volume = 1.0;
    }

    return s;
}

@end
