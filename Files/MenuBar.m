//
//  MenuBar.m
//  Files
//
//  Created by Vlad Alexa on 5/23/12.
//  Copyright (c) 2012 Next Design. All rights reserved.
//

#import "MenuBar.h"

@implementation MenuBar

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(theEvent:) name:@"MenuBarEvent" object:nil];        
        
        defaults = [NSUserDefaults standardUserDefaults]; 
        
        cloudDefaults = [NSUbiquitousKeyValueStore defaultStore];        

        filesUsageString = [NSMutableString stringWithCapacity:1];
        [filesUsageString setString:@""];         
        filesUploadedString = [NSMutableString stringWithCapacity:1];
        [filesUploadedString setString:@""];         
        filesDownloadedString = [NSMutableString stringWithCapacity:1];
        [filesDownloadedString setString:@""];                 
        
        backupUsageString = [NSMutableString stringWithCapacity:1];
        [backupUsageString setString:@""];        
        backupUploadedString = [NSMutableString stringWithCapacity:1];
        [backupUploadedString setString:@""];        
        backupDownloadedString = [NSMutableString stringWithCapacity:1];
        [backupDownloadedString setString:@""];        
        
        errorTitle = [[NSMutableAttributedString alloc] init];

        menuBarIcon = [[MenuBarIcon alloc] init];        
        
        _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
        [_statusItem setHighlightMode:YES];
        [_statusItem setToolTip:[NSString stringWithFormat:@"Files"]];       
        [_statusItem setTarget:self];  
        [_statusItem setView:menuBarIcon];         
        
        [self loadMenu];
        
    }
    
    return self;
}


-(void)theEvent:(NSNotification*)notif
{	
	if (![[notif name] isEqualToString:@"MenuBarEvent"]) {		
		return;
	}	
	if ([[notif object] isKindOfClass:[NSString class]]){
        if ([[notif object] isEqualToString:@"refresh"]) {             
            [menuBarIcon setGray:NO]; 
            [menuBarIcon setBlue:NO];             
            [menuBarIcon removeAnimations];
            [self loadMenu];            
        }
        if ([[notif object] isEqualToString:@"click"]) {
            [_statusItem popUpStatusItemMenu:[_statusItem menu]];
        } 
        if ([[notif object] isEqualToString:@"noiCloud"]) {
            [menuBarIcon setGray:YES];
            [menuBarIcon pulse:@"red"];             
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSColor colorWithDeviceRed:0.5 green:0.0 blue:0.0 alpha:0.5], NSForegroundColorAttributeName,[NSFont systemFontOfSize:14.0] ,NSFontAttributeName,nil];
            [errorTitle setAttributedString:[[NSAttributedString alloc] initWithString:@"iCloud not available" attributes:attributes]];	
            [self loadMenu];                        
        } 
        if ([[notif object] isEqualToString:@"nointernet"]) {
            [menuBarIcon setGray:YES];
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSColor grayColor], NSForegroundColorAttributeName,[NSFont systemFontOfSize:14.0] ,NSFontAttributeName,nil];
            [errorTitle setAttributedString:[[NSAttributedString alloc] initWithString:@"No internet connection" attributes:attributes]];	                      
            [self loadMenu];                        
        }   
	} 
	if ([[notif userInfo] isKindOfClass:[NSDictionary class]]){
        if ([[notif object] isEqualToString:@"backingUp"]) {
            backUpProgress = [[[notif userInfo] objectForKey:@"percent"] intValue];
            if ([menuBarIcon blue] == NO) {
                [menuBarIcon setBlue:YES];    
                if ([defaults boolForKey:@"backupPaused"] == YES) {
                    [menuBarIcon pulse:nil];
                }else {
                    [menuBarIcon slide:nil];                
                }                   
            } 
            [self loadMenu];                        
        }         
        if ([[notif object] isEqualToString:@"countsAndSizes"]) {
            NSDictionary *dict = [notif userInfo];
            
            [filesUsageString setString:[dict objectForKey:@"filesUsageString"]]; 
            NSString *fu = [dict objectForKey:@"filesUploadedString"];
            if (![fu isEqualToString:@"Uploaded 0.0 B in 0 items"]) [filesUploadedString setString:fu];
            NSString *fd = [dict objectForKey:@"filesDownloadedString"];
            if (![fd isEqualToString:@"Downloaded 0.0 B in 0 items"]) [filesDownloadedString setString:fd];             
            
            [backupUsageString setString:[dict objectForKey:@"backupUsageString"]]; 
            NSString *bu = [dict objectForKey:@"backupUploadedString"];
            if (![bu isEqualToString:@"Uploaded 0.0 B in 0 items"]) [backupUploadedString setString:bu];
            NSString *bd = [dict objectForKey:@"backupDownloadedString"];
            if (![bd isEqualToString:@"Downloaded 0.0 B in 0 items"]) [backupDownloadedString setString:bd];
            
            [self loadMenu];            
        }        
    }    
}

