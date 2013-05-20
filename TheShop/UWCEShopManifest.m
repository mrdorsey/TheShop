//
//  UWCEShopManifest.m
//  TheShop
//
//  Created by Doug Russell on 5/13/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import "UWCEShopManifest.h"
#import "UWCEShopItem.h"
#import "UWCEShopKeyword.h"

@implementation UWCEShopManifest
@dynamic created;
@dynamic items;
@dynamic keywords;

+ (NSString *)uwce_entityName
{
	return @"Manifest";
}

@end
