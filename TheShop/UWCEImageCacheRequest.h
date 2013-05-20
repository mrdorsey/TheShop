//
//  UWCEImageCacheRequest.h
//  UWCEImageCaching
//
//  Created by Doug Russell on 4/22/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UWCEImageCacheRequest : NSObject

// Hashed url string
@property (nonatomic) NSString *primaryKey;
// Hashed url string with size appended
@property (nonatomic) NSString *sizedKey;
// Target image size
@property (nonatomic) CGSize size;
// Completion callback
@property (copy, nonatomic) void (^completionHandler)(UIImage *, NSError *);

@end
