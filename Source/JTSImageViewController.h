//
//  JTSImageViewController.h
//
//
//  Created by Jared Sinclair on 3/28/14.
//  Copyright (c) 2014 Nice Boy LLC. All rights reserved.
//

@import UIKit;

#import "JTSImageInfo.h"

///-------------------------------------------------------------------------------
/// Definitions
///-------------------------------------------------------------------------------

@protocol JTSImageViewControllerDismissalDelegate;
@protocol JTSImageViewControllerOptionsDelegate;
@protocol JTSImageViewControllerInteractionsDelegate;

typedef NS_ENUM(NSInteger, JTSImageViewControllerMode) {
    JTSImageViewControllerMode_Image,
    JTSImageViewControllerMode_AltText,
};

typedef NS_ENUM(NSInteger, JTSImageViewControllerTransition) {
    JTSImageViewControllerTransition_FromOriginalPosition,
    JTSImageViewControllerTransition_FromOffscreen,
};

typedef NS_ENUM(NSInteger, JTSImageViewControllerBackgroundStyle) {
    JTSImageViewControllerBackgroundStyle_ScaledDimmed,
    JTSImageViewControllerBackgroundStyle_ScaledDimmedBlurred,
};

///-------------------------------------------------------------------------------
/// JTSImageViewController
///-------------------------------------------------------------------------------

@interface JTSImageViewController : UIViewController

@property (strong, nonatomic, readonly) JTSImageInfo *imageInfo;
@property (strong, nonatomic, readonly) UIImage *image;
@property (copy, nonatomic, readwrite) NSString *accessibilityLabel;
@property (copy, nonatomic, readwrite) NSString *accessibilityHintZoomedIn;
@property (copy, nonatomic, readwrite) NSString *accessibilityHintZoomedOut;
@property (weak, nonatomic, readwrite) id <JTSImageViewControllerDismissalDelegate> dismissalDelegate;
@property (weak, nonatomic, readwrite) id <JTSImageViewControllerOptionsDelegate> optionsDelegate;
@property (weak, nonatomic, readwrite) id <JTSImageViewControllerInteractionsDelegate> interactionsDelegate;

- (instancetype)initWithImageInfo:(JTSImageInfo *)imageInfo
                             mode:(JTSImageViewControllerMode)mode
                  backgroundStyle:(JTSImageViewControllerBackgroundStyle)backgroundStyle;

- (void)showFromViewController:(UIViewController *)viewController
                    transition:(JTSImageViewControllerTransition)transition;

- (void)dismiss:(BOOL)animated;

@end

///-------------------------------------------------------------------------------
/// Dismissal Delegate
///-------------------------------------------------------------------------------

@protocol JTSImageViewControllerDismissalDelegate <NSObject>

- (void)imageViewerDidDismiss:(JTSImageViewController *)imageViewer;

@end

///-------------------------------------------------------------------------------
/// Options Delegate
///-------------------------------------------------------------------------------

@protocol JTSImageViewControllerOptionsDelegate <NSObject>
@optional

- (BOOL)imageViewerShouldDimThumbnails:(JTSImageViewController *)imageViewer;

- (UIFont *)fontForAltTextInImageViewer:(JTSImageViewController *)imageViewer;

- (UIColor *)accentColorForAltTextInImageViewer:(JTSImageViewController *)imageView;

@end

///-------------------------------------------------------------------------------
/// Interactions Delegate
///-------------------------------------------------------------------------------

@protocol JTSImageViewControllerInteractionsDelegate <NSObject>
@optional

- (void)imageViewerDidLongPress:(JTSImageViewController *)imageViewer;

- (BOOL)imageViewerShouldTemporarilyIgnoreTouches:(JTSImageViewController *)imageViewer;

@end



