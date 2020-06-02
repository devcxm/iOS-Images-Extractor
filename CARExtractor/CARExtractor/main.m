//
//  main.m
//  CARExtractor
//
//  Created by chixm on 2020/6/1.
//  Copyright © 2020 chi. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreUI.h"
#import "CarUtilities.h"

static NSString *kProccessingNotificationName = nil;
static CFTimeInterval s_lastPostNotificationTime = 0;

void postProccessingNotification(NSDictionary *userInfo) {
    CFTimeInterval currentMediaTime = CACurrentMediaTime();
    if (currentMediaTime - s_lastPostNotificationTime < 0.05f) {
        return;
    }
    s_lastPostNotificationTime = currentMediaTime;
    if (kProccessingNotificationName && userInfo.count > 0) {
         CFNotificationCenterRef distributedCenter =
               CFNotificationCenterGetDistributedCenter();

        CFNotificationCenterPostNotification(distributedCenter,
                                                (__bridge CFStringRef)kProccessingNotificationName,
                                             NULL,
                                                (__bridge CFDictionaryRef)userInfo,
                                                TRUE);
    }
}

NSString * FindUniquePathForPath(NSString *inPath, NSString *optionalPathComponent, BOOL forceUseOptionalFileNamePathComponent)
{
    NSString *outPath = inPath;
    
    // If the path exists, add the optional path component for differenciation
    if([optionalPathComponent length] > 0 && ([[NSFileManager defaultManager] fileExistsAtPath:inPath] || forceUseOptionalFileNamePathComponent))
    {
        NSString *pathExtension = [inPath pathExtension];
        if([pathExtension length] > 0)
        {
            NSString *replaceString = [NSString stringWithFormat:@".%@", pathExtension];
            outPath = [inPath stringByReplacingOccurrencesOfString:replaceString withString:[NSString stringWithFormat:@"~%@%@", optionalPathComponent, replaceString] options:NSBackwardsSearch range:NSMakeRange(0, [inPath length])];
        }
        else
        {
            outPath = [inPath stringByAppendingFormat:@"%@", [NSString stringWithFormat:@"~%@", optionalPathComponent]];
        }
    }
    
    // Ensure the path does not exist
    NSString *initialPath = outPath;
    if([[NSFileManager defaultManager] fileExistsAtPath:initialPath])
    {
        NSString *pathExtension = [initialPath pathExtension];
        if([pathExtension length] > 0)
        {
            NSString *replaceString = [NSString stringWithFormat:@".%@", pathExtension];
            NSUInteger fileSuffix = 1;
            while([[NSFileManager defaultManager] fileExistsAtPath:outPath])
            {
                outPath = [initialPath stringByReplacingOccurrencesOfString:replaceString withString:[NSString stringWithFormat:@"~%ld%@", fileSuffix, replaceString] options:NSBackwardsSearch range:NSMakeRange(0, [initialPath length])];
                fileSuffix++;
            }
        }
        else
        {
            NSUInteger fileSuffix = 1;
            while([[NSFileManager defaultManager] fileExistsAtPath:outPath])
            {
                outPath = [initialPath stringByAppendingFormat:@"%@", [NSString stringWithFormat:@"~%ld", fileSuffix]];
                fileSuffix++;
            }
        }
    }
    
    return outPath;
}

void DumpCGImageToPath(CGImageRef inImage, NSString *inPath)
{
    if(inImage != NULL && inPath != nil)
    {
        // Get the file URL
        CFURLRef fileURL = (__bridge CFURLRef)[NSURL fileURLWithPath:inPath];
        
        // Write the CGImageRef to disk
        CGImageDestinationRef destinationRef = CGImageDestinationCreateWithURL(fileURL, kUTTypePNG, 1, NULL);
        if(destinationRef != NULL)
        {
            CGImageDestinationAddImage(destinationRef, inImage, nil);
            if (!CGImageDestinationFinalize(destinationRef))
            {
                NSLog(@"Could not dump the image to %@", inPath);
            }
            
            CFRelease(destinationRef);
        }
    }
}

