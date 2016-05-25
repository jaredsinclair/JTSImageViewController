//
//  JTSImageViewController.h
//
//
//  Created by Jared Sinclair on 3/28/14.
//  Copyright (c) 2014 Nice Boy LLC. All rights reserved.
//

@import UIKit;

#import "JTSImageInfo.h"

///--------------------------------------------------------------------------------------------------------------------
/// Definitions
///--------------------------------------------------------------------------------------------------------------------

@protocol JTSImageViewControllerDismissalDelegate;
@protocol JTSImageViewControllerOptionsDelegate;
@protocol JTSImageViewControllerInteractionsDelegate;
@protocol JTSImageViewControllerAccessibilityDelegate;
@protocol JTSImageViewControllerAnimationDelegate;
@protocol JTSImageViewControllerDownloader;
@protocol JTSImageViewControllerDownloaderDelegate;

typedef NS_ENUM(NSInteger, JTSImageViewControllerMode) {
    JTSImageViewControllerMode_Image,
    JTSImageViewControllerMode_AltText,
};

typedef NS_ENUM(NSInteger, JTSImageViewControllerTransition) {
    JTSImageViewControllerTransition_FromOriginalPosition,
    JTSImageViewControllerTransition_FromOffscreen,
};

typedef NS_OPTIONS(NSInteger, JTSImageViewControllerBackgroundOptions) {
    JTSImageViewControllerBackgroundOption_None = 0,
    JTSImageViewControllerBackgroundOption_Scaled = 1 << 0,
    JTSImageViewControllerBackgroundOption_Blurred = 1 << 1,
};

extern CGFloat const JTSImageViewController_DefaultAlphaForBackgroundDimmingOverlay;
extern CGFloat const JTSImageViewController_DefaultBackgroundBlurRadius;

///--------------------------------------------------------------------------------------------------------------------
/// JTSImageViewController
///--------------------------------------------------------------------------------------------------------------------

@interface JTSImageViewController : UIViewController

@property (strong, nonatomic, readonly) JTSImageInfo *imageInfo;

@property (strong, nonatomic, readonly) UIImage *image;

@property (assign, nonatomic, readonly) JTSImageViewControllerMode mode;

@property (assign, nonatomic, readonly) JTSImageViewControllerBackgroundOptions backgroundOptions;

@property (weak, nonatomic, readwrite) id <JTSImageViewControllerDismissalDelegate> dismissalDelegate;

@property (weak, nonatomic, readwrite) id <JTSImageViewControllerOptionsDelegate> optionsDelegate;

@property (weak, nonatomic, readwrite) id <JTSImageViewControllerInteractionsDelegate> interactionsDelegate;

@property (weak, nonatomic, readwrite) id <JTSImageViewControllerAccessibilityDelegate> accessibilityDelegate;

@property (weak, nonatomic, readwrite) id <JTSImageViewControllerAnimationDelegate> animationDelegate;

@property (weak, nonatomic, readonly) id <JTSImageViewControllerDownloaderDelegate> downloaderDelegate;

/**
 Convenience initializer.
 
 @param imageInfo The source info for image and transition metadata. Required.
 
 @param mode The mode to be used. (JTSImageViewController has an alternate alt text mode). Required.
 
 @param backgroundStyle Currently, either scaled-and-dimmed, or scaled-dimmed-and-blurred. 
 The latter is like Tweetbot 3.0's background style.
 */
- (instancetype)initWithImageInfo:(JTSImageInfo *)imageInfo
                             mode:(JTSImageViewControllerMode)mode
                  backgroundStyle:(JTSImageViewControllerBackgroundOptions)backgroundOptions;

/**
 Designated initializer.
 
 @param imageInfo The source info for image and transition metadata. Required.
 
 @param mode The mode to be used. (JTSImageViewController has an alternate alt text mode). Required.
 
 @param backgroundStyle Currently, either scaled-and-dimmed, or scaled-dimmed-and-blurred.
 The latter is like Tweetbot 3.0's background style.
 
 @param downloaderDelegate The downloaderDelegate to be used. Optional.
 */

- (instancetype)initWithImageInfo:(JTSImageInfo *)imageInfo
                             mode:(JTSImageViewControllerMode)mode
                  backgroundStyle:(JTSImageViewControllerBackgroundOptions)backgroundOptions
               downloaderDelegate:(id <JTSImageViewControllerDownloaderDelegate>)downloaderDelegate;

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

///--------------------------------------------------------------------------------------------------------------------
/// Dismissal Delegate
///--------------------------------------------------------------------------------------------------------------------

@protocol JTSImageViewControllerDismissalDelegate <NSObject>

/**
 Called after the image viewer has finished dismissing.
 */
- (void)imageViewerDidDismiss:(JTSImageViewController *)imageViewer;

@end

///--------------------------------------------------------------------------------------------------------------------
/// Options Delegate
///--------------------------------------------------------------------------------------------------------------------

@protocol JTSImageViewControllerOptionsDelegate <NSObject>
@optional

/**
 Return YES if you want the image thumbnail to fade to/from zero during presentation
 and dismissal animations.
 
 This may be helpful if the reference image in your presenting view controller has been
 dimmed, such as for a dark mode. JTSImageViewController otherwise presents the animated 
 image view at full opacity, which can look jarring.
 */
