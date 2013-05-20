//
//  UWCEImage.m
//  UWCEImageCaching
//
//  Created by Doug Russell on 5/6/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import "UWCEImageCacheImage.h"
#import <libkern/OSAtomic.h>

static NSString *const UWCEImageTitleKey = @"title";
static NSString *const UWCEImageURLKey = @"url";

static int32_t _globalIDCounter = 10000;
static int32_t GetID(void)
{
	return OSAtomicIncrement32(&_globalIDCounter);
}

@implementation UWCEImageCacheImage

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
	self = [super init];
	if (self)
	{
		_title = [dictionary[UWCEImageTitleKey] copy];
		NSParameterAssert(_title);
		_urlString = [dictionary[UWCEImageURLKey] copy];
		NSParameterAssert(_urlString);
		_ID = GetID();
	}
	return self;
}

- (NSURL *)url
{
	NSString *urlString = self.urlString;
	if (urlString)
		return [NSURL URLWithString:urlString];
	return nil;
}

@end
