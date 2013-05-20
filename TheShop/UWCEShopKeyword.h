//
//  UWCEShopKeyword.h
//  TheShop
//
//  Created by Doug Russell on 5/13/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class UWCEShopItem, UWCEShopManifest;

@interface UWCEShopKeyword : NSManagedObject

@property (nonatomic, retain) NSString * value;
@property (nonatomic, retain) NSSet *items;
@property (nonatomic, retain) UWCEShopManifest *manifest;

+ (NSString *)uwce_entityName;

@end

@interface UWCEShopKeyword (CoreDataGeneratedAccessors)

- (void)addItemsObject:(UWCEShopItem *)value;
- (void)removeItemsObject:(UWCEShopItem *)value;
- (void)addItems:(NSSet *)values;
- (void)removeItems:(NSSet *)values;

@end
