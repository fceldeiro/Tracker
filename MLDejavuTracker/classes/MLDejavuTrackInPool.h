//
//  DejavuTrackSent.h
//  MercadoLibre
//
//  Created by Fabian Celdeiro on 3/22/14.
//  Copyright (c) 2014 MercadoLibre. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MLDejavuTrackInPool : NSObject
@property (nonatomic,strong) NSManagedObjectID * objectIdSent;
@property (nonatomic,copy) NSString * parameterSent;
@end