- (NSMenu *) newMenu
{
	NSZone *menuZone = [NSMenu menuZone];
	NSMenu *menu = [[NSMenu allocWithZone:menuZone] init];
	[menu setAutoenablesItems:NO];
    [menu setDelegate:self];
	NSMenuItem *menuItem;
    
    //header  
    if ([filesUsageString length] > 0) {
        menuItem = [menu addItemWithTitle:filesUsageString action:nil keyEquivalent:@""];	
        [menuItem setEnabled:NO];             
    }
    
	if (menuBarIcon.gray == YES) {					
        menuItem = [menu addItemWithTitle:@"error" action:nil keyEquivalent:@""];
        [menuItem setAttributedTitle:errorTitle];        
        [menuItem setEnabled:NO];
	}else{
        if ([filesUploadedString length] > 0) {        
            NSMenu *subMenu = [self newUploadedFilesMenu];
            menuItem = [menu addItemWithTitle:filesUploadedString action:nil keyEquivalent:@""];	
            [menuItem setSubmenu:subMenu];            
        }
	}	       
       
    NSMenu *subMenu = [self newBackupsMenu];
	if (menuBarIcon.blue == YES) {
        if ([defaults boolForKey:@"backupPaused"] == YES){
            menuItem = [menu addItemWithTitle:@"Backup paused" action:nil keyEquivalent:@""];	                    
        }else {
            NSString *title = [NSString stringWithFormat:@"Backup progress: %i%%",backUpProgress];
            menuItem = [menu addItemWithTitle:title action:nil keyEquivalent:@""];	                    
        }        
    }else {
        NSDate *lastBackup = [cloudDefaults objectForKey:@"lastBackup"];
        float hourssince = ([lastBackup timeIntervalSinceNow]*-1)/60/60;	
        if (hourssince > 24) {	
            menuItem = [menu addItemWithTitle:@"Backing up today" action:nil keyEquivalent:@""];	            
        }else {
            menuItem = [menu addItemWithTitle:@"Backing up tomorow" action:nil keyEquivalent:@""];            
        }
    }
    [menuItem setSubmenu:subMenu];  
    
    NSDictionary *collisions = [defaults objectForKey:@"collisions"];
    NSDictionary *suspected = [defaults objectForKey:@"suspected"];
    
    if ([collisions count] > 0 || [suspected count] > 0) {
        [menu addItem:[NSMenuItem separatorItem]]; 
        if ([menuBarIcon gray] == NO && [menuBarIcon blue] == NO) [menuBarIcon pulse:@"yellow"];        
    }
    
    if ([collisions count] > 0) {
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSColor colorWithDeviceRed:0.6 green:0.6 blue:0.0 alpha:1.0], NSForegroundColorAttributeName,[NSFont systemFontOfSize:14.0] ,NSFontAttributeName,nil];
        NSAttributedString *title = [[NSAttributedString alloc] initWithString:@"Case Collisions" attributes:attributes];        
        NSMenu *subMenu = [self newCollisionsMenu];
        menuItem = [menu addItemWithTitle:@"Case Collisions" action:nil keyEquivalent:@""];
        [menuItem setAttributedTitle:title];
        [menuItem setSubmenu:subMenu];          
    }    
    
    if ([suspected count] > 0) {
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSColor colorWithDeviceRed:0.6 green:0.6 blue:0.0 alpha:1.0], NSForegroundColorAttributeName,[NSFont systemFontOfSize:14.0] ,NSFontAttributeName,nil];
        NSAttributedString *title = [[NSAttributedString alloc] initWithString:@"Suspect Modifications" attributes:attributes];          
        NSMenu *subMenu = [self newSuspectedMenu];
        menuItem = [menu addItemWithTitle:@"Suspect Modifications" action:nil keyEquivalent:@""];	
        [menuItem setAttributedTitle:title];        
        [menuItem setSubmenu:subMenu];  
    }        
    
	// Add Separator
	[menu addItem:[NSMenuItem separatorItem]];    

	menuItem = [menu addItemWithTitle:@"Help" action:@selector(openHelp:) keyEquivalent:@""]; 
	[menuItem setTarget:self];    
    
	menuItem = [menu addItemWithTitle:@"About" action:@selector(showAbout:) keyEquivalent:@""]; 
	[menuItem setTarget:self];	    
    
	menuItem = [menu addItemWithTitle:@"Quit" action:@selector(actionQuit:) keyEquivalent:@""];
	[menuItem setTarget:self];	
	
	return menu;
}

