#import "HBPlexClient.h"
#import "HBPlexItem.h"
#import "HBPlexTarget.h"
#import "HBPlexSession.h"

NSString * const HBPlexClientConnectionStatusChangedNotification = @"HBPlexClientConnectionStatusChangedNotification";
NSString * const PlexSettingsChangedNotification = @"PlexSettingsChangedNotification";

static NSString * const kDefaultsPlexEnabled        = @"PlexEnabled";
static NSString * const kDefaultsPlexServerURL      = @"PlexServerURL";
static NSString * const kDefaultsPlexToken          = @"PlexToken";
static NSString * const kDefaultsPlexClientId       = @"PlexClientIdentifier";
static NSString * const kDefaultsPlexServerMachine  = @"PlexServerMachineId";
static NSString * const kDefaultsPlexTargetName     = @"PlexTargetClientName";
static NSString * const kDefaultsPlexTargetIP       = @"PlexTargetClientIP";
static NSString * const kDefaultsPlexTargetPort     = @"PlexTargetClientPort";
static NSString * const kDefaultsPlexTargetMachine  = @"PlexTargetClientMachineId";
static NSString * const kDefaultsPlexCommandID      = @"PlexCommandID";

@interface HBPlexClient () <NSURLSessionDelegate>
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSCache *imageCache;
@property (nonatomic, assign, readwrite) BOOL isConnected;
@end

@implementation HBPlexClient

+ (instancetype)sharedClient {
    static HBPlexClient *sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedClient = [[self alloc] init];
    });
    return sharedClient;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 30.0;
        config.timeoutIntervalForResource = 60.0;
        _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];

        _imageCache = [[NSCache alloc] init];
        _imageCache.countLimit = 200;
        _imageCache.totalCostLimit = 64 * 1024 * 1024;

        [self reloadFromDefaults];
    }
    return self;
}

- (void)reloadFromDefaults {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    _enabled                 = [d boolForKey:kDefaultsPlexEnabled];
    _serverURL               = [d stringForKey:kDefaultsPlexServerURL];
    _token                   = [d stringForKey:kDefaultsPlexToken];
    _clientIdentifier        = [d stringForKey:kDefaultsPlexClientId];
    _serverMachineIdentifier = [d stringForKey:kDefaultsPlexServerMachine];

    NSString *name    = [d stringForKey:kDefaultsPlexTargetName];
    NSString *host    = [d stringForKey:kDefaultsPlexTargetIP];
    NSInteger port    = [d integerForKey:kDefaultsPlexTargetPort];
    NSString *machine = [d stringForKey:kDefaultsPlexTargetMachine];
    if (name.length > 0 && host.length > 0 && machine.length > 0) {
        HBPlexTarget *t = [[HBPlexTarget alloc] init];
        t.name = name;
        t.host = host;
        t.port = (port > 0 ? port : 32500);
        t.machineIdentifier = machine;
        _currentTarget = t;
    }
}

