#import "HAAPIClient.h"
#import "HAEntity.h"

NSString * const HAAPIClientConnectionStatusChangedNotification = @"HAAPIClientConnectionStatusChangedNotification";

@interface HAAPIClient () <NSURLSessionDelegate>

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, assign, readwrite) BOOL isConnected;

@end

@implementation HAAPIClient

+ (instancetype)sharedClient {
    static HAAPIClient *sharedClient = nil;
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

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        _baseURL = [defaults stringForKey:@"HABaseURL"];
        _accessToken = [defaults stringForKey:@"HAAccessToken"];
    }
    return self;
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {
    // Bypass SSL certificate validation for self-signed/untrusted certificates
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

- (void)configureWithBaseURL:(NSString *)baseURL accessToken:(NSString *)accessToken {
    self.baseURL = baseURL;
    self.accessToken = accessToken;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:baseURL forKey:@"HABaseURL"];
    [defaults setObject:accessToken forKey:@"HAAccessToken"];
    [defaults synchronize];
}

- (BOOL)isConfigured {
    return self.baseURL && self.accessToken && self.baseURL.length > 0 && self.accessToken.length > 0;
}

- (void)setConnectionStatus:(BOOL)connected {
    if (self.isConnected != connected) {
        self.isConnected = connected;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:HAAPIClientConnectionStatusChangedNotification
                                                                object:self
                                                              userInfo:@{@"connected": @(connected)}];
        });
    }
}

- (void)fetchStatesWithCompletion:(HAEntitiesBlock)completion {
    if (![self isConfigured]) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"HAAPIClient" code:1 userInfo:@{NSLocalizedDescriptionKey: @"API client not configured"}];
            completion(nil, error);
        }
        return;
    }

    NSString *urlString = [NSString stringWithFormat:@"%@/api/states", self.baseURL];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", self.accessToken] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [self setConnectionStatus:NO];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, error);
            });
            return;
        }

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode != 200) {
            [self setConnectionStatus:NO];
            NSError *statusError = [NSError errorWithDomain:@"HAAPIClient" code:httpResponse.statusCode userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP %ld", (long)httpResponse.statusCode]}];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, statusError);
            });
            return;
        }

        NSError *parseError;
        NSArray *jsonArray = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];

        if (parseError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, parseError);
            });
            return;
        }

        [self setConnectionStatus:YES];

        NSMutableArray *entities = [NSMutableArray array];
        for (NSDictionary *dict in jsonArray) {
            HAEntity *entity = [HAEntity entityFromDictionary:dict];
            [entities addObject:entity];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(entities, nil);
        });
    }];

    [task resume];
}

- (void)callService:(NSString *)domain
            service:(NSString *)service
           entityId:(NSString *)entityId
         parameters:(NSDictionary *)parameters
         completion:(HACompletionBlock)completion {
    if (![self isConfigured]) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"HAAPIClient" code:1 userInfo:@{NSLocalizedDescriptionKey: @"API client not configured"}];
            completion(NO, nil, error);
        }
        return;
    }

    NSString *urlString = [NSString stringWithFormat:@"%@/api/services/%@/%@", self.baseURL, domain, service];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", self.accessToken] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    body[@"entity_id"] = entityId;
    if (parameters) {
        [body addEntriesFromDictionary:parameters];
    }

    NSError *jsonError;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
    if (jsonError) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, nil, jsonError);
            });
        }
        return;
    }

    [request setHTTPBody:jsonData];

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, nil, error);
            });
            return;
        }

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        BOOL success = (httpResponse.statusCode == 200 || httpResponse.statusCode == 201);

        id result = nil;
        if (data && data.length > 0) {
            NSError *parseError;
            result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(success, result, error);
        });
    }];

    [task resume];
}

- (void)turnOnEntity:(NSString *)entityId completion:(HACompletionBlock)completion {
    NSString *domain = [[entityId componentsSeparatedByString:@"."] firstObject];
    // Buttons use "press" service instead of "turn_on"
    NSString *service = [domain isEqualToString:@"button"] ? @"press" : @"turn_on";
    [self callService:domain service:service entityId:entityId parameters:nil completion:completion];
}

- (void)turnOffEntity:(NSString *)entityId completion:(HACompletionBlock)completion {
    NSString *domain = [[entityId componentsSeparatedByString:@"."] firstObject];
    [self callService:domain service:@"turn_off" entityId:entityId parameters:nil completion:completion];
}