-(NSMenu *)newCollisionsMenu
{
 	NSMenu *ret = [[NSMenu alloc] initWithTitle:@"Case Collisions"];
    
    NSDictionary *dict = [defaults objectForKey:@"collisions"];
    for (NSString *name in dict) {
        NSString *fullPath = [dict objectForKey:name];
        NSMenuItem *menuItem = [ret addItemWithTitle:name action:@selector(revealInFinder:) keyEquivalent:@""];
        [menuItem setToolTip:fullPath];
        [menuItem setTarget:self];	
    } 
	return ret;
}

-(NSMenu *)newSuspectedMenu
{
 	NSMenu *ret = [[NSMenu alloc] initWithTitle:@"Suspected"];
    
    NSDictionary *dict = [defaults objectForKey:@"suspected"];
    for (NSString *name in dict) {
        NSString *fullPath = [dict objectForKey:name];
        NSMenuItem *menuItem = [ret addItemWithTitle:name action:@selector(revealInFinder:) keyEquivalent:@""];
        [menuItem setToolTip:fullPath];
        [menuItem setTarget:self];	
    } 
	return ret;
}

-(NSMenu *)newUploadedFilesMenu
{
 	NSMenu *ret = [[NSMenu alloc] initWithTitle:@"Uploads"];
    
    NSArray *arr = [defaults objectForKey:@"filesUploads"];
    if ([arr count] == 0) {
        NSMenuItem *menuItem = [ret addItemWithTitle:@"no active uploads" action:nil keyEquivalent:@""];	
        [menuItem setEnabled:NO];              
    }else {
        for (NSString *name in arr) {
            NSMenuItem *menuItem = [ret addItemWithTitle:name action:nil keyEquivalent:@""];
            [menuItem setEnabled:NO];          
        }
    }       
    
	return ret;
}

-(NSMenu *)newUploadedBackupsMenu
{
 	NSMenu *ret = [[NSMenu alloc] initWithTitle:@"Uploads"];
    
    NSArray *arr = [defaults objectForKey:@"backupUploads"];
    if ([arr count] == 0) {
        NSMenuItem *menuItem = [ret addItemWithTitle:@"no active uploads" action:nil keyEquivalent:@""];	
        [menuItem setEnabled:NO];              
    }else {
        for (NSString *name in arr) {
            NSMenuItem *menuItem = [ret addItemWithTitle:name action:nil keyEquivalent:@""];
            [menuItem setEnabled:NO];          
        }
    }
    
	return ret;
}

