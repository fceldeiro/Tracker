//
//  MLDejavuTests.m
//  MercadoLibre
//
//  Created by Fabian Celdeiro on 3/6/14.
//  Copyright (c) 2014 MercadoLibre. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ServiceTest.h"
#import "MLDejavuDAOCoreData.h"
#import "MLDejavu.h"
#import "NSString+URLEncode.h"
#import "MLDejavu_PrivateMethods.h"
#import <AFNetworking/AFNetworking.h>
#import "MLDejavuTrack.h"
#import "MSWeakTimer.h"
#import "MLDejavuTrackInPool.h"


@interface MLDejavuTests:XCTAsyncTestCase

@end

@implementation MLDejavuTests


-(MLDejavuDAOCoreData*) createDAO{
    return  [[MLDejavuDAOCoreData alloc] initWithName:@"TestDAO"];
    
    
    
}


-(NSMutableDictionary*) getSimplePageTrack{
    
    NSMutableDictionary * dic = [NSMutableDictionary dictionaryWithCapacity:3];
    dic[@"track_name"] = @"test-track";
    dic[@"track_type"] = @"PAGE";
    dic[@"track_source_page"] = @"test-track";
    
    return dic;
}



- (void)setUp
{
    [super setUp];

    
    // Put setup code here; it will be run once, before the first test case.


    MLDejavuDAOCoreData * dao = [self createDAO];
    [dao deletePersistentObject];
    
    
    MLDejavu * tracker = [MLDejavu sharedTracker];
    [tracker setDispatchInterval:0.0];
    [tracker setTrackerEnabled:NO];
    [tracker setDejavuDAO:dao];
    [tracker setDryRun:YES];
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
    
    MLDejavuDAOCoreData * dao = [self createDAO];
    [dao deletePersistentObject];
    
    [[MLDejavu sharedTracker] setDryRun:NO];
   
}


-(MLDejavu*) getTestTracker{
    
    MLDejavu *tracker= [[MLDejavu alloc] init];
    [tracker setApiKey:@"ML-DEJA-TEST"];
    [tracker setDryRun:YES];
    [tracker setSid:@"CUSTOM-SID"];
    [tracker setDispatchInterval:0.0];
    [tracker setTrackerEnabled:YES];
    return tracker;
    
}
-(void) testDispatchIntervalSet{
    
    
    

    
    MLDejavu *tracker= [[MLDejavu alloc] init];
    [tracker setApiKey:@"ML-DEJA-TEST"];
    [tracker setDryRun:YES];
    [tracker setSid:@"CUSTOM-SID"];
    [tracker setTrackerEnabled:YES];
    

    
   
    XCTAssertEqual(tracker.dispatchInterval, (NSTimeInterval)kMLDejavuDefaultDispatchInterval, @"Si no seteo dispatch interval, debería ser el default");

    [tracker setDispatchInterval:0.0];
    XCTAssertEqual(tracker.dispatchInterval,0.0, @"Si seteo 0 debería ser 0");
    
    [tracker setDispatchInterval:1.0];
    XCTAssertEqual(tracker.dispatchInterval, (NSTimeInterval)kMLDejavuDispatchIntervalMinimum, @"Si seteo 1 debería ser 5");
    
    [tracker setDispatchInterval:-1.0];
    XCTAssertEqual(tracker.dispatchInterval, (NSTimeInterval)kMLDejavuDispatchIntervalMinimum, @"Si seteo <0 Debería ser 5");
    
    
    [tracker setDispatchInterval:22.0];
    XCTAssertEqual(tracker.dispatchInterval, 22.0, @"Si seteo > 5 debería ser ese valor");
}





