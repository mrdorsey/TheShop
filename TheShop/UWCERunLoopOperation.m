//
//  UWCERunLoopOperation.m
//  Fetcher
//
//  Created by Doug Russell on 4/14/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

// Simplified version of http://developer.apple.com/library/ios/#samplecode/MVCNetworking/Listings/Networking_QRunLoopOperation_m.html#//apple_ref/doc/uid/DTS40010443-Networking_QRunLoopOperation_m-DontLinkElementID_31 and https://github.com/rustle/ESNetworking/blob/master/ESRunLoopOperation.m

#import "UWCERunLoopOperation.h"
#import "NSLock+UWCELockBlock.h"

typedef enum {
	UWCERunLoopOperationStateInited,
	UWCERunLoopOperationStateExecuting,
	UWCERunLoopOperationStateFinished,
} UWCERunLoopOperationState;

static NSString *UWCEStringForState(UWCERunLoopOperationState state)
{
	switch (state) {
		case UWCERunLoopOperationStateInited:
			return @"UWCERunLoopOperationStateInited";
		case UWCERunLoopOperationStateExecuting:
			return @"UWCERunLoopOperationStateExecuting";
		case UWCERunLoopOperationStateFinished:
			return @"UWCERunLoopOperationStateFinished";
		default:
			NSCParameterAssert(NO);
			return @"";
	}
}

@interface UWCERunLoopOperation ()
{
@private
	NSRecursiveLock *_stateLock;
	UWCERunLoopOperationState _state;
	NSLock *_cancelLock;
}
@property UWCERunLoopOperationState state;
@end

@implementation UWCERunLoopOperation

#pragma mark - 

- (instancetype)init
{
	self = [super init];
	if (self)
	{
		_state = UWCERunLoopOperationStateInited;
		_stateLock = [NSRecursiveLock new];
		_cancelLock = [NSLock new];
	}
	return self;
}

- (void)dealloc
{
	NSAssert((_state != UWCERunLoopOperationStateExecuting), @"Run loop operation dealloced while still executing");
}

#pragma mark - State

+ (BOOL)automaticallyNotifiesObserversOfState
{
	return NO;
}

// any thread
- (UWCERunLoopOperationState)state
{
	__block UWCERunLoopOperationState state;
	[_stateLock uwce_lockBlock:^{
		state = _state;
	}];
	return state;
}

// any thread
- (void)setState:(UWCERunLoopOperationState)state
{
	NSParameterAssert(_stateLock);
	[_stateLock uwce_lockBlock:^{
		[self actuallySetState:state];
	}];
}

// any thread, but only from inside _stateLock
- (void)actuallySetState:(UWCERunLoopOperationState)state
{
	UWCERunLoopOperationState oldState = _state;
	
	// The following check is really important.  The state can only go forward, and there 
	// should be no redundant changes to the state (that is, state must never be 
	// equal to oldState).
	NSAssert((state > oldState), @"Invalid state transition from %d to %d", oldState, state);
	
	// Transitions from executing to finished must be done on the run loop thread.
	NSAssert(((state != UWCERunLoopOperationStateFinished) || [self isRunLoopThread]), @"Attempted transition to finish on non run loop thread");
	
	if ((state == UWCERunLoopOperationStateExecuting) || (oldState == UWCERunLoopOperationStateExecuting))
	{
		[self willChangeValueForKey:@"isExecuting"];
	}
	
	if (state == UWCERunLoopOperationStateFinished)
	{
		[self willChangeValueForKey:@"isFinished"];
	}
	
	_state = state;
//	NSLog(@"%@", UWCEStringForState(_state));
	
	if (state == UWCERunLoopOperationStateFinished)
	{
		[self didChangeValueForKey:@"isFinished"];
	}
	
	if ((state == UWCERunLoopOperationStateExecuting) || (oldState == UWCERunLoopOperationStateExecuting))
	{
		[self didChangeValueForKey:@"isExecuting"];
	}
}

#pragma mark - NSOperation

// any thread
- (BOOL)isConcurrent
{
	return YES;
}

// any thread
- (BOOL)isExecuting
{
    return (self.state == UWCERunLoopOperationStateExecuting);
}

