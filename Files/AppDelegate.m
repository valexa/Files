//
//  AppDelegate.m
//  Files
//
//  Created by Vlad Alexa on 5/23/12.
//  Copyright (c) 2012 Next Design. All rights reserved.
//

#import "AppDelegate.h"

#include <arpa/inet.h>
#import <SystemConfiguration/SystemConfiguration.h>

@implementation AppDelegate

@synthesize window = _window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    
    defaults = [NSUserDefaults standardUserDefaults];
    
    cloudDefaults = [NSUbiquitousKeyValueStore defaultStore];  
    
    //NSLog(@"%@",[cloudDefaults dictionaryRepresentation]);    
    
	if ([[defaults objectForKey:@"hideDock"] boolValue] != YES) {
		//show dock icon		        
        ProcessSerialNumber psn = { 0, kCurrentProcess };
        TransformProcessType(&psn, kProcessTransformToForegroundApplication);        
	}	  
    
    if ([defaults objectForKey:@"hideDock"] == nil){
        [defaults setObject:[NSNumber numberWithBool:NO] forKey:@"hideDock"];        
        [defaults synchronize];
    }     

    backupController = [[BackupController alloc] init];
    
    cloudController = [[CloudController alloc] init];
    
    //inits the cloud storage if ran for the first time
    NSURL *url = [cloudController getiCloudURLFor:@"" containerID:nil]; //leaving nil so it is auto filled from entitlements
    
    if (url && [cloudController isiCloudAvailable])
    {
        [defaults setObject:[url path] forKey:@"path"];        
        [defaults synchronize];        
        if ([defaults objectForKey:@"folder"] == nil)
        {
            [self createFolder];
        }           
        
        //[cloudController loopFiles:@"conflicts"]; //TODO
        [cloudController loopFiles:@"sync"];      //TODO           
    }     
            
    [self timerLoop:nil];
    
    [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(timerLoop:) userInfo:nil repeats:YES];       
    
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
    if ([defaults objectForKey:@"path"]) {
        [[NSWorkspace sharedWorkspace] selectFile:nil inFileViewerRootedAtPath:[defaults objectForKey:@"path"]];        
        return YES;        
    }
    return NO;
}

-(void)createFolder
{  
    NSURL *cloudurl = [cloudController getiCloudURLFor:@"" containerID:nil];    
    NSString *path = [[NSString stringWithFormat:@"/Users/%@/Desktop/",NSUserName()] stringByResolvingSymlinksInPath];                
    NSSavePanel *panel = [NSSavePanel savePanel];
    [panel setPrompt:@"Done"];
    [panel setTitle:@"Select a location for the Files folder"];    
    [panel setNameFieldLabel:@"Folder name"];    
    [panel setNameFieldStringValue:[NSString stringWithFormat:@"%@'s cloud files",NSUserName()]];        
    [panel setShowsHiddenFiles:NO];
    [panel setDirectoryURL:[NSURL fileURLWithPath:path]];  
    [panel setCanCreateDirectories:NO];
	[panel beginWithCompletionHandler:^(NSInteger result) {
		if (result == NSFileHandlingPanelOKButton)
        {
            NSString *selection = [[[panel URL] path] stringByResolvingSymlinksInPath];  
            //set icon            
            NSImage *iconImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"foldericon" ofType:@"icns"]];
            if ([iconImage isValid]) {
                BOOL didSetIcon = [[NSWorkspace sharedWorkspace] setIcon:iconImage forFile:[cloudurl path] options:0];                                    
                if (didSetIcon) {
                    NSLog(@"Set icon succesfully");                        
                }
            }
            //make link
            NSError *error = nil;
            [[NSFileManager defaultManager] createSymbolicLinkAtPath:selection withDestinationPath:[cloudurl path] error:&error];
            if (error) 
            {
                NSLog(@"Error %@ creating link to %@ at %@",error,[cloudurl path],selection);                            
                [[NSAlert alertWithMessageText:@"Error creating folder." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:[error localizedDescription]] beginSheetModalForWindow:[NSApp mainWindow] modalDelegate:nil didEndSelector:nil contextInfo:nil];
                [self createFolder];
            }else {
                NSLog(@"Created link to %@ at %@",[cloudurl path],selection); 
                //save bookmark
                NSURL *url = [NSURL fileURLWithPath:selection];
                NSData *data = [url bookmarkDataWithOptions:NSURLBookmarkCreationMinimalBookmark includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
                if (error || (data == nil)) {
                    NSLog(@"Bookmark creation of %@ failed with error: %@",[url path],error);   
                }else{
                    [defaults setObject:data forKey:@"folder"];
                    [defaults synchronize];                                            
                }                 
            }  
        }else{
            NSString *denyNotice = @"The application will ask again the next time it's started.";            
            [[NSAlert alertWithMessageText:@"Without a folder there is not way to access your files." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:denyNotice] beginSheetModalForWindow:[NSApp mainWindow] modalDelegate:nil didEndSelector:nil contextInfo:nil];                            
        }              
	}];    
}

