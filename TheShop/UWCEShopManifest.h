//
//  UWCEShopManifest.h
//  TheShop
//
//  Created by Doug Russell on 5/13/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class UWCEShopItem, UWCEShopKeyword;

@interface UWCEShopManifest : NSManagedObject

@property (nonatomic, retain) NSDate * created;
@property (nonatomic, retain) NSOrderedSet *items;
@property (nonatomic, retain) NSSet *keywords;

+ (NSString *)uwce_entityName;

@end

@interface UWCEShopManifest (CoreDataGeneratedAccessors)

- (void)addKeywordsObject:(UWCEShopKeyword *)value;
- (void)removeKeywordsObject:(UWCEShopKeyword *)value;
- (void)addKeywords:(NSSet *)values;
- (void)removeKeywords:(NSSet *)values;

@end
