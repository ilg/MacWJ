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
//  MWJDocument.m
//  MacWJ
//

#import "MWJDocument.h"
#import "MWJPaperView.h"
#import "MWJInkingPenNib.h"
#import "MWJPaperBackgroundView.h"

#define EXTEND_PAGE_AMOUNT 100.0

@interface MWJDocument (private)

- (void)reloadNibs;

@end


@implementation MWJDocument

// MARK: keys for document file dictionary
NSString * const kMacWJDocumentRawInkDataKey = @"rawInkData";
NSString * const kMacWJDocumentWindowFrameDataKey = @"windowFrame";
NSString * const kMacWJDocumentBackgroundViewSizeDataKey = @"MWJPaperBackgroundViewSize";

// MARK: keys for undo/redo segmented control
NSInteger const kUndoRedoSegmentedUndoSegmentNumber = 0;
NSInteger const kUndoRedoSegmentedRedoSegmentNumber = 1;

// MARK: keys for tool selection segmented control
NSInteger const kToolSelectionSegmentedPenSegmentNumber = 0;
NSInteger const kToolSelectionSegmentedPencilSegmentNumber = 1;
NSInteger const kToolSelectionSegmentedEraserSegmentNumber = 2;
NSInteger const kToolSelectionSegmentedRectangularMarqueeSegmentNumber = 3;
NSInteger const kToolSelectionSegmentedLassoSegmentNumber = 4;

#pragma mark -

- (id)init
{
    self = [super init];
    if (self) {
    
        // Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.
		
		[self awakeFromNib];
    
    }
    return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (void)toggleUndoRedoEnabled:(NSNotification *)notification {
	[undoRedoSegmentedControl setEnabled:[[self undoManager] canUndo]
							  forSegment:kUndoRedoSegmentedUndoSegmentNumber];
	[undoRedoSegmentedControl setEnabled:[[self undoManager] canRedo]
							  forSegment:kUndoRedoSegmentedRedoSegmentNumber];
}

- (void)awakeFromNib {
	[self reloadNibs];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(toggleUndoRedoEnabled:)
												 name:NSUndoManagerCheckpointNotification
											   object:[self undoManager]];
	[self toggleUndoRedoEnabled:nil];
	[[thePaperView window] setAcceptsMouseMovedEvents:YES];
	[theBackgroundView setFrame:[[theBackgroundView superview] bounds]];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
	[self reloadNibs];
}

