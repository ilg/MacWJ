/*********************************************************************************
 
 © Copyright 2010, Isaac Greenspan
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
 
 *********************************************************************************/

//
//  penEditingController.h
//  MacWJ
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
	
	IBOutlet NSSlider *angleCircularSlider;
	IBOutlet NSTextField *angleNumeratorTextField;
	IBOutlet NSBox *angleFractionBar;
	IBOutlet NSTextField *angleDenominatorTextField;
	
	IBOutlet NSTableView *penNibListTableView;
	IBOutlet NSSegmentedControl *penNibListSegmentedControl;
	IBOutlet NSBox *penEditingBox;
	IBOutlet NSImageView *inkStrokePreview;
	
	BOOL isLoadingPen;
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
