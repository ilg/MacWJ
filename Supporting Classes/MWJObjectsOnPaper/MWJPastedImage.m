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
//  MWJPastedImage.m
//  MacWJ
//

#import "MWJPastedImage.h"


@implementation MWJPastedImage


- (id)initWithData:(NSData *)theData
		centeredOn:(NSPoint)centerPoint
{
	self = [super init];
	if (self) {
		theImage = [[NSImage alloc] initWithData:theData];
		[theImage setFlipped:YES];
		NSRect ourFrame;
		ourFrame.size = [theImage size];
		ourFrame.origin.x = centerPoint.x - ourFrame.size.width / 2.0;
		ourFrame.origin.y = centerPoint.y - ourFrame.size.height / 2.0;
		[self setFrame:ourFrame];
	}
	return self;
}


#pragma mark -
#pragma mark MWJObjectOnPaper protocol implementation
// the rest of the protocol is implemented in MWJObjectOnPaperParentClass

- (void)drawInRect:(NSRect)dirtyRect
		 withRects:(const NSRect *)dirtyRects
			 count:(NSInteger)dirtyRectsCount
{
	[theImage drawInRect:[self frame]
				fromRect:NSZeroRect
			   operation:NSCompositeSourceOver
				fraction:1.0];
}

- (BOOL)isResizable
{
	return YES;
}


#pragma mark -
#pragma mark for archiving/unarchiving (for saving/loading documents)

// MARK: string keys for NSCoding
NSString * const kMWJPastedImageImageKey = @"MWJPastedImageImageKey";
NSString * const kMWJPastedImageFrameKey = @"MWJPastedImageFrameKey";

- (void)encodeWithCoder:(NSCoder *)coder {
	// NSObject does not conform to NSCoding
	//    [super encodeWithCoder:coder];
    [coder encodeObject:theImage forKey:kMWJPastedImageImageKey];
	[coder encodeRect:[self frame] forKey:kMWJPastedImageFrameKey];
}

- (id)initWithCoder:(NSCoder *)coder {
	// NSObject does not conform to NSCoding
	//    self = [super initWithCoder:coder];
	self = [super init];
	if (self) {
		theImage = [[coder decodeObjectForKey:kMWJPastedImageImageKey] retain];
		[self setFrame:[coder decodeRectForKey:kMWJPastedImageFrameKey]];
	}
    return self;
}


@end
