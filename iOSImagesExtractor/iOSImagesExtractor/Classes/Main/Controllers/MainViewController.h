//
//  MainViewController.h
//  iOSImagesExtractor
//
//  Created by chi on 15-5-27.
//  Copyright (c) 2015年 chi. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#ifdef DEBUG
#define XMLog(...) NSLog(__VA_ARGS__);
#else
#define XMLog(...)
#endif

@interface MainViewController : NSViewController

@end
