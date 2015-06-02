//
//  main.m
//  CARExtractor
//
//  Created by Brandon McQuilkin on 10/27/14.
//
//  Based on  by cartool Steven Troughton-Smith on 14/07/2013.
//  Copyright (c) 2013 High Caffeine Content. All rights reserved.
//

#import <Foundation/Foundation.h>

#pragma Private Frameworks

@interface CUICommonAssetStorage : NSObject

-(NSArray *)allAssetKeys;
-(NSArray *)allRenditionNames;

-(id)initWithPath:(NSString *)p;

-(NSString *)versionString;


@end

@interface CUINamedImage : NSObject

-(CGImageRef)image;

@end

@interface CUIRenditionKey : NSObject
@end

@interface CUIThemeFacet : NSObject

+(CUIThemeFacet *)themeWithContentsOfURL:(NSURL *)u error:(NSError **)e;
+ (void)_invalidateArtworkCaches;

@end

@interface CUICatalog : NSObject

-(id)initWithName:(NSString *)n fromBundle:(NSBundle *)b;
-(id)allKeys;
-(CUINamedImage *)imageWithName:(NSString *)n scaleFactor:(CGFloat)s;
-(CUINamedImage *)imageWithName:(NSString *)n scaleFactor:(CGFloat)s deviceIdiom:(int)idiom;

@end

#define kCoreThemeIdiomPhone 1
#define kCoreThemeIdiomPad 2

#pragma mark Export Image

void CGImageWriteToFile(CGImageRef image, NSString *path)
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:path.stringByDeletingLastPathComponent])
        [[NSFileManager defaultManager] createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:true attributes:nil error:nil];
    
    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:path];
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL(url, kUTTypePNG, 1, NULL);
    CGImageDestinationAddImage(destination, image, nil);
    
    if (!CGImageDestinationFinalize(destination)) {
        
#ifdef DEBUG
        NSLog(@"Failed to write image to %@", path);
#endif
        
    }
    
    CFRelease(destination);
}

#pragma mark Export CAR

void exportCarFileAtPath(NSString * carPath, NSString *outputDirectoryPath)
{
    NSError *error = nil;
    
    CUIThemeFacet *facet = [CUIThemeFacet themeWithContentsOfURL:[NSURL fileURLWithPath:carPath] error:&error];
    CUICatalog *catalog = [[CUICatalog alloc] init];
    /* Override CUICatalog to point to a file rather than a bundle */
    [catalog setValue:facet forKey:@"_storageRef"];
    /* CUICommonAssetStorage won't link */
    CUICommonAssetStorage *storage = [[NSClassFromString(@"CUICommonAssetStorage") alloc] initWithPath:carPath];
    
    for (NSString *key in [storage allRenditionNames])
    {
        
#ifdef DEBUG
        NSLog(@"Writing Image:%@", key);
#endif
        
        CGImageRef iphone1X = [[catalog imageWithName:key scaleFactor:1.0 deviceIdiom:kCoreThemeIdiomPhone] image];
        CGImageRef iphone2X = [[catalog imageWithName:key scaleFactor:2.0 deviceIdiom:kCoreThemeIdiomPhone] image];
        CGImageRef iphone3X = [[catalog imageWithName:key scaleFactor:3.0 deviceIdiom:kCoreThemeIdiomPhone] image];
        CGImageRef ipad1X = [[catalog imageWithName:key scaleFactor:1.0 deviceIdiom:kCoreThemeIdiomPad] image];
        CGImageRef ipad2X = [[catalog imageWithName:key scaleFactor:2.0 deviceIdiom:kCoreThemeIdiomPad] image];
        
        if (iphone1X)
            CGImageWriteToFile(iphone1X, [outputDirectoryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", key]]);
        
        if (iphone2X && iphone2X != iphone1X)
            CGImageWriteToFile(iphone2X, [outputDirectoryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@@2x.png", key]]);
        
        if (iphone3X && iphone3X != iphone2X)
            CGImageWriteToFile(iphone3X, [outputDirectoryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@@3x.png", key]]);
        
        if (ipad1X && ipad1X != iphone1X)
            CGImageWriteToFile(ipad1X, [outputDirectoryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", key]]);
        
        if (ipad2X && ipad2X != iphone2X)
            CGImageWriteToFile(ipad2X, [outputDirectoryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@@2x.png", key]]);
    }
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        //Check inputs
        NSString *input = [[NSUserDefaults standardUserDefaults] stringForKey:@"i"];
        NSString *output = [[NSUserDefaults standardUserDefaults] stringForKey:@"o"];
        
        if (!input || !output) {
#ifdef DEBUG
            NSLog(@"Invalid call, missing input or output.");
#endif
            return 1;
        }
        
        exportCarFileAtPath(input, output);
    }
    return 0;
}
