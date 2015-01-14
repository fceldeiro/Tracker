//
//  DejavuRequestSerializer.h
//  MercadoLibre
//
//  Created by Fabian Celdeiro on 2/21/14.
//  Copyright (c) 2014 Casa. All rights reserved.
//

#import "AFURLRequestSerialization.h"

@interface MLDejavuRequestSerializer : AFHTTPRequestSerializer

+ (instancetype)serializer ;

@property (nonatomic,copy) NSString * sid;

@end
