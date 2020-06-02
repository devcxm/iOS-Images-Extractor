//
//  MainViewController.m
//  iOSImagesExtractor
//
//  Created by chi on 15-5-27.
//  Copyright (c) 2015年 chi. All rights reserved.
//

#import "MainViewController.h"

#pragma mark - Vendors
#import "ZipArchive.h"


#pragma mark - Models
#import "XMFileItem.h"

#pragma mark - Views
#import "XMDragView.h"
#import "NSAlert+XM.h"

@interface MainViewController () <XMDragViewDelegate, NSTableViewDataSource, NSTableViewDelegate>

/**
 *  展示DragFiles列表
 */
@property (weak) IBOutlet NSTableView *tableView;

/**
 *  处理状态
 */
@property (weak) IBOutlet NSTextField *statusLabel;


/**
 *  响应拖文件
 */
@property (strong) IBOutlet XMDragView *dragView;

/**
 *  清空按钮
 */
@property (weak) IBOutlet NSButton *clearButton;

/**
 *  开始按钮
 */
@property (weak) IBOutlet NSButton *startButton;


#pragma mark - data

/**
 *  支持处理的类型，目前仅支持png、jpg、ipa、car文件
 */
@property (nonatomic, copy) NSArray *extensionList;


/**
 *  拖进来的文件（夹）
 */
@property (nonatomic, strong) NSMutableArray *dragFileList;

/**
 *  在拖新文件进来时是否需要清空现在列表
 */
@property (nonatomic, assign) BOOL needClearDragList;


/**
 *  遍历出的所有文件
 */
@property (nonatomic, strong) NSMutableArray *allFileList;



/**
 *  文件保存文件夹
 */
@property (nonatomic, copy) NSString *destFolder;

/**
 *  当前输出路径
 */
@property (nonatomic, copy) NSString *currentOutputPath;


/**
 *  car文件CARExtractor解压程序路径
 */
@property (nonatomic, copy) NSString *carExtractorLocation;

@end

@implementation MainViewController

static void distributedNotificationCallback(CFNotificationCenterRef center,
                     void *observer,
                     CFStringRef name,
                     const void *object,
                     CFDictionaryRef userInfo)
{
    NSDictionary *userInfoObject = (__bridge NSDictionary *)(userInfo);
    NSString *pname = [userInfoObject objectForKey:@"name"];
    [(__bridge MainViewController *)observer setStatusString:[NSString stringWithFormat:@"Extracting Assets.car %@", pname]];
}

- (void)setupNotification {
    
    CFNotificationCenterRef distributedCenter = CFNotificationCenterGetDistributedCenter();
    
    CFNotificationSuspensionBehavior behavior = CFNotificationSuspensionBehaviorDeliverImmediately;
    
    CFNotificationCenterAddObserver(distributedCenter,
                                    (__bridge const void *)(self),
                                    distributedNotificationCallback,
                                    (__bridge const void *)([NSBundle mainBundle].bundleIdentifier),
                                    NULL,
                                    behavior);
}

#pragma mark - Lifecycle

- (void)dealloc {
    CFNotificationCenterRef distributedCenter = CFNotificationCenterGetDistributedCenter();
     CFNotificationCenterRemoveObserver(distributedCenter, (__bridge const void *)(self), (__bridge const void *)([NSBundle mainBundle].bundleIdentifier), NULL);
}

- (void)awakeFromNib
{
    self.dragView.delegate = self;
    
    [self setupNotification];

    // 获取CARExtractor执行程序路径
    // 1,先从Resource目录查找
    NSString *tmpPath = [[[NSBundle mainBundle]resourcePath]stringByAppendingPathComponent:@"CARExtractor"];
    if (![[NSFileManager defaultManager]fileExistsAtPath:tmpPath]) {
        tmpPath = nil;
//        // 2,再从app同级目录查找
//        NSString *bundlePath = [[NSBundle mainBundle]bundlePath];
//        tmpPath = [[bundlePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"CARExtractor"];
//        if (![[NSFileManager defaultManager]fileExistsAtPath:tmpPath]) {
//            tmpPath = nil;
//        }
    }
    self.carExtractorLocation = tmpPath;

    
    self.needClearDragList = YES;
    
    // 支持的扩展名文件
    self.extensionList = @[@"ipa", @"car", @"png", @"jpg"];
    
}

/**
 *  在主线程中设置状态
 *
 *  @param stauts 处理状态信息
 */