- (void)reloadNibs {
	NSString *currentTitle = [penNibSelectionPopUpButton titleOfSelectedItem];
	[penNibSelectionPopUpButton removeAllItems];
	[penNibSelectionPopUpButton addItemWithTitle:@""];
	NSDictionary *penNibs = [MWJInkingPenNib penNibs];
	for (NSString *penNibName in [[penNibs allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
		MWJInkingPenNib *theNib = [penNibs objectForKey:penNibName];
		[penNibSelectionPopUpButton addItemWithTitle:penNibName];
		[[penNibSelectionPopUpButton itemWithTitle:penNibName]
		 setRepresentedObject:theNib];
		[[penNibSelectionPopUpButton itemWithTitle:penNibName]
		 setImage:[theNib sampleStrokeSmallerImage]];
	}
	if ([penNibs objectForKey:currentTitle]) {
		[penNibSelectionPopUpButton selectItemWithTitle:currentTitle];
	} else {
		[penNibSelectionPopUpButton selectItemAtIndex:1];
	}
	[self penNibSelected:penNibSelectionPopUpButton];
}

#pragma mark -
#pragma mark IBActions

- (IBAction)extendPage:(id)sender {
	NSRect frame = [theBackgroundView frame];
	[theBackgroundView setFrameSize:NSMakeSize(frame.size.width, frame.size.height + EXTEND_PAGE_AMOUNT)];
}

- (IBAction)penNibSelected:(id)sender {
	if ([sender respondsToSelector:@selector(menu)]) {
		[[penNibSelectionPopUpButton itemAtIndex:0] setTitle:[sender titleOfSelectedItem]];
		[[penNibSelectionPopUpButton itemAtIndex:0] setImage:[[sender selectedItem] image]];
		[thePaperView setCurrentPenNib:[[sender selectedItem] representedObject]];
		[toolSelectionSegmentedControl setSelectedSegment:kToolSelectionSegmentedPenSegmentNumber];
		[self toolSelectionAction:sender];
	}
}

- (IBAction)undoRedoAction:(id)sender {
	if ([undoRedoSegmentedControl selectedSegment] == kUndoRedoSegmentedUndoSegmentNumber) {
		[[self undoManager] undo];
	} else if ([undoRedoSegmentedControl selectedSegment] == kUndoRedoSegmentedRedoSegmentNumber) {
		[[self undoManager] redo];
	}
}

- (IBAction)toolSelectionAction:(id)sender {
	if ([toolSelectionSegmentedControl selectedSegment] == kToolSelectionSegmentedPenSegmentNumber) {
		[thePaperView setToolType:kMWJPaperViewPenToolType];
	} else if ([toolSelectionSegmentedControl selectedSegment] == kToolSelectionSegmentedPencilSegmentNumber) {
		[thePaperView setToolType:kMWJPaperViewPenToolType];
	} else if ([toolSelectionSegmentedControl selectedSegment] == kToolSelectionSegmentedEraserSegmentNumber) {
		[thePaperView setToolType:kMWJPaperViewEraserToolType];
	} else if ([toolSelectionSegmentedControl selectedSegment] == kToolSelectionSegmentedRectangularMarqueeSegmentNumber) {
		[thePaperView setToolType:kMWJPaperViewRectangularMarqueeToolType];
	} else if ([toolSelectionSegmentedControl selectedSegment] == kToolSelectionSegmentedLassoSegmentNumber) {
		[thePaperView setToolType:kMWJPaperViewLassoToolType];
	} else {
		[thePaperView setToolType:kMWJPaperViewPenToolType];
	}
}


#pragma mark -
#pragma mark NSDocument stuff

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"MWJDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to write your document to data of the specified type. If the given outError != NULL, ensure that you set *outError when returning nil.

    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.

    // For applications targeted for Panther or earlier systems, you should use the deprecated API -dataRepresentationOfType:. In this case you can also choose to override -fileWrapperRepresentationOfType: or -writeToFile:ofType: instead.
	
	NSString *strError = nil;
	NSData *theData = nil;
	if ([typeName isEqualToString:@"MacWJ Document"]) {
		NSDictionary *theSavedDictionary
		= [NSDictionary dictionaryWithObjectsAndKeys:
		   [thePaperView data], kMacWJDocumentRawInkDataKey,
		   NSStringFromRect([[thePaperView window] frame]), kMacWJDocumentWindowFrameDataKey,
		   NSStringFromSize([theBackgroundView frame].size), kMacWJDocumentBackgroundViewSizeDataKey,
		   nil];
		theData = [NSPropertyListSerialization dataFromPropertyList:theSavedDictionary
															 format:NSPropertyListXMLFormat_v1_0
												   errorDescription:&strError];
	} else if ([typeName isEqualToString:@"PNG File"]) {
		theData = [thePaperView PNGData];
	} else if ([typeName isEqualToString:@"PDF File"]) {
		theData = [thePaperView PDFData];
	} else {
		strError = [NSString stringWithFormat:@"unknown file type: %@", typeName];
	}
	
	if (strError && (outError != NULL)) {
		NSLog(@"Error saving: %@",strError);
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
	}
    return theData;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to read your document from the given data of the specified type.  If the given outError != NULL, ensure that you set *outError when returning NO.

    // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead. 
    
    // For applications targeted for Panther or earlier systems, you should use the deprecated API -loadDataRepresentation:ofType. In this case you can also choose to override -readFromFile:ofType: or -loadFileWrapperRepresentation:ofType: instead.
    
	NSString *strError;
	NSDictionary *theSavedDictionary = [NSPropertyListSerialization propertyListFromData:data
																		mutabilityOption:NSPropertyListImmutable
																				  format:NULL
																		errorDescription:&strError];
	if (theSavedDictionary && !strError) {
		[self performSelector:@selector(delayedSavedDictionaryLoad:)
				   withObject:theSavedDictionary
				   afterDelay:0];
	} else if (outError != NULL) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
	}
    return YES;
}

// helper method since thePaperView isn't set up at the moment readFromData:ofType:error: is called
- (void)delayedSavedDictionaryLoad:(NSDictionary *)theSavedDictionary {
	NSString *windowFrameString = [theSavedDictionary objectForKey:kMacWJDocumentWindowFrameDataKey];
	if (windowFrameString) [[thePaperView window]
							setFrame:NSRectFromString(windowFrameString)
							display:YES];
	
	NSString *paperBackgroundViewSizeString = [theSavedDictionary objectForKey:kMacWJDocumentBackgroundViewSizeDataKey];
	if (paperBackgroundViewSizeString) [theBackgroundView
										setFrameSize:NSSizeFromString(paperBackgroundViewSizeString)];
	
	[thePaperView loadFromData:[theSavedDictionary objectForKey:kMacWJDocumentRawInkDataKey]];
	[thePaperView setNeedsDisplay:YES];
}

@end