-(NSMenu *)newBackupsMenu
{    
 	NSMenu *ret = [[NSMenu alloc] initWithTitle:@"Root"];
    
    NSMenuItem *menuItem;
    
    //header
    if ([backupUsageString length] > 0) {    
        menuItem = [ret addItemWithTitle:backupUsageString action:nil keyEquivalent:@""];	
        [menuItem setEnabled:NO];  
    }    
    
    if ([backupUploadedString length] > 0) {
        NSMenu *uploadMenu = [self newUploadedBackupsMenu];
        menuItem = [ret addItemWithTitle:backupUploadedString action:nil keyEquivalent:@""];	
        [menuItem setSubmenu:uploadMenu];             
    }
    
	if (menuBarIcon.blue == YES) {
        if ([defaults boolForKey:@"backupPaused"] == YES){
            menuItem = [ret addItemWithTitle:@"Resume backup" action:@selector(resumeBackup:) keyEquivalent:@""];
            [menuItem setTarget:self];	                    
        }else {
            menuItem = [ret addItemWithTitle:@"Pause backup" action:@selector(pauseBackup:) keyEquivalent:@""];
            [menuItem setTarget:self];	                    
        }        
    } 
    
    NSString *dirPath = [[[[defaults objectForKey:@"path"] stringByReplacingOccurrencesOfString:@"/Documents" withString:@""] stringByAppendingPathComponent:@".Backups"] stringByResolvingSymlinksInPath];    
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *filelist = [fm contentsOfDirectoryAtPath:dirPath error:&error];
    
    if ([filelist count] == 0) return ret; //do not show a empty menu for no reason
    
 	NSMenu *subMenu = [[NSMenu alloc] initWithTitle:@"Backups"];    
    menuItem = [ret addItemWithTitle:@"Backups" action:nil keyEquivalent:@""];	    
    [menuItem setSubmenu:subMenu];     
    
    for (NSString *lastPathComponent in filelist) {
        if ([lastPathComponent length] < 1) continue;        
        NSString *fullPath = [dirPath stringByAppendingPathComponent:lastPathComponent];
        BOOL isDir;        
        BOOL exists = [fm fileExistsAtPath:fullPath isDirectory:&isDir];
        if (exists) {
            if (isDir) {
                NSMenuItem *menuItem = [subMenu addItemWithTitle:lastPathComponent action:@selector(revealInFinder:) keyEquivalent:@""];
                [menuItem setToolTip:fullPath];
                [menuItem setTarget:self];	
            }                    
        }
    } 
            
	return ret;
}

-(void)pauseBackup:(NSMenuItem*)sender
{ 
    [defaults setObject:[NSNumber numberWithBool:YES] forKey:@"backupPaused"];  
    [defaults synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BackupControllerEvent" object:@"pause" userInfo:nil];                 
    [menuBarIcon pulse:nil];
    [self loadMenu];      
}

-(void)resumeBackup:(NSMenuItem*)sender
{
    [defaults setObject:[NSNumber numberWithBool:NO] forKey:@"backupPaused"];
    [defaults synchronize];    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BackupControllerEvent" object:@"resume" userInfo:nil];                 
    [menuBarIcon slide:nil];
    [self loadMenu];      
}

-(void)revealInFinder:(NSMenuItem*)sender
{
    NSString *path = [sender toolTip];
    [[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:nil];
}

-(void)loadMenu
{
    NSMenu *menu = [self newMenu];
    menu.delegate = self;
    [_statusItem setMenu:menu];
}

#pragma mark NSMenuDelegate

- (void)menuDidClose:(NSMenu *)menu
{
    [menuBarIcon setMouseDown:NO];   
    [menuBarIcon setNeedsDisplay:YES];      
}

- (void) actionQuit:(id)sender
{
	[[NSStatusBar systemStatusBar] removeStatusItem:_statusItem];
	[NSApp terminate:sender];
}


-(void) showAbout:(id)sender
{
	[aboutWindow makeKeyAndOrderFront:sender];
    [NSApp arrangeInFront:aboutWindow];    
}

- (void) openHelp:(id)sender
{
	NSURL *url = [NSURL URLWithString:@"http://vladalexa.com/apps/osx/files/index.html#help"];
	[[NSWorkspace sharedWorkspace] openURL:url];
	[[NSApp keyWindow] close];
}

@end