- (void)setStatusString:(NSString*)stauts
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setStatusString:stauts];
        });
        return;
    }
    
    [self.statusLabel setStringValue:stauts];
}





#pragma mark - Event Response

/**
 *  响应按钮点击
 *
 */
- (IBAction)clickButton:(NSButton*)sender {
    
    if (sender.tag == 100) {// Clear
        [self.dragFileList removeAllObjects];
        [self.tableView reloadData];
        self.currentOutputPath = nil;
        [self setStatusString:@""];
    }
    else if (sender.tag == 300) {// Output Dir
        
        if (_currentOutputPath.length > 0) {
            NSArray *fileURLs = [NSArray arrayWithObjects:[[NSURL alloc] initFileURLWithPath:_currentOutputPath], /* ... */ nil];
            [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
        }
        else {
            
            [[NSAlert xm_alertWithMessageText:@"No Output" informativeText:@"There is no output." defaultButton:nil] beginSheetModalForWindow:self.view.window completionHandler:nil];
        }
        

    }
    else if (sender.tag == 400) {// About
        NSMenu * menu = [[NSMenu alloc] initWithTitle:@"More Options"];
        {
            NSMenuItem *installOrRemovePluginItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ QLCARFiles QuickLook Plugin", ([[NSFileManager defaultManager] fileExistsAtPath:[self.class QuickLookpluginInstallLocation]] ? @"Remove" : @"Install")] action:@selector(clickMenuItem:) keyEquivalent:@""];
            installOrRemovePluginItem.target = self;
            installOrRemovePluginItem.tag = 1000;
            
            NSMenuItem *checkForUpdatesItem = [[NSMenuItem alloc] initWithTitle:@"Check for Updates" action:@selector(clickMenuItem:) keyEquivalent:@""];
            checkForUpdatesItem.target = self;
            checkForUpdatesItem.tag = 2000;
            
            NSMenuItem * aboutItem = [[NSMenuItem alloc] initWithTitle:@"About" action:@selector(clickMenuItem:) keyEquivalent:@""];
            aboutItem.target = self;
            aboutItem.tag = 9001;
            
            [menu addItem:installOrRemovePluginItem];
            [menu addItem:[NSMenuItem separatorItem]];
            [menu addItem:checkForUpdatesItem];
            [menu addItem:[NSMenuItem separatorItem]];
            [menu addItem:aboutItem];
            
            [NSMenu popUpContextMenu:menu withEvent:[NSApplication sharedApplication].currentEvent forView:sender];
        }
    }
    else if (sender.tag == 200) {// Start
        
        if (self.dragFileList.count < 1) {
            [[NSAlert xm_alertWithMessageText:@"Error" informativeText:@"Drag files into window first." defaultButton:nil] beginSheetModalForWindow:self.view.window completionHandler:nil];
            return;
        }
        
        
        
        self.dragView.dragEnable = NO;
        self.clearButton.enabled = NO;
        self.startButton.enabled = NO;
        self.currentOutputPath = nil;
        
        
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            [self getAllFilesFromDragPaths];
            // 处理现有的png、jpg文件
            NSArray *imagesArray = [self.allFileList filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.filePath.pathExtension IN {'jpg', 'png'}"]];
            
            if (imagesArray.count > 0) {
                NSString *existImagesPath = [self.currentOutputPath stringByAppendingPathComponent:@"ImagesOutput"];
                [MainViewController createDirectoryWithPath:existImagesPath];
                for (int i = 0; i < imagesArray.count; ++i) {
                    XMFileItem *item = imagesArray[i];
                    [self doPngOrJpgFileWithPath:item.filePath outputPath:existImagesPath];
                }
            }
            
            
            // 处理现有car文件
            NSArray *carArray = [self.allFileList filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.filePath.pathExtension == 'car'"]];
            
            if (carArray.count > 0) {
                NSString *existCarPath = [self.currentOutputPath stringByAppendingPathComponent:@"CarFilesOutput"];
                [MainViewController createDirectoryWithPath:existCarPath];
                
                for (int i = 0; i < carArray.count; ++i) {
                    
                    XMFileItem *fileItem = carArray[i];
                    
                    NSString *outputPath = [existCarPath stringByAppendingPathComponent:[NSString stringWithFormat:@"car_images_%@", [MainViewController getRandomStringWithCount:5]]];
//                    [self setStatusString:[NSString stringWithFormat:@"Processing %@ ...", fileItem.fileName]];
                    [self exportCarFileAtPath:fileItem.filePath outputPath:outputPath tag:nil];
                }
            }

            
            // 解压并处理ipa文件
            [self doIpaFile];
            
            
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setStatusString:@"Jobs done, have fun."];
                
                // 取消禁用
                self.dragView.dragEnable = YES;
                self.clearButton.enabled = YES;
                self.startButton.enabled = YES;
                
                // 重置参数
                self.needClearDragList = YES;
                [self.allFileList removeAllObjects];
            });
        });
    }
}


