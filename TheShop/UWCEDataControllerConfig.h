//
//  UWCEDataControllerConfig.h
//  TheShop
//
//  Created by Doug Russell on 5/12/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UWCEDataControllerConfig : NSObject

@property (nonatomic, readonly) NSURL *shopManifestURL;
@property (nonatomic, readonly) NSURL *itemDetailURL;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (NSComparisonResult)compare:(UWCEDataControllerConfig *)otherConfig;

@end
