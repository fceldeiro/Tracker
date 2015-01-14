	//
//  MLDejavu.m
//  MercadoLibre
//
//  Created by Fabian Celdeiro on 2/21/14.
//  Copyright (c) 2014 Casa. All rights reserved.
//

#import "MLDejavu.h"

#import "MLDejavuRequestSerializer.h"
#import "NSDictionary+URLQueryString.h"
#import "NSString+URLEncode.h"
#import "MLDejavuTrack.h"
#import "MLDejavuDAOCoreData.h"
#import "MLDejavu_PrivateMethods.h"
#import <AFNetworking/AFNetworking.h>
#import "MSWeakTimer.h"
#import "MLDejavuTrackInPool.h"
#import "MLLogger.h"
#import "MLDejavuFlowData.h"
#import "MLRequestUtils.h"

//LOG SYNC

#ifdef DEBUG
    #if defined( LOG_ASYNC_ENABLED )
    #undef LOG_ASYNC_ENABLED
    #define LOG_ASYNC_ENABLED NO
    #endif
#endif

#define kOperationUserInfoKeyForParameters @"parameterString"
#define kMLDejavuStatus @"MLDejavuStatus"

@interface MLDejavu()

@end

@implementation MLDejavu

#pragma mark - Init methods
//INIT ------------------------------------------------------------------------------------------------------


+(void) initialize{
    MLLogActivateForClass(self);
}

// Singleton for manager
+ (instancetype) sharedTracker{
    
    
    //  Static local predicate must be initialized to 0
    static MLDejavu *sharedInstance = nil;
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[MLDejavu alloc] init];
        // Do any other initialisation stuff here
    });
    return sharedInstance;
    
    
}