- (void)clickMenuItem:(NSMenuItem *)sender {
    
    if (sender.tag == 1000) {
        NSString *destPath = [self.class QuickLookpluginInstallLocation];
        NSString *informativeText = nil;
        if ([[NSFileManager defaultManager] fileExistsAtPath:destPath]) {
            [self.class excuteShellScript:[NSString stringWithFormat:@"rm -rf %@;qlmanage -r;", destPath.xm_shellPath]];
            informativeText = @"Remove QLCARFiles successfully.";
        } else {
            NSString *qlgeneratorSourcePath = [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"QLCARFiles.qlgenerator"];
            [self.class excuteShellScript:[NSString stringWithFormat:@"xattr -c -r %@;cp -r %@ %@;qlmanage -r;", qlgeneratorSourcePath.xm_shellPath, qlgeneratorSourcePath.xm_shellPath, destPath.xm_shellPath]];
            informativeText = @"Install QLCARFiles successfully, if QuickLook plugins not woking, you can try to log out macOS, then log in back.";
        }
        
        [[NSAlert xm_alertWithMessageText:@"macOS Quick Look Plugin" informativeText:informativeText defaultButton:nil] beginSheetModalForWindow:self.view.window completionHandler:nil];
        
    } else if (sender.tag == 2000) {
        [self checkForUpdates:YES];
    } else if (sender.tag == 9001) {
        [[NSApplication sharedApplication].delegate performSelector:NSSelectorFromString(@"showAboutWindow:") withObject:nil];
    }
    
    
}

#pragma mark - Private Method
+ (NSString *)QuickLookpluginInstallLocation {
    NSString *location = [@"~/Library/QuickLook/QLCARFiles.qlgenerator" stringByExpandingTildeInPath];
    return location;
}

+ (void)excuteShellScript:(NSString *)script
{
    // 初始化并设置shell路径
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath: @"/bin/bash"];
    // -c 用来执行string-commands（命令字符串），也就说不管后面的字符串里是什么都会被当做shellcode来执行
    NSArray *arguments = [NSArray arrayWithObjects: @"-c", script, nil];
    [task setArguments: arguments];
    
    // 新建输出管道作为Task的输出
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    
    // 开始task
    NSFileHandle *file = [pipe fileHandleForReading];
    [task launch];
    
    // 获取运行结果
    NSData *data = [file readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    
    XMLog(@"%@", output);
}

#pragma mark - Public Method

- (void)checkForUpdates:(BOOL)manualCheck {
    [[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:@"https://raw.githubusercontent.com/devcxm/iOS-Images-Extractor/pages/appfiles/appinfos.json"] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (!error && data) {
            NSDictionary *JSONObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([JSONObject isKindOfClass:[NSDictionary class]] && JSONObject.count > 3) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *appVersion = [[NSBundle mainBundle].infoDictionary objectForKey:@"CFBundleShortVersionString"];
                    NSString *latestVersion = [JSONObject objectForKey:@"version"];
                    
                    if ([appVersion compare:latestVersion options:NSNumericSearch] == NSOrderedAscending) {
                        NSAlert *updateAlert = [[NSAlert alloc] init];
                        updateAlert.messageText = @"New Update Available";
                        updateAlert.informativeText = [JSONObject objectForKey:@"changelog"];
                        [updateAlert addButtonWithTitle:@"Download"];
                        [updateAlert addButtonWithTitle:@"Close"];
                        __weak typeof(updateAlert) weakAlert = updateAlert;
                        [updateAlert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
                            if (weakAlert.buttons.firstObject.tag == returnCode) {
                                [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[JSONObject objectForKey:@"app_update_url"]]];
                            }
                        }];
                        
                    } else {
                        if (manualCheck) {
                            [[NSAlert xm_alertWithMessageText:@"Update" informativeText:@"No update available." defaultButton:nil] beginSheetModalForWindow:self.view.window completionHandler:nil];
                        }
                    }
                });
                
            }
        } else {
            if (manualCheck) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSAlert xm_alertWithMessageText:@"Update" informativeText:@"Failed to check for updates." defaultButton:nil] beginSheetModalForWindow:self.view.window completionHandler:nil];
                });
            }
            
        }
    }] resume];
}