- (void)setLightBrightness:(NSString *)entityId brightness:(NSInteger)brightness completion:(HACompletionBlock)completion {
    NSDictionary *params = @{@"brightness": @(brightness)};
    [self callService:@"light" service:@"turn_on" entityId:entityId parameters:params completion:completion];
}

- (void)setLightColor:(NSString *)entityId red:(NSInteger)red green:(NSInteger)green blue:(NSInteger)blue completion:(HACompletionBlock)completion {
    NSDictionary *params = @{@"rgb_color": @[@(red), @(green), @(blue)]};
    [self callService:@"light" service:@"turn_on" entityId:entityId parameters:params completion:completion];
}

- (NSString *)cameraStreamURLForEntity:(NSString *)entityId {
    if (![self isConfigured]) {
        return nil;
    }
    return [NSString stringWithFormat:@"%@/api/camera_proxy/%@", self.baseURL, entityId];
}

- (void)fetchWeatherForecastForEntity:(NSString *)entityId completion:(HACompletionBlock)completion {
    if (![self isConfigured]) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"HAAPIClient" code:1 userInfo:@{NSLocalizedDescriptionKey: @"API client not configured"}];
            completion(NO, nil, error);
        }
        return;
    }

    // Try the newer weather.get_forecasts service first (HA 2023.12+)
    [self tryForecastService:entityId type:@"daily" completion:completion];
}

- (void)tryForecastService:(NSString *)entityId type:(NSString *)forecastType completion:(HACompletionBlock)completion {
    // Note: ?return_response is required for HA 2024+ to get service response data
    NSString *urlString = [NSString stringWithFormat:@"%@/api/services/weather/get_forecasts?return_response", self.baseURL];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", self.accessToken] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSDictionary *body = @{
        @"entity_id": entityId,
        @"type": forecastType
    };

    NSLog(@"[HAAPIClient] Fetching forecast for %@ from %@", entityId, urlString);
    NSLog(@"[HAAPIClient] Request body: %@", body);

    NSError *jsonError;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
    if (jsonError) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, nil, jsonError);
            });
        }
        return;
    }

    [request setHTTPBody:jsonData];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"[HAAPIClient] Forecast network error: %@", error);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, nil, error);
            });
            return;
        }

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSLog(@"[HAAPIClient] Forecast response status: %ld", (long)httpResponse.statusCode);

        id result = nil;
        NSError *parseError = nil;
        if (data && data.length > 0) {
            NSString *responseStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"[HAAPIClient] Forecast response body: %@", responseStr);
            result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            if (parseError) {
                NSLog(@"[HAAPIClient] Forecast parse error: %@", parseError);
            }
        }

        BOOL success = (httpResponse.statusCode == 200 || httpResponse.statusCode == 201);

        // If we got a 404 or service not found, try fetching entity state directly
        if (httpResponse.statusCode == 404 || httpResponse.statusCode == 400) {
            NSLog(@"[HAAPIClient] Service not available, trying direct entity state fetch");
            [weakSelf fetchEntityState:entityId completion:completion];
            return;
        }

        if (!success) {
            NSError *statusError = [NSError errorWithDomain:@"HAAPIClient" code:httpResponse.statusCode userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP %ld", (long)httpResponse.statusCode]}];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, result, statusError);
            });
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(YES, result, nil);
        });
    }];

    [task resume];
}

- (void)fetchEntityState:(NSString *)entityId completion:(HACompletionBlock)completion {
    // Fetch the entity state directly - forecast might be in attributes (older HA versions)
    NSString *urlString = [NSString stringWithFormat:@"%@/api/states/%@", self.baseURL, entityId];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", self.accessToken] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSLog(@"[HAAPIClient] Fetching entity state from %@", urlString);

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"[HAAPIClient] Entity state network error: %@", error);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, nil, error);
            });
            return;
        }

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSLog(@"[HAAPIClient] Entity state response status: %ld", (long)httpResponse.statusCode);

        BOOL success = (httpResponse.statusCode == 200);

        id result = nil;
        if (data && data.length > 0) {
            NSString *responseStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"[HAAPIClient] Entity state response: %@", responseStr);
            NSError *parseError = nil;
            result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            if (parseError) {
                NSLog(@"[HAAPIClient] Entity state parse error: %@", parseError);
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(success, result, error);
        });
    }];

    [task resume];
}

@end
