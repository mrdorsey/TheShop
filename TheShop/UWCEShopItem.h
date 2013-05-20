//
//  UWCEShopItem.h
//  TheShop
//
//  Created by Doug Russell on 5/13/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class UWCEShopKeyword, UWCEShopManifest;

@interface UWCEShopItem : NSManagedObject

@property (nonatomic, retain) NSString * identifier;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSString * author;
@property (nonatomic, retain) NSString * smallVideoPosterFrameURL;
@property (nonatomic, retain) NSString * largeVideoPosterFrameURL;
@property (nonatomic, retain) NSString * details;
@property (nonatomic, retain) UWCEShopManifest *manifest;
@property (nonatomic, retain) NSSet *keywords;

+ (NSString *)uwce_entityName;

@end

@interface UWCEShopItem (CoreDataGeneratedAccessors)

- (void)addKeywordsObject:(UWCEShopKeyword *)value;
- (void)removeKeywordsObject:(UWCEShopKeyword *)value;
- (void)addKeywords:(NSSet *)values;
- (void)removeKeywords:(NSSet *)values;

@end
