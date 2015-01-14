//
//  DejavuRequestSerializer.m
//  MercadoLibre
//
//  Created by Fabian Celdeiro on 2/21/14.
//  Copyright (c) 2014 Casa. All rights reserved.
//

#import "MLDejavuRequestSerializer.h"
#import "MLRequestUtils.h"
#import "NSDictionary+URLQueryString.h"

@implementation MLDejavuRequestSerializer

+ (instancetype)serializer {
    return [[self alloc] init];
}

-(id) init{
    if (self = [super init]){
        

  
    }
    return self;
}

-(NSDictionary*) HTTPRequestHeaders{
    /*
    NSDictionary * headers = [NSHTTPCookie requestHeaderFieldsWithCookies:@[@{
                                                       NSHTTPCookieDomain: @"dejavu.mercadolibre.com",
                                                       NSHTTPCookieName : @"_developermode",
                                                       NSHTTPCookieValue : @"true"}]];
    
    [NSHT]
     */
    
    NSMutableDictionary * headers = [NSMutableDictionary dictionary];
    
    if (self.sid){
        headers[@"Cookie"] = [NSString stringWithFormat:@"_d2id=%@",self.sid];
    }
    
    headers[@"User-Agent"] = [MLRequestUtils getUserAgent];
    
    return [NSDictionary dictionaryWithDictionary:headers];

}


- (NSURLRequest *)requestBySerializingRequest:(NSURLRequest *)request
                               withParameters:(NSDictionary *)parameters
                                        error:(NSError *__autoreleasing *)error{
    
    /* Unifico parameteros */
    
    /*
    NSDictionary * dejavuGenericParameters = [MLRequestUtils getDejavuGenericParameters];
    NSMutableDictionary * completeParameters = [NSMutableDictionary dictionaryWithDictionary:dejavuGenericParameters];
    for (NSString * key in parameters.allKeys){
        NSString * parameterValue = parameters[key];
        parameterValue = [parameterValue stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
        [completeParameters setObject:parameterValue forKey:key];
    }
    
    NSString *dejavuString =[completeParameters urlEncodedQueryString];
    NSDictionary * dejavuParam = [NSDictionary dictionaryWithObject:dejavuString forKey:@"dejavu"];

    
    [self setValue:parameters[@"page_id"] forHTTPHeaderField:@"page_id"];
    [self setValue:parameters[@"counter"] forHTTPHeaderField:@"counter"];
    
*/

 
    

    
   return [super requestBySerializingRequest:request withParameters:parameters error:error];
}
@end
