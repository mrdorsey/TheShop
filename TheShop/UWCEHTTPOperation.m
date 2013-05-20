//
//  UWCEHTTPOperation.m
//  Fetcher
//
//  Created by Doug Russell on 4/15/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import "UWCEHTTPOperation.h"
#import "UWCERunLoopOperation_Internals.h"

// Simplified version of http://developer.apple.com/library/ios/#samplecode/MVCNetworking/Listings/Networking_QHTTPOperation_h.html#//apple_ref/doc/uid/DTS40010443-Networking_QHTTPOperation_h-DontLinkElementID_26 and https://github.com/rustle/ESNetworking/blob/master/ESHTTPOperation.m

@interface UWCEHTTPOperation () <NSURLConnectionDataDelegate>
@property (nonatomic) NSURLRequest *request;
@property (nonatomic) NSData *result;
@property (nonatomic) NSMutableData *accumulator;
@property (nonatomic) NSHTTPURLResponse *response;
@property (nonatomic) NSError *error;
@property (nonatomic) NSURLConnection *connection;
@property (nonatomic) bool firstData;
@end

@implementation UWCEHTTPOperation
@dynamic url;

static NSThread *_networkRunLoopThread = nil;

// This thread runs all of our network operation run loop callbacks.
+ (void)networkRunLoopThreadEntry
{
	NSAssert(([[NSThread currentThread] isEqual:[[self class] networkRunLoopThread]]), @"Entered networkRunLoopThreadEntry from invalid thread");	
	@autoreleasepool {
		// Schedule a timer in the distant future to keep the run loop from simply immediately exiting
		[NSTimer scheduledTimerWithTimeInterval:3600*24*365*100 target:nil selector:nil userInfo:nil repeats:NO];
		while (YES) 
		{
			@autoreleasepool {
				CFRunLoopRunInMode(kCFRunLoopDefaultMode, 10, NO);
			}
		}
	}
	NSAssert(NO, @"Exited networkRunLoopThreadEntry prematurely");
}

+ (NSThread *)networkRunLoopThread
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		// We run all of our network callbacks on a secondary thread to ensure that they don't
		// contribute to main thread latency. Create and configure that thread.
		_networkRunLoopThread = [[NSThread alloc] initWithTarget:[self class] selector:@selector(networkRunLoopThreadEntry) object:nil];
		NSParameterAssert(_networkRunLoopThread != nil);
		[_networkRunLoopThread setName:@"NetworkRunLoopThread"];
		[_networkRunLoopThread start];
	});
	return _networkRunLoopThread;
}

- (instancetype)initWithURL:(NSURL *)url
{
	self = [super init];
	if (self)
	{
		NSParameterAssert(url);
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
		//[request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
		_request = request;
	}
	return self;
}

- (NSThread *)runLoopThread
{
	return [[self class] networkRunLoopThread];
}

- (NSURL *)url
{
	return [self.request URL];
}

- (void)main
{
	NSParameterAssert([self isRunLoopThread]);
	
	if ([self isCancelled])
	{
		return;
	}
	
	NSURLRequest *request = self.request;
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
	NSParameterAssert(connection);
	if (connection)
	{
		self.connection = connection;
		[connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
		[connection start];
	}
	else
	{
		self.error = [NSError errorWithDomain:@"" code:0 userInfo:nil];
		[self finish];
	}
}

- (void)cancelOnRunLoopThread
{
	[self.connection cancel];
	self.connection = nil;
	self.error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
	
	[super cancelOnRunLoopThread];
}

#pragma mark - 

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
	NSParameterAssert([self isRunLoopThread]);
	NSParameterAssert(connection == self.connection);
	NSParameterAssert((response == nil) || [response isKindOfClass:[NSHTTPURLResponse class]]);
	self.response = (NSHTTPURLResponse *)response;
	self.firstData = true;
	return request;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	NSParameterAssert([self isRunLoopThread]);
	NSParameterAssert(connection == self.connection);
	NSParameterAssert([response isKindOfClass:[NSHTTPURLResponse class]]);
	self.response = (NSHTTPURLResponse *)response;
	self.firstData = true;
}

- (void)configureAccumulator
{
	NSParameterAssert([self isRunLoopThread]);
	NSParameterAssert(self.response);
	long long length = [self.response expectedContentLength];
	self.accumulator = [[NSMutableData alloc] initWithCapacity:length];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	NSParameterAssert([self isRunLoopThread]);
	NSParameterAssert(connection == self.connection);
	if (self.firstData)
	{
		[self configureAccumulator];
		self.firstData = false;
	}
	[self.accumulator appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	NSParameterAssert([self isRunLoopThread]);
	NSParameterAssert(connection == self.connection);
	NSParameterAssert(self.result == nil);
	if (self.accumulator)
	{
		self.result = self.accumulator;
		self.accumulator = nil;
	}
	else
	{
		self.result = [NSData data];
	}
	self.connection = nil;
	
	[self finish];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	NSParameterAssert([self isRunLoopThread]);
	NSParameterAssert(connection == self.connection);
	NSParameterAssert(self.result == nil);
	self.error = error;
	self.accumulator = nil;
	self.connection = nil;
	
	[self finish];
}

@end
