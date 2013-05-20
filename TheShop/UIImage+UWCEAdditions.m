//
//  UIImage+UWCEAdditions.m
//
//  Created by Doug Russell on 4/7/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import "UIImage+UWCEAdditions.h"

@implementation UIImage (UWCEAdditions)

CG_INLINE CGFloat UWCEGetScaleForProportionalResize(CGSize theSize, CGSize intoSize, bool onlyScaleDown, bool maximize)
{
	CGFloat sizeX = theSize.width;
	CGFloat sizeY = theSize.height;
	CGFloat deltaX = intoSize.width;
	CGFloat deltaY = intoSize.height;
	CGFloat scale = 1.0f;
	if ((sizeX != 0.0f) && (sizeY != 0.0f))
	{
		deltaX = deltaX / sizeX;
		deltaY = deltaY / sizeY;
		// if maximize is true, take LARGER of the scales, else smaller
		if (maximize)
		{
			scale = (deltaX > deltaY) ? deltaX : deltaY;
		}
		else
		{
			scale	= (deltaX < deltaY)	? deltaX : deltaY;
		}
		// reset scale
		if ((scale > 1) && onlyScaleDown)
		{
			scale = 1;
		}
	}
	else
	{
		scale = 0.0f;
	}
	return scale;
}

- (UIImage *)uwce_scaleImageToSize:(CGSize)targetSize
{
	UIImage *image = self;
	CGSize size = image.size;
	CGFloat scale = UWCEGetScaleForProportionalResize(size, targetSize, true, false);
	CGSize scaledSize = size;
	scaledSize.width *= scale;
	scaledSize.height *= scale;
	UIGraphicsBeginImageContextWithOptions(scaledSize, YES, 0.0f);
	[self drawInRect:CGRectMake(0.0f, 0.0f, scaledSize.width, scaledSize.height)];
	UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return scaledImage;
}

@end
