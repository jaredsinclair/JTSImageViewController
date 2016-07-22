//
//  UIApplication+JTSImageViewController.h
//  Riposte
//
//  Created by Jared on 4/3/14.
//  Copyright (c) 2014 Riposte LLC. All rights reserved.
//

@import UIKit;

@interface UIApplication (JTSImageViewController)

- (BOOL)jts_usesViewControllerBasedStatusBarAppearance;

/**
 *   Updates the status bar appearance.
 *
 *   @param hidden The parameter will only be used if the app does not use
 *   controller-based status bar appearance. Else the sender will be asked
 *   by the system.
 *
 *   @param animation The animation that will be used for non-controller-
 *   based appearance updates.
 *
 *   @param sender If the app uses controller-based status bar appearance,
 *   this method will call setNeedsStatusBarAppearanceUpdate on the sender.
 *
 *   @note This method will ignore status bar updates if the app does not
 *   use controller-based status bar appearance while the deployment
 *   target is set to iOS 9 or later to prevent deprecation warnings.
 */
- (void)jts_updateStatusBarAppearanceHidden:(BOOL)hidden animation:(UIStatusBarAnimation)animation fromViewController:(UIViewController *)sender;

@end
