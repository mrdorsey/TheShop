//
//  UWCEImageScalingOperation.m
//  UWCEImageCaching
//
//  Created by Doug Russell on 4/22/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import "UWCEImageScalingOperation.h"
#import "UIImage+UWCEAdditions.h"

@interface UWCEImageScalingOperation ()
@property (nonatomic) UIImage *scaledImage;
@end

@implementation UWCEImageScalingOperation

- (instancetype)initWithImage:(UIImage *)image targetSize:(CGSize)targetSize
{
	self = [super init];
	if (self)
	{
		NSParameterAssert(image);
		NSParameterAssert(!CGSizeEqualToSize(CGSizeZero, targetSize));
		_targetSize = targetSize;
		_image = image;
	}
	return self;
}

- (void)main
{
	@autoreleasepool {
		self.scaledImage = [self.image uwce_scaleImageToSize:self.targetSize];
	}
}

@end