#pragma mark - XMDragViewDelegate

/**
 *  处理拖拽文件代理
 */
- (void)dragView:(XMDragView *)dragView didDragItems:(NSArray *)items
{
    [self addPathsWithArray:items];
    [self.tableView reloadData];
}

/**
 *  添加拖拽进来的文件
 */
- (void)addPathsWithArray:(NSArray*)path
{
    
    if (self.needClearDragList) {
        [self.dragFileList removeAllObjects];
        self.needClearDragList = NO;
    }
    
    for (NSString *addItem in path) {
        
        XMFileItem *fileItem = [XMFileItem xmFileItemWithPath:addItem];

        // 过滤不支持的文件格式
        if (!fileItem.isDirectory) {
            BOOL isExpectExtension = NO;
            NSString *pathExtension = [addItem pathExtension];
            for (NSString *item in self.extensionList) {
                if ([item isEqualToString:pathExtension]) {
                    isExpectExtension = YES;
                    break;
                }
            }
            
            if (!isExpectExtension) {
                continue;
            }
        }
        
        // 过滤已经存在的路径
        BOOL isExist = NO;
        for (XMFileItem *dataItem in self.dragFileList) {
            if ([dataItem.filePath isEqualToString:addItem]) {
                isExist = YES;
                break;
            }
        }
        if (!isExist) {
            [self.dragFileList addObject:fileItem];
        }
    }
    
    if (self.dragFileList.count > 0) {
        [self setStatusString:@"Ready to start."];
    }
    else {
        [self setStatusString:@""];
    }
    
}

#pragma mark - Extract Methods

/**
 *  遍历获取拖进来的所有的文件
 */
- (void)getAllFilesFromDragPaths{
    
    [self.allFileList removeAllObjects];
    
    for (int i = 0; i < self.dragFileList.count; ++i) {
        XMFileItem *fileItem = self.dragFileList[i];
        
        if (fileItem.isDirectory) {
            NSArray *tList = [MainViewController getFileListWithPath:fileItem.filePath extensions:self.extensionList];
            [self.allFileList addObjectsFromArray:tList];
        }
        else {
            [self.allFileList addObject:fileItem];
        }
    }
    
}



/**
 *  获取当前操作的输出目录
 */
- (NSString *)currentOutputPath
{
    if (_currentOutputPath == nil) {
        
        NSDateFormatter *fm = [[NSDateFormatter alloc]init];
        fm.dateFormat = @"HH-mm-ss";
        _currentOutputPath = [self.destFolder stringByAppendingPathComponent:[fm stringFromDate:[NSDate date]]];
        
        [MainViewController createDirectoryWithPath:_currentOutputPath];
    }
    
    return _currentOutputPath;
}

/**
 *  处理ipa文件
 */
- (void)doIpaFile
{

    // 过滤获取ipa文件路径
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF.filePath.pathExtension == 'ipa'"];
    NSArray *ipaArray = [self.allFileList filteredArrayUsingPredicate:pred];
    
    
    for (XMFileItem *item in ipaArray) {
        
        // 使用ZipArchive解压https://github.com/mattconnolly/ZipArchive
        // 先解压到临时文件夹
        NSString *outputPath = [self.currentOutputPath stringByAppendingPathComponent:[item.fileName stringByReplacingOccurrencesOfString:@"." withString:@"_"]];
        NSString *unzipPath = [outputPath stringByAppendingPathComponent:@"tmp"];
        ZipArchive *zipArc = [[ZipArchive alloc]init];
        [zipArc UnzipOpenFile:item.filePath];
        
        [self setStatusString:[NSString stringWithFormat:@"Unpacking %@ ...", item.fileName]];
        
        [zipArc UnzipFileTo:unzipPath overWrite:YES];
        zipArc = nil;
        
        // 处理解压的文件
        [self doZipFilesWithPath:unzipPath outputPath:outputPath];
        
        // 删除临时文件夹
        [[NSFileManager defaultManager]removeItemAtPath:unzipPath error:nil];
        
    }

}