-(void)timerLoop:(NSTimer*)timer
{
    
    if ([self testConnectionByName:YES] == nil) {
        if ([self testConnectionByName:NO] == nil) {        
            NSLog(@"No internet");
            [[NSNotificationCenter defaultCenter] postNotificationName:@"MenuBarEvent" object:@"nointernet" userInfo:nil];            
            return;
        }    
    }
    
    if (![cloudController isiCloudAvailable]) {
        NSLog(@"No icloud");
        [[NSNotificationCenter defaultCenter] postNotificationName:@"MenuBarEvent" object:@"noiCloud" userInfo:nil];
        return;
    }     
    
    //run backup
    if ([backupController checkDir]){
        [backupController checkLoop];
        if ([backupController working] == YES) {
            return;  
        }else {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSString *dirPath = [[defaults objectForKey:@"path"] stringByResolvingSymlinksInPath];  
                NSString *backupsPath = [[dirPath stringByReplacingOccurrencesOfString:@"/Documents" withString:@""] stringByAppendingPathComponent:@".Backups"]; 
                NSArray *backups = [backupController backupsPaths:backupsPath];   
                NSDictionary *countsAndSizes = [backupController countsAndSizes];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"MenuBarEvent" object:@"countsAndSizes" userInfo:
                 [NSDictionary dictionaryWithObjectsAndKeys:
                  [NSString stringWithFormat:@"%@ in %@ files",[backupController humanizeSize:[[countsAndSizes objectForKey:@"filesSize"] intValue]],[countsAndSizes objectForKey:@"filesCount"]],@"filesUsageString",
                  [NSString stringWithFormat:@"Uploaded %@ in %@ items",[backupController humanizeSize:[[countsAndSizes objectForKey:@"filesUploadedSize"] intValue]],[countsAndSizes objectForKey:@"filesUploadedCount"]],@"filesUploadedString",
                  [NSString stringWithFormat:@"Downloaded %@ in %@ items",[backupController humanizeSize:[[countsAndSizes objectForKey:@"filesDownloadedSize"] intValue]],[countsAndSizes objectForKey:@"filesDownloadedCount"]],@"filesDownloadedString",             
                  [NSString stringWithFormat:@"%@ in %i backups",[backupController humanizeSize:[[countsAndSizes objectForKey:@"backupsSize"] intValue]],[backups count]],@"backupUsageString",
                  [NSString stringWithFormat:@"Uploaded %@ in %@ items",[backupController humanizeSize:[[countsAndSizes objectForKey:@"backupsUploadedSize"] intValue]],[countsAndSizes objectForKey:@"backupsUploadedCount"]],@"backupUploadedString",
                  [NSString stringWithFormat:@"Downloaded %@ in %@ items",[backupController humanizeSize:[[countsAndSizes objectForKey:@"backupsDownloadedSize"] intValue]],[countsAndSizes objectForKey:@"backupsDownloadedCount"]],@"backupDownloadedString",                                                                                                  
                  nil]];          
            });                    
        }        
    } 
    
    //check case collisions
	NSDate *lastUpdatecheck = [defaults objectForKey:@"lastCaseCheck"];
	float hourssince = ([lastUpdatecheck timeIntervalSinceNow]*-1)/60/60;	
	if (hourssince > 6 || lastUpdatecheck == nil) {	
        NSString *dirPath = [[defaults objectForKey:@"path"] stringByResolvingSymlinksInPath]; 
        NSMutableDictionary *collisions = [NSMutableDictionary dictionaryWithCapacity:1];        
        [defaults setObject:[self checkCase:dirPath collisions:collisions] forKey:@"collisions"];
        [defaults setObject:[NSDate date] forKey:@"lastCaseCheck"];
        [defaults synchronize];
    } 
    
    //[cloudController loopFiles:@"conflicts"]; //TODO
    //[cloudController loopFiles:@"sync"];      //TODO  
            
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MenuBarEvent" object:@"refresh" userInfo:nil];    
    
}

