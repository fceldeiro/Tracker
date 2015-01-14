//
//  MLDejavuDAOTests.m
//  MercadoLibre
//
//  Created by Fabian Celdeiro on 3/5/14.
//  Copyright (c) 2014 MercadoLibre. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ServiceTest.h"
#import "MLDejavuTrack.h"
#import "MLDejavuDAOCoreData.h"

#import "MLDejavuTrackInPool.h"


@interface MLDejavuDAOTests : ServiceTest

@end

@implementation MLDejavuDAOTests


-(MLDejavuDAOCoreData*) createDAO{
    return  [[MLDejavuDAOCoreData alloc] initWithName:@"TestDAO"];

}
- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.
    MLDejavuDAOCoreData * dao = [[MLDejavuDAOCoreData alloc] initWithName:@"TestDAO"];
    [dao deletePersistentObject];

}

- (void)tearDown
{
    [super tearDown];
    // Put teardown code here; it will be run once, after the last test case.
     MLDejavuDAOCoreData * dao = [[MLDejavuDAOCoreData alloc] initWithName:@"TestDAO"];
     [dao deletePersistentObject];
    
    
}


-(void) testDeletePersistentStore{
    
    MLDejavuDAOCoreData * dao = [self createDAO];
    NSString *path = dao.persistentStoreFilePath;
    
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:NO], @"Debe existir el archivo");
    
    [dao deletePersistentObject];
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:NO], @"No debe existir el archivo");
    
}
-(void) testInsertDejavuTrack{

    MLDejavuDAOCoreData * dao = [self createDAO];
    
       NSDate *currentDate = [NSDate date];
    [dao insertDejavuTrackWithDejavuString:@"TEST_1" withDate:currentDate];
    
    NSError * error;

    NSArray * array = [dao getDejavuTracksForPoolOrderedAscending:YES withLimit:0 withError:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(array);
    
    XCTAssertTrue(array.count == 1,@"No es igual");
    MLDejavuTrackInPool * trackInPool = array[0];
    
    XCTAssertNotNil(trackInPool, @"No debe ser null");
    
    XCTAssertEqualObjects(trackInPool.parameterSent, @"TEST_1");
    
    
    
    
    
}

-(void) testInsertMultipleTracksAndOrderedGet{
    
    MLDejavuDAOCoreData * dao = [self createDAO];
    
    NSDate *currentDate1 = [NSDate date];
    NSDate *currentDate2 = [currentDate1 dateByAddingTimeInterval:10];
   
    //Los inserto al revez aproposito
    [dao insertDejavuTrackWithDejavuString:@"TEST_2" withDate:currentDate2];
    [dao insertDejavuTrackWithDejavuString:@"TEST_1" withDate:currentDate1];
    
    
    
    NSError * error;
    NSArray * array = [dao getDejavuTracksForPoolOrderedAscending:YES withLimit:0 withError:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(array);

    
    XCTAssertTrue(array.count == 2,@"No es igual");
    MLDejavuTrackInPool * track1 = array[0];
    MLDejavuTrackInPool * track2 = array[1];
    
    
    XCTAssertNotNil(track1, @"No debe ser null");
    XCTAssertNotNil(track2, @"No debe ser null");
    
    XCTAssertEqualObjects(track1.parameterSent, @"TEST_1", @"El primer track debe ser TEST_1");
    XCTAssertEqualObjects(track2.parameterSent, @"TEST_2", @"El primer track debe ser TEST_2");


    
   
    
}

-(void) testObjectDeleteFirstEntry{
    
    
    MLDejavuDAOCoreData * dao = [self createDAO];
    
    NSDate *currentDate1 = [NSDate date];
    NSDate *currentDate2 = [currentDate1 dateByAddingTimeInterval:10];
    NSDate *currentDate3 = [currentDate2 dateByAddingTimeInterval:10];
    
    
    //Los inserto al revez aproposito
    NSManagedObjectID * originalTrack2 = [dao insertDejavuTrackWithDejavuString:@"TEST_2" withDate:currentDate2];
    NSManagedObjectID * originalTrack1 = [dao insertDejavuTrackWithDejavuString:@"TEST_1" withDate:currentDate1];
    NSManagedObjectID * originalTrack3 = [dao insertDejavuTrackWithDejavuString:@"TEST_3" withDate:currentDate3];
    
    
    
    NSError * error;
    NSArray * array = [dao getDejavuTracksForPoolOrderedAscending:YES withLimit:0 withError:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(array);
    
   
    [dao deleteObject:originalTrack1];
    
    error = nil;
    array = [dao getDejavuTracksForPoolOrderedAscending:YES withLimit:0 withError:&error];
    XCTAssertNil(error, @"No debe haber error");
    XCTAssertNotNil(array, @"Debo tener un array");

    XCTAssertTrue(array.count == 2, @"Ahora debo tener 2 elementos");
    
    XCTAssertEqualObjects([array[0] objectIdSent],originalTrack2, @"El primer elemento ahora deberia ser el TEST_2");
    XCTAssertEqualObjects([[array lastObject] objectIdSent], originalTrack3, @"El último elemento debería ser el TEST_3");
    
  

}

-(void) testDeleteObjectMiddleEntry{
    
    MLDejavuDAOCoreData * dao = [self createDAO];
    
    NSDate *currentDate1 = [NSDate date];
    NSDate *currentDate2 = [currentDate1 dateByAddingTimeInterval:10];
    NSDate *currentDate3 = [currentDate2 dateByAddingTimeInterval:10];
    
    
    //Los inserto al revez aproposito
    NSManagedObjectID * originalTrack2 = [dao insertDejavuTrackWithDejavuString:@"TEST_2" withDate:currentDate2];
    NSManagedObjectID * originalTrack1 = [dao insertDejavuTrackWithDejavuString:@"TEST_1" withDate:currentDate1];
    NSManagedObjectID * originalTrack3 = [dao insertDejavuTrackWithDejavuString:@"TEST_3" withDate:currentDate3];
    
    
    
    NSError * error;
    NSArray * array = [dao getDejavuTracksForPoolOrderedAscending:YES withLimit:0 withError:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(array);
    
    
    [dao deleteObject:originalTrack2];
    
    error = nil;
    array = [dao getDejavuTracksForPoolOrderedAscending:YES withLimit:0 withError:&error];
    XCTAssertNil(error, @"No debe haber error");
    XCTAssertNotNil(array, @"Debo tener un array");
    
    XCTAssertTrue(array.count == 2, @"Ahora debo tener 2 elementos");
    
    XCTAssertEqualObjects([array[0] objectIdSent],originalTrack1, @"El primer elemento ahora deberia ser el TEST_1");
    XCTAssertEqualObjects([[array lastObject] objectIdSent], originalTrack3, @"El último elemento debería ser el TEST_3");
    
    

}

-(void)testDeleteObjectLastEntry{
    
    MLDejavuDAOCoreData * dao = [self createDAO];
    
    NSDate *currentDate1 = [NSDate date];
    NSDate *currentDate2 = [currentDate1 dateByAddingTimeInterval:10];
    NSDate *currentDate3 = [currentDate2 dateByAddingTimeInterval:10];
    
    
    //Los inserto al revez aproposito
    NSManagedObjectID * originalTrack2 = [dao insertDejavuTrackWithDejavuString:@"TEST_2" withDate:currentDate2];
    NSManagedObjectID * originalTrack1 = [dao insertDejavuTrackWithDejavuString:@"TEST_1" withDate:currentDate1];
    NSManagedObjectID * originalTrack3 = [dao insertDejavuTrackWithDejavuString:@"TEST_3" withDate:currentDate3];
    
    
    
    NSError * error;
    NSArray * array = [dao getDejavuTracksForPoolOrderedAscending:YES withLimit:0 withError:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(array);
    
    
    [dao deleteObject:originalTrack3];
    
    error = nil;
    array = [dao getDejavuTracksForPoolOrderedAscending:YES withLimit:0 withError:&error];
    XCTAssertNil(error, @"No debe haber error");
    XCTAssertNotNil(array, @"Debo tener un array");
    
    XCTAssertTrue(array.count == 2, @"Ahora debo tener 2 elementos");
    
    XCTAssertEqualObjects([array[0] objectIdSent],originalTrack1, @"El primer elemento ahora deberia ser el TEST_1");
    XCTAssertEqualObjects([[array lastObject] objectIdSent], originalTrack2, @"El último elemento debería ser el TEST_2");
    
    
    [dao deletePersistentObject];
}

-(void) testDeleteObjectsFromDate{
 
    MLDejavuDAOCoreData * dao = [self createDAO];
    
    NSDate *currentDate1 = [NSDate date];
    NSDate *currentDate2 = [currentDate1 dateByAddingTimeInterval:10];
    NSDate *currentDate3 = [currentDate2 dateByAddingTimeInterval:10];
    
    
    //Los inserto al revez aproposito
    [dao insertDejavuTrackWithDejavuString:@"TEST_2" withDate:currentDate2];
    [dao insertDejavuTrackWithDejavuString:@"TEST_1" withDate:currentDate1];
    NSManagedObjectID * originalTrack3 = [dao insertDejavuTrackWithDejavuString:@"TEST_3" withDate:currentDate3];
    
    
    
    NSError * error;
    NSArray * array = [dao getDejavuTracksForPoolOrderedAscending:YES withLimit:0 withError:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(array);
    
    
    [dao deleteTracksOlderThan:currentDate3];
    
    
    error = nil;
    array = [dao getDejavuTracksForPoolOrderedAscending:YES withLimit:0 withError:&error];
    XCTAssertNil(error, @"No debe haber error");
    XCTAssertNotNil(array, @"Debo tener un array");
    
    XCTAssertTrue(array.count == 1, @"Ahora debo tener 1 elemento");
    
    XCTAssertEqualObjects([array[0] objectIdSent],originalTrack3, @"El único que debería quedar es el TEST_3");
    
    
   
}

-(void) testDeleteAllObjects{
    
    MLDejavuDAOCoreData * dao = [self createDAO];
    
    NSDate *currentDate1 = [NSDate date];
    NSDate *currentDate2 = [currentDate1 dateByAddingTimeInterval:10];
    NSDate *currentDate3 = [currentDate2 dateByAddingTimeInterval:10];
    
    
    //Los inserto al revez aproposito
    [dao insertDejavuTrackWithDejavuString:@"TEST_2" withDate:currentDate2];
    [dao insertDejavuTrackWithDejavuString:@"TEST_1" withDate:currentDate1];
    [dao insertDejavuTrackWithDejavuString:@"TEST_3" withDate:currentDate3];
    
    
    
    NSError * error;
    NSArray * array = [dao getDejavuTracksForPoolOrderedAscending:YES withLimit:0 withError:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(array);
    
    
    for (MLDejavuTrackInPool * track in array){
        [dao deleteObject:[track objectIdSent]];
    }
    
    
    error = nil;
    array = [dao getDejavuTracksForPoolOrderedAscending:YES withLimit:0 withError:&error];
    XCTAssertNil(error, @"No debe haber error");
    XCTAssertNotNil(array, @"Debo tener un array");
    
    XCTAssertTrue(array.count == 0, @"Ahora debo tener 0 elementos");
    
  
}

-(void) testCount{
    
    MLDejavuDAOCoreData * dao = [self createDAO];
    
    NSDate *currentDate1 = [NSDate date];
    NSDate *currentDate2 = [currentDate1 dateByAddingTimeInterval:10];
    NSDate *currentDate3 = [currentDate2 dateByAddingTimeInterval:10];
    
    
    //Los inserto al revez aproposito
    [dao insertDejavuTrackWithDejavuString:@"TEST_2" withDate:currentDate2];
    NSManagedObjectID * originalTrack1 = [dao insertDejavuTrackWithDejavuString:@"TEST_1" withDate:currentDate1];
    [dao insertDejavuTrackWithDejavuString:@"TEST_3" withDate:currentDate3];
    
    
    
    NSUInteger count = [dao getDejavuTrackCount];
    
    XCTAssertTrue(count == 3, @"La cantidad debe ser 3");

    [dao deleteObject:originalTrack1];
    
    count = [dao getDejavuTrackCount];
    
    XCTAssertTrue(count == 2, @"La cantidad debe ser 2");

}


@end