- (void)saveTargetToDefaults:(HBPlexTarget *)target {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (target) {
        [d setObject:target.name              ?: @"" forKey:kDefaultsPlexTargetName];
        [d setObject:target.host              ?: @"" forKey:kDefaultsPlexTargetIP];
        [d setInteger:target.port                     forKey:kDefaultsPlexTargetPort];
        [d setObject:target.machineIdentifier ?: @"" forKey:kDefaultsPlexTargetMachine];
    } else {
        [d removeObjectForKey:kDefaultsPlexTargetName];
        [d removeObjectForKey:kDefaultsPlexTargetIP];
        [d removeObjectForKey:kDefaultsPlexTargetPort];
        [d removeObjectForKey:kDefaultsPlexTargetMachine];
    }
    [d synchronize];
    self.currentTarget = target;
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDefaultsPlexEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setServerURL:(NSString *)serverURL {
    _serverURL = [serverURL copy];
    [[NSUserDefaults standardUserDefaults] setObject:serverURL ?: @"" forKey:kDefaultsPlexServerURL];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setToken:(NSString *)token {
    _token = [token copy];
    [[NSUserDefaults standardUserDefaults] setObject:token ?: @"" forKey:kDefaultsPlexToken];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setClientIdentifier:(NSString *)clientIdentifier {
    _clientIdentifier = [clientIdentifier copy];
    [[NSUserDefaults standardUserDefaults] setObject:clientIdentifier ?: @"" forKey:kDefaultsPlexClientId];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setServerMachineIdentifier:(NSString *)serverMachineIdentifier {
    _serverMachineIdentifier = [serverMachineIdentifier copy];
    [[NSUserDefaults standardUserDefaults] setObject:serverMachineIdentifier ?: @"" forKey:kDefaultsPlexServerMachine];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)isConfigured {
    return self.serverURL.length > 0 && self.token.length > 0;
}

- (void)setConnectionStatus:(BOOL)connected {
    if (self.isConnected != connected) {
        self.isConnected = connected;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:HBPlexClientConnectionStatusChangedNotification
                                                                object:self
                                                              userInfo:@{@"connected": @(connected)}];
        });
    }
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

#pragma mark - Headers

- (NSDictionary *)plexHeaders {
    NSString *bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0";
    UIDevice *device = [UIDevice currentDevice];
    NSMutableDictionary *h = [NSMutableDictionary dictionary];
    h[@"Accept"]                  = @"application/json";
    h[@"X-Plex-Token"]            = self.token ?: @"";
    h[@"X-Plex-Product"]          = @"HomeButler";
    h[@"X-Plex-Version"]          = bundleVersion;
    h[@"X-Plex-Client-Identifier"]= self.clientIdentifier ?: @"";
    h[@"X-Plex-Device"]           = device.model ?: @"iOS";
    h[@"X-Plex-Device-Name"]      = device.name ?: @"HomeButler";
    h[@"X-Plex-Platform"]         = @"iOS";
    h[@"X-Plex-Platform-Version"] = device.systemVersion ?: @"";
    return h;
}

- (NSInteger)nextCommandID {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSInteger current = [d integerForKey:kDefaultsPlexCommandID];
    current += 1;
    [d setInteger:current forKey:kDefaultsPlexCommandID];
    [d synchronize];
    return current;
}

#pragma mark - Request builder

- (NSMutableURLRequest *)plexRequestWithPath:(NSString *)path
                                       query:(NSDictionary *)query
                                     baseURL:(NSString *)baseURL
                                      method:(NSString *)method {
    NSMutableString *urlStr = [NSMutableString stringWithFormat:@"%@%@", baseURL, path];
    if (query.count > 0) {
        NSMutableArray *pairs = [NSMutableArray array];
        for (NSString *k in query) {
            id v = query[k];
            NSString *vs = [v isKindOfClass:[NSString class]] ? v : [v description];
            NSCharacterSet *allowed = [NSCharacterSet URLQueryAllowedCharacterSet];
            NSString *encV = [vs stringByAddingPercentEncodingWithAllowedCharacters:allowed];
            [pairs addObject:[NSString stringWithFormat:@"%@=%@", k, encV]];
        }
        [urlStr appendFormat:@"?%@", [pairs componentsJoinedByString:@"&"]];
    }
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = method ?: @"GET";
    NSDictionary *headers = [self plexHeaders];
    for (NSString *k in headers) {
        [req setValue:headers[k] forHTTPHeaderField:k];
    }
    return req;
}

#pragma mark - Dispatch helper

- (void)runJSONRequest:(NSURLRequest *)req completion:(void(^)(id _Nullable jsonRoot, NSError * _Nullable error))completion {
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [self setConnectionStatus:NO];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, error);
            });
            return;
        }
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        if (http.statusCode < 200 || http.statusCode >= 300) {
            [self setConnectionStatus:NO];
            NSError *err = [NSError errorWithDomain:@"HBPlexClient" code:http.statusCode userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP %ld", (long)http.statusCode]}];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, err);
            });
            return;
        }
        id json = nil;
        NSError *parseError = nil;
        if (data && data.length > 0) {
            json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
        }
        if (parseError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, parseError);
            });
            return;
        }
        [self setConnectionStatus:YES];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(json, nil);
        });
    }];
    [task resume];
}

