//
//  DCOTransparentScrollView.m
//  Tapetrap
//
//  Created by Boy van Amstel on 06-01-14.
//  Copyright (c) 2014 Danger Cove. All rights reserved.
//

#import "DCOTransparentScrollView.h"

@implementation DCOTransparentScrollView

#pragma mark - Overrides

- (void)tile {
    [super tile];
    [[self contentView] setFrame:[self bounds]];
}

@end