-(void) testFailureBlock{
    
    
    
    [self prepare];
    
    //Creo un dao para test
    MLDejavuDAOCoreData * testDao = [self createDAO];
    MLDejavu *tracker= [self getTestTracker];
    [tracker setDejavuDAO:testDao];

    
    //Paro el tracker
    [tracker setDispatchInterval:0.0];
    
    
    NSMutableDictionary * track1 = [self getSimplePageTrack];
    track1[@"track_name"] = @"1";
    
    NSMutableDictionary * track2 = [self getSimplePageTrack];
    track2[@"track_name"] = @"2";
    
    NSMutableDictionary * track3 = [self getSimplePageTrack];
    track3[@"track_name"] = @"3";
    
    
    //meto 3 eventos
    [tracker trackWithParameters:track1];
    [tracker trackWithParameters:track2];
    [tracker trackWithParameters:track3];
    
    dispatch_async(tracker.serialQueue, ^{
        NSError *error;
        
        //Hago un fetch
        NSMutableArray *array = [NSMutableArray arrayWithArray:[testDao getDejavuTracksForPoolOrderedAscending:YES withLimit:0 withError:&error]];
        
        //Seteo el current pool
        tracker.currentPool = array;
        
        //Creo una operation
        AFHTTPRequestOperation * operation = [tracker createGETOperation:kMLDejavuGETResource withDejavuTrackInPool:array[0]];
        
        NSHTTPURLResponse * response = [[NSHTTPURLResponse alloc] initWithURL:operation.request.URL statusCode:500 HTTPVersion:@"GET" headerFields:nil];
        
        
        //Llamo al success block haciendole creer que termino con exito
        NSError * responseError = [NSError errorWithDomain:@"dejavu.mercadolibre.com" code:500 userInfo:@{@"responseBody":response}];
        tracker.failureBlock(operation,responseError);
        
        
        dispatch_async(tracker.serialQueue, ^{
            
            XCTAssertEqual(tracker.currentPool.count, 0U, @"No debería tener ningun objeto en la current pool");
            
            //Hago un fetch
            NSArray * newFetch = [testDao getDejavuTracksForPoolOrderedAscending:YES withLimit:0 withError:nil];
            
            XCTAssertEqual(newFetch.count, 3U, @"Debería los mismos objetos en la base");
            XCTAssertTrue([[newFetch[0] parameterSent] isEqualToString:[array[0] parameterSent]], @"Debería tener el mismo track en la base en la misma posicion");
            XCTAssertTrue([[newFetch[1] parameterSent] isEqualToString:[array[1] parameterSent]], @"Debería tener el mismo track en la base en la misma posición");
            XCTAssertTrue([[newFetch[2] parameterSent]isEqualToString:[array[2] parameterSent]], @"Debería tener el mismo track en la base en la misma posición");
            [testDao deletePersistentObject];
            
            [self notify:kXCTUnitWaitStatusSuccess];

        });
        
        
 
    });
    
    [self waitForStatus:kXCTUnitWaitStatusSuccess timeout:10];
    
    

}


-(void) testIfTrackerDisabledShouldNotTrack{
    
   
    
    
    MLDejavuDAOCoreData * dao = [[MLDejavuDAOCoreData alloc] initWithName:@"TEST-DB"];
    [dao deletePersistentObject];
    
    MLDejavu *tracker= [self getTestTracker];
    [tracker setDejavuDAO:dao];
    
     [self prepare];
    
    [tracker setTrackerEnabled:NO];
    
    [tracker trackWithParameters:@{@"TEST-KEY":@"TEST-VALUE"}];
    
    dispatch_async(tracker.serialQueue, ^{
       
        XCTAssertEqual([dao getDejavuTrackCount], 0u, @"Debería tener 0 tracks");
        [self notify:kXCTUnitWaitStatusSuccess];
        
    });
    
     [self waitForStatus:kXCTUnitWaitStatusSuccess timeout:10];
    
   
    
    

    

}

-(void) testIfTrackerDisabledShouldNotDispatch{
    
    

    
    MLDejavuDAOCoreData * dao = [[MLDejavuDAOCoreData alloc] initWithName:@"TEST-DB"];
    [dao deletePersistentObject];
    
    MLDejavu *tracker=     [self getTestTracker];
    [tracker setDejavuDAO:dao];
    
    [self prepare];
    
    [tracker setTrackerEnabled:YES];
    
    [tracker trackWithParameters:@{@"TEST-KEY":@"TEST-VALUE"}];
    
    dispatch_async(tracker.serialQueue, ^{
        
        XCTAssertEqual([dao getDejavuTrackCount], 1u, @"Debería tener 1 track");
       
        
    });
    
    [tracker setTrackerEnabled:NO];
    [tracker dispatch];
    
    dispatch_async(tracker.serialQueue, ^{
          XCTAssertEqual([dao getDejavuTrackCount], 1u, @"Debería tener 1 track");
    });
    
    [tracker setTrackerEnabled:YES];
    [tracker dispatch];
    

    
    dispatch_async(tracker.serialQueue, ^{
        XCTAssertEqual([dao getDejavuTrackCount], 1u, @"Debería tener 1 track");
        XCTAssertEqual(  [tracker.currentPool count],1u,@"Debería tener 1 track el pool");
        [self notify:kXCTUnitWaitStatusSuccess];
    });
    
    [self waitForStatus:kXCTUnitWaitStatusSuccess timeout:10];
    
    
    
    
    

}


