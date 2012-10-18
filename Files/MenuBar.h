//
//  MenuBar.h
//  Files
//
//  Created by Vlad Alexa on 5/23/12.
//  Copyright (c) 2012 Next Design. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MenuBarIcon.h"

@interface MenuBar : NSObject <NSMenuDelegate> {
@private
	NSStatusItem *_statusItem;
    NSUserDefaults *defaults;
    NSUbiquitousKeyValueStore *cloudDefaults;    
    id nseventMonitor;
    MenuBarIcon *menuBarIcon;
    IBOutlet NSWindow *aboutWindow;
    NSMutableAttributedString *errorTitle;
    NSMutableString *filesUsageString;
    NSMutableString *filesUploadedString;
    NSMutableString *filesDownloadedString;        
    NSMutableString *backupUsageString;
    NSMutableString *backupUploadedString;
    NSMutableString *backupDownloadedString;    
    int backUpProgress;
}


-(void)pauseBackup:(NSMenuItem*)sender;
-(void)revealInFinder:(NSMenuItem*)sender;

- (NSMenu *) newMenu;
- (void)loadMenu;

- (void) actionQuit:(id)sender;
- (void) showAbout:(id)sender;

@end
