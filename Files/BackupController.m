//
//  BackupController.m
//  Files
//
//  Created by Vlad Alexa on 6/16/12.
//  Copyright (c) 2012 Next Design. All rights reserved.
//

#import "BackupController.h"

#include <sys/sysctl.h> 

@implementation BackupController

@synthesize working;

- (id)init
{
    self = [super init];
    if (self) {
        defaults = [NSUserDefaults standardUserDefaults];
        
        cloudDefaults = [NSUbiquitousKeyValueStore defaultStore];        
        
        [self checkDir];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(theEvent:) name:@"BackupControllerEvent" object:nil];         
        
    }
    return self;
}

-(void)theEvent:(NSNotification*)notif
{	
	if (![[notif name] isEqualToString:@"BackupControllerEvent"]) {		
		return;
	}	
	if ([[notif object] isKindOfClass:[NSString class]]){
        if ([[notif object] isEqualToString:@"pause"]) {
            paused = YES;  
        }
        if ([[notif object] isEqualToString:@"resume"]) {
            paused = NO;                
        } 
  
	}   
}


-(void)checkLoop
{
    if (working == YES) return;
    
    [cloudDefaults synchronize];    
    if ([cloudDefaults boolForKey:@"isBackingUp"] == YES) return; //TODO
    
	NSDate *lastBackup = [cloudDefaults objectForKey:@"lastBackup"];
    if (lastBackup == nil) {
        //postpone the first backup by one day
        [cloudDefaults setObject:[NSDate date] forKey:@"lastBackup"];
        [cloudDefaults synchronize];        
        return;
    }
	float hourssince = ([lastBackup timeIntervalSinceNow]*-1)/60/60;	
	if (hourssince > 24 || lastBackup == nil) {	
		NSLog(@"%f hours since last backup",hourssince);
	}else {       
        return;
    }    

    if ([self loadAverage] < 1.75) { //TODO TEMP
        
        if ([self allBackupsDownloaded] != YES) {
            NSLog(@"Skipping backup, not all backups downloaded");
            return;
        }
                
        if ([defaults boolForKey:@"backupPaused"] == YES) paused = YES;
        
        working = YES;
        
        [cloudDefaults setObject:[NSNumber numberWithBool:YES] forKey:@"isBackingUp"];    
        [cloudDefaults synchronize];        
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"MenuBarEvent" object:@"backingUp" userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0] forKey:@"percent"]];         
        
        [NSThread detachNewThreadSelector:@selector(startBackup) toTarget:self withObject:nil];                
        
    }    
    
}

-(float)loadAverage
{
	size_t len;
	struct loadavg load;
	len = sizeof(struct loadavg);	
	if (sysctlbyname("vm.loadavg", &load, &len,NULL, 0) == -1){
        NSLog(@"loadavg error");
        return 0;
	}	    
    
    return load.ldavg[2]/(float)load.fscale; 
}

-(BOOL)checkDir
{
    NSString *dirPath = [[[[defaults objectForKey:@"path"] stringByReplacingOccurrencesOfString:@"/Documents" withString:@""] stringByAppendingPathComponent:@".Backups"] stringByResolvingSymlinksInPath];        
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL dir;
    BOOL exists = [fm fileExistsAtPath:dirPath isDirectory:&dir];
    if (!exists) {
        NSError *err = nil;
        [fm createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&err];
        if (err) {
            NSLog(@"%@",err);
        }else {
            return YES;
        }
    }else {
        if (!dir) {
            NSError *err = nil;            
            [fm removeItemAtPath:dirPath error:&err];
            if (err) {
                NSLog(@"%@",err);
            }else {
                [self checkDir];
            }
        } 
        return YES;        
    } 
    
    return NO;
}

-(BOOL)allBackupsDownloaded
{
    NSString *dirPath = [[defaults objectForKey:@"path"] stringByResolvingSymlinksInPath];  
    NSString *backupsPath = [[dirPath stringByReplacingOccurrencesOfString:@"/Documents" withString:@""] stringByAppendingPathComponent:@".Backups"];     
    NSDictionary *backups = [cloudDefaults objectForKey:@"backups"];
    for (NSString *key in backups) {
        NSURL *url = [NSURL fileURLWithPath:[backupsPath stringByAppendingPathComponent:key]]; 
        NSError *error = nil;    
        NSNumber *rsrc = nil;        
        [url getResourceValue:&rsrc forKey:NSURLUbiquitousItemIsDownloadedKey error:&error];    
        if ([rsrc boolValue] != YES) {
            NSLog(@"%@ not downloaded",[url path]);
            return NO;
        }      
    }
    
    return YES;
}

