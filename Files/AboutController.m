//
//  AboutController.m
//  Files
//
//  Created by Vlad Alexa on 5/24/12.
//  Copyright (c) 2012 Next Design. All rights reserved.
//

#import "AboutController.h"

#import <ServiceManagement/ServiceManagement.h>

@implementation AboutController

-(void)awakeFromNib
{
    
    defaults = [NSUserDefaults standardUserDefaults];
    
    if ([self bundleIDExistsAsLoginItem:@"com.vladalexa.fileshelper"]) {
        [startToggle setSelectedSegment:1];
    }else {
        [startToggle setSelectedSegment:0];      
    } 
    
	if ([[defaults objectForKey:@"hideDock"] boolValue] == YES) {
		[dockToggle setSelectedSegment:1];
	}else {
		[dockToggle setSelectedSegment:0];		
	}    
    
}

#pragma mark actions

- (IBAction) openWebsite:(id)sender
{
	[NSApp endSheet:[sender window]];
	[[sender window] orderOut:self];
	NSURL *url = [NSURL URLWithString:@"http://vladalexa.com/apps/osx/files"];
	[[NSWorkspace sharedWorkspace] openURL:url];
	[[NSApp keyWindow] close];
}

-(IBAction) startToggle:(id)sender{
	if ([sender selectedSegment] == 1){
		[self setAutostart:YES];
		//NSLog(@"autostart on");
	}else {
		[self setAutostart:NO];
		//NSLog(@"autostart off");
	}	
}

-(IBAction) dockToggle:(id)sender{
	if ([sender selectedSegment] == 1){
		[defaults setObject:[NSNumber numberWithBool:YES] forKey:@"hideDock"];     
        [defaults synchronize];
        [self restartDialog];
		//NSLog(@"dock icon hiden");
	}else {
		[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"hideDock"];
        [defaults synchronize];        
        [self restartDialog];	
		//NSLog(@"dock icon shown");
	}	
}

-(void)restartDialog
{
    NSAlert *alert = [NSAlert alertWithMessageText:@"Application relaunch required" defaultButton:@"Ok quit the app" alternateButton:nil otherButton:nil informativeTextWithFormat:@"A relaunch of the application is required for the setting to take effect."];
    [alert beginSheetModalForWindow:[NSApp mainWindow] modalDelegate:NSApp didEndSelector:@selector(terminate:) contextInfo:nil]; 
}

#pragma mark version

- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key { 
    if ([key isEqualToString: @"versionString"]) return YES; 
    return NO; 
} 

- (NSString *)versionString {
	NSString *sv = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	NSString *v = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];	
	return [NSString stringWithFormat:@"version %@ (%@)",sv,v];	
}


#pragma mark autostart

- (void)setAutostart:(BOOL)set
{
	NSURL *theURL = [[[NSBundle mainBundle] bundleURL] URLByAppendingPathComponent:@"Contents/Library/LoginItems/fileshelper.app"];    
    NSString *theBID = @"com.vladalexa.fileshelper"; 
    
    Boolean success = SMLoginItemSetEnabled((__bridge CFStringRef)theBID, set);
    if (!success) {
        NSLog(@"Failed to SMLoginItemSetEnabled %@ %@",[theURL path],theBID);       
    }   
}

- (BOOL) bundleIDExistsAsLoginItem:(NSString *)bundleID {
    
    NSArray * jobDicts = nil;
    jobDicts = (__bridge_transfer NSArray *)SMCopyAllJobDictionaries( kSMDomainUserLaunchd );
    // Note: Sandbox issue when using SMJobCopyDictionary()
    
    if ( (jobDicts != nil) && [jobDicts count] > 0 ) {
        
        BOOL bOnDemand = NO;        
        for ( NSDictionary * job in jobDicts ) {        
            if ( [bundleID isEqualToString:[job objectForKey:@"Label"]] ) {
                bOnDemand = [[job objectForKey:@"OnDemand"] boolValue];                
                break;
            } 
        }

        jobDicts = nil;
        return bOnDemand;
        
    } 
    return NO;
}

@end
