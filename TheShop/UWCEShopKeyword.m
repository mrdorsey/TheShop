//
//  UWCEShopKeyword.m
//  TheShop
//
//  Created by Doug Russell on 5/13/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import "UWCEShopKeyword.h"
#import "UWCEShopItem.h"
#import "UWCEShopManifest.h"

@implementation UWCEShopKeyword
@dynamic value;
@dynamic items;
@dynamic manifest;

+ (NSString *)uwce_entityName
{
	return @"Keyword";
}

@end