-(void)startBackup
{
    while (paused == YES) [NSThread sleepUntilDate:[[NSDate date] dateByAddingTimeInterval:10]];        
    
    NSDate *backupDate = [self performBackup];        
    
    working = NO;   //no multithread synchronization is needed for booleans
    
    if (backupDate == nil) {
        NSLog(@"Backup failed");
    }else {
        NSMutableDictionary *backups = [NSMutableDictionary dictionaryWithDictionary:[cloudDefaults objectForKey:@"backups"]];
        NSDateFormatter *format = [[NSDateFormatter alloc] init];
        [format setDateFormat:@"yyyy-MM-dd"];    
        [backups setObject:backupDate forKey:[format stringFromDate:backupDate]];
        [cloudDefaults setObject:backups forKey:@"backups"];
        [cloudDefaults setObject:[NSDate date] forKey:@"lastBackup"];
        [cloudDefaults setObject:[NSNumber numberWithBool:NO] forKey:@"isBackingUp"];    
        [cloudDefaults synchronize];
    }
    
    [self performSelectorOnMainThread:@selector(menubarRefresh:) withObject:nil waitUntilDone:NO];      

}

-(void)menubarRefresh:(id)arg
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MenuBarEvent" object:@"refresh" userInfo:nil];      
}

-(void)menubarUpdate:(id)arg
{
    
	//limit to once every 10 seconds
	float interval = CFAbsoluteTimeGetCurrent() - menubarUpdateTime;
	if (interval < 10) {
		return;
	}else {	
        [[NSNotificationCenter defaultCenter] postNotificationName:@"MenuBarEvent" object:@"backingUp" userInfo:arg];            
		menubarUpdateTime = CFAbsoluteTimeGetCurrent();
	}
}


-(NSString *)humanizeSize:(int)value
{
    float ret;
	NSString *sizeType = @"";		
	
	if (value >= 1073741824){
		ret = value / 1073741824.0; sizeType = @"GB";
	}else if (value >= 1048576)	{
		ret = value / 1048576.0; sizeType = @"MB";
	}else if (value >= 1024) {
		ret = value / 1024.0; sizeType = @"KB";
	}else if (value >= 0){
		ret = (float)value; sizeType = @"B";
	}    
	
	return [NSString stringWithFormat:@"%.1f %@",ret,sizeType];
}


