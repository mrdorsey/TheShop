//
//  NSLock+UWCELockBlock.h
//  Fetcher
//
//  Created by Doug Russell on 4/14/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSLock (UWCELockBlock)
- (void)uwce_lockBlock:(void (^)(void))block;
@end

@interface NSRecursiveLock (UWCELockBlock)
- (void)uwce_lockBlock:(void (^)(void))block;
@end