-(id) init{
    if (self =[super init]){
        
        self.dryRun = NO;
        
        _trackerEnabled = NO;
        
        self.serialQueue = dispatch_queue_create("com.mercadolibre.dejavu-tracker", DISPATCH_QUEUE_SERIAL);
        
        self.manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:kMLDejavuURI]];
        
        //Sets a name for the manager queue of AFNetworking
        [self.manager.operationQueue setName:@"MLDejavuQueue"];
        
        //Only 1 operation can be called simultaneusly
        [self.manager.operationQueue setMaxConcurrentOperationCount:1];
        
        //Serializer that form the requests (handle headers, body and uri format)
        [self.manager setRequestSerializer:[MLDejavuRequestSerializer serializer]];
        
        //Serializer that form the response, we use a default so far.
        [self.manager setResponseSerializer:[AFHTTPResponseSerializer serializer]];
        
        self.currentPool = [NSMutableArray arrayWithCapacity:kMLDejavuDefaultMaxRequestsToQueue];
        
        self.dispatchInterval = kMLDejavuDefaultDispatchInterval;
        
        self.flowData = [NSMutableDictionary dictionaryWithCapacity:10];
    
    
        self.dejavuDAO = [[MLDejavuDAOCoreData alloc] initWithName:kDejavuDefaultDAOName];
        
        self.flowDuration = kMLDejavuDefaultFlowDuration;
    
        __weak typeof(self) weakSelf = self;
        
        //Block to handle success request
        
        self.successBlock = ^(AFHTTPRequestOperation *operation, id responseObject) {
            
            if (!weakSelf){
                return;
            }
            dispatch_async(weakSelf.serialQueue, ^{
                
                //The completed element is removed , we don't needed anymore since the track is already sent.
                
                if (weakSelf.currentPool.count > 0){
                    
                    MLDejavuTrackInPool * trackSent = weakSelf.currentPool[0];
                    
                    if (![weakSelf.dejavuDAO deleteObject:trackSent.objectIdSent]){
                     //   NSLog(@"Object doesn't exist in database anymore");
                    }
                    
                    [weakSelf.currentPool removeObjectAtIndex:0];

                }
                
                //If the pool is empty we release the background task and start the timer again
                if (weakSelf.currentPool.count == 0){
                    
                    [MLLogger logWithLevel:MLLoggerDebug forClass:[weakSelf class] text:@"Current pool completed"];
                    
                    NSUInteger count = [weakSelf.dejavuDAO getDejavuTrackCount];
                    if(count == NSNotFound) {
                        //Handle error
                    }
                    else if (count == 0){
                        
                        [MLLogger logWithLevel:MLLoggerDebug forClass:[weakSelf class] text:@"All tracks completed"];
                        
                        //Mato el timer
                        [weakSelf stopTimer];
                        
                        if (weakSelf.bgTask != UIBackgroundTaskInvalid){
                            [[UIApplication sharedApplication] endBackgroundTask:weakSelf.bgTask];
                            weakSelf.bgTask = UIBackgroundTaskInvalid;
                        }
                        
                    }
                    else{
                        [weakSelf startTimer];
                    }
                }
                //If we still have elements in the pool we repeat the process
                else{
                    
                    [weakSelf GET:kMLDejavuGETResource withDejavuTrackInPool:weakSelf.currentPool[0]];
                }

                
            });
        } ;
        
        //Block to handle request failures
        self.failureBlock = ^(AFHTTPRequestOperation *operation, NSError *error) {
            
            if (!weakSelf){
                return;
            }
            dispatch_async(weakSelf.serialQueue, ^{
                
                if (operation){
                    NSString *paramString = [operation.request.URL.query substringFromIndex:[@"dejavu=" length]];
                    paramString = [paramString urlDecode];
                    NSString * dateString = [[paramString dictionaryFromQueryComponents][@"date_created"] lastObject];
                    NSString * pageIdString = [[paramString dictionaryFromQueryComponents][@"page_id"] lastObject];
                    if (dateString && pageIdString){
                        [MLLogger logWithLevel:MLLoggerError message:[NSString stringWithFormat:@"Error %@ - %@", pageIdString,dateString]];

                    }
                    else if (dateString){
                        [MLLogger logWithLevel:MLLoggerError message:[NSString stringWithFormat:@"Error %@",dateString]];
                    }
                }
                

                //ERROR! mandar todo al pool original y comenzar devuelta
                
                //We reset the currentPool
                weakSelf.currentPool = [NSMutableArray arrayWithCapacity:kMLDejavuDefaultMaxRequestsToQueue];
                
                //The timer starts again so the request can try again later
                [weakSelf startTimer];

            });
            
        };
        
        
        AFNetworkReachabilityManager *rechabilityManager = [AFNetworkReachabilityManager sharedManager];
        [rechabilityManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            //MLLogInfo(@"Network status changed %d",status);
        }];
        
        self.bgTask = UIBackgroundTaskInvalid;
        
        
        if ([[NSUserDefaults standardUserDefaults] objectForKey:kMLDejavuStatus]){
            _trackerEnabled = [[[NSUserDefaults standardUserDefaults] objectForKey:kMLDejavuStatus] boolValue];
        }
        else{
            _trackerEnabled = NO;
        }
        
        
        
        
      
        

        
    }
    return self;
}

-(void) dealloc{

    [self.manager.operationQueue cancelAllOperations];
    
    [self.timer invalidate];
    self.timer = nil;
    

}

#pragma mark - Class methods


+(void) startWithAPIKey:(NSString*) apiKey andDispatchInterval:(NSTimeInterval) interval andSid:(NSString*) sid{
    
    
        [[MLDejavu sharedTracker] setApiKey:apiKey];
        [[MLDejavu sharedTracker] setDispatchInterval:interval];
        [[MLDejavu sharedTracker] setSid:sid];
    
    
        MLLogInfo(@"MLDejavu: Starting session");
    
    
}



+(void) trackPageWithName:(NSString *)name andFlowData:(MLDejavuFlowData*) flowData{
    
    [self trackPageWithName:name andFlowData:flowData andExtraParameters:nil];
}

+(void) trackPageWithName:(NSString *)name andFlowData:(MLDejavuFlowData *)flowData andExtraParameters:(NSDictionary *)extraParameters {
    
    if (![[MLDejavu sharedTracker] trackerEnabled]){
        return;
    }
    [[MLDejavu sharedTracker] trackPageWithName:name andFlowData:flowData andExtraParameters:extraParameters];
}


