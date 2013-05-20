//
//  UWCEHTTPOperation.h
//  Fetcher
//
//  Created by Doug Russell on 4/15/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import "UWCERunLoopOperation.h"

@interface UWCEHTTPOperation : UWCERunLoopOperation

@property (nonatomic, readonly) NSURL *url;
@property (nonatomic, readonly) NSData *result;
@property (nonatomic, readonly) NSHTTPURLResponse *response;
@property (nonatomic, readonly) NSError *error;

- (instancetype)initWithURL:(NSURL *)url;

@end
