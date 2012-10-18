//
//  AboutController.h
//  Files
//
//  Created by Vlad Alexa on 5/24/12.
//  Copyright (c) 2012 Next Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AboutController : NSObject{
    NSUserDefaults *defaults;    
	IBOutlet NSSegmentedControl *startToggle;
	IBOutlet NSSegmentedControl *dockToggle; 
}

-(IBAction) openWebsite:(id)sender;
-(IBAction) startToggle:(id)sender;
-(IBAction) dockToggle:(id)sender;

@end
