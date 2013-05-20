//
//  UWCEAppDelegate.m
//  TheShop
//
//  Created by Doug Russell on 5/12/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import "UWCEAppDelegate.h"
#import "UWCEDataController.h"

@implementation UWCEAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	[[UWCEDataController sharedInstance] fetchConfig];
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    return YES;
}

@end
