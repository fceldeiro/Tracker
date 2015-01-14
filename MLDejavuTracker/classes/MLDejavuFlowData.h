//
//  MLDejavuFlowData.h
//  MercadoLibre
//
//  Created by Fabian Celdeiro on 2/26/14.
//  Copyright (c) 2014 Casa. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MLDejavuFlowData : NSObject
@property (nonatomic,copy) NSString *flowName;
@property (nonatomic,copy) NSString *flowId;
@property (nonatomic,strong) NSDate * dateCreated;
@property (nonatomic,strong) NSDictionary * extraParameters;
@end
