//
//  UWCEDatabase.m
//  TheShop
//
//  Created by Doug Russell on 5/13/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import "UWCEDatabase.h"

#if DEBUG && 0
#define CoreDataLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#define CoreDataLog(fmt, ...) 
#endif //DEBUG

@interface UWCEDatabase ()
// General Core Data
@property (nonatomic) NSManagedObjectModel *managedObjectModel;
@property (nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic) NSManagedObjectContext *writerContext;
@property (nonatomic) NSManagedObjectContext *readerContext;
@end

@implementation UWCEDatabase

- (instancetype)init
{
	self = [super init];
	if (self)
	{
		_managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
		_persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_managedObjectModel];
		
		NSURL *url = [self storeURL];
		
		// nuke the database on every launch
		//[[NSFileManager defaultManager] removeItemAtURL:url error:nil];
		
		NSDictionary *options = @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES};
		NSError *error = nil;
		if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:url options:options error:&error])
		{
			// Error adding persistent store
			[NSException raise:@"Could not add persistent store" format:@"%@", [error localizedDescription]];
		}
		
		_writerContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
		_writerContext.persistentStoreCoordinator = _persistentStoreCoordinator;
		
		_readerContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
		_readerContext.persistentStoreCoordinator = _persistentStoreCoordinator;
	}
	return self;
}

- (void)registerNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(managedObjectContextDidSaveNotification:) name:NSManagedObjectContextDidSaveNotification object:_writerContext];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willTerminate:) name:UIApplicationWillTerminateNotification object:nil];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Core Data Stack

- (NSURL *)storeURL
{
	NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
	return [directoryURL URLByAppendingPathComponent:@"TheShop.sqlite"];
}

- (void)managedObjectContextDidSaveNotification:(NSNotification *)notification
{
	NSParameterAssert([notification object] == self.writerContext);
	CoreDataLog(@"Context did save notification");
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		[self.readerContext mergeChangesFromContextDidSaveNotification:notification];
	});
}

- (NSManagedObjectContext *)childContext
{
	NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	context.parentContext = self.writerContext;
	return context;
}

- (BOOL)saveWriterContext
{
	NSParameterAssert(![NSThread isMainThread]);
	__block BOOL success;
	NSManagedObjectContext *context = self.writerContext;
	[context performBlockAndWait:^{
		success = [self saveContext:context];
	}];
	return success;
}

- (BOOL)saveContext:(NSManagedObjectContext *)context
{
	CoreDataLog(@"Save Context: %@", context);
	NSError *error;
	if (![context save:&error])
	{
		CoreDataLog(@"Core Data Error: %@", error);
		return NO;
	}
	return YES;
}

#pragma mark - Terminate

- (void)willTerminate:(NSNotification *)notification
{
	[self saveWriterContext];
}

@end