/**
 *  处理解压的文件
 *
 *  @param path       输出路径
 *  @param outputPath 输出路径
 */
- (void)doZipFilesWithPath:(NSString*)path outputPath:(NSString*)outputPath
{
    NSArray *zipFileList = [MainViewController getFileListWithPath:path extensions:@[@"png", @"jpg", @"car"]];
    
    NSMutableArray *carArrayM = [NSMutableArray array];
    for (int i = 0; i < zipFileList.count; ++i) {// 先将car文件加入数组,后面开启新进程处理
        XMFileItem *fileItem = zipFileList[i];
        
        NSString *pathExtension = [fileItem.filePath pathExtension];
        if ([pathExtension isEqualToString:@"car"]) {
            [carArrayM addObject:fileItem];
        }
        else {// 处理png,jpg
            [self setStatusString:[NSString stringWithFormat:@"Processing %@ ...", fileItem.fileName]];
            [self doPngOrJpgFileWithPath:fileItem.filePath outputPath:outputPath];
        }
    }
    
    
    for (int i = 0; i < carArrayM.count; ++i) {// 处理car文件
         XMFileItem *fileItem = carArrayM[i];
//        [self setStatusString:[NSString stringWithFormat:@"Processing %@ ...", fileItem.fileName]];
        NSString *tag = nil;
        // ipa安装包不只1个car文件时，放在不同的文件夹
        if (carArrayM.count > 1) {
            NSString *filePath = fileItem.filePath;
            if ([[filePath stringByDeletingLastPathComponent].pathExtension isEqualToString:@"app"]) {
                tag = @"AppRoot";
            }
        }
        
        [self exportCarFileAtPath:fileItem.filePath outputPath:[outputPath stringByAppendingPathComponent:@"car_images"] tag:tag];
    }
    
}

/**
 *  处理png或者jpg文件
 *
 *  @param path       文件路径
 *  @param outputPath 保存路径
 */
- (void)doPngOrJpgFileWithPath:(NSString*)path outputPath:(NSString*)outputPath
{
    NSImage *tmpImage = [[NSImage alloc]initWithContentsOfFile:path];
    
    if (tmpImage == nil) {
        return;
    }
    
    NSString *extension = [path pathExtension];
    NSData *saveData = nil;
    
    if ([extension isEqualToString:@"png"]) {
        saveData = [self imageDataWithImage:tmpImage bitmapImageFileType:NSBitmapImageFileTypePNG];
    }
    else if ([extension isEqualToString:@"jpg"]){
        saveData = [self imageDataWithImage:tmpImage bitmapImageFileType:NSBitmapImageFileTypeJPEG];
    }
    
    // 写入新文件
    if (saveData) {
        outputPath = [outputPath stringByAppendingPathComponent:[path lastPathComponent]];
        [saveData writeToFile:outputPath atomically:YES];
    }
    

}


/**
 *  将NSImage对象转换成png,jpg...NSData
 *  http://stackoverflow.com/questions/29262624/nsimage-to-nsdata-as-png-swift
 */
- (NSData*)imageDataWithImage:(NSImage*)image bitmapImageFileType:(NSBitmapImageFileType)fileType
{
    NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
    return [rep representationUsingType:fileType properties:@{}];
}

/**
 *  用CARExtractor程序处理Assets.car文件
 *
 *  @param path       Assets.car路径
 *  @param outputPath 保存路径
 */
- (void)exportCarFileAtPath:(NSString*)path outputPath:(NSString*)outputPath tag:(NSString *)tag {
    // 判断CARExtractor处理程序是否存在
    if (self.carExtractorLocation.length < 1) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [[NSAlert xm_alertWithMessageText:@"Error" informativeText:@"Can't find CARExtractor." defaultButton:nil] beginSheetModalForWindow:self.view.window completionHandler:nil];
        });
        
        return;
    }
    
    if (tag.length == 0) {
        NSString *bundleName = [path stringByDeletingLastPathComponent].lastPathComponent;
        if ([bundleName.pathExtension caseInsensitiveCompare:@"bundle"] == NSOrderedSame) {
            tag = [bundleName stringByReplacingOccurrencesOfString:@"." withString:@"_"];
        }
    }
    
    if (tag.length > 0) {
        outputPath = [outputPath stringByAppendingPathComponent:tag];
    }
    
    
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:self.carExtractorLocation];
    
    NSArray *arguments = @[path, outputPath, [NSString stringWithFormat:@"--DistributedNotificationName=%@", [NSBundle mainBundle].bundleIdentifier]];
    [task setArguments:arguments];
    
    
    [task launch];
    [task waitUntilExit];
}


