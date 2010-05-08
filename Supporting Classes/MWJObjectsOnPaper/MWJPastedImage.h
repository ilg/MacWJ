//
//  MWJPastedImage.h
//  MacWJ
//
//  Created by Isaac Greenspan on 5/8/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MWJObjectOnPaper.h"


@interface MWJPastedImage : NSObject < MWJObjectOnPaper > {
	@private
	NSImage *theImage;
	NSRect imageFrame;
}

- (id)initWithData:(NSData *)theData
		   inFrame:(NSRect)theFrame;

@end
