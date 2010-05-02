//
//  penEditingController.m
//  MacWJ
//
//  Created by Isaac Greenspan on 5/2/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "penEditingController.h"
#import "tabletPenNib.h"


@implementation penEditingController

@synthesize penName;
@synthesize minimumStrokeWidth, maximumStrokeWidth, isAngleDependent, widestAngle, inkColor;
@synthesize angleCircularSliderValue;

const NSInteger kAddAPenSegmentNumber = 0;
const NSInteger kRemoveSelectedPenSegmentNumber = 1;


- (void)awakeFromNib {
	[self addObserver:self
		   forKeyPath:@"penName"
			  options:0
			  context:NULL];
	[self addObserver:self
		   forKeyPath:@"minimumStrokeWidth"
			  options:0
			  context:NULL];
	[self addObserver:self
		   forKeyPath:@"maximumStrokeWidth"
			  options:0
			  context:NULL];
	[self addObserver:self
		   forKeyPath:@"isAngleDependent"
			  options:0
			  context:NULL];
	[self addObserver:self
		   forKeyPath:@"widestAngle"
			  options:0
			  context:NULL];
	[self addObserver:self
		   forKeyPath:@"inkColor"
			  options:0
			  context:NULL];
}

- (void)reloadTableData {
	[nibNames release];
	nibNames = [[NSMutableArray arrayWithArray:[nibs allKeys]] retain];
	[nibNames sortUsingSelector:@selector(compare:)];
	[penNibListTableView reloadData];
}

#pragma mark -
#pragma mark IBActions

- (IBAction)angleCircularSliderAction:(id)sender {
	// round to a whole twelfth of pi or a 15-degree increment
	[self setAngleCircularSliderValue:(15.0 * roundf([self angleCircularSliderValue] / 15.0))];
	
	// the value of the slider is 0 at the top and increases clockwise to 360,
	// so do some converting to get a proper mathematical degree-measure
	CGFloat sliderAngle = 90.0 - [self angleCircularSliderValue];
	if (sliderAngle < 0) sliderAngle += 360;
	[self setWidestAngle:(sliderAngle * pi / 180.0)];
	
	// since sliderAngle is in [0,360), twelfthsOfPi will be an integer in [0,24)
	long int twelfthsOfPi = lroundf(sliderAngle / 15.0);
	if (twelfthsOfPi == 24) twelfthsOfPi = 0;
	
	NSString *numerator;
	NSString *denominator;
	switch (twelfthsOfPi) {
		case 0: numerator = @"0"; denominator = @""; break;
		case 1: numerator = @"π"; denominator = @"12"; break;
		case 2: numerator = @"π"; denominator = @"6"; break;
		case 3: numerator = @"π"; denominator = @"4"; break;
		case 4: numerator = @"π"; denominator = @"3"; break;
		case 5: numerator = @"5π"; denominator = @"12"; break;
		case 6: numerator = @"π"; denominator = @"2"; break;
		case 7: numerator = @"7π"; denominator = @"12"; break;
		case 8: numerator = @"2π"; denominator = @"3"; break;
		case 9: numerator = @"3π"; denominator = @"4"; break;
		case 10: numerator = @"5π"; denominator = @"6"; break;
		case 11: numerator = @"11π"; denominator = @"12"; break;
		case 12: numerator = @"π"; denominator = @""; break;
		case 13: numerator = @"13π"; denominator = @"12"; break;
		case 14: numerator = @"7π"; denominator = @"6"; break;
		case 15: numerator = @"5π"; denominator = @"4"; break;
		case 16: numerator = @"4π"; denominator = @"3"; break;
		case 17: numerator = @"17π"; denominator = @"12"; break;
		case 18: numerator = @"3π"; denominator = @"2"; break;
		case 19: numerator = @"19π"; denominator = @"12"; break;
		case 20: numerator = @"5π"; denominator = @"3"; break;
		case 21: numerator = @"7π"; denominator = @"4"; break;
		case 22: numerator = @"11π"; denominator = @"6"; break;
		case 23: numerator = @"23π"; denominator = @"12"; break;
		default: numerator = @""; denominator = @""; break;
	}
	[angleNumeratorTextField setStringValue:numerator];
	[angleDenominatorTextField setStringValue:denominator];
	[angleFractionBar setHidden:([denominator length] == 0)];
}

