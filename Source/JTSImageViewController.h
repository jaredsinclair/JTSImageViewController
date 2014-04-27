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

extern CGFloat const JTSImageViewController_DefaultAlphaForBackgroundDimmingOverlay;
extern CGFloat const JTSImageViewController_DefaultBackgroundBlurRadius;

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

/**
 Changes to this property must be made before showFromViewController:transition: is called, 
 or else they will have no effect.
 
 Defaults to `JTSImageViewController_DefaultAlphaForBackgroundDimmingOverlay`.
 */
@property (assign, nonatomic, readwrite) CGFloat alphaForBackgroundDimmingOverlay;

/**
 Used with a JTSImageViewControllerBackgroundStyle_ScaledDimmedBlurred background style.
 
 Changes to this property must be made before showFromViewController:transition: is called,
 or else they will have no effect.
 
 Defaults to `JTSImageViewController_DefaultBackgroundBlurRadius`.
 */
@property (assign, nonatomic, readwrite) CGFloat backgroundBlurRadius;

/**
 Designated initializer.
 
 @param imageInfo The source info for image and transition metadata. Required.
 
 @param mode The mode to be used. (JTSImageViewController has an alternate alt text mode). Required.
 
 @param backgroundStyle Currently, either scaled-and-dimmed, or scaled-dimmed-and-blurred. The latter is like Tweetbot 3.0's background style.
 */
- (instancetype)initWithImageInfo:(JTSImageInfo *)imageInfo
                             mode:(JTSImageViewControllerMode)mode
                  backgroundStyle:(JTSImageViewControllerBackgroundStyle)backgroundStyle;

/**
 JTSImageViewController is presented from viewController as a UIKit modal view controller.
 
 It's first presented as a full-screen modal *without* animation. At this stage the view controller
 is merely displaying a snapshot of viewController's topmost parentViewController's view.
 
 Next, there is an animated transition to a full-screen image viewer.
 */
- (void)showFromViewController:(UIViewController *)viewController
                    transition:(JTSImageViewControllerTransition)transition;

/**
 Dismisses the image viewer. Must not be called while previous presentation or dismissal is still in flight.
 */
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



