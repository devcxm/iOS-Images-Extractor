//
//  AppDelegate.m
//  iOSImagesExtractor
//
//  Created by chi on 15-5-27.
//  Copyright (c) 2015年 chi. All rights reserved.
//

#import "AppDelegate.h"


#pragma mark - libs
#import "DCOAboutWindowController.h"

#import "MainViewController.h"


@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;



@property (nonatomic, strong) MainViewController *mainVc;

/** The window controller that handles the about window. */
@property (nonatomic, strong) DCOAboutWindowController *aboutWindowController;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    
    self.mainVc = [[MainViewController alloc]initWithNibName:@"MainViewController" bundle:nil];
    
    [self.window.contentView addSubview:self.mainVc.view];
    
    // AutoLayout
    NSView *selfView = self.mainVc.view;
    selfView.translatesAutoresizingMaskIntoConstraints = NO;
    NSDictionary *views = NSDictionaryOfVariableBindings(selfView);
    NSArray *consH = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0.0-[selfView]-0.0-|" options:0 metrics:nil views:views];
    [selfView.superview addConstraints:consH];
    
    NSArray *consV = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0.0-[selfView]-0.0-|" options:0 metrics:nil views:views];
    [selfView.superview addConstraints:consV];
    
    
    
}

- (IBAction)showAboutWindow:(id)sender {
    
    // https://github.com/DangerCove/DCOAboutWindow
    // Set about window values (override defaults)
    self.aboutWindowController.appWebsiteURL = [NSURL URLWithString:@"https://github.com/devcxm/iOS-Images-Extractor"];
    
    // Show the about window
    [self.aboutWindowController showWindow:nil];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

#pragma mark - Lazy Initializers

- (DCOAboutWindowController *)aboutWindowController {
    if(!_aboutWindowController) {
        _aboutWindowController = [[DCOAboutWindowController alloc] init];
    }
    return _aboutWindowController;
}


#pragma mark - Resizable

- (BOOL)isResizable {
    return self.aboutWindowController.window.styleMask & NSResizableWindowMask;
}

- (void)setResizable:(BOOL)resizable {
    
    if(self.isResizable) {
        self.aboutWindowController.window.styleMask &= ~NSResizableWindowMask;
    } else {
        self.aboutWindowController.window.styleMask |= NSResizableWindowMask;
    }
}

//- (void)setUseTextView:(BOOL)useTextView {
//    
//    _useTextView = useTextView;
//    self.aboutWindowController.useTextViewForAcknowledgments = useTextView;
//}

@end
