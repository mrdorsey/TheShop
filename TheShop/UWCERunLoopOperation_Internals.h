//
//  UWCERunLoopOperation_Internals.h
//  Fetcher
//
//  Created by Doug Russell on 4/15/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import "UWCERunLoopOperation.h"

@interface UWCERunLoopOperation ()

- (BOOL)isRunLoopThread;
- (NSThread *)runLoopThread;
- (void)startOnRunLoopThread;
- (void)cancelOnRunLoopThread;
- (void)finish;

@end