+(void) trackEventWithName:(NSString *)name andSourcePageName:(NSString*) sourcePageName andFlowData:(MLDejavuFlowData*) flowData andExtraParameters:(NSDictionary*) extraParameters{
    
    if (![[MLDejavu sharedTracker] trackerEnabled]){
        return;
    }
    
    [[MLDejavu sharedTracker] trackEventWithName:name andSourcePageName:sourcePageName andFlowData:flowData andExtraParameters:extraParameters];


}

+(void) trackWithExtraParameters:(NSDictionary*) extraParameters{
    
    if (![[MLDejavu sharedTracker] trackerEnabled]){
        return;
    }
    
    [[MLDejavu sharedTracker] trackWithParameters:extraParameters];
    
    

}


+(void) dispatch{
    
    if (![[MLDejavu sharedTracker] trackerEnabled]){
        return;
    }
    
    [[MLDejavu sharedTracker] dispatch];
    
}


+(MLDejavuFlowData*) updatedFlowDataForKey:(NSString*) key withFlowName:(NSString*) flowName withExtraParameters:(NSDictionary *)extraParameters {
    
    MLDejavu *sharedTracker = [MLDejavu sharedTracker];
    return [sharedTracker updatedFlowDataForKey:key withFlowName:flowName withExtraParameters:extraParameters];

}

+(void) removeFlowDataForKey:(NSString*)key{

    [[MLDejavu sharedTracker] removeFlowDataForKey:key];
}

+(void) removeFlowData:(MLDejavuFlowData*) flowData{
    
    
    [[MLDejavu sharedTracker] removeFlowData:flowData];
}

+(void) resetAllFlows{
    
    [[MLDejavu sharedTracker] resetAllFlows];
}
+(void) resetAllTracks{
    
    [[MLDejavu sharedTracker] resetAllTracks];
}

+(void) setSID:(NSString*) sid{
    
    [[MLDejavu sharedTracker] setSid:sid];
}
+(void) setCommonParameters:(NSDictionary*) commonParameters{
    [[MLDejavu sharedTracker] setCommonParameters:commonParameters];
}

+(void) setTrackerEnabled:(BOOL)enabled{
    
    if ([[MLDejavu sharedTracker] trackerEnabled] != enabled){
        [[MLDejavu sharedTracker] setTrackerEnabled:enabled];
    }

}

#pragma mark - Instance private methods class extension

-(void) setSid:(NSString *)sid{

    @synchronized(self){
        _sid = [sid copy];
        if ([self.manager.requestSerializer isKindOfClass:[MLDejavuRequestSerializer class]]){
            
            [(MLDejavuRequestSerializer*)self.manager.requestSerializer setSid:sid];
        }
    }

    
}


-(void) setDispatchInterval:(NSTimeInterval)dispatchInterval{
    
    //If the timer set is too small we set a default value that is of 5 seconds
    //If its 0 , the dispatch is manual
    
    NSTimeInterval oldDispatchInterval = _dispatchInterval;

    
    if (dispatchInterval < kMLDejavuDispatchIntervalMinimum && dispatchInterval != 0.0 ){
        _dispatchInterval = kMLDejavuDispatchIntervalMinimum;
    }
    else {
        _dispatchInterval = dispatchInterval;
    }
    
    if (oldDispatchInterval > 0.0 && _dispatchInterval == 0){
        [self stopTimer];
    }

    if (oldDispatchInterval == 0.0 && _dispatchInterval > 0.0){
        [self startTimer];
    }
}

//Used to start timer for automatic dispatch.
-(void) startTimer{
    
    if (!self.timer){
        [self stopTimer];
        
        if (self.dispatchInterval > 0 && self.trackerEnabled){
        
            MLLogInfo(@"Starting timer...");
            
            self.timer = [MSWeakTimer scheduledTimerWithTimeInterval:self.dispatchInterval target:self selector:@selector(sendRequests:) userInfo:nil repeats:NO dispatchQueue:self.serialQueue];
        }
    }
   
}
-(void) stopTimer{
    
    if (self.timer){
        MLLogInfo(@"Stopping timer...");
        [self.timer invalidate];
        self.timer = nil;
    }
    
}