- (BOOL)imageViewerShouldFadeThumbnailsDuringPresentationAndDismissal:(JTSImageViewController *)imageViewer;

/**
 The font used in the alt text mode's text view.
 
 This method is only used with `JTSImageViewControllerMode_AltText`.
 */
- (UIFont *)fontForAltTextInImageViewer:(JTSImageViewController *)imageViewer;

/**
 The tint color applied to tappable text and selection controls.
 
 This method is only used with `JTSImageViewControllerMode_AltText`.
 */
- (UIColor *)accentColorForAltTextInImageViewer:(JTSImageViewController *)imageView;

/**
 The background color of the image view itself, not to be confused with the background
 color for the view controller's view. 
 
 You may wish to override this method if displaying an image with dark content on an 
 otherwise clear background color (such as images from the XKCD What If? site).
 
 The default color is `[UIColor clearColor]`.
 */
- (UIColor *)backgroundColorImageViewInImageViewer:(JTSImageViewController *)imageViewer;

/**
 Defaults to `JTSImageViewController_DefaultAlphaForBackgroundDimmingOverlay`.
 */
- (CGFloat)alphaForBackgroundDimmingOverlayInImageViewer:(JTSImageViewController *)imageViewer;

/**
 Used with a JTSImageViewControllerBackgroundStyle_ScaledDimmedBlurred background style.
 
 Defaults to `JTSImageViewController_DefaultBackgroundBlurRadius`. The larger the radius,
 the more profound the blur effect. Larger radii may lead to decreased performance on
 older devices. To offset this, JTSImageViewController applies the blur effect to a
 scaled-down snapshot of the background view.
 */
- (CGFloat)backgroundBlurRadiusForImageViewer:(JTSImageViewController *)imageViewer;

@end

///--------------------------------------------------------------------------------------------------------------------
/// Interactions Delegate
///--------------------------------------------------------------------------------------------------------------------

@protocol JTSImageViewControllerInteractionsDelegate <NSObject>
@optional

/**
 Called when the image viewer detects a long press.
 */
- (void)imageViewerDidLongPress:(JTSImageViewController *)imageViewer atRect:(CGRect)rect;

/**
 Called when the image viewer is deciding whether to respond to user interactions.
 
 You may need to return NO if you are presenting custom, temporary UI on top of the image viewer. 
 This method is called more than once. Returning NO does not "lock" the image viewer.
 */
- (BOOL)imageViewerShouldTemporarilyIgnoreTouches:(JTSImageViewController *)imageViewer;

/**
 Called when the image viewer is deciding whether to display the Menu Controller, to allow the user to copy the image to the general pasteboard.
 */
- (BOOL)imageViewerAllowCopyToPasteboard:(JTSImageViewController *)imageViewer;

@end

///--------------------------------------------------------------------------------------------------------------------
/// Accessibility Delegate
///--------------------------------------------------------------------------------------------------------------------


@protocol JTSImageViewControllerAccessibilityDelegate <NSObject>
@optional

- (NSString *)accessibilityLabelForImageViewer:(JTSImageViewController *)imageViewer;

- (NSString *)accessibilityHintZoomedInForImageViewer:(JTSImageViewController *)imageViewer;

- (NSString *)accessibilityHintZoomedOutForImageViewer:(JTSImageViewController *)imageViewer;

@end

///---------------------------------------------------------------------------------------------------
/// Animation Delegate
///---------------------------------------------------------------------------------------------------

@protocol JTSImageViewControllerAnimationDelegate <NSObject>
@optional

- (void)imageViewerWillBeginPresentation:(JTSImageViewController *)imageViewer withContainerView:(UIView *)containerView;

- (void)imageViewerWillAnimatePresentation:(JTSImageViewController *)imageViewer withContainerView:(UIView *)containerView duration:(CGFloat)duration;

- (void)imageViewer:(JTSImageViewController *)imageViewer willAdjustInterfaceForZoomScale:(CGFloat)zoomScale withContainerView:(UIView *)containerView duration:(CGFloat)duration;

- (void)imageViewerWillBeginDismissal:(JTSImageViewController *)imageViewer withContainerView:(UIView *)containerView;

- (void)imageViewerWillAnimateDismissal:(JTSImageViewController *)imageViewer withContainerView:(UIView *)containerView duration:(CGFloat)duration;

@end

///---------------------------------------------------------------------------------------------------
/// Downloader
///---------------------------------------------------------------------------------------------------

@protocol JTSImageViewControllerDownloader <NSObject>

/**
 The number of bytes that are expected to be recieved.
 */
@property (readonly) int64_t countOfBytesExpectedToReceive;

/**
 The number of bytes that have been received.
 */
@property (readonly) int64_t countOfBytesReceived;

/**
 Called to begin downloading the image.
 
 Calls block with non-nil value on success, and nil on failure.
 */
- (void)downloadImage:(void (^)(UIImage *image))completion;

@optional

/**
 Called to cancel the download if it is in progress.
 */
- (void)cancel;

@end

///---------------------------------------------------------------------------------------------------
/// Downloader Delegate
///---------------------------------------------------------------------------------------------------

@protocol JTSImageViewControllerDownloaderDelegate <NSObject>

/**
 Called to retrieve a downloader for the given image information.
 */
- (id <JTSImageViewControllerDownloader>)downloaderForImageInfo:(JTSImageInfo *)imageInfo;

@end






