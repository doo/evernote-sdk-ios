//
//  AppDelegate.m
//  SampleNoteApp
//
//  Created by Ben Zotto on 4/3/14.
//  Copyright (c) 2014 n/a. All rights reserved.
//

#import "AppDelegate.h"
#import "ENSDK.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Set shared session key information.
    [ENSession setSharedSessionConsumerKey:@"your key"
                            consumerSecret:@"your secret"
                              optionalHost:ENSessionHostSandbox];
    
    return YES;
}
							
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    return [[ENSession sharedSession] handleOpenURL:url];
}
@end