void ProcessNamedLookup(NSString *inOutputFolder, NSString *fileName, NSString *optionalFileNameComponent, BOOL forceUseOptionalFileNamePathComponent, CGImageRef cgImage, NSData *representation)
{
    //
    //
    // From /Applications/Xcode.app/Contents/Developer/Platforms/AppleTVSimulator.platform/Developer/SDKs/AppleTVSimulator.sdk/System/Library/PrivateFrameworks/CoreThemeDefinition.framework/CoreThemeDefinition
    // "ZZZZExplicitlyPackedAsset-%d.%d.%d-gamut%d"
    // "ZZZZPackedAsset-%d.%d.%d-gamut%d"
    // "ZZZZFlattenedImage-%d.%d.%d"
    // "ZZZZRadiosityImage-%d.%d.%d"
    //
    
    if([fileName hasPrefix:@"ZZZZPackedAsset"])
    {
        // Ignore ZZZZPackedAsset
        return;
    }
    
    NSString *uniqueFilePath = FindUniquePathForPath([inOutputFolder stringByAppendingPathComponent:fileName], optionalFileNameComponent, forceUseOptionalFileNamePathComponent);
    
    if(cgImage != NULL)
    {
        DumpCGImageToPath(cgImage, uniqueFilePath);
    }
    else if([representation isKindOfClass:[NSData class]])
    {
        [(NSData *)representation writeToFile:uniqueFilePath atomically:NO];
    }
    else
    {
        NSLog(@"Nothing to output for %@", uniqueFilePath);
    }
}

void exportCarFileAtPath(NSString * carPath, NSString *outputDirectoryPath)
{
    
    outputDirectoryPath = [outputDirectoryPath stringByExpandingTildeInPath];

    if (![[NSFileManager defaultManager] fileExistsAtPath:outputDirectoryPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:outputDirectoryPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    
    __block NSMutableArray<NSString *> *filenameListM = [NSMutableArray array];
    
    ProcessCarFileAtPath(carPath, outputDirectoryPath, ^(NSString *inOutputFolder, CarNamedLookupDict carNamedLookupDict)
    {
        if(carNamedLookupDict != nil)
        {
            NSString *fileName = carNamedLookupDict[kCarInfoDict_FilenameKey];
            if([fileName hasPrefix:@"ZZZZExplicitlyPackedAsset-"] ||
                    [fileName hasPrefix:@"ZZZZPackedAsset-"] ||
                    [fileName hasPrefix:@"ZZZZFlattenedImage-"] ||
                    [fileName hasPrefix:@"ZZZZRadiosityImage-"])
            {
                // Ignore assets like:
                // "ZZZZExplicitlyPackedAsset-%d.%d.%d-gamut%d"
                // "ZZZZPackedAsset-%d.%d.%d-gamut%d"
                // "ZZZZFlattenedImage-%d.%d.%d"
                // "ZZZZRadiosityImage-%d.%d.%d"
                return;
            }
            
            if (!fileName || [filenameListM containsObject:fileName]) {
                return;
            }
            
            postProccessingNotification(@{@"name":fileName});
            
            [filenameListM addObject:fileName];
            
            CGImageRef cgImage = (__bridge CGImageRef)(carNamedLookupDict[kCarInfoDict_CGImageKey]);
            NSData *assetData = carNamedLookupDict[kCarInfoDict_DataKey];
            
            NSString *optionalFileNamePathComponent = nil;
            if(cgImage != nil)
            {
                optionalFileNamePathComponent = [NSString stringWithFormat:@"%ldx%ld", CGImageGetWidth(cgImage), CGImageGetHeight(cgImage)];
            }
            
            BOOL forceUseOptionalFileNamePathComponent = [carNamedLookupDict[kCarInfoDict_IsMultisizeImageKey] boolValue];
            ProcessNamedLookup(inOutputFolder, fileName, optionalFileNamePathComponent, forceUseOptionalFileNamePathComponent, cgImage, assetData);
        }
    });
}


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc > 3) {
            for (int i = 2; i < argc; ++i) {
                NSString *argvString = [NSString stringWithUTF8String:argv[i]];
                if ([argvString containsString:@"--DistributedNotificationName="]) {
                    NSArray<NSString *> *components = [argvString componentsSeparatedByString:@"="];
                    if (components.count == 2) {
                        kProccessingNotificationName = components.lastObject.length > 0 ? components.lastObject : nil;
                    }
                    break;
                }
            }
        }
        
        
        exportCarFileAtPath([NSString stringWithUTF8String:argv[1]], argc > 2 ? [NSString stringWithUTF8String:argv[2]] : nil);
        
    }
    return 0;
}