- (void)testSingleTrack
{
    
  
    
    MLDejavuDAOCoreData * dao = [[MLDejavuDAOCoreData alloc] initWithName:@"TEST-DB"];
    [dao deletePersistentObject];
    
    MLDejavu *tracker= [self getTestTracker];
    [tracker setDejavuDAO:dao];
    [tracker setTrackerEnabled:YES];
    [self prepare];
    

    

    
    [tracker trackWithParameters:@{@"track_name":@"OK",
                                   @"track_type":@"PAGE",
                                   @"track_source_page":@"OK"}];
    
    
    
    [tracker dispatch];
    
    
    
    tracker.successBlock(nil,nil);
    
  
    dispatch_async(tracker.serialQueue, ^{
    
        [self notify:kXCTUnitWaitStatusSuccess];
    });
    
    [self waitForStatus:kXCTUnitWaitStatusSuccess timeout:10.0];
    
    
    
    XCTAssertEqual([dao getDejavuTrackCount], 0u, @"Debería tener 0 tracks");

    
}


- (void)testTwoTracks
{
    
  
    
    MLDejavuDAOCoreData * dao = [[MLDejavuDAOCoreData alloc] initWithName:@"TEST-DB"];
    [dao deletePersistentObject];
    
    MLDejavu *tracker= [self getTestTracker];
    [tracker setDejavuDAO:dao];
    [tracker setTrackerEnabled:YES];

    
    [self prepare];
    
    
    [tracker trackWithParameters:[self getSimplePageTrack]];
    [tracker trackWithParameters:[self getSimplePageTrack]];
    
    
    dispatch_async(tracker.serialQueue, ^{
        
         XCTAssertEqual([dao getDejavuTrackCount], 2u, @"Debería tener sólo 2 tracks");
    });
    
    [tracker dispatch];
    
    tracker.successBlock(nil,nil);
    tracker.successBlock(nil,nil);
    
    
    
    dispatch_async(tracker.serialQueue, ^{
        
        [self notify:kXCTUnitWaitStatusSuccess];
    });
    
    [self waitForStatus:kXCTUnitWaitStatusSuccess timeout:10.0];
    
    
    
    XCTAssertEqual([dao getDejavuTrackCount], 0u, @"Debería tener sólo 0 tracks");
    
    
}


- (void)testOneOkOneError
{
    
   
    
    MLDejavuDAOCoreData * dao = [[MLDejavuDAOCoreData alloc] initWithName:@"TEST-DB"];
    [dao deletePersistentObject];
    
    MLDejavu *tracker= [self getTestTracker];
    [tracker setDejavuDAO:dao];
    [tracker setTrackerEnabled:YES];
    
    [self prepare];
    
    
    [tracker trackWithParameters:[self getSimplePageTrack]];
    [tracker trackWithParameters:[self getSimplePageTrack]];
    
    [tracker dispatch];
    
    tracker.successBlock(nil,nil);
    tracker.failureBlock(nil,nil);
    
    
    
    
    dispatch_async(tracker.serialQueue, ^{
        
        [self notify:kXCTUnitWaitStatusSuccess];
    });
    
    [self waitForStatus:kXCTUnitWaitStatusSuccess timeout:10.0];
    
    
    
    XCTAssertEqual([dao getDejavuTrackCount], 1u, @"Debería tener sólo 1 track");
    
    
}

- (void)testAllErrors
{
    

    MLDejavuDAOCoreData * dao = [[MLDejavuDAOCoreData alloc] initWithName:@"TEST-DB"];
    [dao deletePersistentObject];
    
    MLDejavu *tracker= [self getTestTracker];
    [tracker setDejavuDAO:dao];
    [tracker setTrackerEnabled:YES];
    
    
    [self prepare];
    
    
    [tracker trackWithParameters:[self getSimplePageTrack]];
    [tracker trackWithParameters:[self getSimplePageTrack]];
    
    [tracker dispatch];
    
    tracker.failureBlock(nil,nil);
    
    dispatch_async(tracker.serialQueue, ^{
        
        [self notify:kXCTUnitWaitStatusSuccess];
    });
    
    [self waitForStatus:kXCTUnitWaitStatusSuccess timeout:10.0];
    
    
    
    XCTAssertEqual([dao getDejavuTrackCount], 2u, @"Debería tener sólo 2 tracks");
    
    
}

