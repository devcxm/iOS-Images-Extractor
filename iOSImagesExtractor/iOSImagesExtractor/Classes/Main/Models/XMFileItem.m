//
//  XMFileItem.m
//  iOSImagesExtractor
//
//  Created by chi on 15/5/27.
//  Copyright (c) 2015年 chi. All rights reserved.
//

#import "XMFileItem.h"


@interface XMFileItem ()
{
    BOOL _isDirectory;
    BOOL _isFileExists;
}

@end

@implementation XMFileItem


- (NSString *)description
{
    return self.filePath;
}

- (NSString *)fileName
{
    return [self.filePath lastPathComponent];
}

- (void)setFilePath:(NSString *)filePath
{
    _filePath = filePath;
    
    _isFileExists = [[NSFileManager defaultManager]fileExistsAtPath:filePath isDirectory:&_isDirectory];
}


- (BOOL)isDirectory
{
    return _isDirectory;
}


- (BOOL)isFileExists
{
    return _isFileExists;
}



+ (instancetype)xmFileItemWithPath:(NSString*)filePath
{
    XMFileItem *item = [[self alloc]init];
    item.filePath = filePath;
    return item;
}

@end


@implementation NSString (_ShellPath)

- (NSString *)xm_shellPath {
    NSString *spaceString =@" ";
    NSString *backslash = @"\\";
    NSString *path = [self stringByReplacingOccurrencesOfString:@" " withString:[NSString stringWithFormat:@"%@%@",backslash,spaceString]];
    
    return path;
}

@end
