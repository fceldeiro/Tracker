//
//  MLDejavu_PrivateMethods.h
//  MercadoLibre
//
//  Created by Fabian Celdeiro on 3/6/14.
//  Copyright (c) 2014 MercadoLibre. All rights reserved.
//

#import "MLDejavu.h"


@class AFHTTPRequestOperationManager;
@class AFHTTPRequestOperation;
@class MLDejavuTrack;
@class MSWeakTimer;
@class MLDejavuTrackInPool;




typedef void (^MLDejavuOperationSuccessBlock)(AFHTTPRequestOperation* operation, id responseObject);
typedef void (^MLDejavuOperationFailureBlock)(AFHTTPRequestOperation* operation, NSError* error);



@interface MLDejavu (){
    BOOL _trackerEnabled;
}

//Queue used
@property (nonatomic,strong) dispatch_queue_t serialQueue;

//AFNetworking operation manager
@property (nonatomic,strong) AFHTTPRequestOperationManager * manager;

//Timer for automatic dispatch in queue
@property (nonatomic,strong) MSWeakTimer * timer;

//Tracks that are being processed for dispatch
@property (nonatomic,strong) NSMutableArray * currentPool;

//Id of background task
@property (nonatomic) UIBackgroundTaskIdentifier bgTask;

//API Key set for identification in hadoop dejavu database
@property (nonatomic,copy) NSString * apiKey;


@property (nonatomic) NSTimeInterval flowDuration;

//Variable usada para no mandar requests hacia afuera.
@property (nonatomic) BOOL dryRun;


/*
 If this value is positive, tracking information will be automatically
 dispatched every dispatchInterval seconds. Otherwise, tracking information must
 be sent manually by calling dispatch.
 
 By default, this is set to `20`, which indicates tracking information should
 be dispatched automatically every 20 seconds.
 */
@property(nonatomic, assign) NSTimeInterval dispatchInterval;

//Blocks for nsoperations
@property (readwrite, nonatomic, copy) MLDejavuOperationSuccessBlock successBlock;
@property (readwrite, nonatomic, copy) MLDejavuOperationFailureBlock failureBlock;

//Map used for storing flowData objects
@property (nonatomic,strong) NSMutableDictionary * flowData;

@property (nonatomic,copy) NSString * sid;
@property (nonatomic,strong) NSDictionary * commonParameters;

#pragma mark - Instance private methods

//SYNC
-(void) setDispatchInterval:(NSTimeInterval)dispatchInterval;


//Used to start timer for automatic dispatch.
//SYNC
-(void) startTimer;
//SYNC
-(void) stopTimer;

//SYNC:
// Creates an AFHTTPRequest operation object , adds it to the queue and starts, using the default
-(AFHTTPRequestOperation*) createGETOperation:(NSString*)URLString withDejavuTrackInPool:(MLDejavuTrackInPool*) dejavuTrackInPool;
    
// Creates an AFHTTPRequest operation object , adds it to the queue and starts, using the default blocks defined in -(id) init to manage response
//URLString last part of the url ej: pixel.gif
//SYNC
- (AFHTTPRequestOperation *)GET:(NSString *)URLString withDejavuTrackInPool:(MLDejavuTrackInPool*) dejavuTrackInPool;

//ASYNC
-(void) dispatch;

//SYNC Method call for autmatic dispatch
-(void) sendRequests:(NSTimer*)timer;

-(void)resetAllTracks;


-(MLDejavuFlowData*) createFlowDataForKey:(NSString*) key withName:(NSString*) name withExtraParameters:(NSDictionary*) extraParameters andDate:(NSDate*) date;
-(MLDejavuFlowData*) updatedFlowDataForKey:(NSString*) key withFlowName:(NSString*) flowName withExtraParameters:(NSDictionary *)extraParameters withDateToCompareWith:(NSDate*) date;
-(MLDejavuFlowData*) updatedFlowDataForKey:(NSString*) key withFlowName:(NSString*) flowName withExtraParameters:(NSDictionary*) extraParameters;

-(void) removeFlowDataForKey:(NSString*) key;
-(void) removeFlowData:(MLDejavuFlowData*) flowData;
-(void) resetAllFlows;

-(void) trackWithParameters:(NSDictionary*) parameters;
-(void) trackWithParameters:(NSDictionary *)parameters andFlowData:(MLDejavuFlowData*) flowData;
-(void) trackPageWithName:(NSString *)name andFlowData:(MLDejavuFlowData*) flowData;
-(void) trackEventWithName:(NSString *)name andSourcePageName:(NSString*) sourcePageName andFlowData:(MLDejavuFlowData*) flowData andExtraParameters:(NSDictionary*) extraParameters;


-(BOOL) trackerEnabled;
-(void) setTrackerEnabled:(BOOL) enabled;

@end