- (void)testOneErrorRetryWithSuccess
{
    

    
    MLDejavuDAOCoreData * dao = [[MLDejavuDAOCoreData alloc] initWithName:@"TEST-DB"];
    [dao deletePersistentObject];
    
    MLDejavu *tracker= [self getTestTracker];
    [tracker setDejavuDAO:dao];
    [tracker setTrackerEnabled:YES];
    
    
    [self prepare];
    
    
    
    [tracker trackWithParameters:[self getSimplePageTrack]];
    
    [tracker dispatch];

    tracker.failureBlock(nil,nil);

    [tracker dispatch];
    
    tracker.successBlock(nil,nil);
  
    
    dispatch_async(tracker.serialQueue, ^{
        
        [self notify:kXCTUnitWaitStatusSuccess];
    });
    
    [self waitForStatus:kXCTUnitWaitStatusSuccess timeout:10.0];
    
    
    
    XCTAssertEqual([dao getDejavuTrackCount], 0u, @"Debería tener sólo 0 tracks");
    
    
}

-(void) testStress2{
    
    
  
    
    MLDejavuDAOCoreData * dao = [[MLDejavuDAOCoreData alloc] initWithName:@"TEST-STRESS-2-DB"];
    [dao deletePersistentObject];
    
    MLDejavu *tracker=     [self getTestTracker];
    [tracker setDejavuDAO:dao];
    [tracker setTrackerEnabled:YES];
    [self prepare];
    
    
    dispatch_queue_t concurrentQueue = dispatch_queue_create("testQueue", DISPATCH_QUEUE_CONCURRENT);
    
    dispatch_apply(100, concurrentQueue, ^(size_t iterator){
        [tracker trackPageWithName:[NSString stringWithFormat:@"PAGE_%lu",iterator] andFlowData:nil];
    });
    
    dispatch_barrier_async(concurrentQueue, ^{
       
        
        [tracker dispatch];
        
        dispatch_async(tracker.serialQueue, ^{
            
            XCTAssertEqual([tracker.dejavuDAO getDejavuTrackCount],100u,@"Debería tener 100 tracks ");

            NSInteger currentPoolSize = tracker.currentPool.count;
            dispatch_apply(currentPoolSize, concurrentQueue, ^(size_t iterator) {
               
                //NSHTTPURLResponse * response= [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"sarasa"] statusCode:200 HTTPVersion:@"GET" headerFields:nil];
                tracker.successBlock(nil,nil);
                
            });
            
            dispatch_barrier_async(concurrentQueue, ^{
                dispatch_async(tracker.serialQueue, ^{
                     XCTAssertEqual([tracker.dejavuDAO getDejavuTrackCount],100u-(NSUInteger)kMLDejavuDefaultMaxRequestsToQueue,@"Debería tener 70 tracks ");
                    [dao deletePersistentObject];
                    [self notify:kXCTUnitWaitStatusSuccess];
                });

            });

        });

        
    });
    
    [self waitForStatus:kXCTUnitWaitStatusSuccess timeout:31110];
    
    
    
    
    
}

