//
//  AppDelegate.h
//  Files
//
//  Created by Vlad Alexa on 5/23/12.
//  Copyright (c) 2012 Next Design. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "CloudController.h"
#import "BackupController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    CloudController *cloudController;
    BackupController *backupController;
    NSUserDefaults *defaults;
    NSUbiquitousKeyValueStore  *cloudDefaults;    
    IBOutlet NSWindow *aboutWindow;
}

@property (unsafe_unretained) IBOutlet NSWindow *window;

-(void)createFolder;
-(void)timerLoop:(NSTimer*)timer;
- (NSString*)testConnectionByName:(BOOL)byName;

@end
