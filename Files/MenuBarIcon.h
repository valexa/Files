//
//  MenuBarIcon.h
//  Files
//
//  Created by Vlad Alexa on 5/23/12.
//  Copyright (c) 2012 Next Design. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MenuBarIcon : NSView {
    BOOL mouseDown;
    BOOL gray;
    BOOL blue;    
    NSRect imagerect;    
}

@property     BOOL mouseDown;
@property     BOOL gray;
@property     BOOL blue;

-(CGFloat)pixelScaling;
-(NSImage*)resizeImage:(NSImage*)input by:(CGFloat)factor;

-(void)removeAnimations;

-(void)pulse:(NSString*)color;
-(void)slide:(NSString*)color;

@end
