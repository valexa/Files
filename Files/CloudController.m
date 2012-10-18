//
//  CloudController.m
//  Files
//
//  Created by Vlad Alexa on 3/1/12.
//  Copyright (c) 2012 Next Design. All rights reserved.
//

#import "CloudController.h"

@implementation CloudController

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mainWindowOpened:) name:NSWindowDidBecomeMainNotification object:nil];        
        
    }
    
    return self;
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)mainWindowOpened:(NSNotification *)notification
{
}

#pragma mark icloud

-(BOOL)isiCloudAvailable
{
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm respondsToSelector:@selector(URLForUbiquityContainerIdentifier:)]) {
        if ([fm URLForUbiquityContainerIdentifier:nil]) return YES;        
    }
    return NO;
}

- (NSURL*)getiCloudURLFor:(NSString*)fileName containerID:(NSString*)containerID
{   
    NSFileManager *fm = [NSFileManager defaultManager];  
    
    NSURL *localURL = [[[fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] objectAtIndex:0] URLByAppendingPathComponent:fileName]; //no cloud     
    
    if (![fm respondsToSelector:@selector(URLForUbiquityContainerIdentifier:)]) return localURL; //not Lion
    
    NSURL *rootURL = [fm URLForUbiquityContainerIdentifier:containerID];
    if (rootURL) {
        NSURL *directoryURL = [rootURL URLByAppendingPathComponent:@"Documents"];
        [fm createDirectoryAtURL:directoryURL withIntermediateDirectories:NO attributes:nil error:NULL];
        NSURL *cloudURL = [directoryURL URLByAppendingPathComponent:fileName];
        if (![fm isUbiquitousItemAtURL:cloudURL]) [self makeUbiquitousItemAtURL:cloudURL];//this only runs once per filename when it is first added to iCloud
        return cloudURL;
    }
      
    return  localURL;
}

- (void)makeUbiquitousItemAtURL:(NSURL*)cloudURL
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *localURL = [[[fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] objectAtIndex:0] URLByAppendingPathComponent:[cloudURL lastPathComponent]];            
    if (![fm fileExistsAtPath:[localURL path]]) [fm createFileAtPath:[localURL path] contents:nil attributes:nil];//create local file it if it does not exist
    NSError *error;            
    if(![fm setUbiquitous:YES itemAtURL:localURL destinationURL:cloudURL error:&error])  {
        NSLog(@"Error making %@ ubiquituous at %@ (%@)",[localURL path],[cloudURL path],[error description]);
    }else{
        NSLog(@"Made %@ ubiquituous at %@",[localURL lastPathComponent],[cloudURL path]);      
    }      
}

- (void)makeNonUbiquitousItemAtURL:(NSURL*)cloudURL
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *localURL = [[[fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] objectAtIndex:0] URLByAppendingPathComponent:[cloudURL lastPathComponent]];            
    NSError *error;            
    if(![fm setUbiquitous:NO itemAtURL:cloudURL destinationURL:localURL error:&error])  {
        NSLog(@"Error making %@ non-ubiquituous at %@ (%@)",[cloudURL path],[localURL path],[error description]);
    }else{
        NSLog(@"Made %@ non-ubiquituous at %@",[cloudURL lastPathComponent],[localURL path]);
    }      
}

#pragma mark extra

-(NSURL*)getSnapshotLink:(NSURL*)cloudURL
{
    NSDate *date = nil;
    NSError *err = nil;
    NSURL *link = [[NSFileManager defaultManager] URLForPublishingUbiquitousItemAtURL:cloudURL expirationDate:&date error:&err];
    if (!err) {
        NSLog(@"%@ is available until %@",link,date);
    }else {
        NSLog(@"%@",err);
    }
    return link;
}

- (void)resolveConflicts:(NSURL*)cloudURL
{       
    NSArray *conflicts = [NSFileVersion unresolvedConflictVersionsOfItemAtURL:cloudURL];
    for (NSFileVersion *conflict in conflicts) {
        NSString *message = [NSString stringWithFormat:@"Conflicting %@ at %@ by %@ from %@",[cloudURL path],[conflict URL],[conflict localizedNameOfSavingComputer],[conflict modificationDate]];   
        //[conflict setResolved:YES];
        //NSString *message = [NSString stringWithFormat:@"Resolved iCloud conflict with %@",[conflict localizedNameOfSavingComputer]];
        NSLog(@"%@",message);
        [[NSNotificationCenter defaultCenter] postNotificationName:@"MenuBarEvent" object:nil userInfo:
         [NSDictionary dictionaryWithObjectsAndKeys:@"doGrowl",@"what",@"iCloud event",@"title",message,@"message",nil]
         ];          
    }
}

