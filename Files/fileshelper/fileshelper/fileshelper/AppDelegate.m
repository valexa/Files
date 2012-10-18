//
//  AppDelegate.m
//  fileshelper
//
//  Created by Vlad Alexa on 5/24/12.
//  Copyright (c) 2012 Next Design. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

@synthesize window = _window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    
    NSArray *identifiers;
    [[NSWorkspace sharedWorkspace] openURLs:nil withAppBundleIdentifier:@"com.vladalexa.files" options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil launchIdentifiers:&identifiers];        
    
    //[[NSWorkspace sharedWorkspace] launchApplication:@"Files"];
    [NSApp terminate:self];
    
}

@end