-(AFHTTPRequestOperation*) createGETOperation:(NSString*)URLString withDejavuTrackInPool:(MLDejavuTrackInPool*) dejavuTrackInPool{
    
    NSString * parameter = dejavuTrackInPool.parameterSent;
    
    if (parameter){
        NSDictionary *parameters = @{@"dejavu":parameter};
    
        NSMutableURLRequest *request = [self.manager.requestSerializer requestWithMethod:@"GET" URLString:[[NSURL URLWithString:URLString relativeToURL:self.manager.baseURL] absoluteString] parameters:parameters error:nil];
        AFHTTPRequestOperation *operation = [self.manager HTTPRequestOperationWithRequest:request success:self.successBlock failure:self.failureBlock];
        [operation setUserInfo:@{kOperationUserInfoKeyForParameters:parameters}];
    
        return operation;
    }
    else{
        return nil;
    }
}
// Creates an AFHTTPRequest operation object , adds it to the queue and starts, using the default blocks defined in -(id) init to manage response
//URLString last part of the url ej: pixel.gif
//Track: DejavuTrack object with parameters in string and date of creation

- (AFHTTPRequestOperation *)GET:(NSString *)URLString withDejavuTrackInPool:(MLDejavuTrackInPool*) dejavuTrackInPool{


    AFHTTPRequestOperation* operation = [self createGETOperation:URLString withDejavuTrackInPool:dejavuTrackInPool];

    if (operation && !self.dryRun){
        [self.manager.operationQueue addOperation:operation];

    }
    return operation;


}


-(void) dispatch{
    
    
    if (!self.trackerEnabled){
        return;
    }
    
    dispatch_async(self.serialQueue, ^{
        
        if (!self.sid){
            MLLogDebug(@"Not logging because sid not set");
            return;
        }
        /*
        //No pude actualizar la cookie
        if (![self updateCookieForCookieStorage:[NSHTTPCookieStorage sharedHTTPCookieStorage]]){
            DDLogDebug(@"Omitting dispatch, cookies not updated");
            return;
        }
         */
        MLLogDebug(@"Dispatching");
        
        //Invalido el timer
        [self stopTimer];
        
        [self.dejavuDAO deleteTracksOlderThan:[NSDate dateWithTimeInterval:-(3600*24*30) sinceDate:[NSDate date]]];
        
        //Our max pool size
        
        NSError* fetchError = nil;
        NSArray * tracksForPool = [self.dejavuDAO getDejavuTracksForPoolOrderedAscending:YES withLimit:kMLDejavuDefaultMaxRequestsToQueue withError:&fetchError];
        
        self.currentPool = [NSMutableArray arrayWithArray:tracksForPool];
        
        //INITIAL GET
        //If we have elements in the pool we create a background task and launch the first GET request.
        if (self.currentPool.count > 0 && ![self.manager.operationQueue operationCount] ){
            
            [self GET:kMLDejavuGETResource withDejavuTrackInPool:self.currentPool[0]];
        }
        
        //NO HACER ESTO POR AHORA, EL ADD TRACK LO VA A SOLUCIONAR
        if (self.currentPool.count == 0 && self.manager.operationQueue.operationCount == 0){
        //IF we dont have elements in the pool , we start the timer again.
            MLLogDebug(@"Nothing to dispatch");
          //  [self startTimer];
        }

        
    });
    
    

}

// Method call for autmatic dispatch
-(void) sendRequests:(MSWeakTimer*)timer{
    
        MLLogDebug(@"Timer ticked..");
        
        [self.timer invalidate];
        self.timer = nil;
        
        [self dispatch];


    

}


-(void) resetAllTracks{
    
    dispatch_barrier_async(self.serialQueue, ^{
        MLLogInfo(@"About to reset all tracks");
        [self.dejavuDAO deletePersistentObject];
     //   self.currentPool = [NSMutableArray array];
        MLLogInfo(@"All tracks deleted");
    });
    
}


