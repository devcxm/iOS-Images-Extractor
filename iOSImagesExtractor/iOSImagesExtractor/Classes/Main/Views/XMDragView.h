//
//  XMDragView.h
//  iOSImagesExtractor
//
//  Created by chi on 15-5-27.
//  Copyright (c) 2015年 chi. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class XMDragView;

@protocol XMDragViewDelegate <NSObject>

/**
 *  接收到拖拽文件后回调
 */
- (void)dragView:(XMDragView *)dragView didDragItems:(NSArray *)items;

@end

@interface XMDragView : NSView <NSDraggingDestination>


@property (nonatomic, assign) id<XMDragViewDelegate> delegate;

/**
 *  设置是否可接受拖文件
 */
@property (nonatomic, assign) BOOL dragEnable;

@end
