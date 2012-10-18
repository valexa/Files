//
//  BackupController.h
//  Files
//
//  Created by Vlad Alexa on 6/16/12.
//  Copyright (c) 2012 Next Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BackupController : NSObject
{
    NSUserDefaults *defaults;
    NSUbiquitousKeyValueStore  *cloudDefaults;    
    BOOL working;
    BOOL paused;
    CFTimeInterval menubarUpdateTime;
}

@property   BOOL working;

-(NSDate*)performBackup;
-(BOOL)allBackupsDownloaded;

-(BOOL)checkDir;
-(void)checkLoop;
-(NSString *)humanizeSize:(int)value;
-(NSDictionary*)countsAndSizes;
-(NSArray*)backupsPaths:(NSString*)rootPath;

@end