-(MLDejavuFlowData*) createFlowDataForKey:(NSString*) key withName:(NSString*) name withExtraParameters:(NSDictionary*) extraParameters andDate:(NSDate*) date{
    

    MLDejavuFlowData * flowData = [[MLDejavuFlowData alloc] init];
    [flowData setFlowName:name];
    NSString *flowId = [[NSUUID UUID] UUIDString];
    [flowData setFlowId:flowId];
    
    if (date){
        [flowData setDateCreated:date];
    }
    else{
        [flowData setDateCreated:[NSDate date]];
    }
    
    [flowData setExtraParameters:extraParameters];
    
    if (!self.flowData){
        self.flowData = [NSMutableDictionary dictionary];
    }
    
    [[self flowData] setObject:flowData forKey:key];
    return flowData;

}
-(MLDejavuFlowData*) updatedFlowDataForKey:(NSString*) key withFlowName:(NSString*) flowName withExtraParameters:(NSDictionary *)extraParameters withDateToCompareWith:(NSDate*) date{
    
    MLDejavuFlowData * oldFlowData = [[self flowData] objectForKey:key];
    
    //Si existe un old data
    if (oldFlowData){
        //me fijo si vencio
        NSDate * flowDataDate = oldFlowData.dateCreated;
        
        NSTimeInterval distanceBetweenDates = [date timeIntervalSinceDate:flowDataDate];
        
        if (distanceBetweenDates > self.flowDuration){
            
            [self.flowData removeObjectForKey:key];
            return [self createFlowDataForKey:key withName:flowName withExtraParameters:extraParameters andDate:[NSDate date]];
        }
        else{
            //Reseteo el flow date
            [oldFlowData setDateCreated:[NSDate date]];
            return oldFlowData;
        }
        
    }
    //Si no existe lo creo y lo inserto en el mapa
    else{
        return [self createFlowDataForKey:key withName:flowName withExtraParameters:extraParameters andDate:[NSDate date]];
    }

}
//Returns an updated flow data if it hasnt expired, otherwise returns a new one.
//flowName: name of the flow ej: CHECKOUT
//newFlowId: id fow the flow, will only be used if there is now flow data object or has expired ej:hash

-(MLDejavuFlowData*) updatedFlowDataForKey:(NSString*) key withFlowName:(NSString*) flowName withExtraParameters:(NSDictionary *)extraParameters{
    
    return [self updatedFlowDataForKey:key withFlowName:flowName withExtraParameters:extraParameters withDateToCompareWith:[NSDate date]];
 
}


-(void) removeFlowDataForKey:(NSString*) key{
    
    if ([[self flowData] objectForKey:key]){
        [[self flowData] removeObjectForKey:key];
    }
    
}

-(void) removeFlowData:(MLDejavuFlowData*) flowData{
    
    NSMutableDictionary * flowDataDictionary = [self flowData];
    for (NSString * key in flowDataDictionary){
        if (flowDataDictionary[key] == flowData){
            [flowDataDictionary removeObjectForKey:key];
            return;
        }
    }
    
}

- (void) resetAllFlows{
    
    self.flowData = [NSMutableDictionary dictionary];
}


