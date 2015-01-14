//
//  DejavuDAOCoreData.m
//  MercadoLibre
//
//  Created by Fabian Celdeiro on 3/6/14.
//  Copyright (c) 2014 MercadoLibre. All rights reserved.
//

#import "MLDejavuDAOCoreData.h"
#import "MLDejavuTrack.h"
#import "NSString+URLEncode.h"
#import "NSDictionary+URLQueryString.h"
#import "MLDejavuTrackInPool.h"


#define kDejavuManagedObjectModelName @"mldejavu"

@interface MLDejavuDAOCoreData()

@property (nonatomic,strong) NSManagedObjectContext * managedObjectContext;
@property (nonatomic,strong) NSPersistentStoreCoordinator * persistentStoreCoordinator;
@property (nonatomic,strong) NSManagedObjectModel * managedObjectModel;

@end


@implementation MLDejavuDAOCoreData


-(NSString* ) getDejavuTrackClass{
    return NSStringFromClass([MLDejavuTrack class]);
}

#pragma mark - Init
-(id) initWithName:(NSString *)name{
    if (self = [super init]){
        
        if (_name){
            _name = nil;
        }
        _name = [name copy];

        //init of context
        [self managedObjectContext];
        
    }
    return self;
}
#pragma mark - Public methods

-(NSString*) persistentStoreFilePath{
    return  [[self applicationDocumentsDirectory] stringByAppendingPathComponent: [NSString stringWithFormat:@"%@.sqlite",self.name]];
}

-(NSUInteger) getDejavuTrackCount{
    
    NSManagedObjectContext * context = [self managedObjectContext];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:[self getDejavuTrackClass] inManagedObjectContext:context]];
    
    [request setIncludesSubentities:NO]; //Omit subentities. Default is YES (i.e. include subentities)
    
    NSError *err;
    NSUInteger count = [context countForFetchRequest:request error:&err];
    if (err){
        return 0;
    }
    return count;
}

//Borra todos los tracks que superen en antiguedad a la fecha pasada
-(void) deleteTracksOlderThan:(NSDate*)date{
    
    
    NSManagedObjectContext * context = [self managedObjectContext];
    if (!context){
        return;
    }
    
    //We fetch
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:[self getDejavuTrackClass] inManagedObjectContext:context];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(dateCreated < %@)", date];
    [fetchRequest setEntity:entity];
    [fetchRequest setPredicate:predicate];
    NSError * error;
    NSArray *fetchedObjects = [context executeFetchRequest:fetchRequest error:&error];
    
    if (fetchedObjects && fetchedObjects.count > 0){
        //  DDLogDebug(@"About to delete %i tracks because they are older than 30 days",fetchedObjects.count);
    }
    for (NSManagedObject  * object in fetchedObjects){
        [context deleteObject:object];
    }
    
    
    
    if (![context save:&error]) {
        NSLog(@"Whoops, couldn't save: %@", [error localizedDescription]);
    }
    
    
}
//inserta un objeto de track de dejavu a la base de core data
-(NSManagedObjectID*) insertDejavuTrackWithDejavuString:(NSString*) dejavuString withDate:(NSDate*) date{
    NSManagedObjectContext *context = [self managedObjectContext];
    
    if (!context){
        return nil;
    }
    
    MLDejavuTrack *track = [NSEntityDescription
                          insertNewObjectForEntityForName:[self getDejavuTrackClass]
                          inManagedObjectContext:context];
    track.dateCreated = date;
    track.parameters = dejavuString;
    
  //  DDLogDebug(@"Tracking: %@",track.parameters);
    
    NSError *error;
    if (![context save:&error]) {
        NSLog(@"Whoops, couldn't save: %@", [error localizedDescription]);
    }
    
    return [track objectID];
}

//Limit 0 will be no limit, more than 0 will limit the ammount of results
-(NSArray*) getDejavuTracksForPoolOrderedAscending:(BOOL) ascending withLimit:(NSUInteger) limit withError:(NSError**) error{
    
    //We fetch
    NSManagedObjectContext * context = [self managedObjectContext];
    
    if (!context){
        return nil;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:[self getDejavuTrackClass]
                                              inManagedObjectContext:context];
    
    NSSortDescriptor *dateSort = [[NSSortDescriptor alloc] initWithKey:@"dateCreated" ascending:ascending selector:nil];
    NSArray *sortDescriptors = [NSArray arrayWithObjects:dateSort, nil];
    [fetchRequest setSortDescriptors:sortDescriptors];
    [fetchRequest setEntity:entity];
    if (limit > 0){
        [fetchRequest setFetchLimit:limit];
    }
    
    NSArray *fetchedObjects = [context executeFetchRequest:fetchRequest error:error];
    
    NSMutableArray * parameterArray = [NSMutableArray arrayWithCapacity:fetchedObjects.count];
    for (MLDejavuTrack* dejaTrack in fetchedObjects){
        
        MLDejavuTrackInPool * newTrackInPool = [[MLDejavuTrackInPool alloc] init];
        newTrackInPool.objectIdSent = dejaTrack.objectID;
        newTrackInPool.parameterSent = dejaTrack.parameters;
        [parameterArray addObject:newTrackInPool];
    }
    return [NSArray arrayWithArray:parameterArray];
    
    
}

/*
-(NSString*) getPageIdFromObjectId:(NSManagedObjectID*) objectId{
    
    NSManagedObjectContext *context = [self managedObjectContext];
    
    NSError * error = nil;
    NSManagedObject * object = [context existingObjectWithID:objectId error:&error];
    if (error){
//        DDLogDebug(@"Object not existant");
        return nil;
    }
    
    if (!object){
        return nil;
    }
    
    NSString * param = [object valueForKey:@"parameters"];

    param = [param urlDecode];
    NSDictionary * dic = [param dictionaryFromQueryComponents];
    if (dic){
        return dic[@"page_id"];
    }
    return nil;
}
 */