-(NSDictionary*)countsAndSizes
{
    
    int backupsSize = 0;  
    int backupsCount = 0;    
    int backupsUploadedSize = 0;
    int backupsUploadedCount = 0;
    int backupsDownloadedSize = 0;
    int backupsDownloadedCount = 0;

    int filesSize = 0;    
    int filesCount = 0;    
    int filesUploadedSize = 0;
    int filesUploadedCount = 0;
    int filesDownloadedSize = 0;
    int filesDownloadedCount = 0;    
    
    NSString *dirPath = [[defaults objectForKey:@"path"] stringByResolvingSymlinksInPath]; 
    NSString *backupsPath = [[dirPath stringByReplacingOccurrencesOfString:@"/Documents" withString:@""] stringByAppendingPathComponent:@".Backups"]; 
    
    NSMutableArray *backupsUploading = [NSMutableArray arrayWithCapacity:1];
    NSMutableArray *backupsDownloading = [NSMutableArray arrayWithCapacity:1];        
    NSMutableArray *filesUploading = [NSMutableArray arrayWithCapacity:1];
    NSMutableArray *filesDownloading = [NSMutableArray arrayWithCapacity:1];        
    
    NSFileManager *fm = [[NSFileManager alloc] init];  
    
    NSArray *prop = [NSArray arrayWithObjects:NSURLFileSizeKey,NSURLIsDirectoryKey,NSURLIsPackageKey,NSURLUbiquitousItemIsUploadedKey,NSURLUbiquitousItemPercentUploadedKey,NSURLUbiquitousItemIsDownloadedKey,NSURLUbiquitousItemPercentDownloadedKey,nil];
    NSDirectoryEnumerator *dirEnumerator = [fm enumeratorAtURL:[NSURL fileURLWithPath:dirPath] includingPropertiesForKeys:prop options:0 errorHandler:nil];

    NSMutableString *lastPackagePath = [NSMutableString stringWithCapacity:1];
    
    // Enumerate the dirEnumerator results, each value is stored in allURLs
    for (NSURL *theURL in dirEnumerator) {   
                
        //skip .DS_Store
        if ([[theURL lastPathComponent] isEqualToString:@".DS_Store"]) continue;
        
        //do not count package descendants but factor their size
        NSNumber *isPackage;
        [theURL getResourceValue:&isPackage forKey:NSURLIsPackageKey error:NULL];              
        if ([isPackage boolValue] == YES) [lastPackagePath setString:[theURL path]];        
        
        BOOL skipPackageCounts;  
        if (lastPackagePath) {
            if ([[theURL path] rangeOfString:lastPackagePath].location != NSNotFound) {
                skipPackageCounts = YES;
            }else {
                skipPackageCounts = NO;            
            }               
        }       
        
        NSNumber *isDirectory;
        [theURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL];      
        if ([isDirectory boolValue] == YES) continue;
        
        NSNumber *size;
        [theURL getResourceValue:&size forKey:NSURLFileSizeKey error:NULL]; 
        
        NSNumber *downloaded;
        [theURL getResourceValue:&downloaded forKey:NSURLUbiquitousItemIsDownloadedKey error:NULL]; 
        
        NSNumber *p_downloaded;
        [theURL getResourceValue:&p_downloaded forKey: NSURLUbiquitousItemPercentDownloadedKey error:NULL];               
        
        NSNumber *uploaded;
        [theURL getResourceValue:&uploaded forKey:NSURLUbiquitousItemIsUploadedKey error:NULL];    
        
        NSNumber *p_uploaded;
        [theURL getResourceValue:&p_uploaded forKey: NSURLUbiquitousItemPercentUploadedKey error:NULL];       
        
        if ([[theURL path] rangeOfString:backupsPath].location != NSNotFound) {
            backupsSize += [size intValue];
            if (!skipPackageCounts) backupsCount += 1;
            if ([uploaded boolValue] == YES) {                 
                backupsUploadedSize += [size intValue];
                if (!skipPackageCounts) backupsUploadedCount += 1;
            }
            if ([downloaded boolValue] == YES) {              
                backupsDownloadedSize += [size intValue];
                if (!skipPackageCounts) backupsDownloadedCount += 1; 
            } 
            if ([p_uploaded intValue] > 0) {
                [backupsUploading addObject:[NSString stringWithFormat:@"%@%% %@ ",p_uploaded,[theURL lastPathComponent]]];
            }
            if ([p_downloaded intValue] > 0) {
                [backupsDownloading addObject:[NSString stringWithFormat:@"%@%% %@",p_downloaded,[theURL lastPathComponent]]];
            }            
        } else {
            filesSize += [size intValue];
            if (!skipPackageCounts) filesCount += 1;  
            if ([uploaded boolValue] == YES) {
                filesUploadedSize += [size intValue];
                if (!skipPackageCounts) filesUploadedCount += 1;               
            }
            if ([downloaded boolValue] == YES) {
                filesDownloadedSize += [size intValue];
                if (!skipPackageCounts) filesDownloadedCount += 1; 
            }  
            if ([p_uploaded intValue] > 0) {
                [filesUploading addObject:[NSString stringWithFormat:@"%@%% %@",p_uploaded,[theURL lastPathComponent]]];
            }
            if ([p_downloaded intValue] > 0) {
                [filesDownloading addObject:[NSString stringWithFormat:@"%@%% %@",p_downloaded,[theURL lastPathComponent]]];
            }            
        }               
    }   
    
    [defaults setObject:backupsDownloading forKey:@"backupDownloads"];
    [defaults setObject:backupsUploading forKey:@"backupUploads"];
    [defaults setObject:filesDownloading forKey:@"filesDownloads"];
    [defaults setObject:filesUploading forKey:@"filesUploads"];  
    [defaults synchronize];
    
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInt:filesSize],@"filesSize",            
            [NSNumber numberWithInt:filesCount],@"filesCount",
            [NSNumber numberWithInt:filesDownloadedSize],@"filesDownloadedSize",            
            [NSNumber numberWithInt:filesDownloadedCount],@"filesDownloadedCount",
            [NSNumber numberWithInt:filesUploadedSize],@"filesUploadedSize",            
            [NSNumber numberWithInt:filesUploadedCount],@"filesUploadedCount",
            [NSNumber numberWithInt:backupsSize],@"backupsSize",
            [NSNumber numberWithInt:backupsCount],@"backupsCount",
            [NSNumber numberWithInt:backupsDownloadedSize],@"backupsDownloadedSize",            
            [NSNumber numberWithInt:backupsDownloadedCount],@"backupsDownloadedCount",
            [NSNumber numberWithInt:backupsUploadedSize],@"backupsUploadedSize",            
            [NSNumber numberWithInt:backupsUploadedCount],@"backupsUploadedCount",
            nil];    
}

