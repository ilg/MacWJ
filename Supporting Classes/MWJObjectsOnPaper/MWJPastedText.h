//
//  MWJPastedText.h
//  MacWJ
//
//  Created by Isaac Greenspan on 5/9/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MWJObjectOnPaper.h"


@interface MWJPastedText : NSObject < MWJObjectOnPaper > {
	@private
	NSTextField *theTextField;
	NSRect textFrame;
}

- (id)initWithData:(NSData *)theData
		centeredOn:(NSPoint)centerPoint;

@end
