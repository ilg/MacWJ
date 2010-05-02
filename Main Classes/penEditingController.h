//
//  penEditingController.h
//  MacWJ
//
//  Created by Isaac Greenspan on 5/2/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface penEditingController : NSObject {
	NSString *penName;
	
	CGFloat minimumStrokeWidth;
	CGFloat maximumStrokeWidth;
	BOOL isAngleDependent;
	CGFloat widestAngle;
	NSColor *inkColor;
	
	CGFloat angleCircularSliderValue;
	
	NSMutableDictionary *nibs;
	NSMutableArray *nibNames;
	NSString *selectedPen;
	
	IBOutlet NSTextField *angleNumeratorTextField;
	IBOutlet NSBox *angleFractionBar;
	IBOutlet NSTextField *angleDenominatorTextField;
	
	IBOutlet NSTableView *penNibListTableView;
	IBOutlet NSSegmentedControl *penNibListSegmentedControl;
	IBOutlet NSBox *penEditingBox;
	IBOutlet NSImageView *inkStrokePreview;
}

@property (retain) NSString *penName;

@property CGFloat minimumStrokeWidth;
@property CGFloat maximumStrokeWidth;
@property BOOL isAngleDependent;
@property CGFloat widestAngle;
@property (retain) NSColor *inkColor;

@property CGFloat angleCircularSliderValue;

- (IBAction)angleCircularSliderAction:(id)sender;
- (IBAction)penNibListAction:(id)sender;
- (IBAction)penNibListSegmentedControlAction:(id)sender;

@end