-(void) testStress{
    
    

 
    MLDejavuDAOCoreData * dao = [[MLDejavuDAOCoreData alloc] initWithName:@"TEST-STRESS-DB"];
    [dao deletePersistentObject];
    
    MLDejavu *tracker= [self getTestTracker];
    [tracker setDejavuDAO:dao];
    [tracker setTrackerEnabled:YES];
    [self prepare];
    
    
    //Meto 100 tracks
    
    for (int i=0 ; i< 100 ; i++){
        
        NSDictionary *dic = @{@"track_name": [NSString stringWithFormat:@"%@_%i",@"track",i],
                              @"track_type": @"EVENT",
                              @"track_source_page": @"TEST"};
        
        
        [tracker trackWithParameters:dic];
    }

    //TENGO QUe tener 100 tracks en la base
    dispatch_async(tracker.serialQueue, ^{
        
        NSArray * dataBaseTracks = [tracker.dejavuDAO getDejavuTracksForPoolOrderedAscending:YES withLimit:0 withError:nil];
        XCTAssertEqual(dataBaseTracks.count, 100u);
    });

    [tracker dispatch];
    
    
    //VERIFICO QUE TENGA lo permitido por el pool size
    dispatch_async(tracker.serialQueue, ^{
        XCTAssertEqual(tracker.currentPool.count, (uint)kMLDejavuDefaultMaxRequestsToQueue);
        
        for (int i= 0 ; i <tracker.currentPool.count ; i++){
            MLDejavuTrackInPool * trackInPool = tracker.currentPool[i];

            NSString * regexString = [NSString stringWithFormat:@".*track_name=track_%i.*",i];
            NSRegularExpression * regex = [NSRegularExpression regularExpressionWithPattern:regexString options:NSRegularExpressionCaseInsensitive error:nil];
        
            NSArray * regexMatches = [regex matchesInString:trackInPool.parameterSent options:NSMatchingReportCompletion range:NSMakeRange(0, trackInPool.parameterSent.length)];
            
            
            BOOL isEqualToString = regexMatches.count > 0;
            
            XCTAssertTrue(isEqualToString);
        }
    });
    
    
    //BORRO LA BASE DESPUES DE HACER EL DISPATCH
    [tracker resetAllTracks];
    
    //LLAMO A LOS 20 success blocks (deberían pasar todos aunque avisando que no estan mas en la base)
    
    dispatch_sync(tracker.serialQueue, ^{
        for (int i=0 ; i<tracker.currentPool.count ;i++){
            tracker.successBlock(nil,nil);
        }

    });

    
    
    //AHORA EL CURRENT POOL DEBERIA SER 0
    dispatch_async(tracker.serialQueue, ^{
        XCTAssertEqual(tracker.currentPool.count, 0u);
    });


    
    
    dispatch_async(tracker.serialQueue, ^{
        
        [self notify:kXCTUnitWaitStatusSuccess];
        [dao deletePersistentObject];
    });
    
    [self waitForStatus:kXCTUnitWaitStatusSuccess timeout:10.0];

    

    
}



