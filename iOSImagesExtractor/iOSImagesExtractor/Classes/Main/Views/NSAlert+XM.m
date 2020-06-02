//
//  NSAlert+XM.m
//  iOSImagesExtractor
//
//  Created by chixm on 2020/6/2.
//  Copyright © 2020 chi. All rights reserved.
//

#import "NSAlert+XM.h"

@implementation NSAlert (XM)

+ (instancetype)xm_alertWithMessageText:(NSString *)message informativeText:(NSString *)informativeText defaultButton:(NSString *)defaultButton {
    NSAlert *alert = [[self alloc] init];
    alert.messageText = message ?: @"";;
    alert.informativeText = informativeText ?: @"";
    if (defaultButton.length > 0) {    
        [alert addButtonWithTitle:defaultButton];
    }
    return alert;
}

@end