- (NSDictionary *)mediaContainerFromRoot:(id)json {
    if (![json isKindOfClass:[NSDictionary class]]) return nil;
    return json[@"MediaContainer"];
}

- (NSArray *)metadataFromRoot:(id)json {
    NSDictionary *mc = [self mediaContainerFromRoot:json];
    id md = mc[@"Metadata"];
    if ([md isKindOfClass:[NSArray class]]) return md;
    return @[];
}

- (NSArray<HBPlexItem *> *)itemsFromMetadataArray:(NSArray *)metadata {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *d in metadata) {
        HBPlexItem *i = [HBPlexItem itemFromDictionary:d];
        if (i) [out addObject:i];
    }
    return out;
}

#pragma mark - Browse

- (void)fetchSectionsWithCompletion:(HBPlexSectionsBlock)completion {
    if (![self isConfigured]) { if (completion) completion(nil, [self notConfiguredError]); return; }
    NSURLRequest *req = [self plexRequestWithPath:@"/library/sections" query:nil baseURL:self.serverURL method:@"GET"];
    [self runJSONRequest:req completion:^(id json, NSError *err) {
        if (err) { if (completion) completion(nil, err); return; }
        NSDictionary *mc = [self mediaContainerFromRoot:json];
        // Cache server machine ID if present
        NSString *machine = mc[@"machineIdentifier"];
        if (machine.length > 0 && ![machine isEqualToString:self.serverMachineIdentifier]) {
            self.serverMachineIdentifier = machine;
        }
        id dir = mc[@"Directory"];
        NSArray *sections = [dir isKindOfClass:[NSArray class]] ? dir : @[];
        if (completion) completion(sections, nil);
    }];
}

- (void)fetchItemsInSection:(NSString *)sectionId
                       sort:(NSString *)sort
            containerStart:(NSInteger)start
             containerSize:(NSInteger)size
                completion:(HBPlexItemsBlock)completion {
    if (![self isConfigured]) { if (completion) completion(nil, [self notConfiguredError]); return; }
    NSString *path = [NSString stringWithFormat:@"/library/sections/%@/all", sectionId];
    NSMutableDictionary *q = [NSMutableDictionary dictionary];
    if (sort) q[@"sort"] = sort;
    q[@"X-Plex-Container-Start"] = @(start);
    q[@"X-Plex-Container-Size"]  = @(size > 0 ? size : 50);
    NSURLRequest *req = [self plexRequestWithPath:path query:q baseURL:self.serverURL method:@"GET"];
    [self runJSONRequest:req completion:^(id json, NSError *err) {
        if (err) { if (completion) completion(nil, err); return; }
        if (completion) completion([self itemsFromMetadataArray:[self metadataFromRoot:json]], nil);
    }];
}

- (void)fetchOnDeckWithCompletion:(HBPlexItemsBlock)completion {
    if (![self isConfigured]) { if (completion) completion(nil, [self notConfiguredError]); return; }
    NSURLRequest *req = [self plexRequestWithPath:@"/library/onDeck" query:nil baseURL:self.serverURL method:@"GET"];
    [self runJSONRequest:req completion:^(id json, NSError *err) {
        if (err) { if (completion) completion(nil, err); return; }
        if (completion) completion([self itemsFromMetadataArray:[self metadataFromRoot:json]], nil);
    }];
}

- (void)fetchRecentlyAddedWithCompletion:(HBPlexItemsBlock)completion {
    if (![self isConfigured]) { if (completion) completion(nil, [self notConfiguredError]); return; }
    NSURLRequest *req = [self plexRequestWithPath:@"/library/recentlyAdded" query:nil baseURL:self.serverURL method:@"GET"];
    [self runJSONRequest:req completion:^(id json, NSError *err) {
        if (err) { if (completion) completion(nil, err); return; }
        if (completion) completion([self itemsFromMetadataArray:[self metadataFromRoot:json]], nil);
    }];
}