- (void)syncFile:(NSURL*)cloudURL
{          
    NSError *error;
    if (![[NSFileManager defaultManager] startDownloadingUbiquitousItemAtURL:cloudURL error:&error]) {
        NSLog(@"Error downloading/syncing %@ (%@)",[cloudURL path],[error description]);                
    }else{
        NSLog(@"Started downloading/syncing %@",[cloudURL path]); 
    } 
}


-(void)loopFiles:(NSString*)what
{
    if (![self isiCloudAvailable]) return;
    
    NSString *dirPath = [[self getiCloudURLFor:@"" containerID:nil] path];
    
    NSError *error;
    NSFileManager *filemgr = [NSFileManager defaultManager];
    NSArray *filelist = [filemgr contentsOfDirectoryAtPath:dirPath error:&error];
    
    for (NSString *lastPathComponent in filelist) {
        NSString *fullPath = [dirPath stringByAppendingPathComponent:lastPathComponent];
        BOOL isDir;        
        BOOL exists = [filemgr fileExistsAtPath:fullPath isDirectory:&isDir];
        if (exists) {
            if (!isDir) {
                //[self cloudStatusFor:fullPath];
                NSURL *url = [NSURL fileURLWithPath:fullPath];                 
                //if ([what isEqualToString:@"conflicts"]) [self resolveConflicts:url];
                //if ([what isEqualToString:@"sync"]) [self syncFile:url];                
            }                    
        }
    } 
}

-(NSDictionary*)cloudStatusFor:(NSString*)file
{
    NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithCapacity:1];
    NSURL *url = [NSURL fileURLWithPath:file];  
    NSError *error = nil;    
    NSNumber *rsrc = nil;
    
    [url getResourceValue:&rsrc forKey:NSURLIsUbiquitousItemKey error:&error];    
    if (rsrc)[ret setObject:rsrc forKey:@"NSURLIsUbiquitousItemKey"];
    
    [url getResourceValue:&rsrc forKey:NSURLUbiquitousItemHasUnresolvedConflictsKey error:&error];    
    if (rsrc)[ret setObject:rsrc forKey:@"NSURLUbiquitousItemHasUnresolvedConflictsKey"];
    
    [url getResourceValue:&rsrc forKey:NSURLUbiquitousItemIsDownloadedKey error:&error];    
    if (rsrc)[ret setObject:rsrc forKey:@"NSURLUbiquitousItemIsDownloadedKey"];

    [url getResourceValue:&rsrc forKey:NSURLUbiquitousItemIsDownloadingKey error:&error];    
    if (rsrc)[ret setObject:rsrc forKey:@"NSURLUbiquitousItemIsDownloadingKey"];
    
    [url getResourceValue:&rsrc forKey:NSURLUbiquitousItemIsUploadedKey error:&error];    
    if (rsrc)[ret setObject:rsrc forKey:@"NSURLUbiquitousItemIsUploadedKey"];
    
    [url getResourceValue:&rsrc forKey:NSURLUbiquitousItemIsUploadingKey error:&error];    
    if (rsrc)[ret setObject:rsrc forKey:@"NSURLUbiquitousItemIsUploadingKey"];
    
    [url getResourceValue:&rsrc forKey:NSURLUbiquitousItemPercentDownloadedKey error:&error];    
    if (rsrc)[ret setObject:rsrc forKey:@"NSURLUbiquitousItemPercentDownloadedKey"];  
    
    [url getResourceValue:&rsrc forKey:NSURLUbiquitousItemPercentUploadedKey error:&error];    
    if (rsrc)[ret setObject:rsrc forKey:@"NSURLUbiquitousItemPercentUploadedKey"];      
    
    NSLog(@"%@ %@",file,ret);    
    return ret;
}


@end
