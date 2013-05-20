//
//  UWCEImageCache.h
//  UWCEImageCaching
//
//  Created by Doug Russell on 4/22/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const UWCEImageCacheErrorDomain;

typedef NS_ENUM(NSUInteger, UWCEImageCacheErrorCode) {
	UWCEImageCacheErrorCodeUnknown,
	UWCEImageCacheErrorCodeInvalidInput,
	UWCEImageCacheErrorCodeCorruptImageData,
	UWCEImageCacheErrorCodeScalingFailed,
};

@interface UWCEImageCache : NSObject

+ (instancetype)imageCache;

// Completion callbacks will occur on a private queue, be sure to move any UI interactions onto the main queue
// Pass CGSizeZero to use the image at it's natural size

- (void)imageForURL:(NSURL *)url size:(CGSize)size completionHandler:(void (^)(UIImage *, NSError *))completionHandler;

@end