#pragma mark - Tracks
//Store the track in an array for later dispatch
-(void) trackWithParameters:(NSDictionary*) parameters{
    
    
    
    if (!self.trackerEnabled){
        return;
    }
    
    dispatch_async(self.serialQueue, ^{
        
        if (!self.apiKey){
            return;
        }
        
        //CREATION OF ALL EXTRA PARAMETERS
        [self setCommonParameters:[MLRequestUtils getDejavuGenericParameters]];
        
        //Create custom date stamp
        NSDate *dateTemp = [NSDate date];
        
        
        
        NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
        [dateFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
        NSString *dateString = [dateFormat stringFromDate:dateTemp];
        
        
        NSMutableDictionary * parametersWithExtra = [NSMutableDictionary dictionaryWithDictionary:parameters];
        //Le agrego la fecha del track
        [parametersWithExtra setObject:[NSString stringWithFormat:@"%@",dateString] forKey:@"date_created"];
        // Le agrego la api key al track
        [parametersWithExtra setObject:self.apiKey forKey:@"api_key"];
        
        
        /* Unifico parameteros */
        NSDictionary * dejavuGenericParameters = self.commonParameters;
        
        NSMutableDictionary * completeParameters = nil;
        if (dejavuGenericParameters){
            completeParameters = [NSMutableDictionary dictionaryWithDictionary:dejavuGenericParameters];
        }
        else{
            completeParameters = [NSMutableDictionary dictionary];
        }
        
        for (NSString * key in parametersWithExtra.allKeys){
            
            NSString *parameterValue = nil;
            if ([parametersWithExtra[key] isKindOfClass:[NSNumber class]]){
                parameterValue = [parametersWithExtra[key] stringValue];
            }
            else if ([parametersWithExtra[key] isKindOfClass:[NSString class]]){
                parameterValue = parametersWithExtra[key];
                parameterValue = [parameterValue stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
               
            }
            if (parameterValue){
                 [completeParameters setObject:parameterValue forKey:key];
            }
            
        }
        
        NSString *encodedDejavuString =[completeParameters urlQueryString];
        [self.dejavuDAO insertDejavuTrackWithDejavuString:encodedDejavuString withDate:dateTemp];
        
        
        //Si no tengo un timer lo inicio
        if(!self.timer && self.currentPool.count == 0 && !self.manager.operationQueue.operationCount){
            [self startTimer];
        }
        
        
        MLLogDebug(@"Tracking.. %@",completeParameters);
        
        if (self.bgTask == UIBackgroundTaskInvalid){
            self.bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                [[UIApplication sharedApplication] endBackgroundTask:self.bgTask];
            }];
        }
        
    });
}


-(void) trackWithParameters:(NSDictionary *)parameters andFlowData:(MLDejavuFlowData*) flowData{
    
    if (!self.trackerEnabled){
        return;
    }
    
    NSMutableDictionary * params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    
    if (flowData){
        if (flowData.flowId){
            params[@"flow_id"] = flowData.flowId;
        }
        if (flowData.flowName){
            params[@"flow_name"] = flowData.flowName;
        }
        if (flowData.extraParameters){
            for (NSString * key in flowData.extraParameters){
                params[key] = flowData.extraParameters[key];
            }
        }
    }
    
    [self trackWithParameters:params];
    
}

-(void) trackPageWithName:(NSString *)name andFlowData:(MLDejavuFlowData*) flowData{
    
    [self trackPageWithName:name andFlowData:flowData andExtraParameters:nil];
}

-(void) trackPageWithName:(NSString *)name andFlowData:(MLDejavuFlowData *)flowData andExtraParameters:(NSDictionary *)extraParameters {
    if (!self.trackerEnabled){
        return;
    }
    
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    if (extraParameters) {
        [params addEntriesFromDictionary:extraParameters];
    }
    
    params[@"track_type"] = @"PAGE";
    
    if (name){
        params[@"track_name"] = name;
        params[@"track_source_page"] = name;
    }
    
    
    [self trackWithParameters:params andFlowData:flowData];
}

-(void) trackEventWithName:(NSString *)name andSourcePageName:(NSString*) sourcePageName andFlowData:(MLDejavuFlowData*) flowData andExtraParameters:(NSDictionary*) extraParameters{
    
    if (!self.trackerEnabled){
        return;
    }
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    params[@"track_type"] = @"EVENT";
    
    if (name){
        params[@"track_name"] = name;
        if (sourcePageName){
            params[@"track_source_page"] = sourcePageName;
        }
    }
    
    
    for (NSString * key in extraParameters){
        params[key] = extraParameters[key];
    }
    
    
    [self trackWithParameters:params andFlowData:flowData];
    
}

-(BOOL) trackerEnabled{
    
    @synchronized(self){
        return _trackerEnabled;
    }
}
-(void) setTrackerEnabled:(BOOL)enabled{
    
    
    @synchronized(self){
        _trackerEnabled = enabled;
        
        if (!_trackerEnabled){
            [self stopTimer];
        }
        else{
            [self startTimer];
        }
        
        
        //Lo tiro en el main
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:_trackerEnabled] forKey:kMLDejavuStatus];
            [[NSUserDefaults standardUserDefaults] synchronize];
        });

    }
    
}

@end
