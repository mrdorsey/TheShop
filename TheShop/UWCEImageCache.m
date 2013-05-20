//
//  UWCEImageCache.m
//  UWCEImageCaching
//
//  Created by Doug Russell on 4/22/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import "UWCEImageCache.h"
#import "UWCEImageCacheRequest.h"
#import "UWCEImageScalingOperation.h"
#import "UWCEHTTPOperation.h"

#if DEBUG && 0
#define ImageCacheLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#define ImageCacheLog(fmt, ...) 
#endif //DEBUG

NSString *const UWCEImageCacheErrorDomain = @"UWCEImageCacheErrorDomain";

@interface UWCEImageCache ()
// Self purging in memory cache
@property (nonatomic) NSCache *memoryCache;
// ESHTTPOperations for images whose requests haven't been fulfilled
// Operations are left in activeImageConnections until all their 
// completion handlers have been called.
@property (nonatomic) NSMutableDictionary *activeImageConnections;
@property (nonatomic) NSMutableDictionary *activeScalingOperations;
// UWCEImageCacheRequest objects
@property (nonatomic) NSMutableDictionary *requests;
// File url for image cache folder
@property (nonatomic) NSURL *imageCacheURL;
// Queue through which interactions with collections funnels
// Used primarily for de-duplication
@property (nonatomic) NSOperationQueue *syncQueue;
// Queue for scheduling network ops, these are all concurrent ops
// scheduled on a single thread, so it's width is about how much
// traffic you want simultaneously, rather than about how much
// CPU you want to take up
@property (nonatomic) NSOperationQueue *networkQueue;
// CPU bound task queue
@property (nonatomic) NSOperationQueue *workQueue;
@end

@implementation UWCEImageCache

#pragma mark - Setup/Cleanup

+ (instancetype)imageCache
{
	static id instance;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [self new];
	});
	return instance;
}

- (instancetype)init
{
	self = [super init];
	if (self)
	{
		// Cap the cache at 100 items
		// This limit is arbitrary, but on devices with a lot
		// of ram, the NSCache can grow very large and then
		// fail to empty fast enough to avoid the watch dog
		_memoryCache = [NSCache new];
		_memoryCache.countLimit = 100;
		
		// Serial queue
		_syncQueue = [NSOperationQueue new];
		_syncQueue.name = @"com.uwce.imagecache.syncqueue";
		_syncQueue.maxConcurrentOperationCount = 1;
		
		_networkQueue = [NSOperationQueue new];
		_networkQueue.name = @"com.uwce.imagecache.networkqueue";
		NSParameterAssert(_networkQueue);
		_networkQueue.maxConcurrentOperationCount = 10;
		
		_workQueue = [NSOperationQueue new];
		_workQueue.name = @"com.uwce.imagecache.workqueue";
		NSParameterAssert(_workQueue);
		
		_activeImageConnections = [NSMutableDictionary new];
		_activeScalingOperations = [NSMutableDictionary new];
		_requests = [NSMutableDictionary new];
	}
	return self;
}

#pragma mark - Memory Cache Subscripting

// Allow self[key] for looking up and writing to memory cache
// This is mostly a novelty

- (id)objectForKeyedSubscript:(id)key
{
	return [self.memoryCache objectForKey:key];
}

- (void)setObject:(id)obj forKeyedSubscript:(id)key
{
	[self.memoryCache setObject:obj forKey:key];
}

#pragma mark - Disk IO

