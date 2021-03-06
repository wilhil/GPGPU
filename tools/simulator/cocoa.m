// 
// Copyright 2011-2012 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

#import <Cocoa/Cocoa.h>
#include "core.h"

//
// Code to display live framebuffer contents in a window
//

@interface FrameBufferView : NSView
{
	CGDataProviderRef mFbBitsProviderRef;
	int mWidth;
	int mHeight;
	Core *mCore;
}

- (void) dealloc;
- (void) executeCode;
- (void) setCore: (Core*) core;
- (void) updateFb;

@end

@implementation FrameBufferView

- (id) initWithFrame: (NSRect) frameRect
{
	self = [super initWithFrame: frameRect];

	mWidth = frameRect.size.width;
	mHeight = frameRect.size.height;

	return self;
}

- (void) setFb:(void*) baseAddress
{
	mFbBitsProviderRef = CGDataProviderCreateWithData(NULL, baseAddress, 
		mWidth * 4 * mHeight, NULL);
}

- (void) dealloc
{
	if (mFbBitsProviderRef)
		CGDataProviderRelease(mFbBitsProviderRef);

	[super dealloc];
}

- (void) updateFb
{
	[self setNeedsDisplayInRect:NSMakeRect(0, 0, mWidth, mHeight)];
}

- (void) drawRect:(NSRect) rect
{
	CGContextRef viewContextRef = [[NSGraphicsContext currentContext] graphicsPort];
	CGContextSetInterpolationQuality(viewContextRef, kCGInterpolationNone);
	CGContextSetShouldAntialias(viewContextRef, NO);

	if (mFbBitsProviderRef) 
	{
		CGImageRef imageRef = CGImageCreate(
			mWidth,
			mHeight,
			8, //bitsPerComponent
			32, //bitsPerPixel
			(mWidth * 4), //bytesPerRow
			CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB), 
			kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst,
			mFbBitsProviderRef, //provider
			NULL, //decode
			0, //interpolate
			kCGRenderingIntentDefault); //intent
		CGContextDrawImage(viewContextRef, CGRectMake(0, 0, [self bounds].size.width, [self bounds].size.height), imageRef);
		CGImageRelease(imageRef);
	}
}

- (void) executeCode
{
	if (!runQuantum(mCore, 500000))
	{
		printf("app terminated\n");
		[NSApp terminate: nil];
	}
	
	[self updateFb];
}

- (void) setCore: (Core*) core
{
	mCore = core;
}

@end

@interface SimAppController : NSObject
{
}
@end

@implementation SimAppController
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}
@end

void runUI(Core *core, int width, int height)
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	// Make foreground application with icon in task bar
	ProcessSerialNumber psn = { 0, kCurrentProcess };
	TransformProcessType(&psn, kProcessTransformToForegroundApplication);

	[NSApplication sharedApplication];

	NSView *mainView = [[FrameBufferView alloc] initWithFrame:NSMakeRect(0.0, 0.0, width, height)];
	if (!mainView) 
	{
		fprintf(stderr, "Couldn't allocate view\n");
		exit(1);
	}

	[mainView setCore:core];
	[mainView setFb: getCoreFb(core)];

	NSWindow *mainWindow = [[NSWindow alloc] initWithContentRect:[mainView frame]
		styleMask:NSTitledWindowMask|NSMiniaturizableWindowMask|NSClosableWindowMask
		backing:NSBackingStoreBuffered defer:NO];
	if (!mainWindow) 
	{
		fprintf(stderr, "(cocoa) can't create window\n");
		exit(1);
	}

	[NSApp activateIgnoringOtherApps:YES];
	
	[mainWindow setTitle:[NSString stringWithFormat:@"Framebuffer"]];
	[mainWindow setContentView:mainView];
	[mainWindow useOptimizedDrawing:YES];
	[mainWindow center];
	[mainWindow makeKeyAndOrderFront:nil];

	[NSTimer scheduledTimerWithTimeInterval:0
		target:mainView selector:@selector(executeCode)
		userInfo:nil repeats:YES];

    SimAppController *appController = [[SimAppController alloc] init];
    [NSApp setDelegate:appController];

	[NSApp run];

	[pool release];
}
