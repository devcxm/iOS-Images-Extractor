//
//  DCOAboutWindowController.m
//  Tapetrap
//
//  Created by Boy van Amstel on 20-01-14.
//  Copyright (c) 2014 Danger Cove. All rights reserved.
//

#import "DCOAboutWindowController.h"

@interface DCOAboutWindowController()

/** The window nib to load. */
+ (NSString *)nibName;

/** The place holder view. */
@property (assign) IBOutlet NSView *placeHolderView;

/** The info view. */
@property (assign) IBOutlet NSView *infoView;

/** The acknowledgments view. */
@property (assign) IBOutlet NSView *acknowledgmentsView;

/** The credits text view. */
@property (assign) IBOutlet NSTextView *creditsTextView;

/** The acknowledgments text view. */
@property (assign) IBOutlet NSTextView *acknowledgmentsTextView;

/** The button that opens the app's website. */
@property (assign) IBOutlet NSButton *visitWebsiteButton;

/** The button that opens the acknowledgments. */
@property (assign) IBOutlet NSButton *acknowledgmentsButton;

/** The view that's currently active. */
@property (assign) NSView *activeView;

/** The string to hold the acknowledgments if we're showing them in same window. */
@property (copy) NSAttributedString *acknowledgmentsString;

@end

@implementation DCOAboutWindowController

#pragma mark - Class Methods

+ (NSString *)nibName {
    return @"DCOAboutWindow";
}

#pragma mark - Overrides

- (id)init {
    return [super initWithWindowNibName:[[self class] nibName]];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Load variables
    NSDictionary *bundleDict = [[NSBundle mainBundle] infoDictionary];
    
    // Set app name
    if(!self.appName) {
        self.appName = [bundleDict objectForKey:@"CFBundleName"];
    }
    
    // Set app version
    if(!self.appVersion) {
        NSString *version = [bundleDict objectForKey:@"CFBundleVersion"];
        NSString *shortVersion = [bundleDict objectForKey:@"CFBundleShortVersionString"];
        self.appVersion = [NSString stringWithFormat:NSLocalizedString(@"Version %@ (Build %@)", @"Version %@ (Build %@), displayed in the about window"), shortVersion, version];
    }
    
    // Set copyright
    if(!self.appCopyright) {
        self.appCopyright = [bundleDict objectForKey:@"NSHumanReadableCopyright"];
    }
    
    // Set "visit website" caption
    self.visitWebsiteButton.title = [NSString stringWithFormat:NSLocalizedString(@"Visit the %@ Website", @"Caption on the 'Visit the %@ Website' button in the about window"), self.appName];
    // Set the "acknowledgments" caption
    self.acknowledgmentsButton.title = NSLocalizedString(@"Acknowledgments", @"Caption of the 'Acknowledgments' button in the about window");
    
    // Set acknowledgments
    if(!self.acknowledgmentsPath) {
        self.acknowledgmentsPath = [[NSBundle mainBundle] pathForResource:@"Acknowledgments" ofType:@"rtf"];
    }
    
    // Set credits
    if(!self.appCredits) {
        NSString *creditsPath = [[NSBundle mainBundle] pathForResource:@"Credits" ofType:@"rtf"];
        self.appCredits = [[NSAttributedString alloc] initWithPath:creditsPath documentAttributes:nil];
    }
    
    // Disable editing
    [self.creditsTextView setEditable:NO]; // Somehow IB checkboxes are not working
    [self.acknowledgmentsTextView setEditable:NO]; // Somehow IB checkboxes are not working
}

- (void)showWindow:(id)sender {
    [super showWindow:sender];
    
    // Show infoView per default
    [self showView:self.infoView];
}

#pragma mark - Getters/Setters

- (void)setAcknowledgmentsPath:(NSString *)acknowledgmentsPath {
    _acknowledgmentsPath = acknowledgmentsPath;
    
    if(acknowledgmentsPath) {
        
        // Set acknowledgments
        self.acknowledgmentsString = [[NSAttributedString alloc] initWithPath:acknowledgmentsPath documentAttributes:nil];
        
    } else {
    
        // Remove the button (and constraints)
        [self.acknowledgmentsButton removeFromSuperview];
        
    }
}

#pragma mark - Interface Methods

- (IBAction)visitWebsite:(id)sender {
    
    if(self.appWebsiteURL) {
        [[NSWorkspace sharedWorkspace] openURL:self.appWebsiteURL];
    } else {
        NSLog(@"Error: please set the appWebsiteURL property on the about window");
    }
}

- (IBAction)showAcknowledgments:(id)sender {
    
    if(self.useTextViewForAcknowledgments) {

        // Toggle between the infoView and the acknowledgmentsView
        if([self.activeView isEqualTo:self.infoView]) {
            
            [self showView:self.acknowledgmentsView];
            self.acknowledgmentsButton.title = NSLocalizedString(@"Credits", nil);
            
        } else {
            
            [self showView:self.infoView];
            self.acknowledgmentsButton.title = NSLocalizedString(@"Acknowledgments", nil);
        }

    } else {

        if(self.acknowledgmentsPath) {
            
            // Load in default editor
            [[NSWorkspace sharedWorkspace] openFile:self.acknowledgmentsPath];
            
        } else {
            NSLog(@"Error: couldn't load the acknowledgments file");
        }
    }
}

#pragma mark - Private Methods

- (void)showView:(NSView*)theView {
    
    // Exit early if the view is the same
    if([theView isEqualTo:self.activeView]) {
        return;
    }
    
    // Remove the active view from the place holder
    if(self.activeView) {
        [self.activeView removeFromSuperview];
    }
    
    // Resize view to fit
    theView.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
    theView.frame = self.placeHolderView.bounds;
    
    // Add to placeholder
    [self.placeHolderView addSubview:theView];

    // Enable layer backing and change the background color
    theView.wantsLayer = YES;
    theView.layer.backgroundColor = [NSColor whiteColor].CGColor;
    
    // Add bottom border
    CALayer *bottomBorder = [CALayer layer];
    bottomBorder.borderColor = [NSColor grayColor].CGColor;
    bottomBorder.borderWidth = 1;
    bottomBorder.frame = CGRectMake(-1.f, .0f, CGRectGetWidth(theView.frame) + 2.f, CGRectGetHeight(theView.frame) + 1.f);
    bottomBorder.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
    [theView.layer addSublayer:bottomBorder];
    
    // Set active view
    self.activeView = theView;
}

@end
