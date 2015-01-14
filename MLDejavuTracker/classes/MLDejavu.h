//
//  MLDejavu.h
//  MercadoLibre
//
//  Created by Fabian Celdeiro on 2/21/14.
//  Copyright (c) 2014 Casa. All rights reserved.
//
//  Tracker for Dejavu metrics


#import <Foundation/Foundation.h>
#import "MLDejavuFlowData.h"


#define kMLDejavuDispatchIntervalMinimum 5
#define kMLDejavuDefaultDispatchInterval 30
#define kMLDejavuURI @"http://dejavu.mercadolibre.com"
#define kMLDejavuDomain @".mercadolibre.com"
#define kMLDejavuGETResource @"pixel.gif"
#define kMLDejavuDefaultMaxRequestsToQueue 20

//The default flow duration is 30 minutes
#define kMLDejavuDefaultFlowDuration 60*30

@class MLDejavuDAOCoreData;
@class MLDejavuTrack;

typedef enum {
    MLDejavuLogLevelNone,         //No output
    MLDejavuLogLevelCriticalOnly,     //Default, outputs only critical log events
    MLDejavuLogLevelInfo,             //Info logs
    MLDejavuLogLevelDebug,            //Debug level, outputs critical and main log events
    MLDejavuLogLevelAll               //Highest level, outputs all log events
} MLDejavuLogLevel;

@interface MLDejavu : NSObject

//Data access object
@property (nonatomic,strong) MLDejavuDAOCoreData * dejavuDAO;


//Singleton property
+ (instancetype) sharedTracker;

//Init the tracker with an api key, must be called to start tracking and tracks will start, remember to set the dispatchInterval before if you want to change it.
+(void) startWithAPIKey:(NSString*) apiKey andDispatchInterval:(NSTimeInterval) interval andSid:(NSString*) sid;

+(void) trackPageWithName:(NSString *)name andFlowData:(MLDejavuFlowData*) flowData;
+(void) trackPageWithName:(NSString *)name andFlowData:(MLDejavuFlowData *)flowData andExtraParameters:(NSDictionary *)extraParameters;
+(void) trackEventWithName:(NSString *)name andSourcePageName:(NSString*) sourcePageName andFlowData:(MLDejavuFlowData*) flowData andExtraParameters:(NSDictionary*) extraParameters;
+(void) trackWithExtraParameters:(NSDictionary*) extraParameters;

//Manual dispatch of tracks , can be used only if dispatchInterval is not set, otherwise won't do anything
//Doesn't handle errors, if one track fails rest wont be send until next dispatch order.
+(void) dispatch;

//Returns an updated flow data if it hasnt expired, otherwise returns a new one.
//flowName: name of the flow ej: CHECKOUT
//newFlowId: id fow the flow, will only be used if there is now flow data object or has expired ej:hash

+(MLDejavuFlowData*) updatedFlowDataForKey:(NSString*) key withFlowName:(NSString*) newFlowName withExtraParameters:(NSDictionary*) extraParameters;

+(void) removeFlowDataForKey:(NSString*)key;
+(void) removeFlowData:(MLDejavuFlowData*) flowData;

//Deletes all flows from memory
+(void) resetAllFlows;

+(void) resetAllTracks;


+(void) setSID:(NSString*) sid;
+(void) setCommonParameters:(NSDictionary*) commonParameters;

+(void) setTrackerEnabled:(BOOL)enabled;


@end