-(NSDate*)performBackup
{    
    //prequisites
    NSString *dirPath = [[defaults objectForKey:@"path"] stringByResolvingSymlinksInPath];  
    NSString *backupsPath = [[dirPath stringByReplacingOccurrencesOfString:@"/Documents" withString:@""] stringByAppendingPathComponent:@".Backups"]; 
    NSArray *backups = [self backupsPaths:backupsPath];   
    NSDictionary *countsAndSizes = [self countsAndSizes];
    NSFileManager *fm = [[NSFileManager alloc] init];
    
    //make temp dir
    NSDate *ret = [NSDate date];
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    [format setDateFormat:@"yyyy-MM-dd"];
    NSString *tempBackup = [NSTemporaryDirectory() stringByAppendingPathComponent:[format stringFromDate:ret]]; 
    [fm removeItemAtPath:tempBackup error:nil];
    NSError *error;
    [fm createDirectoryAtPath:tempBackup withIntermediateDirectories:YES attributes:nil error:&error];
    if (error) {
        NSLog(@"%@",error);
        return nil;
    }
    
    //start copying
    NSArray *prop = [NSArray arrayWithObjects:NSURLNameKey,NSURLIsDirectoryKey,NSURLContentModificationDateKey,NSURLIsReadableKey,nil];
    NSDirectoryEnumerator *dirEnumerator = [fm enumeratorAtURL:[NSURL fileURLWithPath:dirPath] includingPropertiesForKeys:prop options:0 errorHandler:nil];
    
    int progress = 0;    
    // Enumerate the dirEnumerator results, each value is stored in allURLs
    for (NSURL *theURL in dirEnumerator) {
                
        NSString *lastPathComponent;
        [theURL getResourceValue:&lastPathComponent forKey:NSURLNameKey error:NULL];
        
        NSNumber *isDirectory;
        [theURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL];
        
        NSDate *date;
        [theURL getResourceValue:&date forKey:NSURLContentModificationDateKey error:NULL];          
        
        NSNumber *readable;
        [theURL getResourceValue:&readable forKey:NSURLIsReadableKey error:NULL];             
        
        if ([readable boolValue] != YES) {
            NSLog(@"%@ not readable",[theURL path]);
            continue;
        }
        
        //skip backups
        if ([isDirectory boolValue] == YES) {
            if ([[theURL path] isEqualToString:backupsPath]) {
                 [dirEnumerator skipDescendants];         
            }               
        }else {
            //skip .DS_Store
            if ([lastPathComponent isEqualToString:@".DS_Store"]) continue;
            
            progress++;
            int total = [[countsAndSizes objectForKey:@"filesCount"] intValue];
            [self performSelectorOnMainThread:@selector(menubarUpdate:) withObject:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:(float)progress/total*100] forKey:@"percent"] waitUntilDone:NO];
            
            NSString *endPath = [[theURL path] stringByReplacingOccurrencesOfString:dirPath withString:@""];
            
            if (backups) {
                if (![self haveBackupWithSameModifDate:date at:endPath backups:backups]) {                                             
                    //NSLog(@"%@ diffs from backups",endPath);                    

                    NSError *error;                    
                    NSString *parent = [[tempBackup stringByAppendingPathComponent:endPath] stringByReplacingOccurrencesOfString:[theURL lastPathComponent] withString:@""];
                    [fm createDirectoryAtPath:parent withIntermediateDirectories:YES attributes:nil error:&error];
                    if (error) {
                        NSLog(@"%@",error);
                    }                    
                    [fm copyItemAtPath:[theURL path] toPath:[tempBackup stringByAppendingPathComponent:endPath] error:&error];
                    if (error) {
                        NSLog(@"%@",error);
                    }else {
                        //NSLog(@"%@",[tempBackup stringByAppendingPathComponent:endPath]);
                    }
                    
                }
            }          

        }
        
    }
       
    //move backup in place
    NSString *newBackup = [backupsPath stringByAppendingPathComponent:[format stringFromDate:[NSDate date]]];
    
    if ([fm fileExistsAtPath:newBackup]) {
        NSLog(@"%@ already exists",newBackup);
    }else {
        NSError *error;    
        [fm moveItemAtPath:tempBackup toPath:newBackup error:&error];
        if (error) {
            NSLog(@"%@",error);
        }else {
            //NSLog(@"backup put in place from %@ to %@",tempBackup,newBackup);
        }         
    }
    
    //lock backup
    NSDictionary *attribs = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:NSFileImmutable];
    [fm setAttributes:attribs ofItemAtPath:newBackup error:&error];
    if (error) NSLog(@"%@",error);
    
    //update menubar
    backups = [self backupsPaths:backupsPath];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MenuBarEvent" object:@"countsAndSizes" userInfo:
     [NSDictionary dictionaryWithObjectsAndKeys:
      [NSString stringWithFormat:@"%@ in %@ files",[self humanizeSize:[[countsAndSizes objectForKey:@"filesSize"] intValue]],[countsAndSizes objectForKey:@"filesCount"]],@"filesUsageString",
      [NSString stringWithFormat:@"Uploaded %@ in %@ items",[self humanizeSize:[[countsAndSizes objectForKey:@"filesUploadedSize"] intValue]],[countsAndSizes objectForKey:@"filesUploadedCount"]],@"filesUploadedString",
      [NSString stringWithFormat:@"Downloaded %@ in %@ items",[self humanizeSize:[[countsAndSizes objectForKey:@"filesDownloadedSize"] intValue]],[countsAndSizes objectForKey:@"filesDownloadedCount"]],@"filesDownloadedString",             
      [NSString stringWithFormat:@"%@ in %i backups",[self humanizeSize:[[countsAndSizes objectForKey:@"backupsSize"] intValue]],[backups count]],@"backupUsageString",
      [NSString stringWithFormat:@"Uploaded %@ in %@ items",[self humanizeSize:[[countsAndSizes objectForKey:@"backupsUploadedSize"] intValue]],[countsAndSizes objectForKey:@"backupsUploadedCount"]],@"backupUploadedString",
      [NSString stringWithFormat:@"Downloaded %@ in %@ items",[self humanizeSize:[[countsAndSizes objectForKey:@"backupsDownloadedSize"] intValue]],[countsAndSizes objectForKey:@"backupsDownloadedCount"]],@"backupDownloadedString",                                                                                                  
      nil]];    
    
    return ret;
        
}

