//
//  UWCEDataControllerConfig.m
//  TheShop
//
//  Created by Doug Russell on 5/12/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import "UWCEDataControllerConfig.h"

static NSString *UWCEShopManifestURLKey = @"shopManifestURL";
static NSString *UWCEItemDetailURLKey = @"itemDetailURL";
static NSString *UWCECreatedKey = @"created";

@interface UWCEDataControllerConfig ()
@property (nonatomic, readonly) NSDate *created;
@end

@implementation UWCEDataControllerConfig

// We can't accept a bad config so we fail to initialize
#define ConfigSanityCheck(value) if (!value) { self = nil; return nil; }

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
	self = [super init];
	if (self)
	{
		ConfigSanityCheck([dictionary isKindOfClass:[NSDictionary class]]);
		NSString *shopManifestURLString = dictionary[UWCEShopManifestURLKey];
		ConfigSanityCheck(shopManifestURLString);
		_shopManifestURL = [NSURL URLWithString:shopManifestURLString];
		ConfigSanityCheck(_shopManifestURL);
		NSString *itemDetailURLString = dictionary[UWCEItemDetailURLKey];
		ConfigSanityCheck(itemDetailURLString);
		_itemDetailURL = [NSURL URLWithString:itemDetailURLString];
		ConfigSanityCheck(_itemDetailURL);
		NSNumber *createdTimeStamp = dictionary[UWCECreatedKey];
		ConfigSanityCheck(createdTimeStamp);
		_created = [NSDate dateWithTimeIntervalSince1970:[createdTimeStamp doubleValue]];
		ConfigSanityCheck(_created);
	}
	return self;
}

- (NSComparisonResult)compare:(UWCEDataControllerConfig *)otherConfig
{
	if (self == otherConfig)
	{
		return NSOrderedSame;
	}
	return [self.created compare:[NSDate date]];
}

@end
