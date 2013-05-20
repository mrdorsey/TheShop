//
//  UWCEImageScalingOperation.h
//  UWCEImageCaching
//
//  Created by Doug Russell on 4/22/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UWCEImageScalingOperation : NSOperation

@property (nonatomic, readonly) CGSize targetSize;
@property (nonatomic, readonly) UIImage *image;
@property (nonatomic, readonly) UIImage *scaledImage;

- (instancetype)initWithImage:(UIImage *)image targetSize:(CGSize)targetSize;

@end