- (void)fetchMetadataForRatingKey:(NSString *)ratingKey completion:(void(^)(HBPlexItem * _Nullable item, NSError * _Nullable error))completion {
    if (![self isConfigured]) { if (completion) completion(nil, [self notConfiguredError]); return; }
    NSString *path = [NSString stringWithFormat:@"/library/metadata/%@", ratingKey];
    NSURLRequest *req = [self plexRequestWithPath:path query:nil baseURL:self.serverURL method:@"GET"];
    [self runJSONRequest:req completion:^(id json, NSError *err) {
        if (err) { if (completion) completion(nil, err); return; }
        NSArray *md = [self metadataFromRoot:json];
        HBPlexItem *item = md.count > 0 ? [HBPlexItem itemFromDictionary:md[0]] : nil;
        if (completion) completion(item, nil);
    }];
}

- (void)fetchChildrenForRatingKey:(NSString *)ratingKey completion:(HBPlexItemsBlock)completion {
    if (![self isConfigured]) { if (completion) completion(nil, [self notConfiguredError]); return; }
    NSString *path = [NSString stringWithFormat:@"/library/metadata/%@/children", ratingKey];
    NSURLRequest *req = [self plexRequestWithPath:path query:nil baseURL:self.serverURL method:@"GET"];
    [self runJSONRequest:req completion:^(id json, NSError *err) {
        if (err) { if (completion) completion(nil, err); return; }
        if (completion) completion([self itemsFromMetadataArray:[self metadataFromRoot:json]], nil);
    }];
}

- (void)searchQuery:(NSString *)query completion:(HBPlexItemsBlock)completion {
    if (![self isConfigured]) { if (completion) completion(nil, [self notConfiguredError]); return; }
    if (query.length == 0) { if (completion) completion(@[], nil); return; }
    NSURLRequest *req = [self plexRequestWithPath:@"/hubs/search" query:@{@"query": query, @"limit": @"30"} baseURL:self.serverURL method:@"GET"];
    [self runJSONRequest:req completion:^(id json, NSError *err) {
        if (err) { if (completion) completion(nil, err); return; }
        NSDictionary *mc = [self mediaContainerFromRoot:json];
        NSArray *hubs = mc[@"Hub"];
        if (![hubs isKindOfClass:[NSArray class]]) { if (completion) completion(@[], nil); return; }

        NSDictionary *order = @{@"movie": @0, @"show": @1, @"episode": @2, @"artist": @3, @"album": @4, @"track": @5};
        NSArray *sortedHubs = [hubs sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            NSNumber *oa = order[a[@"type"]] ?: @99;
            NSNumber *ob = order[b[@"type"]] ?: @99;
            return [oa compare:ob];
        }];
        NSMutableArray *out = [NSMutableArray array];
        for (NSDictionary *hub in sortedHubs) {
            NSArray *md = hub[@"Metadata"];
            if ([md isKindOfClass:[NSArray class]]) {
                for (NSDictionary *d in md) {
                    HBPlexItem *i = [HBPlexItem itemFromDictionary:d];
                    if (i) [out addObject:i];
                }
            }
        }
        if (completion) completion(out, nil);
    }];
}

#pragma mark - Targets

- (void)fetchAvailableTargetsWithCompletion:(HBPlexTargetsBlock)completion {
    if (![self isConfigured]) { if (completion) completion(nil, [self notConfiguredError]); return; }
    NSURLRequest *req = [self plexRequestWithPath:@"/clients" query:nil baseURL:self.serverURL method:@"GET"];
    [self runJSONRequest:req completion:^(id json, NSError *err) {
        if (err) { if (completion) completion(nil, err); return; }
        NSDictionary *mc = [self mediaContainerFromRoot:json];
        id arr = mc[@"Server"];
        NSMutableArray *targets = [NSMutableArray array];
        if ([arr isKindOfClass:[NSArray class]]) {
            for (NSDictionary *d in arr) {
                HBPlexTarget *t = [HBPlexTarget targetFromDictionary:d];
                if (t) [targets addObject:t];
            }
        }
        if (completion) completion(targets, nil);
    }];
}

#pragma mark - Sessions

