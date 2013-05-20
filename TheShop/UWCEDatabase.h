//
//  UWCEDatabase.h
//  TheShop
//
//  Created by Doug Russell on 5/13/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface UWCEDatabase : NSObject

// All methods are thread safe
@property (nonatomic, readonly) NSManagedObjectContext *readerContext;
- (NSManagedObjectContext *)childContext;
- (BOOL)saveWriterContext;
- (BOOL)saveContext:(NSManagedObjectContext *)context;

@end