- (IBAction)penNibListAction:(id)sender {
	NSInteger selection = [penNibListTableView selectedRow];
	if (selection < 0) {
		// nothing selected
		[selectedPen release];
		selectedPen = nil;
		[penNibListSegmentedControl setEnabled:NO forSegment:kRemoveSelectedPenSegmentNumber];
		[self setPenName:@""];
		// disable the editing controls
		for (NSView *aView in [[penEditingBox contentView] subviews]) {
			if ([aView respondsToSelector:@selector(setEnabled:)]) {
				[(NSControl *)aView setEnabled:NO];
			}
		}
	} else {
		// a pen is selected
		selectedPen = [[nibNames objectAtIndex:selection] retain];
		[penNibListSegmentedControl setEnabled:YES forSegment:kRemoveSelectedPenSegmentNumber];
		[self setPenName:selectedPen];
		tabletPenNib *theNib = [nibs objectForKey:selectedPen];
		[self setMaximumStrokeWidth:[theNib maximumStrokeWidth]];
		[self setMinimumStrokeWidth:[theNib minimumStrokeWidth]];
		[self setIsAngleDependent:[theNib isAngleDependent]];
		if ([theNib isAngleDependent]) {
			[self setWidestAngle:[theNib widestAngle]];
			CGFloat sliderValue = 90.0 - ([self widestAngle] * 180.0 / pi);
			if (sliderValue < 0) sliderValue += 360;
			[self setAngleCircularSliderValue:sliderValue];
		}
		[self setInkColor:[theNib inkColor]];
		// enable the editing controls
		for (NSView *aView in [[penEditingBox contentView] subviews]) {
			if ([aView respondsToSelector:@selector(setEnabled:)]) {
				[(NSControl *)aView setEnabled:YES];
			}
		}
		[inkStrokePreview setImage:[theNib sampleStrokeImage]];
	}
	[self angleCircularSliderAction:nil];
}

- (IBAction)penNibListSegmentedControlAction:(id)sender {
	if ([penNibListSegmentedControl selectedSegment] == kAddAPenSegmentNumber) {
		NSUInteger untitledNumber = 1;
		while ([nibNames containsObject:[NSString stringWithFormat:@"Untitled Pen %d", untitledNumber]]) {
			untitledNumber++;
		}
		NSString *newNibName = [NSString stringWithFormat:@"Untitled Pen %d", untitledNumber];
		[nibs setObject:[tabletPenNib defaultTabletPenNib] forKey:newNibName];
		[tabletPenNib savePenNibs:nibs];
		[self reloadTableData];
		[penNibListTableView selectRow:[nibNames indexOfObject:newNibName] byExtendingSelection:NO];
		[self penNibListAction:nil];
	} else if ([penNibListSegmentedControl selectedSegment] == kRemoveSelectedPenSegmentNumber) {
		NSInteger selection = [penNibListTableView selectedRow];
		if (selection >= 0) {
			[nibs removeObjectForKey:[nibNames objectAtIndex:selection]];
			[tabletPenNib savePenNibs:nibs];
			[self reloadTableData];
			[penNibListTableView deselectAll:nil];
			[self penNibListAction:nil];
		}
	}
}

#pragma mark -
#pragma mark KVO so we can tell when our own properties change

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
	tabletPenNib *theNib = [nibs objectForKey:selectedPen];
	[theNib setMaximumStrokeWidth:[self maximumStrokeWidth]];
	[theNib setMinimumStrokeWidth:[self minimumStrokeWidth]];
	[theNib setIsAngleDependent:[self isAngleDependent]];
	if ([theNib isAngleDependent]) [theNib setWidestAngle:[self widestAngle]];
	[theNib setInkColor:[self inkColor]];
	if (![[self penName] isEqualToString:selectedPen]) {
		// pen was renamed
		[nibs setObject:theNib forKey:[self penName]];
		[nibs removeObjectForKey:selectedPen];
		[self reloadTableData];
	}
	[tabletPenNib savePenNibs:nibs];
	[inkStrokePreview setImage:[theNib sampleStrokeImage]];
}

#pragma mark -
#pragma mark window delegate methods

- (void)windowDidBecomeKey:(NSNotification *)notification {
	[nibs release];
	nibs = [[NSMutableDictionary dictionaryWithDictionary:[tabletPenNib penNibs]] retain];
	
	[self reloadTableData];
	
	[selectedPen release];
	selectedPen = nil;
	if ([penNibListTableView selectedRow] >= 0) {
		selectedPen = [[nibNames objectAtIndex:[penNibListTableView selectedRow]] retain];
	}
	[self penNibListAction:nil];
}

#pragma mark -
#pragma mark table view data source methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
	return [nibNames count];
}

- (id)tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(NSInteger)rowIndex
{
	return [nibNames objectAtIndex:rowIndex];
}


@end