- (NSURL *)imageCacheURL
{
	// If the URL has already been resolved/created, return it
	if (_imageCacheURL)
	{
		return _imageCacheURL;
	}
	// Find the caches URL and create it if needed
	NSURL *url = [[NSFileManager defaultManager] URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
	// Append an arbitrary directory name, in this case KATGImageCache
	url = [url URLByAppendingPathComponent:@"UWCEImageCache"];
	// See if our directory exists and is actually a directory
	BOOL isDir;
	if (![[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDir])
	{
		// Create the directory
		NSError *error;
		if (![[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:NO attributes:nil error:&error])
		{
			// Not much we can do about this failing, so return nil and the cache will behave as an in memory only cache
			ImageCacheLog(@"%@", error);
			return nil;
		}
	}
	else if (!isDir)
	{
		// If the directory exists, but is not a directory, then some other logic is colliding with this cache and needs to be addressed
		// either by renaming this caches directory or fixing that other logic
		@throw [NSException exceptionWithName:NSGenericException reason:@"UWCEImageCache exists in caches directory, but is not a directory." userInfo:nil];
	}
	_imageCacheURL = url;
	return _imageCacheURL;
}

- (NSURL *)fileURLForImageKey:(NSString *)key
{
	NSParameterAssert(key);
	NSURL *url = [self.imageCacheURL URLByAppendingPathComponent:key];
	return url;
}

- (NSData *)imageDataForKey:(NSString *)key
{
	NSParameterAssert(![NSThread isMainThread]);
	NSParameterAssert(key);
	NSURL *fileURL = [self fileURLForImageKey:key];
	if (fileURL == nil)
	{
		return nil;
	}
	return [NSData dataWithContentsOfURL:fileURL];
}

- (void)deleteImageForKey:(NSString *)key extension:(NSString *)extension
{
	NSParameterAssert(![NSThread isMainThread]);
	NSParameterAssert(key);
	NSURL *fileURL = [self fileURLForImageKey:key];
	if (fileURL)
	{
		[[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
	}
}

- (UIImage *)tryToLoadImageData:(NSString *)key error:(NSError **)error
{
	NSData *imageData = [self imageDataForKey:key];
	if (imageData)
	{
		UIImage *image = [UIImage imageWithData:imageData scale:[[UIScreen mainScreen] scale]];
		if (image)
		{
			return image;
		}
		else
		{
			// If we have data but can't make an image from it, our data is no good
			[self deleteImageForKey:key extension:nil];
			if (error)
			{
				*error = [NSError errorWithDomain:UWCEImageCacheErrorDomain code:UWCEImageCacheErrorCodeCorruptImageData userInfo:nil];
			}
			return nil;
		}
	}
	if (error)
	{
		*error = nil;
	}
	return nil;
}

- (BOOL)writeImageData:(NSData *)imageData key:(NSString *)key
{
	NSParameterAssert(![NSThread isMainThread]);
	NSParameterAssert(imageData);
	NSParameterAssert(key);
	ImageCacheLog(@"Write image data %@", key);
	NSURL *fileURL = [self fileURLForImageKey:key];
	if (fileURL == nil)
	{
		return NO;
	}
	return [imageData writeToURL:fileURL atomically:YES];
}

#pragma mark - Requests

// Dead simple hash to generate a reasonably unique key from the string
NS_INLINE unsigned int UWCEBernsteinHash(NSString *string)
{
	unsigned int length = MIN([string length], 256);
	unichar buffer[length];
	[string getCharacters:buffer range:NSMakeRange(0, length)];
	unsigned int result = 5381;
	for (unsigned int i = 0; i < length; i++) { result = ((result << 5) + result) + buffer[i]; }
	return result;
}

// Create a new request object
- (UWCEImageCacheRequest *)newRequestForURL:(NSURL *)url size:(CGSize)size
{
	// Hash the url string to make a key
	unsigned int hash = UWCEBernsteinHash([url absoluteString]);
	NSString *primaryKey = [NSString stringWithFormat:@"%u", hash];
	// Append the image size to the key
	NSString *sizedKey = [NSString stringWithFormat:@"%u-%@", hash, NSStringFromCGSize(size)];
	UWCEImageCacheRequest *request = [UWCEImageCacheRequest new];
	request.primaryKey = primaryKey;
	request.sizedKey = sizedKey;
	request.size = size;
	return request;
}

// Store a map of maps of requests :)
// { primaryKey => { sizedkey => request } } 
// i.e. for url hashes 1 and 2, with requests for a 60x60 and 100x100 version of each:
// { 1 => { 1-60x60 => requestForOne60x60, 1-100x100 => requestForOne100x100 }, 2 => { 2-60x60 => requestForTwo60x60, 2-100x100 => requestForTwo100x100 } }
- (void)storeRequest:(UWCEImageCacheRequest *)request
{
	NSParameterAssert([[NSOperationQueue currentQueue] isEqual:self.syncQueue]);
	NSParameterAssert(request);
	NSParameterAssert(request.primaryKey);
	NSParameterAssert(request.sizedKey);
	NSParameterAssert(request.completionHandler);
	NSMutableDictionary *requestsMappedBySize = self.requests[request.primaryKey];
	if (requestsMappedBySize == nil)
	{
		requestsMappedBySize = [NSMutableDictionary new];
	}
	NSMutableArray *requestsForSize = requestsMappedBySize[request.sizedKey];
	if (requestsForSize == nil)
	{
		requestsForSize = [NSMutableArray new];
	}
	[requestsForSize addObject:request];
	requestsMappedBySize[request.sizedKey] = requestsForSize;
	self.requests[request.primaryKey] = requestsMappedBySize;
}

- (void)callCompletionHandlers:(UIImage *)image error:(NSError *)error primaryKey:(NSString *)primaryKey sizedKey:(NSString *)sizedKey
{
	NSParameterAssert([[NSOperationQueue currentQueue] isEqual:self.syncQueue]);
	ImageCacheLog(@"Calling completion handlers for %@ %@", primaryKey, sizedKey);
	NSMutableDictionary *requestsMappedBySize = self.requests[primaryKey];
	NSMutableArray *requestsForSize = requestsMappedBySize[sizedKey];
	for (UWCEImageCacheRequest *request in requestsForSize)
	{
		ImageCacheLog(@"Calling completion for %@", request.sizedKey);
		NSParameterAssert(request.completionHandler);
		request.completionHandler(image, error);
	}
	[requestsMappedBySize removeObjectForKey:sizedKey];
	// If there are no more requests in this size, we can remove this container
	if ([requestsMappedBySize count] == 0)
	{
		ImageCacheLog(@"Removing requests storage for %@", primaryKey);
		[self.requests removeObjectForKey:primaryKey];
	}
}

- (void)fullfillRequests:(UIImage *)image error:(NSError *)error primaryKey:(NSString *)primaryKey
{
	NSParameterAssert(primaryKey);
	if (image == nil && error == nil)
	{
		error = [NSError errorWithDomain:UWCEImageCacheErrorDomain code:UWCEImageCacheErrorCodeCorruptImageData userInfo:nil];
	}
	// Bounce to our serial queue 
	[self.syncQueue addOperationWithBlock:^{
		CGSize size = [image size];
		NSDictionary *requestsMappedBySize = self.requests[primaryKey];
		for (NSArray *requestsForSize in [[requestsMappedBySize allValues] copy]) 
		{
			NSParameterAssert([requestsForSize count]);
			UWCEImageCacheRequest *request = requestsForSize[0];
			bool sizeIsZero = CGSizeEqualToSize(request.size, CGSizeZero);
			// CGSizeZero indicates that no scaling should occur
			if (sizeIsZero || CGSizeEqualToSize(size, request.size))
			{
				ImageCacheLog(@"image is already the right size, calling completion handlers %@", request.sizedKey);
				// TODO: if image is already the right size or CGSizeZero is passed, just copy full into place
				[self callCompletionHandlers:image error:error primaryKey:primaryKey sizedKey:request.sizedKey];
			}
			else
			{
				[self queueScalingOp:image request:request];
			}
		}
	}];
}

#pragma mark - Scaling

- (void)handleScalingOperation:(UWCEImageScalingOperation *)op request:(UWCEImageCacheRequest *)request
{
	// Having a scaled image indicates success
	if (op.scaledImage)
	{
		ImageCacheLog(@"Done scaling %@", request.sizedKey);
		// Bounce onto the work queue
		[self.workQueue addOperationWithBlock:^{
			// Write out to disk
			BOOL success = YES;//[self writeImage:op.scaledImage key:request.sizedKey];
			NSParameterAssert(success);
			ImageCacheLog(@"Wrote %@ to disk", request.sizedKey);
			// Put the scaled image into the memory cache
			self[request.sizedKey] = op.scaledImage;
			// Bounce to sync queue to notify and cleanup
			[self.syncQueue addOperationWithBlock:^{
				ImageCacheLog(@"Calling completion handlers after scaling %@", request.sizedKey);
				// Call any request completion handlers for our newly scaled image
				[self callCompletionHandlers:op.scaledImage error:nil primaryKey:request.primaryKey sizedKey:request.sizedKey];
				// Cleanup active scaling ops
				[self.activeScalingOperations removeObjectForKey:request.sizedKey];
				ImageCacheLog(@"Checking for requests to fullfill after scaling %@", request.sizedKey);
				// Call fullfill to empty any image requests that have shown up during scaling
				[self fullfillRequests:op.image error:nil primaryKey:request.primaryKey];
			}];
		}];
	}
	else
	{
		NSError *error = [NSError errorWithDomain:UWCEImageCacheErrorDomain code:UWCEImageCacheErrorCodeScalingFailed userInfo:nil];
		[self callCompletionHandlers:nil error:error primaryKey:request.primaryKey sizedKey:request.sizedKey];
	}
}

- (void)queueScalingOp:(UIImage *)image request:(UWCEImageCacheRequest *)request
{
	NSParameterAssert(image);
	NSParameterAssert(request);
	NSParameterAssert(!CGSizeEqualToSize(CGSizeZero, request.size));
	[self.syncQueue addOperationWithBlock:^{
		// See if there's already an active scaling op for this size
		UWCEImageScalingOperation *op = self.activeScalingOperations[request.sizedKey];
		if (!op)
		{
			ImageCacheLog(@"Queueing up scaling for %@", request.sizedKey);
			op = [[UWCEImageScalingOperation alloc] initWithImage:image targetSize:request.size];
			NSParameterAssert(op);
			// Store the op for tracking
			self.activeScalingOperations[request.sizedKey] = op;
			__weak typeof(*op) *weakOp = op;
			op.completionBlock = ^ {
				ImageCacheLog(@"Done scaling %@", request.sizedKey);
				// Toss to handling which will notify waiting completion handlers and see if there
				// are any requests waiting to be fullfilled
				[self handleScalingOperation:weakOp request:request];
			};
			[self.workQueue addOperation:op];
		}
		else
		{
			ImageCacheLog(@"Already scaling for %@", request.sizedKey);
		}
	}];
}

#pragma mark - Networking

- (UIImage *)handleImageData:(NSData *)data size:(CGSize)size key:(NSString *)key sizedKey:(NSString *)sizedKey error:(NSError **)error
{
	UIImage *image = [UIImage imageWithData:data];
	if (image)
	{
		[self writeImageData:data key:key];
		return image;
	}
	if (error)
	{
		*error = [NSError errorWithDomain:UWCEImageCacheErrorDomain code:UWCEImageCacheErrorCodeCorruptImageData userInfo:nil];
	}
	return nil;
}

#pragma mark - Pretty

- (void)workQueueImageForURL:(NSURL *)url size:(CGSize)size completionHandler:(void (^)(UIImage *, NSError *))completionHandler
{
	[self.workQueue addOperationWithBlock:^{
		UWCEImageCacheRequest *imageRequest = [self newRequestForURL:url size:size];
		ImageCacheLog(@"URL %@ maps to %@", url, imageRequest.sizedKey);
		imageRequest.completionHandler = completionHandler;
		// See if an already scaled image is already in the memory cache
		UIImage *imageFromMemoryCache = self[imageRequest.sizedKey];
		if (imageFromMemoryCache)
		{
			ImageCacheLog(@"%@ from memory", imageRequest.sizedKey);
			completionHandler(imageFromMemoryCache, nil);
			return;
		}
		NSError *error;
		UIImage *sizedImageFromDisk = [self tryToLoadImageData:imageRequest.sizedKey error:&error];
		if (sizedImageFromDisk)
		{
			ImageCacheLog(@"Read %@ from disk", imageRequest.sizedKey);
			self[imageRequest.sizedKey] = sizedImageFromDisk;
			completionHandler(sizedImageFromDisk, nil);
			return;
		}
		UIImage *fullImageFromDisk = [self tryToLoadImageData:imageRequest.primaryKey error:&error];
		if (fullImageFromDisk)
		{
			ImageCacheLog(@"Read full image from disk %@", imageRequest.sizedKey);
			// TODO: if image is already the right size or CGSizeZero is passed, just copy full into place
			if (CGSizeEqualToSize(CGSizeZero, imageRequest.size))
			{
				completionHandler(fullImageFromDisk, nil);
			}
			else
			{
				ImageCacheLog(@"Queueing scaling %@", imageRequest.sizedKey);
				[self syncQueueScalingOperationWithRequest:imageRequest fullImageFromDisk:fullImageFromDisk];
			}
			return;
		}
		[self syncQueueNetworkOperationWithRequest:imageRequest url:url];
	}];
}

- (void)syncQueueScalingOperationWithRequest:(UWCEImageCacheRequest *)imageRequest fullImageFromDisk:(UIImage *)fullImageFromDisk
{
	[self.syncQueue addOperationWithBlock:^{
		// Store the image request so we can use it to queue up scaling ops and to call completion handlers
		// This only works because we funnel interactions with activeImageConnections and completionHandlers through syncQueue
		[self storeRequest:imageRequest];
		// Actually queue the scaling op
		[self queueScalingOp:fullImageFromDisk request:imageRequest];
	}];
}

- (void)syncQueueNetworkOperationWithRequest:(UWCEImageCacheRequest *)imageRequest url:(NSURL *)url
{
	// Before we can interrogate active network or image operations, we have to be on the sync queue
	[self.syncQueue addOperationWithBlock:^{
		// Store the image request so we can use it to queue up scaling ops and to call completion handlers
		// This only works because we funnel interactions with activeImageConnections and completionHandlers through syncQueue
		[self storeRequest:imageRequest];
		// See if we're already fetching the image
		UWCEHTTPOperation *op = self.activeImageConnections[imageRequest.primaryKey];
		if (!op)
		{
			ImageCacheLog(@"Downloading %@", imageRequest.sizedKey);
			op = [[UWCEHTTPOperation alloc] initWithURL:url];
			__weak typeof(*op) *weakOp = op;
			[op setCompletionBlock:^{
				NSData *result = weakOp.result;
				[self workQueueHandleResultData:result imageRequest:imageRequest];
			}];
			self.activeImageConnections[imageRequest.primaryKey] = op;
			[self.networkQueue addOperation:op];
		}
	}];
}

- (void)workQueueHandleResultData:(NSData *)result imageRequest:(UWCEImageCacheRequest *)imageRequest
{
	[self.workQueue addOperationWithBlock:^{
		NSError *error;
		UIImage *image = [self handleImageData:result size:imageRequest.size key:imageRequest.primaryKey sizedKey:imageRequest.sizedKey error:&error];
		ImageCacheLog(@"Done downloading %@", imageRequest.sizedKey);
		[self fullfillRequests:image error:image ? nil : error primaryKey:imageRequest.primaryKey];
	}];
}

#pragma mark - Public API

- (void)imageForURL:(NSURL *)url size:(CGSize)size completionHandler:(void (^)(UIImage *, NSError *))completionHandler
{
	ImageCacheLog(@"Request image for %@", url);
	// No completion handler, no dice
	NSParameterAssert(completionHandler);
	// No url, no dice
	if (url == nil)
	{
		NSParameterAssert(NO);
		completionHandler(nil, [NSError errorWithDomain:UWCEImageCacheErrorDomain code:UWCEImageCacheErrorCodeInvalidInput userInfo:nil]);
		return;
	}
	// Don't do squat on the main thread (we could be on any thread, but we're probably on the main thread)
	[self workQueueImageForURL:url size:size completionHandler:completionHandler];
}

@end
