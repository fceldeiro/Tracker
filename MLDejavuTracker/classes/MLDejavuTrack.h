//
//  DejavuTrack.h
//  MercadoLibre
//
//  Created by Fabian Celdeiro on 2/27/14.
//  Copyright (c) 2014 Casa. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface MLDejavuTrack : NSManagedObject

@property (nonatomic, retain) NSDate * dateCreated;
@property (nonatomic, retain) NSString * parameters;

@end