/**
 *  遍历路径下特定扩展名的文件
 *
 *  @param path           遍历路径
 *  @param extensionArray 包含的扩展名
 */
+ (NSArray*)getFileListWithPath:(NSString*)path extensions:(NSArray*)extensionArray
{
    
    NSMutableArray *retArrayM = [NSMutableArray array];
    
    NSArray *contentOfFolder = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL];
    for (NSString *aPath in contentOfFolder) {
        NSString * fullPath = [path stringByAppendingPathComponent:aPath];
        BOOL isDir = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir])
        {
            if (isDir == YES) {
                [retArrayM addObjectsFromArray:[MainViewController getFileListWithPath:fullPath extensions:extensionArray]];
            }
            else {
                BOOL isExpectExtension = NO;
                NSString *pathExtension = [fullPath pathExtension];
                for (NSString *item in extensionArray) {
                    if ([item isEqualToString:pathExtension]) {
                        isExpectExtension = YES;
                        break;
                    }
                }
                
                if (isExpectExtension) {
                    [retArrayM addObject:[XMFileItem xmFileItemWithPath:fullPath]];
                }
            }
        }
    }
    
    return [retArrayM copy];
}

/**
 *  创建文件夹路径
 *
 *  @param path 目录路径
 */
+ (void)createDirectoryWithPath:(NSString*)path
{
    
    if ([[NSFileManager defaultManager]fileExistsAtPath:path isDirectory:nil]) {
        return;
    }
    
    NSError *err = nil;
    [[NSFileManager defaultManager]createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&err];
    
    
    if (err) {
        XMLog(@"come here %@ ...", err.localizedDescription);
    }
}


/**
 *  获取随机字符串
 *
 */
+ (NSString*)getRandomStringWithCount:(NSInteger)count
{
    NSMutableString *strM = [NSMutableString string];
    
    for (int i = 0; i < count; ++i) {
        [strM appendFormat:@"%c", 'A' + arc4random_uniform(26)];
    }
    
    
    return [strM copy];
}


#pragma mark - Table View Data Source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    
    // how many rows do we have here?
    return self.dragFileList.count;
}

//- (NSView *)tableView:(NSTableView *)tableView
//   viewForTableColumn:(NSTableColumn *)tableColumn
//                  row:(NSInteger)row {
//
//    // Retrieve to get the @"MyView" from the pool or,
//    // if no version is available in the pool, load the Interface Builder version
//    NSTableCellView *result = [tableView makeViewWithIdentifier:@"MyView" owner:self];
//
//    // Set the stringValue of the cell's text field to the nameArray value at row
//    result.textField.stringValue = [self.numberCodes objectAtIndex:row];
//
//    // Return the result
//    return result;
//}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    
    // populate each row of our table view with data
    // display a different value depending on each column (as identified in XIB)
    
    
    XMFileItem *fileItem = self.dragFileList[row];
    
    if ([tableColumn.identifier isEqualToString:@"name"]) {
        
        // first colum (numbers)
        return fileItem.fileName;
        
    } else {
        
        // second column (numberCodes)
        return fileItem.filePath;
    }
}



#pragma mark - Lazy Initializers

- (NSString *)destFolder
{
    if (_destFolder == nil) {
        NSString *dlPath = [NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES) firstObject];
        NSDateFormatter *fm = [[NSDateFormatter alloc]init];
        fm.dateFormat = @"yyyy-MM-dd";
        NSString *cmp = [NSString stringWithFormat:@"iOSImagesExtractor/%@", [fm stringFromDate:[NSDate date]]];
        _destFolder = [dlPath stringByAppendingPathComponent:cmp];
        
        if (![[NSFileManager defaultManager]fileExistsAtPath:_destFolder isDirectory:nil]) {
            [MainViewController createDirectoryWithPath:_destFolder];
        }
    }
    
    return _destFolder;
}

- (NSMutableArray *)dragFileList
{
    if (_dragFileList == nil) {
        _dragFileList = [NSMutableArray array];
    }
    
    return _dragFileList;
}

- (NSMutableArray *)allFileList
{
    if (_allFileList == nil) {
        _allFileList = [NSMutableArray array];
    }
    
    return _allFileList;
}

@end
