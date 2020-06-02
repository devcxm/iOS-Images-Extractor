//
//  NSAlert+XM.h
//  iOSImagesExtractor
//
//  Created by chixm on 2020/6/2.
//  Copyright © 2020 chi. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSAlert (XM)

+ (instancetype)xm_alertWithMessageText:(nullable NSString *)message informativeText:(nullable NSString *)informativeText defaultButton:(nullable NSString *)defaultButton;

@end

NS_ASSUME_NONNULL_END