-(NSArray*)backupsPaths:(NSString*)rootPath
{
    NSMutableArray *ret = [NSMutableArray arrayWithCapacity:1];
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSError *error;
    NSArray *filelist = [fm contentsOfDirectoryAtPath:rootPath error:&error];
    
    if (error) {
        NSLog(@"%@",error);
        return nil;
    }
    
    for (NSString *lastPathComponent in filelist) {
        if ([lastPathComponent length] < 1) continue;        
        NSString *fullPath = [rootPath stringByAppendingPathComponent:lastPathComponent];
        BOOL isDir;        
        BOOL exists = [fm fileExistsAtPath:fullPath isDirectory:&isDir];
        if (exists) {
            if (isDir) {
                
                //lock backup
                NSDictionary *attribs = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:NSFileImmutable];
                [fm setAttributes:attribs ofItemAtPath:fullPath error:&error];
                if (error) NSLog(@"%@",error);
                
                [ret addObject:fullPath];
            }                    
        }
    }     
    
    int cloudCount = [[cloudDefaults objectForKey:@"backups"] count];
    if ( cloudCount != [ret count]) {
        NSLog(@"Local(%lu)/cloud(%i) backups out of sync",[ret count],cloudCount); //TODO
    }
    
    return ret;
}

-(BOOL)haveBackupWithSameModifDate:(NSDate*)date at:(NSString*)endPath backups:(NSArray*)backups
{    
    NSFileManager *fm = [NSFileManager defaultManager];    
    for (NSString *root in backups) {
        NSString *lookup = [root stringByAppendingPathComponent:endPath];
        NSDictionary *dict = [fm attributesOfItemAtPath:lookup error:nil];
        NSDate *backupDate = [dict objectForKey:@"NSFileModificationDate"];
        if ([backupDate isEqualToDate:date]) {
            return YES;
        }
    }
    return NO;
}

@end
