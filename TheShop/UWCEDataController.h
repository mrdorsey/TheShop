//
//  UWCEDataController.h
//  UWCEImageCaching
//
//  Created by Doug Russell on 5/6/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UWCEImageCache.h"

// Posted after a new manifest has been saved successfully
// notification object is the new manifests objectID
extern NSString *const UWCEDataControllerNewManifestAvailableNotification;

@interface UWCEDataController : NSObject

+ (instancetype)sharedInstance;

- (void)fetchConfig;
@property (getter=isReady) bool ready;

// Main thread only
- (NSManagedObjectContext *)readerContext;

@end
