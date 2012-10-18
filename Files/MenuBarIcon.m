//
//  MenuBarIcon.m
//  Files
//
//  Created by Vlad Alexa on 5/23/12.
//  Copyright (c) 2012 Next Design. All rights reserved.
//

#import "MenuBarIcon.h"

#import <QuartzCore/CoreAnimation.h>

@implementation MenuBarIcon

@synthesize mouseDown,gray,blue;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.        
        
        [self setWantsLayer:YES]; 

    }
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    
    if (!NSIsEmptyRect(self.bounds)) {
        float height = self.bounds.size.height/1.31;
        imagerect = NSMakeRect(self.bounds.size.width/5.0,self.bounds.size.height/7.0,height,height);	           
    }
    
    // Drawing code here.
    
    NSImage *image;        
    if (mouseDown == YES) {				
        NSColor *topColor = [NSColor colorWithDeviceRed:0.49 green:0.55 blue:0.95 alpha:1.0];
        NSColor *botColor = [NSColor colorWithDeviceRed:0.25 green:0.29 blue:0.92 alpha:1.0];
		NSGradient *aGradient = [[NSGradient alloc] initWithStartingColor:topColor endingColor:botColor];
		[aGradient drawInRect:self.bounds angle:-90];	
        
        image = [NSImage imageNamed:@"menubar_white"];        
    }else {
        if (gray == YES) {
            image = [NSImage imageNamed:@"menubar_gray"];  
        }else if (blue == YES){
            image = [NSImage imageNamed:@"menubar_blue"];             
        }else {
            image = [NSImage imageNamed:@"menubar"];                    
        }
    }
    
	NSImageRep *imagerep = [image bestRepresentationForRect:self.frame context:nil hints:nil];	
	[imagerep drawInRect:imagerect];	   
    
}

-(void)removeAnimations
{
    //remove previous ones
    if ([[self.layer sublayers] count] > 0) {
        [[[self.layer sublayers] objectAtIndex:0] removeFromSuperlayer];         
    } 
    //redraw
    [self setNeedsDisplay:YES];    
}

-(void)pulse:(NSString*)color
{   
    //remove previous ones
    [self removeAnimations];
    
    NSRect proposedRect = imagerect;    
    
    NSString *imgname = [NSString stringWithFormat:@"menubar_%@",color];
    if (color == nil) imgname = @"menubar";
	
	CALayer *maskLayer = [CALayer layer];
    NSImage *maskImage = [NSImage imageNamed:imgname]; 
	maskLayer.contents = (id)[maskImage CGImageForProposedRect:&proposedRect context:nil hints:nil];       

	maskLayer.frame = imagerect; 
    
	CABasicAnimation *theAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
	theAnimation.fromValue = [NSNumber numberWithFloat:0.2f]; 
	theAnimation.toValue = [NSNumber numberWithFloat:1.0f];    
	theAnimation.repeatCount = FLT_MAX;    
	theAnimation.duration = 1.0f;	
	theAnimation.autoreverses = YES;	
	[maskLayer addAnimation:theAnimation forKey:@"pulseAnim"];
    
	[self.layer addSublayer:maskLayer];    
}

-(void)slide:(NSString*)color
{    
    //remove previous ones
    [self removeAnimations];   
    
	CGFloat width = imagerect.size.width;
	CGFloat height = imagerect.size.height;
    NSRect proposedRect = imagerect;    
    
    NSString *imgname = [NSString stringWithFormat:@"menubar_%@",color];
    if (color == nil) imgname = @"menubar";    
    
	CALayer *parentLayer = [CALayer layer];
    NSImage *parentImage = [NSImage imageNamed:imgname];    
	parentLayer.contents = (id)[parentImage CGImageForProposedRect:&proposedRect context:nil hints:nil];
	parentLayer.frame = imagerect;        
	
	CALayer *maskLayer = [CALayer layer];
    NSImage *image = [NSImage imageNamed:@"mask"];     
	float factor = height/image.size.height/[self pixelScaling];
    NSImage *maskImage = [self resizeImage:image by:factor]; 
	maskLayer.contents = (id)[maskImage CGImageForProposedRect:&proposedRect context:nil hints:nil];
	
	maskLayer.contentsGravity = kCAGravityCenter;
	maskLayer.frame = CGRectMake(-width, 0.0f, width * 2, height);
    
	CABasicAnimation *theAnimation = [CABasicAnimation animationWithKeyPath:@"position.x"];
	theAnimation.byValue = [NSNumber numberWithFloat:width*2];
	theAnimation.repeatCount = FLT_MAX;
	theAnimation.duration = 3.0f;
	theAnimation.fillMode = kCAFillModeForwards;   
	[maskLayer addAnimation:theAnimation forKey:@"slideAnim"];	
    
	parentLayer.mask = maskLayer;
    
	[self.layer addSublayer:parentLayer];	
}

-(CGFloat)pixelScaling
{
    NSRect pixelBounds = [self convertRectToBacking:self.bounds];
    return pixelBounds.size.width/self.bounds.size.width;
}

-(NSImage*)resizeImage:(NSImage*)input by:(CGFloat)factor
{    
	NSSize size = NSZeroSize;	   
    size.width = input.size.width*factor;
    size.height = input.size.height*factor; 
    
	NSImage *ret = [[NSImage alloc] initWithSize:size];
	[ret lockFocus];
	NSAffineTransform *transform = [NSAffineTransform transform];
	[transform scaleBy:factor];  
	[transform concat];	
	[input drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];    
	[ret unlockFocus];		  
    
	return ret;
}

- (void)mouseDown:(NSEvent *)theEvent
{
    mouseDown = YES;  
    [self setNeedsDisplay:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MenuBarEvent" object:@"click" userInfo:nil]; 
}


@end