- (void)fetchActiveSessionsWithCompletion:(HBPlexSessionsBlock)completion {
    if (![self isConfigured]) { if (completion) completion(nil, [self notConfiguredError]); return; }
    NSURLRequest *req = [self plexRequestWithPath:@"/status/sessions" query:nil baseURL:self.serverURL method:@"GET"];
    [self runJSONRequest:req completion:^(id json, NSError *err) {
        if (err) { if (completion) completion(nil, err); return; }
        NSArray *md = [self metadataFromRoot:json];
        NSMutableArray *out = [NSMutableArray array];
        for (NSDictionary *d in md) {
            HBPlexSession *s = [HBPlexSession sessionFromDictionary:d];
            if (!s) continue;
            // Filter to current target machine
            if (self.currentTarget.machineIdentifier.length > 0) {
                if (![s.playerMachineIdentifier isEqualToString:self.currentTarget.machineIdentifier]) {
                    continue;
                }
            }
            [out addObject:s];
        }
        if (completion) completion(out, nil);
    }];
}

#pragma mark - Playback

- (NSString *)serverHostOnly {
    NSURL *u = [NSURL URLWithString:self.serverURL];
    return u.host ?: @"";
}

- (NSInteger)serverPort {
    NSURL *u = [NSURL URLWithString:self.serverURL];
    return u.port.integerValue > 0 ? u.port.integerValue : 32400;
}

- (NSString *)serverScheme {
    NSURL *u = [NSURL URLWithString:self.serverURL];
    return u.scheme ?: @"http";
}

- (NSString *)targetBaseURL {
    if (!self.currentTarget) return nil;
    return [NSString stringWithFormat:@"http://%@:%ld", self.currentTarget.host, (long)self.currentTarget.port];
}

- (void)sendPlaybackCommand:(NSString *)command extraQuery:(NSDictionary *)extra completion:(HBPlexCompletionBlock)completion {
    if (!self.currentTarget) {
        if (completion) completion(NO, nil, [self noTargetError]);
        return;
    }
    NSString *path = [NSString stringWithFormat:@"/player/playback/%@", command];
    NSMutableDictionary *q = [NSMutableDictionary dictionary];
    if (extra) [q addEntriesFromDictionary:extra];
    q[@"commandID"] = @([self nextCommandID]);
    NSMutableURLRequest *req = [self plexRequestWithPath:path query:q baseURL:[self targetBaseURL] method:@"GET"];
    [req setValue:self.currentTarget.machineIdentifier forHTTPHeaderField:@"X-Plex-Target-Client-Identifier"];
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        BOOL success = NO;
        if (!error) {
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            success = (http.statusCode >= 200 && http.statusCode < 300);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(success, data, error);
        });
    }];
    [task resume];
}

- (void)playMediaItem:(HBPlexItem *)item offset:(NSInteger)offsetMs completion:(HBPlexCompletionBlock)completion {
    if (!self.currentTarget) { if (completion) completion(NO, nil, [self noTargetError]); return; }
    NSMutableDictionary *q = [NSMutableDictionary dictionary];
    q[@"key"]               = [NSString stringWithFormat:@"/library/metadata/%@", item.ratingKey];
    q[@"offset"]            = @(offsetMs);
    q[@"machineIdentifier"] = self.serverMachineIdentifier ?: @"";
    q[@"address"]           = [self serverHostOnly];
    q[@"port"]              = @([self serverPort]);
    q[@"protocol"]          = [self serverScheme];
    q[@"token"]             = self.token ?: @"";
    [self sendPlaybackCommand:@"playMedia" extraQuery:q completion:completion];
}

- (void)playWithCompletion:(HBPlexCompletionBlock)completion          { [self sendPlaybackCommand:@"play"      extraQuery:nil completion:completion]; }
- (void)pauseWithCompletion:(HBPlexCompletionBlock)completion         { [self sendPlaybackCommand:@"pause"     extraQuery:nil completion:completion]; }
- (void)playPauseWithCompletion:(HBPlexCompletionBlock)completion     { [self sendPlaybackCommand:@"playPause" extraQuery:nil completion:completion]; }
- (void)stopWithCompletion:(HBPlexCompletionBlock)completion          { [self sendPlaybackCommand:@"stop"      extraQuery:nil completion:completion]; }
- (void)skipNextWithCompletion:(HBPlexCompletionBlock)completion      { [self sendPlaybackCommand:@"skipNext"  extraQuery:nil completion:completion]; }
- (void)skipPreviousWithCompletion:(HBPlexCompletionBlock)completion  { [self sendPlaybackCommand:@"skipPrevious" extraQuery:nil completion:completion]; }

