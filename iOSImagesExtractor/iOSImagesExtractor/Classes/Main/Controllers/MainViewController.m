//
//  MainViewController.m
//  iOSImagesExtractor
//
//  Created by chi on 15-5-27.
//  Copyright (c) 2015年 chi. All rights reserved.
//

#import "MainViewController.h"

#pragma mark - libs
#import "ZipArchive.h"


#pragma mark - models
#import "XMFileItem.h"

#pragma mark - views
#import "XMDragView.h"


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


#pragma mark - life cycel

- (void)awakeFromNib
{
    self.dragView.delegate = self;

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
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.statusLabel setStringValue:stauts];
    });
}





#pragma mark - event response

/**
 *  响应按钮点击
 *
 *  @param sender <#sender description#>
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
            NSAlert *alert = [NSAlert alertWithMessageText:@"No Output" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"There is no output."];
            [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
        }
        

    }
    else if (sender.tag == 400) {// About
        
        [[NSApplication sharedApplication].delegate performSelector:NSSelectorFromString(@"showAboutWindow:") withObject:nil];
    }
    else if (sender.tag == 200) {// Start
        
        if (self.dragFileList.count < 1) {
            NSAlert *alert = [NSAlert alertWithMessageText:@"Error" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Drag files into window first."];
            [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
            
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
                    
                    NSString *outputPath = [existCarPath stringByAppendingPathComponent:[NSString stringWithFormat:@"car_images_%@", [MainViewController getRandomStringWithCount:5]
                                                                                         ]];
                    [self setStatusString:[NSString stringWithFormat:@"Processing %@ ...", fileItem.fileName]];
                    [self doCarFilesWithPath:fileItem.filePath outputPath:outputPath];
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

#pragma mark - business

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
        [self setStatusString:[NSString stringWithFormat:@"Processing %@ ...", fileItem.fileName]];
        [self doCarFilesWithPath:fileItem.filePath outputPath:[outputPath stringByAppendingPathComponent:@"car_images"]];
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
        saveData = [self imageDataWithImage:tmpImage bitmapImageFileType:NSPNGFileType];
    }
    else if ([extension isEqualToString:@"jpg"]){
        saveData = [self imageDataWithImage:tmpImage bitmapImageFileType:NSJPEGFileType];
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
    return [rep representationUsingType:fileType properties:nil];
}

/**
 *  用CARExtractor程序处理Assets.car文件
 *
 *  @param path       Assets.car路径
 *  @param outputPath 保存路径
 */
- (void)doCarFilesWithPath:(NSString*)path outputPath:(NSString*)outputPath
{
    
    // 判断CARExtractor处理程序是否存在
    if (self.carExtractorLocation.length < 1) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            NSAlert *alert = [NSAlert alertWithMessageText:@"Error" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Can't find CARExtractor"];
            [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
        });
        
        return;
    }
    
    // 以下源代码来自https://github.com/Marxon13/iOS-Asset-Extractor
    
    //Create the task to run the process
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:self.carExtractorLocation];
    
    NSArray *arguments = @[@"-i", path, @"-o", outputPath];
    [task setArguments:arguments];
    
    //Handle output
    NSPipe *pipe = [[NSPipe alloc] init];
    task.standardOutput = pipe;
    
    [pipe.fileHandleForReading waitForDataInBackgroundAndNotify];
    [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleDataAvailableNotification object:[pipe fileHandleForReading] queue:nil usingBlock:^(NSNotification *notification){
//        NSData *output = [[pipe fileHandleForReading] availableData];
//        NSString *outString = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
//        XMLog(@"ddddddddd%@", outString);
//        if (outputPath.length > 0) {
//            [self setStatusString:outString];
//        }
        
        [[pipe fileHandleForReading] waitForDataInBackgroundAndNotify];
    }];
    
    //Run the task
    [task launch];
    [task waitUntilExit];
    
    [[NSNotificationCenter defaultCenter] removeObserver:nil name:NSFileHandleDataAvailableNotification object:[pipe fileHandleForReading]];
    
}



/**
 *  遍历路径下特定扩展名的文件
 *
 *  @param path           遍历路径
 *  @param extensionArray 包含的扩展名
 *
 *  @return <#return value description#>
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
        XMLog(@"come here <#identifier#> %@ ...", err.localizedDescription);
    }
}


/**
 *  获取随机字符串
 *
 *  @param count <#count description#>
 *
 *  @return <#return value description#>
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