// any thread
- (BOOL)isFinished
{
    return (self.state == UWCERunLoopOperationStateFinished);
}

#pragma mark - Life Cycle

// any thread
- (void)start
{
	NSAssert((self.state == UWCERunLoopOperationStateInited), @"Operation started in invalid state %d", self.state);
	
	// We have to change the state here, otherwise isExecuting won't necessarily return 
    // true by the time we return from -start.  Also, we don't test for cancellation 
    // here because that would a) result in us sending isFinished notifications on a 
    // thread that isn't our run loop thread, and b) confuse the core cancellation code, 
    // which expects to run on our run loop thread.  Finally, we don't have to worry 
    // about races with other threads calling -start.  Only one thread is allowed to 
    // start us at a time.
	
	self.state = UWCERunLoopOperationStateExecuting;
	[self performSelector:@selector(startOnRunLoopThread) onThread:[self runLoopThread] withObject:nil waitUntilDone:NO];
}

// run loop thread only
- (void)startOnRunLoopThread
{
	NSParameterAssert([self isRunLoopThread]);
	
	// Starts the operation. The actual -start method is very simple, 
	// deferring all of the work to be done on the run loop thread by this 
	// method.
	
	// If we got canceled and finished waiting for this to get scheduled, bail
	if (self.state != UWCERunLoopOperationStateExecuting)
	{
		return;
	}
	
	if ([self isCancelled]) 
	{
        // We were cancelled before we even got running.  Flip the the finished 
        // state immediately.
        [self finish];
    }
	else 
	{
        @autoreleasepool {
				[self main];
			}
    }
}

// run loop thread only
- (void)finish
{
	NSAssert([self isRunLoopThread], @"Entered finishWithError from non run loop thread");
	
	NSParameterAssert(_stateLock);
	[_stateLock uwce_lockBlock:^{
		// If we got canceled and finished waiting for this to get scheduled, bail
		if (_state != UWCERunLoopOperationStateExecuting)
		{
			return;
		}
		
		[self actuallySetState:UWCERunLoopOperationStateFinished];
	}];
}

// any thread
- (void)cancel
{
	__block BOOL runCancelOnRunLoopThread;
	
	// any thread
	
	// We need to synchronize here to avoid state changes to isCancelled and state
	// while we're running.
	
	NSParameterAssert(_cancelLock);
	[_cancelLock uwce_lockBlock:^{
		BOOL oldValue = [self isCancelled];
	
		// Call our super class so that isCancelled starts returning true immediately.
		
		[super cancel];
		
		// If we were the one to set isCancelled (that is, we won the race with regards 
		// other threads calling -cancel) and we're actually running (that is, we lost 
		// the race with other threads calling -start and the run loop thread finishing), 
		// we schedule to run on the run loop thread.
		
		runCancelOnRunLoopThread = !(oldValue && (self.state == UWCERunLoopOperationStateExecuting));
	}];
	if (runCancelOnRunLoopThread)
	{
		[self performSelector:@selector(cancelOnRunLoopThread) onThread:[self runLoopThread] withObject:nil waitUntilDone:YES];
	}
}

// run loop thread only
- (void)cancelOnRunLoopThread
{
    NSParameterAssert([self isRunLoopThread]);
	
    // We know that
	// a) state was UWCERunLoopOperationStateExecuting when we were  scheduled (that's enforced by -cancel)
	// b) the state can't go backwards (that's enforced by -setState)
	// so we know the state must either be UWCERunLoopOperationStateExecuting or UWCERunLoopOperationStateFinished. 
    // We also know that the transition from executing to finished always 
    // happens on the run loop thread.  Thus, we don't need to lock here.  
    // We can look at state and, if we're executing, trigger a cancellation.
    
    if (self.state == UWCERunLoopOperationStateExecuting)
	{
		[self finish];
	}
}

#pragma mark - Run Loop Thread

// any thread
- (NSThread *)runLoopThread
{
	return [NSThread mainThread];
}

// any thread
- (BOOL)isRunLoopThread
{
	return [[NSThread currentThread] isEqual:[self runLoopThread]];
}

#pragma mark - Main

// run loop thread only
- (void)main
{
	[self finish];
}

@end