- (void)seekToOffsetMs:(NSInteger)offsetMs completion:(HBPlexCompletionBlock)completion {
    [self sendPlaybackCommand:@"seekTo" extraQuery:@{@"offset": @(offsetMs)} completion:completion];
}

- (void)setVolume:(CGFloat)volume completion:(HBPlexCompletionBlock)completion {
    NSInteger v = (NSInteger)round(volume * 100.0);
    if (v < 0) v = 0; if (v > 100) v = 100;
    [self sendPlaybackCommand:@"setParameters" extraQuery:@{@"volume": @(v)} completion:completion];
}

- (void)setSubtitleStreamID:(NSString *)streamID completion:(HBPlexCompletionBlock)completion {
    NSString *sid = streamID ?: @"0";
    [self sendPlaybackCommand:@"setStreams" extraQuery:@{@"subtitleStreamID": sid, @"type": @"video"} completion:completion];
}

- (void)setAudioStreamID:(NSString *)streamID completion:(HBPlexCompletionBlock)completion {
    [self sendPlaybackCommand:@"setStreams" extraQuery:@{@"audioStreamID": streamID ?: @"", @"type": @"video"} completion:completion];
}

#pragma mark - Images

- (NSString *)imageURLForThumbKey:(NSString *)thumbKey width:(NSInteger)w height:(NSInteger)h {
    if (thumbKey.length == 0 || !self.serverURL) return nil;
    NSString *innerURL = [NSString stringWithFormat:@"%@%@", self.serverURL, thumbKey];
    NSCharacterSet *allowed = [NSCharacterSet URLQueryAllowedCharacterSet];
    NSString *enc = [innerURL stringByAddingPercentEncodingWithAllowedCharacters:allowed];
    return [NSString stringWithFormat:@"%@/photo/:/transcode?width=%ld&height=%ld&url=%@&X-Plex-Token=%@",
            self.serverURL, (long)w, (long)h, enc, self.token ?: @""];
}

- (NSURLSessionDataTask *)loadImageForThumbKey:(NSString *)thumbKey
                                          size:(CGSize)size
                                    completion:(HBPlexImageBlock)completion {
    if (thumbKey.length == 0) { if (completion) completion(nil, nil); return nil; }
    NSInteger w = (NSInteger)round(size.width  * [UIScreen mainScreen].scale);
    NSInteger h = (NSInteger)round(size.height * [UIScreen mainScreen].scale);
    NSString *url = [self imageURLForThumbKey:thumbKey width:w height:h];
    if (!url) { if (completion) completion(nil, nil); return nil; }

    UIImage *cached = [self.imageCache objectForKey:url];
    if (cached) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(cached, nil);
        });
        return nil;
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    NSDictionary *headers = [self plexHeaders];
    for (NSString *k in headers) [req setValue:headers[k] forHTTPHeaderField:k];
    [req setValue:@"image/*" forHTTPHeaderField:@"Accept"];

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || data.length == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, error);
            });
            return;
        }
        UIImage *img = [UIImage imageWithData:data];
        if (img) {
            NSUInteger cost = data.length;
            [self.imageCache setObject:img forKey:url cost:cost];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(img, nil);
        });
    }];
    [task resume];
    return task;
}

#pragma mark - Errors

- (NSError *)notConfiguredError {
    return [NSError errorWithDomain:@"HBPlexClient" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Plex client not configured"}];
}

- (NSError *)noTargetError {
    return [NSError errorWithDomain:@"HBPlexClient" code:2 userInfo:@{NSLocalizedDescriptionKey: @"No Plex playback target selected"}];
}

@end
