//
//  DejavuDAOCoreData.h
//  MercadoLibre
//
//  Created by Fabian Celdeiro on 3/6/14.
//  Copyright (c) 2014 MercadoLibre. All rights reserved.
//


@class NSManagedObjectID;

#define kDejavuDefaultDAOName @"mlDejavu"

/*DAO for core data */
@interface MLDejavuDAOCoreData : NSObject

@property (nonatomic,copy,readonly) NSString * name;
@property (nonatomic,copy,readonly) NSString * persistentStoreFilePath;

-(id) initWithName:(NSString*) name;


-(NSString*) persistentStoreFilePath;

-(NSUInteger) getDejavuTrackCount;
//Borra todos los tracks que superen en antiguedad a la fecha pasada
-(void) deleteTracksOlderThan:(NSDate*)date;

//inserta un objeto de track de dejavu a la base de core data
-(NSManagedObjectID*) insertDejavuTrackWithDejavuString:(NSString*) dejavuString withDate:(NSDate*) date;

//-(NSString*) getPageIdFromObjectId:(NSManagedObjectID*) objectId;

//Limit 0 will be no limit, more than 0 will limit the ammount of results
-(NSArray*) getDejavuTracksForPoolOrderedAscending:(BOOL) ascending withLimit:(NSUInteger) limit withError:(NSError**) error;


-(NSString*) getObjectParameterStringForId:(NSManagedObjectID*) objectId;


-(BOOL) deleteObject:(NSManagedObjectID *)objectId;

-(void) deletePersistentObject;


@end
