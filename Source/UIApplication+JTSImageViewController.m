//
//  UIApplication+JTSImageViewController.m
//  Riposte
//
//  Created by Jared on 4/3/14.
//  Copyright (c) 2014 Riposte LLC. All rights reserved.
//

#import "UIApplication+JTSImageViewController.h"

@implementation UIApplication (JTSImageViewController)

- (BOOL)jts_usesViewControllerBasedStatusBarAppearance {
    static dispatch_once_t once;
    static BOOL viewControllerBased;
    dispatch_once(&once, ^ {
        NSString *key = @"UIViewControllerBasedStatusBarAppearance";
        id object = [[NSBundle mainBundle] objectForInfoDictionaryKey:key];
        if (!object) {
            viewControllerBased = YES;
        } else {
            viewControllerBased = [object boolValue];
        }
    });
    return viewControllerBased;
}

- (void)jts_updateStatusBarAppearanceHidden:(BOOL)hidden animation:(UIStatusBarAnimation)animation fromViewController:(UIViewController *)sender {
    if ([self jts_usesViewControllerBasedStatusBarAppearance]) {
        [sender setNeedsStatusBarAppearanceUpdate];
    } else {
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_9_0
        [[UIApplication sharedApplication] setStatusBarHidden:hidden withAnimation:animation];
#else
        NSLog(@"setStatusBarHidden:withAnimation: is deprecated. Please use view-controller-based status bar appearance.");
#endif
    }
}

@end