-(void) testFlowData{
    
    MLDejavu * tracker = [self getTestTracker];
    MLDejavuDAOCoreData * dao = [self createDAO];
    [dao deletePersistentObject];
    [tracker setDejavuDAO:dao];
    [tracker setTrackerEnabled:YES];

    XCTAssertEqual(tracker.flowDuration, (NSTimeInterval)kMLDejavuDefaultFlowDuration, @"Debería estar por defecto el flow duration default");
    
    //Creating a new flow
    MLDejavuFlowData * flowData = [tracker updatedFlowDataForKey:@"FLOW-TEST" withFlowName:@"FLOW" withExtraParameters:nil];
    
    NSString * flowDataKey1  = flowData.flowId;
    XCTAssertTrue([flowData.flowName isEqualToString:@"FLOW"], @"El nombre del flow debería ser FLOW");
    
    flowData = nil;
    flowData = [tracker updatedFlowDataForKey:@"FLOW-TEST" withFlowName:@"FLOW" withExtraParameters:nil ];
    XCTAssertTrue([flowData.flowId isEqualToString:flowDataKey1], @"Debería ser el mismo id de flow");
    
    flowData = nil;
    flowData = [tracker updatedFlowDataForKey:@"FLOW-TEST-1" withFlowName:@"FLOW" withExtraParameters:nil];
    XCTAssertFalse([flowData.flowId isEqualToString:flowDataKey1], @"Debería tener otro id de flow");
    
    
    flowData = nil;
    [tracker setFlowDuration:0];
    flowData = [tracker updatedFlowDataForKey:@"FLOW-TEST" withFlowName:@"FLOW" withExtraParameters:nil];
    XCTAssertFalse([flowData.flowId isEqualToString:flowDataKey1], @"Debería tener una nueva key, ya que el flow expiró");
    flowDataKey1 = flowData.flowId;
    
    flowData = nil;
    //Le pongo duración 30 segundos
    [tracker setFlowDuration:30];
    flowData = [tracker updatedFlowDataForKey:@"FLOW-TEST" withFlowName:@"FLOW" withExtraParameters:nil];
    XCTAssertTrue([flowData.flowId isEqualToString:flowDataKey1], @"Debería tener la misma  key, ya que el flow no expiró");

    //Ahora le paso una fecha 30 segundos en el futuro entonces debería expirar
    flowData = nil;
    [tracker setFlowDuration:30];
    flowData = [tracker updatedFlowDataForKey:@"FLOW-TEST" withFlowName:@"FLOW" withExtraParameters:nil withDateToCompareWith:[NSDate dateWithTimeIntervalSinceNow:30]];
    XCTAssertFalse([flowData.flowId isEqualToString:flowDataKey1], @"No Debería tener la misma  key, ya que el flow  expiró");
    flowDataKey1 = flowData.flowId;


    flowData = nil;
    [tracker setFlowDuration:kMLDejavuDefaultFlowDuration];
    flowData = [tracker updatedFlowDataForKey:@"FLOW-TEST" withFlowName:@"FLOW" withExtraParameters:nil withDateToCompareWith:[NSDate date]];
    XCTAssertTrue([flowData.flowId isEqualToString:flowDataKey1], @"Debería tener la misma key estoy dentro del periodo sin expiración");
    
    //29 minutos despues debería ser válido aún
    flowData = nil;
    flowData = [tracker updatedFlowDataForKey:@"FLOW-TEST" withFlowName:@"FLOW" withExtraParameters:nil withDateToCompareWith:[NSDate dateWithTimeIntervalSinceNow:60*29]];
    XCTAssertTrue([flowData.flowId isEqualToString:flowDataKey1], @"Debería ser válido 29 minutos después");
    
    //30 minutos despues no debería ser válido
    flowData = nil;
    flowData = [tracker updatedFlowDataForKey:@"FLOW-TEST" withFlowName:@"FLOW" withExtraParameters:nil withDateToCompareWith:[NSDate dateWithTimeIntervalSinceNow:60*30]];
    XCTAssertFalse([flowData.flowId isEqualToString:flowDataKey1], @"No Debería ser válido 30 minutos después");
    
    
    
    NSDictionary * extra = @{@"TEST":@"A"};
    
    MLDejavuFlowData * otherFlowData = [tracker createFlowDataForKey:@"SARASA-1" withName:@"SARASA" withExtraParameters:extra andDate:nil];
    
    XCTAssertNotNil(otherFlowData, @"Debería tener un flow");
    XCTAssertEqual(otherFlowData.extraParameters, extra, @"DEbería tener mis extra parameters");
    XCTAssertTrue([otherFlowData.flowName isEqualToString:@"SARASA"], @"DEbería tener el mismo nombre");
    XCTAssertNotNil(tracker.flowData[@"SARASA-1"],@"Debería tener el objeto en el mapa");
    XCTAssertTrue([flowData.dateCreated timeIntervalSinceNow] < 5, @"Debería tener una fecha como la de ahora");
    
    MLDejavuFlowData * lastFlowData = [tracker updatedFlowDataForKey:@"SARASA-1" withFlowName:@"SARASA" withExtraParameters:nil withDateToCompareWith:[NSDate date]];
    
    XCTAssertEqual(otherFlowData, lastFlowData, @"DEbería ser el mismo flow data");
    
    lastFlowData = [tracker updatedFlowDataForKey:@"SARASA-1" withFlowName:@"SARASA" withExtraParameters:nil withDateToCompareWith:[NSDate dateWithTimeIntervalSinceNow:30*60]];
    XCTAssertNotEqual(otherFlowData, lastFlowData, @"No debería ser el mismo flow data");
    
    
    
}

-(void) testResetAllFlows{
    
    
    
    MLDejavu *tracker= [self getTestTracker];
    [tracker setTrackerEnabled:YES];

    tracker.flowData[@"flow_data_test_key"] = @"flow_data_test_value";
    
    XCTAssertEqual(tracker.flowData.count, 1, @"Debería tener 1 flow data");
    
    [tracker resetAllFlows];
    XCTAssertEqual(tracker.flowData.count, 0, @"No debería tener ningun flow data");
}

#pragma mark - Canned protocol

- (NSData*)responseDataForClient:(id<NSURLProtocolClient>)client request:(NSURLRequest*)request{
    return nil;
}


- (NSInteger)statusCodeForClient:(id<NSURLProtocolClient>)client request:(NSURLRequest*)request{
      NSString *queryValue = [request.URL.query stringByReplacingOccurrencesOfString:@"dejavu=" withString:@""];
    NSString *queryValueDecoded = [queryValue urlDecode];
    NSDictionary * params = [queryValueDecoded dictionaryFromQueryComponentsOneValuePerKey];
    
    NSLog(@"Params:%@",params);

    return 200;
    

    
}
 


@end
