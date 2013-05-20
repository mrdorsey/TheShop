//
//  UWCEShopItem.m
//  TheShop
//
//  Created by Doug Russell on 5/13/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import "UWCEShopItem.h"
#import "UWCEShopKeyword.h"
#import "UWCEShopManifest.h"

@implementation UWCEShopItem
@dynamic identifier;
@dynamic title;
@dynamic author;
@dynamic smallVideoPosterFrameURL;
@dynamic largeVideoPosterFrameURL;
@dynamic details;
@dynamic manifest;
@dynamic keywords;

+ (NSString *)uwce_entityName
{
	return @"Item";
}

@end
