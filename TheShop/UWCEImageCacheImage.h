//
//  UWCEImage.h
//  UWCEImageCaching
//
//  Created by Doug Russell on 5/6/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UWCEImageCacheImage : NSObject

@property (copy, nonatomic) NSString *title;
@property (copy, nonatomic) NSString *urlString;
@property (nonatomic) NSUInteger ID;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

- (NSURL *)url;

@end
