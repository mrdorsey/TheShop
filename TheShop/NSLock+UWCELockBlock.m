//
//  NSLock+UWCELockBlock.m
//  Fetcher
//
//  Created by Doug Russell on 4/14/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import "NSLock+UWCELockBlock.h"

@implementation NSLock (UWCELockBlock)

- (void)uwce_lockBlock:(void (^)(void))block
{
	NSParameterAssert(block);
	NSException *exceptionForRethrow;
	@try {
		[self lock];
		block();
	}
	@catch (NSException *exception) {
		exceptionForRethrow = exception;
	}
	@finally {
		[self unlock];
		if (exceptionForRethrow)
		{
			@throw exceptionForRethrow;
		}
	}
}

@end

@implementation NSRecursiveLock (UWCELockBlock)

- (void)uwce_lockBlock:(void (^)(void))block
{
	NSParameterAssert(block);
	NSException *exceptionForRethrow;
	@try {
		[self lock];
		block();
	}
	@catch (NSException *exception) {
		exceptionForRethrow = exception;
	}
	@finally {
		[self unlock];
		if (exceptionForRethrow)
		{
			@throw exceptionForRethrow;
		}
	}
}

@end