- (NSString*)testConnectionByName:(BOOL)byName
{
    SCNetworkReachabilityFlags  flags;
    SCNetworkReachabilityRef    reachabilityRef;
    BOOL                        gotFlags;
	NSMutableString *str = nil;
	
	if (byName) {
        reachabilityRef = SCNetworkReachabilityCreateWithName(NULL, [@"www.apple.com" UTF8String]);
    } else {
        struct sockaddr_in  addr;
		memset(&addr, 0, sizeof(addr));
        addr.sin_len = sizeof(addr);
        addr.sin_family = AF_INET;
        addr.sin_port   = htons(80);
        addr.sin_addr.s_addr = inet_addr("17.149.160.49");
        reachabilityRef = SCNetworkReachabilityCreateWithAddress(NULL, (const struct sockaddr *) &addr);
    }
    gotFlags        = SCNetworkReachabilityGetFlags(reachabilityRef, &flags);
    CFRelease(reachabilityRef);
	
    if (gotFlags) {
        if (flags & kSCNetworkReachabilityFlagsReachable) {
            str = [NSMutableString stringWithFormat:@"Wi-Fi"];
        } else {
            str = [NSMutableString stringWithFormat:@"None"];
			NSLog(@"Connection Flags %#x", flags);	
			return str;
        }
		if (flags & kSCNetworkReachabilityFlagsIsDirect) {
			[str appendString:@" (direct)"];
		}else{
			[str appendString:@" (gateway)"];
		}		
    }
	return str;
}

-(NSMutableDictionary*)checkCase:(NSString*)dirPath collisions:(NSMutableDictionary*)collisions
{       
    NSError *error;
    NSFileManager *filemgr = [NSFileManager defaultManager];
    NSArray *filelist = [filemgr contentsOfDirectoryAtPath:dirPath error:&error];
    NSMutableArray *lowercaseList = [NSMutableArray arrayWithCapacity:1];
    
    for (NSString *lastPathComponent in filelist) {
        NSString *fullPath = [dirPath stringByAppendingPathComponent:lastPathComponent];
        BOOL isDir;        
        BOOL exists = [filemgr fileExistsAtPath:fullPath isDirectory:&isDir];
        if (exists) {
            if (isDir) {
                if (![lastPathComponent isEqualToString:@".Backups"]) {
                    [self checkCase:fullPath collisions:collisions];                    
                }
            }else {
                NSString *lowercase = [lastPathComponent lowercaseString];
                if ([lowercaseList containsObject:lowercase]) {
                    [collisions setObject:dirPath forKey:lowercase];
                }else {
                    [lowercaseList addObject:lowercase];
                }
            }                    
        }
    } 

    return collisions;
}

@end
