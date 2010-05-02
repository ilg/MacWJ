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
//  AppDelegate.m
//  MacWJ
//

#import "MacWJ_AppDelegate.h"
#import "tabletPenNib.h"


@implementation MacWJ_AppDelegate

+ (void)initialize {
	[[NSUserDefaults standardUserDefaults]
	 registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
					   // object, key; nil-terminated
					   [NSKeyedArchiver archivedDataWithRootObject:
						[NSDictionary dictionaryWithObjectsAndKeys:
						 [tabletPenNib tabletPenNibWithMinimumWidth:0.5
													   maximumWidth:5.0
												   isAngleDependent:YES
												   angleForMaxWidth:(-pi/4.0)
															  color:[NSColor blackColor]],
						 @"Default Black Pen",
						 [tabletPenNib tabletPenNibWithMinimumWidth:0.5
													   maximumWidth:5.0
												   isAngleDependent:YES
												   angleForMaxWidth:(-pi/4.0)
															  color:[NSColor blueColor]],
						 @"Default Blue Pen",
						 nil]], @"penNibs",
					   [NSNumber numberWithFloat:0.5], @"minStrokeWidth",
					   [NSNumber numberWithFloat:5.0], @"maxStrokeWidth",
					   [NSNumber numberWithFloat:1.0], @"eraserRadius",
					   [NSNumber numberWithFloat:1.0], @"copyAsImageScaleFactor",
					   nil]];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application
}

@end
