//
//  XMFileItem.h
//  iOSImagesExtractor
//
//  Created by chi on 15/5/27.
//  Copyright (c) 2015年 chi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XMFileItem : NSObject


/**
 *  文件路径
 */
@property (nonatomic, copy) NSString *filePath;

/**
 *  文件(夹)名称
 */
@property (nonatomic, copy, readonly) NSString *fileName;


/**
 *  是否是文件夹
 */
@property (nonatomic, assign, readonly) BOOL isDirectory;


/**
 *  是否存在
 */
@property (nonatomic, assign, readonly) BOOL isFileExists;


#pragma mark - 类工厂
+ (instancetype)xmFileItemWithPath:(NSString*)filePath;

@end
