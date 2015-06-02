//
//  XMDragView.m
//  iOSImagesExtractor
//
//  Created by chi on 15-5-27.
//  Copyright (c) 2015年 chi. All rights reserved.
//

#import "XMDragView.h"

@implementation XMDragView
{
    BOOL _draggingEntered;
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if(self) {
        _dragEnable = NO;
        self.dragEnable = YES;
    }
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    
    if(_draggingEntered) [[NSColor lightGrayColor] set];
    else [[NSColor windowBackgroundColor] set];
    NSRectFill(dirtyRect);
}


- (void)setDragEnable:(BOOL)dragEnable
{
    if (_dragEnable != dragEnable) {
        [self unregisterDraggedTypes];
        
        if (dragEnable) {
            [self registerForDraggedTypes:@[NSFilenamesPboardType]];
        }
    }
    
    _dragEnable = dragEnable;
}


#pragma mark -
#pragma mark NSDraggingDestination Methods
- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
    _draggingEntered = YES;
    [self setNeedsDisplay:YES];
    return NSDragOperationCopy;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender
{
    _draggingEntered = NO;
    [self setNeedsDisplay:YES];
}

- (void)draggingEnded:(id<NSDraggingInfo>)sender
{
    _draggingEntered = NO;
    [self setNeedsDisplay:YES];
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    NSPasteboard *pasteboard = [sender draggingPasteboard];
    if([[pasteboard types] containsObject:NSFilenamesPboardType]) {
        NSArray *items = [pasteboard propertyListForType:NSFilenamesPboardType];
        if([self.delegate respondsToSelector:@selector(dragView:didDragItems:)]) {
            [self.delegate dragView:self didDragItems:items];
        }
        return YES;
    }
    
    return NO;
}

@end