-(NSString*) getObjectParameterStringForId:(NSManagedObjectID*) objectId{
    
    NSManagedObjectContext *context = [self managedObjectContext];
    
    if (!context){
        return nil;
    }
    
    NSError * error = nil;
    NSManagedObject * object = [context existingObjectWithID:objectId error:&error];
    if (error){
  //      DDLogDebug(@"Object not existant");
        return nil;
    }
    
    if (!object){
        return nil;
    }
    
    return [object valueForKey:@"parameters"];

}

-(BOOL) deleteObject:(NSManagedObjectID *)objectId{
    
    NSManagedObjectContext *context = [self managedObjectContext];
    
    NSError * error = nil;
    NSManagedObject * object = [context existingObjectWithID:objectId error:&error];
    if (error){
    //    DDLogDebug(@"Problem fetching object id");
    }
    
    if (!error && object){
        [context deleteObject:object];
        
        if (![context save:&error]) {
            NSLog(@"Whoops, couldn't save: %@", [error localizedDescription]);
            return NO;
        }else{
            return YES;
        }

    }else{
        return NO;
    }

    
}

-(void) deletePersistentObject{
    NSString *storePath = [self persistentStoreFilePath];

    NSFileManager *manager = [NSFileManager defaultManager];
   
    if ([manager fileExistsAtPath:storePath isDirectory:NO]){
     [[NSFileManager defaultManager] removeItemAtPath:storePath error:nil];
    }
    
    self.persistentStoreCoordinator = nil;
    self.managedObjectContext = nil;
    
    
}


#pragma mark - Core Data - CORE METHODS


/**
 Returns the path to the application's Documents directory.
 */
- (NSString *)applicationDocumentsDirectory {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

- (NSManagedObjectContext *)managedObjectContext {
    

    NSManagedObjectContext * contextToReturn = nil;
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        contextToReturn = [[NSManagedObjectContext alloc] init];
        [contextToReturn setPersistentStoreCoordinator:coordinator];
    }
    return contextToReturn;
}


/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created from the application's model.
 */
- (NSManagedObjectModel *)managedObjectModel {
    
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSString *modelPath = [[NSBundle mainBundle] pathForResource:kDejavuManagedObjectModelName ofType:@"momd"];
    //    NSString *modelPath = [[NSBundle mainBundle] pathForResource:@"ml" ofType:@"momd" inDirectory:@"mom"];
    NSFileManager * defaultManager = [NSFileManager defaultManager];
    if ([defaultManager fileExistsAtPath:modelPath isDirectory:NO]){
        
        NSURL *modelURL = [NSURL fileURLWithPath:modelPath];
        _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    }
    else{
        [[MLGAI sharedInstance] trackLegacyEvent:@"DEJAVU_CORE_DATA_COULD_NOT_LOAD_MANAGED_OBJECT_MODEL_ERROR"];
        
        NSLog(@"ERROR: Could not load managed object model");
        #ifdef DEBUG
        NSAssert(YES, @"ERROR: Could not load managed object model");
        #endif
    }
    
       return _managedObjectModel;
}


/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSString *storePath = [self persistentStoreFilePath];
    NSURL *storeURL = [NSURL fileURLWithPath: storePath];
    
    
    NSError *error = nil;
    
    //NSDictionary *options = @{ NSSQLitePragmasOption : @{@"journal_mode" : @"DELETE"},NSMigratePersistentStoresAutomaticallyOption: @YES,NSInferMappingModelAutomaticallyOption: @YES };
    
    NSDictionary* options = @{NSMigratePersistentStoresAutomaticallyOption: @YES,NSInferMappingModelAutomaticallyOption: @YES};
    
    
    NSManagedObjectModel * model = [self managedObjectModel];
    if (model){
        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
        if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]) {
        
        
        // Replace this implementation with code to handle the error appropriately.
        
        //causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
        
            [[MLGAI sharedInstance] trackLegacyEvent:@"ERROR_PERSISTENT_STORE_COORDINATOR"];
        
            #ifdef DEBUG
            NSLog(@"Error persistent store coordinator");
            NSLog(@"%@",[error userInfo]);
            //    abort();
            #endif
        
            /*
             Typical reasons for an error here include:
             * The persistent store is not accessible;
             * The schema for the persistent store is incompatible with current managed object model.
             Check the error message to determine what the actual problem was.
         
         
             If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
             If you encounter schema incompatibility errors during development, you can reduce their frequency by:
             * Simply deleting the existing store:
             */
        
            [[NSFileManager defaultManager] removeItemAtPath:storePath error:nil];
        
            if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error])
            {
                NSLog(@"Error after error, cannot recover");
                [[MLGAI sharedInstance] trackLegacyEvent:@"DEJAVU_CORE_DATA_PERSISTENT_STORE_ERROR"];
            
                NSString *alertTitle = NSLocalizedString(@"DATABASE_NOT_RECOVER_DELETE_DATABASE_TITLE", nil);
                NSString *alertMsg = NSLocalizedString(@"DATABASE_NOT_RECOVER_DELETE_DATABASE_MSG", nil);
                NSString *alertBtn = NSLocalizedString(@"DATABASE_NOT_RECOVER_DELETE_DATABASE_BUTTON", nil);
            
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:alertTitle message:alertMsg delegate:nil cancelButtonTitle:alertBtn otherButtonTitles:nil, nil];
                [alert show];
            
            }
        
        }
    
    }
    return _persistentStoreCoordinator;
}
@end


