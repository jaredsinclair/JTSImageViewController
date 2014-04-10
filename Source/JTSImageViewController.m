//
//  JTSImageViewController.m
//
//
//  Created by Jared Sinclair on 3/28/14.
//  Copyright (c) 2014 Nice Boy LLC. All rights reserved.
//

#import "JTSImageViewController.h"

#import "JTSSimpleImageDownloader.h"
#import "UIImage+JTSImageEffects.h"
#import "UIApplication+JTSImageViewController.h"

@interface JTSImageViewController ()
<
    UIScrollViewDelegate,
    UITextViewDelegate,
    UIViewControllerTransitioningDelegate,
    UIGestureRecognizerDelegate
>

@property (strong, nonatomic, readwrite) JTSImageInfo *imageInfo;
@property (strong, nonatomic, readwrite) UIImage *image;

@property (assign, nonatomic) JTSImageViewControllerTransition transition;
@property (assign, nonatomic) JTSImageViewControllerMode mode;
@property (assign, nonatomic) JTSImageViewControllerBackgroundStyle backgroundStyle;

@property (assign, nonatomic) BOOL isAnimatingAPresentationOrDismissal;
@property (assign, nonatomic) BOOL isDismissing;
@property (assign, nonatomic) BOOL isTransitioningFromInitialModalToInteractiveState;
@property (assign, nonatomic) BOOL viewHasAppeared;
@property (assign, nonatomic) BOOL isRotating;
@property (assign, nonatomic) BOOL isPresented;
@property (assign, nonatomic) BOOL rotationTransformIsDirty;
@property (assign, nonatomic) BOOL imageIsFlickingAwayForDismissal;
@property (assign, nonatomic) BOOL isDraggingImage;
@property (assign, nonatomic) BOOL presentingViewControllerPresentedFromItsUnsupportedOrientation;
@property (assign, nonatomic) BOOL scrollViewIsAnimatingAZoom;
@property (assign, nonatomic) BOOL imageIsBeingReadFromDisk;
@property (assign, nonatomic) BOOL isManuallyResizingTheScrollViewFrame;
@property (assign, nonatomic) BOOL imageDownloadFailed;
@property (assign, nonatomic) BOOL statusBarHiddenPriorToPresentation;

@property (assign, nonatomic) CGRect startingReferenceFrameForThumbnail;
@property (assign, nonatomic) CGRect startingReferenceFrameForThumbnailInPresentingViewControllersOriginalOrientation;
@property (assign, nonatomic) CGPoint imageDragStartingPoint;
@property (assign, nonatomic) UIOffset imageDragOffsetFromActualTranslation;
@property (assign, nonatomic) UIOffset imageDragOffsetFromImageCenter;
@property (assign, nonatomic) CGAffineTransform currentSnapshotRotationTransform;

@property (assign, nonatomic) UIInterfaceOrientation startingInterfaceOrientation;
@property (assign, nonatomic) UIInterfaceOrientation lastUsedOrientation;

@property (strong, nonatomic) UIView *progressContainer;
@property (strong, nonatomic) UIView *outerContainerForScrollView;
@property (strong, nonatomic) UIView *snapshotView;
@property (strong, nonatomic) UIView *blurredSnapshotView;
@property (strong, nonatomic) UIView *blackBackdrop;
@property (strong, nonatomic) UIImageView *imageView;
@property (strong, nonatomic) UIScrollView *scrollView;
@property (strong, nonatomic) UITextView *textView;
@property (strong, nonatomic) UIProgressView *progressView;
@property (strong, nonatomic) UIActivityIndicatorView *spinner;

@property (strong, nonatomic) UITapGestureRecognizer *singleTapperPhoto;
@property (strong, nonatomic) UITapGestureRecognizer *doubleTapperPhoto;
@property (strong, nonatomic) UITapGestureRecognizer *singleTapperText;
@property (strong, nonatomic) UILongPressGestureRecognizer *longPresserPhoto;
@property (strong, nonatomic) UIPanGestureRecognizer *panRecognizer;

@property (strong, nonatomic) UIDynamicAnimator *animator;
@property (strong, nonatomic) UIAttachmentBehavior *attachmentBehavior;

@property (strong, nonatomic) NSURLSessionDataTask *imageDownloadDataTask;
@property (strong, nonatomic) NSTimer *downloadProgressTimer;

@end

#define MAX_BACK_SCALING 0.94
#define DOUBLE_TAP_TARGET_ZOOM 3.0f
#define TRANSITION_THUMBNAIL_MAX_ZOOM 1.25f
#define BLACK_BACKDROP_ALPHA_NORMAL 0.8f
#define USE_DEBUG_SLOW_ANIMATIONS 0
#define DEFAULT_TRANSITION_DURATION 0.28f
#define MINIMUM_FLICK_DISMISSAL_VELOCITY 800.0f

@implementation JTSImageViewController

#pragma mark - Public

- (instancetype)initWithImageInfo:(JTSImageInfo *)imageInfo
                             mode:(JTSImageViewControllerMode)mode
                  backgroundStyle:(JTSImageViewControllerBackgroundStyle)backgroundStyle {
    
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _imageInfo = imageInfo;
        _currentSnapshotRotationTransform = CGAffineTransformIdentity;
        _mode = mode;
        _backgroundStyle = backgroundStyle;
        _accessibilityLabel = [self defaultAccessibilityLabelForScrollView];
        _accessibilityHintZoomedIn = [self defaultAccessibilityHintForScrollView:YES];
        _accessibilityHintZoomedOut = [self defaultAccessibilityHintForScrollView:NO];
        if (_mode == JTSImageViewControllerMode_Image) {
            [self setupImageAndDownloadIfNecessary:imageInfo];
        }
    }
    return self;
}

- (void)showFromViewController:(UIViewController *)viewController
                    transition:(JTSImageViewControllerTransition)transition {
    
    [self setTransition:transition];
    
    _statusBarHiddenPriorToPresentation = [UIApplication sharedApplication].statusBarHidden;
    
    if (self.mode == JTSImageViewControllerMode_Image) {
        if (transition == JTSImageViewControllerTransition_FromOffscreen) {
            [self _showImageViewerByScalingDownFromOffscreenPositionWithViewController:viewController];
        } else {
            [self _showImageViewerByExpandingFromOriginalPositionFromViewController:viewController];
        }
    } else if (self.mode == JTSImageViewControllerMode_AltText) {
        [self _showAltTextFromViewController:viewController];
    }
}

- (void)dismiss:(BOOL)animated {
    
    if (self.isPresented == NO) {
        return;
    }
    
    [self setIsPresented:NO];
    
    if (self.mode == JTSImageViewControllerMode_AltText) {
        [self _dismissByExpandingAltTextToOffscreenPosition];
    }
    else if (self.mode == JTSImageViewControllerMode_Image) {
        
        if (self.imageIsFlickingAwayForDismissal) {
            [self _dismissByCleaningUpAfterImageWasFlickedOffscreen];
        }
        else if (self.transition == JTSImageViewControllerTransition_FromOffscreen) {
            [self _dismissByExpandingImageToOffscreenPosition];
        }
        else {
            BOOL startingRectForThumbnailIsNonZero = (CGRectEqualToRect(CGRectZero, self.startingReferenceFrameForThumbnail) == NO);
            BOOL useCollapsingThumbnailStyle = (startingRectForThumbnailIsNonZero
                                                && self.image != nil
                                                && self.transition != JTSImageViewControllerTransition_FromOffscreen);
            if (useCollapsingThumbnailStyle) {
                [self _dismissByCollapsingImageBackToOriginalPosition];
            } else {
                [self _dismissByExpandingImageToOffscreenPosition];
            }
        }
    }
}

#pragma mark - NSObject

- (void)dealloc {
    [_imageDownloadDataTask cancel];
    [self cancelProgressTimer];
}

#pragma mark - UIViewController

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (BOOL)shouldAutorotate {
    return (self.isAnimatingAPresentationOrDismissal == NO);
}

- (BOOL)prefersStatusBarHidden {
    
    if (self.isPresented || self.isTransitioningFromInitialModalToInteractiveState) {
        return YES;
    }
    
    return self.statusBarHiddenPriorToPresentation;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation {
    return UIStatusBarAnimationFade;
}

- (UIModalTransitionStyle)modalTransitionStyle {
    return UIModalTransitionStyleCrossDissolve;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (self.mode == JTSImageViewControllerMode_Image) {
        [self _viewDidLoadForImageMode];
    }
    else if (self.mode == JTSImageViewControllerMode_AltText) {
        [self _viewDidLoadForAltTextMode];
    }
}

- (void)viewDidLayoutSubviews {
    [self updateLayoutsForCurrentOrientation];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.lastUsedOrientation != self.interfaceOrientation) {
        [self setLastUsedOrientation:self.interfaceOrientation];
        [self setRotationTransformIsDirty:YES];
        [self updateLayoutsForCurrentOrientation];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self setViewHasAppeared:YES];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [self setLastUsedOrientation:toInterfaceOrientation];
    [self setRotationTransformIsDirty:YES];
    [self setIsRotating:YES];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [self cancelCurrentImageDrag:NO];
    [self updateLayoutsForCurrentOrientation];
    [self updateDimmingViewForCurrentZoomScale:NO];
    __weak JTSImageViewController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, duration * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [weakSelf setIsRotating:NO];
    });
}

#pragma mark - Setup

- (void)setupImageAndDownloadIfNecessary:(JTSImageInfo *)imageInfo {
    if (imageInfo.image) {
        [self setImage:imageInfo.image];
    }
    else {
        
        [self setImage:imageInfo.placeholderImage];
        
        BOOL fromDisk = [imageInfo.imageURL.absoluteString hasPrefix:@"file://"];
        [self setImageIsBeingReadFromDisk:fromDisk];
        
        __weak JTSImageViewController *weakSelf = self;
        NSURLSessionDataTask *task = [JTSSimpleImageDownloader downloadImageForURL:imageInfo.imageURL canonicalURL:imageInfo.canonicalImageURL completion:^(UIImage *image) {
            [weakSelf cancelProgressTimer];
            if (image) {
                if (weakSelf.isViewLoaded) {
                    [weakSelf updateInterfaceWithImage:image];
                } else {
                    [weakSelf setImage:image];
                }
            } else if (weakSelf.image == nil) {
                [weakSelf setImageDownloadFailed:YES];
                if (weakSelf.isPresented && weakSelf.isAnimatingAPresentationOrDismissal == NO) {
                    [weakSelf dismiss:YES];
                }
                // If we're still presenting, at the end of presentation,
                // we'll auto dismiss.
            }
        }];
        
        [self setImageDownloadDataTask:task];
        
        [self startProgressTimer];
    }
}

- (void)_viewDidLoadForImageMode {
    
    [self.view setBackgroundColor:[UIColor blackColor]];
    [self.view setAutoresizingMask:UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth];
    
    self.blackBackdrop = [[UIView alloc] initWithFrame:CGRectInset(self.view.bounds, -512, -512)];
    [self.blackBackdrop setBackgroundColor:[UIColor blackColor]];
    [self.blackBackdrop setAlpha:0];
    [self.view addSubview:self.blackBackdrop];
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.delegate = self;
    self.scrollView.zoomScale = 1.0f;
    self.scrollView.maximumZoomScale = 8.0f;
    self.scrollView.scrollEnabled = NO;
    self.scrollView.isAccessibilityElement = YES;
    self.scrollView.accessibilityLabel = self.accessibilityLabel;
    self.scrollView.accessibilityHint = self.accessibilityHintZoomedOut;
    [self.view addSubview:self.scrollView];
    
    self.imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    self.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.imageView.isAccessibilityElement = NO;
    self.imageView.clipsToBounds = YES;
    
    // We'll add the image view to either the scroll view
    // or the parent view, based on the transition style
    // used in the "show" method.
    // After that transition completes, the image view will be
    // added to the scroll view.
    
    [self setupImageModeGestureRecognizers];
    
    self.progressContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 128.0f, 128.0f)];
    [self.view addSubview:self.progressContainer];
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.progress = 0;
    self.progressView.tintColor = [UIColor whiteColor];
    self.progressView.trackTintColor = [UIColor darkGrayColor];
    CGRect progressFrame = self.progressView.frame;
    progressFrame.size.width = 128.0f;
    self.progressView.frame = progressFrame;
    self.progressView.center = CGPointMake(64.0f, 64.0f);
    self.progressView.alpha = 0;
    [self.progressContainer addSubview:self.progressView];
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.center = CGPointMake(64.0f, 64.0f);
    [self.spinner startAnimating];
    [self.progressContainer addSubview:self.spinner];
    [self.progressContainer setAlpha:0];
    
    self.animator = [[UIDynamicAnimator alloc] initWithReferenceView:self.scrollView];
    
    if (self.image) {
        [self updateInterfaceWithImage:self.image];
    }
}

- (void)_viewDidLoadForAltTextMode {
    
    [self.view setBackgroundColor:[UIColor blackColor]];
    [self.view setAutoresizingMask:UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth];
    
    self.blackBackdrop = [[UIView alloc] initWithFrame:CGRectInset(self.view.bounds, -512, -512)];
    [self.blackBackdrop setBackgroundColor:[UIColor blackColor]];
    [self.blackBackdrop setAlpha:0];
    [self.view addSubview:self.blackBackdrop];
    
    self.textView = [[UITextView alloc] initWithFrame:CGRectInset(self.view.bounds, 14.0f, 0)];
    self.textView.delegate = self;
    self.textView.textColor = [UIColor whiteColor];
    self.textView.backgroundColor = [UIColor clearColor];
    
    UIFont *font = nil;
    if ([self.optionsDelegate respondsToSelector:@selector(fontForAltTextInImageViewer:)]) {
        font = [self.optionsDelegate fontForAltTextInImageViewer:self];
    }
    if (font == nil) {
        font = [UIFont systemFontOfSize:21];
    }
    self.textView.font = font;
    
    self.textView.text = self.imageInfo.displayableTitleAltTextSummary;
    
    UIColor *tintColor = nil;
    if ([self.optionsDelegate respondsToSelector:@selector(accentColorForAltTextInImageViewer:)]) {
        tintColor = [self.optionsDelegate accentColorForAltTextInImageViewer:self];
    }
    if (tintColor != nil) {
        self.textView.tintColor = tintColor;
    }
    
    self.textView.textAlignment = NSTextAlignmentCenter;
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.textView.editable = NO;
    self.textView.dataDetectorTypes = UIDataDetectorTypeAll;
    [self.view addSubview:self.textView];
    
    [self setupTextViewTapGestureRecognizer];
}

- (void)setupImageModeGestureRecognizers {
    
    UITapGestureRecognizer *doubleTapper = nil;
    doubleTapper = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(imageDoubleTapped:)];
    doubleTapper.numberOfTapsRequired = 2;
    doubleTapper.delegate = self;
    self.doubleTapperPhoto = doubleTapper;
    
    UILongPressGestureRecognizer *longPresser = [[UILongPressGestureRecognizer alloc] init];
    [longPresser addTarget:self action:@selector(imageLongPressed:)];
    longPresser.delegate = self;
    self.longPresserPhoto = longPresser;
    
    UITapGestureRecognizer *singleTapper = nil;
    singleTapper = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(imageSingleTapped:)];
    [singleTapper requireGestureRecognizerToFail:doubleTapper];
    [singleTapper requireGestureRecognizerToFail:longPresser];
    singleTapper.delegate = self;
    self.singleTapperPhoto = singleTapper;
    
    UIPanGestureRecognizer *panner = [[UIPanGestureRecognizer alloc] init];
    [panner addTarget:self action:@selector(dismissingPanGestureRecognizerPanned:)];
    [panner setDelegate:self];
    [self.scrollView addGestureRecognizer:panner];
    [self setPanRecognizer:panner];
    
    [self.view addGestureRecognizer:singleTapper];
    [self.view addGestureRecognizer:doubleTapper];
    [self.view addGestureRecognizer:longPresser];
}

- (void)setupTextViewTapGestureRecognizer {
    
    UITapGestureRecognizer *singleTapper = nil;
    singleTapper = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(textViewSingleTapped:)];
    [singleTapper setDelegate:self];
    self.singleTapperText = singleTapper;
    
    [self.textView addGestureRecognizer:singleTapper];
}

#pragma mark - Presentation

- (void)_showImageViewerByExpandingFromOriginalPositionFromViewController:(UIViewController *)viewController {
    
    [self setIsAnimatingAPresentationOrDismissal:YES];
    [self.view setUserInteractionEnabled:NO];
    
    self.snapshotView = [self snapshotFromParentmostViewController:viewController];
    
    if (self.backgroundStyle == JTSImageViewControllerBackgroundStyle_ScaledDimmedBlurred) {
        self.blurredSnapshotView = [self blurredSnapshotFromParentmostViewController:viewController];
        [self.snapshotView addSubview:self.blurredSnapshotView];
        [self.blurredSnapshotView setAlpha:0];
    }
    
    [self.view insertSubview:self.snapshotView atIndex:0];
    [self setStartingInterfaceOrientation:viewController.interfaceOrientation];
    [self setLastUsedOrientation:viewController.interfaceOrientation];
    CGRect referenceFrameInWindow = [self.imageInfo.referenceView convertRect:self.imageInfo.referenceRect toView:nil];
    self.startingReferenceFrameForThumbnailInPresentingViewControllersOriginalOrientation = [self.view convertRect:referenceFrameInWindow fromView:nil];
    
    // This will be moved into the scroll view after
    // the transition finishes.
    [self.view addSubview:self.imageView];
    
    [viewController presentViewController:self animated:NO completion:^{
        
        if (self.interfaceOrientation != self.startingInterfaceOrientation) {
            [self setPresentingViewControllerPresentedFromItsUnsupportedOrientation:YES];
        }
        
        CGRect referenceFrameInMyView = [self.view convertRect:referenceFrameInWindow fromView:nil];
        [self setStartingReferenceFrameForThumbnail:referenceFrameInMyView];
        [self.imageView setFrame:referenceFrameInMyView];
        [self updateScrollViewAndImageViewForCurrentMetrics];
        
        BOOL mustRotateDuringTransition = (self.interfaceOrientation != self.startingInterfaceOrientation);
        if (mustRotateDuringTransition) {
            CGRect newStartingRect = [self.snapshotView convertRect:self.startingReferenceFrameForThumbnail toView:self.view];
            [self.imageView setFrame:newStartingRect];
            [self updateScrollViewAndImageViewForCurrentMetrics];
            self.imageView.transform = self.snapshotView.transform;
            CGPoint centerInRect = CGPointMake(self.startingReferenceFrameForThumbnail.origin.x+self.startingReferenceFrameForThumbnail.size.width/2.0f,
                                               self.startingReferenceFrameForThumbnail.origin.y+self.startingReferenceFrameForThumbnail.size.height/2.0f);
            [self.imageView setCenter:centerInRect];
        }
        
        if ([self.optionsDelegate imageViewerShouldDimThumbnails:self]) {
            [self.imageView setAlpha:0];
            [UIView animateWithDuration:0.15f animations:^{
                [self.imageView setAlpha:1];
            }];
        }
        
        CGFloat duration = DEFAULT_TRANSITION_DURATION;
        if (USE_DEBUG_SLOW_ANIMATIONS == 1) {
            duration *= 4;
        }
        
        __weak JTSImageViewController *weakSelf = self;
        
        // Have to dispatch to the next runloop,
        // or else the image view changes above won't be
        // committed prior to the animations below.
        dispatch_async(dispatch_get_main_queue(), ^{
        
            [UIView
             animateWithDuration:duration
             delay:0
             options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
             animations:^{
                 
                 [weakSelf setIsTransitioningFromInitialModalToInteractiveState:YES];
                 
                 if ([UIApplication sharedApplication].jts_usesViewControllerBasedStatusBarAppearance) {
                     [weakSelf setNeedsStatusBarAppearanceUpdate];
                 } else {
                     [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
                 }
                 
                 weakSelf.snapshotView.transform = CGAffineTransformConcat(weakSelf.snapshotView.transform,
                                                                       CGAffineTransformMakeScale(MAX_BACK_SCALING, MAX_BACK_SCALING));
                 
                 if (weakSelf.backgroundStyle == JTSImageViewControllerBackgroundStyle_ScaledDimmedBlurred) {
                     [weakSelf.blurredSnapshotView setAlpha:1];
                 }
                 
                 [weakSelf addMotionEffectsToSnapshotView];
                 [weakSelf.blackBackdrop setAlpha:BLACK_BACKDROP_ALPHA_NORMAL];
                 
                 if (mustRotateDuringTransition) {
                     [weakSelf.imageView setTransform:CGAffineTransformIdentity];
                 }
                 
                 CGRect endFrameForImageView;
                 if (weakSelf.image) {
                     endFrameForImageView = [weakSelf resizedFrameForAutorotatingImageView:weakSelf.image.size];
                 } else {
                     endFrameForImageView = [weakSelf resizedFrameForAutorotatingImageView:weakSelf.imageInfo.referenceRect.size];
                 }
                 [weakSelf.imageView setFrame:endFrameForImageView];
                 
                 CGPoint endCenterForImageView = CGPointMake(weakSelf.view.bounds.size.width/2.0f, weakSelf.view.bounds.size.height/2.0f);
                 [weakSelf.imageView setCenter:endCenterForImageView];
                 
                 if (weakSelf.image == nil) {
                     [weakSelf.progressContainer setAlpha:1.0f];
                 }
                 
             } completion:^(BOOL finished) {
                 
                 [weakSelf setIsManuallyResizingTheScrollViewFrame:YES];
                 [weakSelf.scrollView setFrame:weakSelf.view.bounds];
                 [weakSelf setIsManuallyResizingTheScrollViewFrame:NO];
                 [weakSelf.scrollView addSubview:weakSelf.imageView];
                 
                 [weakSelf setIsTransitioningFromInitialModalToInteractiveState:NO];
                 [weakSelf setIsAnimatingAPresentationOrDismissal:NO];
                 [weakSelf setIsPresented:YES];
                 
                 [weakSelf updateScrollViewAndImageViewForCurrentMetrics];
                 
                 if (weakSelf.imageDownloadFailed) {
                     [weakSelf dismiss:YES];
                 } else {
                     [weakSelf.view setUserInteractionEnabled:YES];
                 }
             }];
        });
    }];
}

- (void)_showImageViewerByScalingDownFromOffscreenPositionWithViewController:(UIViewController *)viewController {
    
    [self setIsAnimatingAPresentationOrDismissal:YES];
    [self.view setUserInteractionEnabled:NO];
    
    self.snapshotView = [self snapshotFromParentmostViewController:viewController];
    
    if (self.backgroundStyle == JTSImageViewControllerBackgroundStyle_ScaledDimmedBlurred) {
        self.blurredSnapshotView = [self blurredSnapshotFromParentmostViewController:viewController];
        [self.snapshotView addSubview:self.blurredSnapshotView];
        [self.blurredSnapshotView setAlpha:0];
    }
    
    [self.view insertSubview:self.snapshotView atIndex:0];
    [self setStartingInterfaceOrientation:viewController.interfaceOrientation];
    [self setLastUsedOrientation:viewController.interfaceOrientation];
    CGRect referenceFrameInWindow = [self.imageInfo.referenceView convertRect:self.imageInfo.referenceRect toView:nil];
    self.startingReferenceFrameForThumbnailInPresentingViewControllersOriginalOrientation = [self.view convertRect:referenceFrameInWindow fromView:nil];
    
    [self.scrollView addSubview:self.imageView];
    
    [viewController presentViewController:self animated:NO completion:^{
        
        if (self.interfaceOrientation != self.startingInterfaceOrientation) {
            [self setPresentingViewControllerPresentedFromItsUnsupportedOrientation:YES];
        }
        
        [self.scrollView setAlpha:0];
        [self.scrollView setFrame:self.view.bounds];
        [self updateScrollViewAndImageViewForCurrentMetrics];
        [self.scrollView setTransform:CGAffineTransformMakeScale(TRANSITION_THUMBNAIL_MAX_ZOOM, TRANSITION_THUMBNAIL_MAX_ZOOM)];
        
        CGFloat duration = DEFAULT_TRANSITION_DURATION;
        if (USE_DEBUG_SLOW_ANIMATIONS == 1) {
            duration *= 4;
        }
        
        __weak JTSImageViewController *weakSelf = self;
        
        // Have to dispatch to the next runloop,
        // or else the image view changes above won't be
        // committed prior to the animations below.
        dispatch_async(dispatch_get_main_queue(), ^{
        
            [UIView
             animateWithDuration:duration
             delay:0
             options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
             animations:^{
                 
                 [weakSelf setIsTransitioningFromInitialModalToInteractiveState:YES];
                 
                 if ([UIApplication sharedApplication].jts_usesViewControllerBasedStatusBarAppearance) {
                     [weakSelf setNeedsStatusBarAppearanceUpdate];
                 } else {
                     [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
                 }
                 
                 weakSelf.snapshotView.transform = CGAffineTransformConcat(weakSelf.snapshotView.transform,
                                                                       CGAffineTransformMakeScale(MAX_BACK_SCALING, MAX_BACK_SCALING));
                 
                 if (weakSelf.backgroundStyle == JTSImageViewControllerBackgroundStyle_ScaledDimmedBlurred) {
                     [weakSelf.blurredSnapshotView setAlpha:1];
                 }
                 
                 [weakSelf addMotionEffectsToSnapshotView];
                 [weakSelf.blackBackdrop setAlpha:BLACK_BACKDROP_ALPHA_NORMAL];
                 
                 [weakSelf.scrollView setAlpha:1.0f];
                 [weakSelf.scrollView setTransform:CGAffineTransformIdentity];
                 
                 if (weakSelf.image == nil) {
                     [weakSelf.progressContainer setAlpha:1.0f];
                 }
                 
             } completion:^(BOOL finished) {
                 [weakSelf setIsTransitioningFromInitialModalToInteractiveState:NO];
                 [weakSelf setIsAnimatingAPresentationOrDismissal:NO];
                 [weakSelf.view setUserInteractionEnabled:YES];
                 [weakSelf setIsPresented:YES];
                 if (weakSelf.imageDownloadFailed) {
                     [weakSelf dismiss:YES];
                 }
             }];
        });
    }];
}

- (void)_showAltTextFromViewController:(UIViewController *)viewController {
    
    [self setIsAnimatingAPresentationOrDismissal:YES];
    [self.view setUserInteractionEnabled:NO];
    
    self.snapshotView = [self snapshotFromParentmostViewController:viewController];
    
    if (self.backgroundStyle == JTSImageViewControllerBackgroundStyle_ScaledDimmedBlurred) {
        self.blurredSnapshotView = [self blurredSnapshotFromParentmostViewController:viewController];
        [self.snapshotView addSubview:self.blurredSnapshotView];
        [self.blurredSnapshotView setAlpha:0];
    }
    
    [self.view insertSubview:self.snapshotView atIndex:0];
    [self setStartingInterfaceOrientation:viewController.interfaceOrientation];
    [self setLastUsedOrientation:viewController.interfaceOrientation];
    CGRect referenceFrameInWindow = [self.imageInfo.referenceView convertRect:self.imageInfo.referenceRect toView:nil];
    self.startingReferenceFrameForThumbnailInPresentingViewControllersOriginalOrientation = [self.view convertRect:referenceFrameInWindow fromView:nil];
    
    __weak JTSImageViewController *weakSelf = self;
    
    [viewController presentViewController:weakSelf animated:NO completion:^{
        
        if (weakSelf.interfaceOrientation != weakSelf.startingInterfaceOrientation) {
            [weakSelf setPresentingViewControllerPresentedFromItsUnsupportedOrientation:YES];
        }
        
        // Replace the text view with a snapshot of itself,
        // to prevent the text from reflowing during the dismissal animation.
        [weakSelf verticallyCenterTextInTextView];
        UIView *textViewSnapshot = [weakSelf.textView snapshotViewAfterScreenUpdates:YES];
        [textViewSnapshot setFrame:weakSelf.textView.frame];
        [weakSelf.textView.superview insertSubview:textViewSnapshot aboveSubview:self.textView];
        [weakSelf.textView setHidden:YES];
        
        [textViewSnapshot setAlpha:0];
        [textViewSnapshot setTransform:CGAffineTransformMakeScale(TRANSITION_THUMBNAIL_MAX_ZOOM, TRANSITION_THUMBNAIL_MAX_ZOOM)];
        
        CGFloat duration = DEFAULT_TRANSITION_DURATION;
        if (USE_DEBUG_SLOW_ANIMATIONS == 1) {
            duration *= 4;
        }
        
        // Have to dispatch to the next runloop,
        // or else the image view changes above won't be
        // committed prior to the animations below.
        dispatch_async(dispatch_get_main_queue(), ^{
        
            [UIView
             animateWithDuration:duration
             delay:0
             options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
             animations:^{
                 
                 [weakSelf setIsTransitioningFromInitialModalToInteractiveState:YES];
                 
                 if ([UIApplication sharedApplication].jts_usesViewControllerBasedStatusBarAppearance) {
                     [weakSelf setNeedsStatusBarAppearanceUpdate];
                 } else {
                     [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
                 }
                 
                 weakSelf.snapshotView.transform = CGAffineTransformConcat(weakSelf.snapshotView.transform,
                                                                       CGAffineTransformMakeScale(MAX_BACK_SCALING, MAX_BACK_SCALING));
                 
                 if (weakSelf.backgroundStyle == JTSImageViewControllerBackgroundStyle_ScaledDimmedBlurred) {
                     [weakSelf.blurredSnapshotView setAlpha:1];
                 }
                 
                 [weakSelf addMotionEffectsToSnapshotView];
                 [weakSelf.blackBackdrop setAlpha:BLACK_BACKDROP_ALPHA_NORMAL];
                 
                 [textViewSnapshot setAlpha:1.0];
                 [textViewSnapshot setTransform:CGAffineTransformIdentity];
                 
             } completion:^(BOOL finished) {
                 
                 [textViewSnapshot removeFromSuperview];
                 [weakSelf.textView setHidden:NO];
                 
                 [weakSelf setIsTransitioningFromInitialModalToInteractiveState:NO];
                 [weakSelf setIsAnimatingAPresentationOrDismissal:NO];
                 [weakSelf.view setUserInteractionEnabled:YES];
                 [weakSelf setIsPresented:YES];
             }];
        });
    }];
}

#pragma mark - Dismissal

- (void)_dismissByCollapsingImageBackToOriginalPosition {
    
    [self.view setUserInteractionEnabled:NO];
    [self setIsAnimatingAPresentationOrDismissal:YES];
    [self setIsDismissing:YES];
    
    if ([self.optionsDelegate imageViewerShouldDimThumbnails:self]) {
        [UIView animateWithDuration:0.15 delay:0.18 options:0 animations:^{
            [self.scrollView setAlpha:0];
        } completion:nil];
    }
    
    CGRect imageFrame = [self.view convertRect:self.imageView.frame fromView:self.scrollView];
    self.imageView.autoresizingMask = UIViewAutoresizingNone;
    [self.imageView setTransform:CGAffineTransformIdentity];
    [self.imageView.layer setTransform:CATransform3DIdentity];
    [self.imageView removeFromSuperview];
    [self.imageView setFrame:imageFrame];
    [self.view addSubview:self.imageView];
    [self.scrollView removeFromSuperview];
    [self setScrollView:nil];
    
    __weak JTSImageViewController *weakSelf = self;
    
    // Have to dispatch after or else the image view changes above won't be
    // committed prior to the animations below. A single dispatch_async(dispatch_get_main_queue()
    // wouldn't work under certain scrolling conditions, so it has to be an ugly
    // two runloops ahead.
    dispatch_async(dispatch_get_main_queue(), ^{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        CGFloat duration = DEFAULT_TRANSITION_DURATION;
        if (USE_DEBUG_SLOW_ANIMATIONS == 1) {
            duration *= 4;
        }
        
        [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut animations:^{
            
            weakSelf.snapshotView.transform = weakSelf.currentSnapshotRotationTransform;
            [weakSelf removeMotionEffectsFromSnapshotView];
            [weakSelf.blackBackdrop setAlpha:0];
            
            if (weakSelf.backgroundStyle == JTSImageViewControllerBackgroundStyle_ScaledDimmedBlurred) {
                [weakSelf.blurredSnapshotView setAlpha:0];
            }
            
            BOOL mustRotateDuringTransition = (weakSelf.interfaceOrientation != weakSelf.startingInterfaceOrientation);
            if (mustRotateDuringTransition) {
                CGRect newEndingRect;
                CGPoint centerInRect;
                if (weakSelf.presentingViewControllerPresentedFromItsUnsupportedOrientation) {
                    CGRect rectToConvert = weakSelf.startingReferenceFrameForThumbnailInPresentingViewControllersOriginalOrientation;
                    CGRect rectForCentering = [weakSelf.snapshotView convertRect:rectToConvert toView:weakSelf.view];
                    centerInRect = CGPointMake(rectForCentering.origin.x+rectForCentering.size.width/2.0f,
                                               rectForCentering.origin.y+rectForCentering.size.height/2.0f);
                    newEndingRect = weakSelf.startingReferenceFrameForThumbnailInPresentingViewControllersOriginalOrientation;
                } else {
                    newEndingRect = weakSelf.startingReferenceFrameForThumbnail;
                    CGRect rectForCentering = [weakSelf.snapshotView convertRect:weakSelf.startingReferenceFrameForThumbnail toView:weakSelf.view];
                    centerInRect = CGPointMake(rectForCentering.origin.x+rectForCentering.size.width/2.0f,
                                               rectForCentering.origin.y+rectForCentering.size.height/2.0f);
                }
                [weakSelf.imageView setFrame:newEndingRect];
                weakSelf.imageView.transform = weakSelf.currentSnapshotRotationTransform;
                [weakSelf.imageView setCenter:centerInRect];
            } else {
                if (weakSelf.presentingViewControllerPresentedFromItsUnsupportedOrientation) {
                    [weakSelf.imageView setFrame:weakSelf.startingReferenceFrameForThumbnailInPresentingViewControllersOriginalOrientation];
                } else {
                    [weakSelf.imageView setFrame:weakSelf.startingReferenceFrameForThumbnail];
                }
                
                // Rotation not needed, so fade the status bar back in. Looks nicer.
                if ([UIApplication sharedApplication].jts_usesViewControllerBasedStatusBarAppearance) {
                    [weakSelf setNeedsStatusBarAppearanceUpdate];
                } else {
                    [[UIApplication sharedApplication] setStatusBarHidden:weakSelf.statusBarHiddenPriorToPresentation
                                                            withAnimation:UIStatusBarAnimationFade];
                }
            }
        } completion:^(BOOL finished) {
            
            // Needed if dismissing from a different orientation then the one we started with
            if ([UIApplication sharedApplication].jts_usesViewControllerBasedStatusBarAppearance == NO) {
                [[UIApplication sharedApplication] setStatusBarHidden:weakSelf.statusBarHiddenPriorToPresentation
                                                        withAnimation:UIStatusBarAnimationNone];
            }
            
            [weakSelf.presentingViewController dismissViewControllerAnimated:NO completion:^{
                [weakSelf.dismissalDelegate imageViewerDidDismiss:weakSelf];
            }];
        }];
    });
    });
}

- (void)_dismissByCleaningUpAfterImageWasFlickedOffscreen {
    
    [self.view setUserInteractionEnabled:NO];
    [self setIsAnimatingAPresentationOrDismissal:YES];
    [self setIsDismissing:YES];
    
    __weak JTSImageViewController *weakSelf = self;
    
    CGFloat duration = DEFAULT_TRANSITION_DURATION;
    if (USE_DEBUG_SLOW_ANIMATIONS == 1) {
        duration *= 4;
    }
    
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut animations:^{
        weakSelf.snapshotView.transform = weakSelf.currentSnapshotRotationTransform;
        [weakSelf removeMotionEffectsFromSnapshotView];
        [weakSelf.blackBackdrop setAlpha:0];
        if (weakSelf.backgroundStyle == JTSImageViewControllerBackgroundStyle_ScaledDimmedBlurred) {
            [weakSelf.blurredSnapshotView setAlpha:0];
        }
        [weakSelf.scrollView setAlpha:0];
        if ([UIApplication sharedApplication].jts_usesViewControllerBasedStatusBarAppearance) {
            [weakSelf setNeedsStatusBarAppearanceUpdate];
        } else {
            [[UIApplication sharedApplication] setStatusBarHidden:weakSelf.statusBarHiddenPriorToPresentation
                                                    withAnimation:UIStatusBarAnimationFade];
        }
    } completion:^(BOOL finished) {
        
        [weakSelf.presentingViewController dismissViewControllerAnimated:NO completion:^{
            [weakSelf.dismissalDelegate imageViewerDidDismiss:weakSelf];
        }];
    }];
}

- (void)_dismissByExpandingImageToOffscreenPosition {
    
    [self.view setUserInteractionEnabled:NO];
    [self setIsAnimatingAPresentationOrDismissal:YES];
    [self setIsDismissing:YES];
    
    __weak JTSImageViewController *weakSelf = self;
    
    CGFloat duration = DEFAULT_TRANSITION_DURATION;
    if (USE_DEBUG_SLOW_ANIMATIONS == 1) {
        duration *= 4;
    }

    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut animations:^{
        weakSelf.snapshotView.transform = weakSelf.currentSnapshotRotationTransform;
        [weakSelf removeMotionEffectsFromSnapshotView];
        [weakSelf.blackBackdrop setAlpha:0];
        if (weakSelf.backgroundStyle == JTSImageViewControllerBackgroundStyle_ScaledDimmedBlurred) {
            [weakSelf.blurredSnapshotView setAlpha:0];
        }
        [weakSelf.scrollView setAlpha:0];
        [weakSelf.scrollView setTransform:CGAffineTransformMakeScale(TRANSITION_THUMBNAIL_MAX_ZOOM, TRANSITION_THUMBNAIL_MAX_ZOOM)];
        if ([UIApplication sharedApplication].jts_usesViewControllerBasedStatusBarAppearance) {
            [weakSelf setNeedsStatusBarAppearanceUpdate];
        } else {
            [[UIApplication sharedApplication] setStatusBarHidden:weakSelf.statusBarHiddenPriorToPresentation
                                                    withAnimation:UIStatusBarAnimationFade];
        }
    } completion:^(BOOL finished) {
        [weakSelf.presentingViewController dismissViewControllerAnimated:NO completion:^{
            [weakSelf.dismissalDelegate imageViewerDidDismiss:weakSelf];
        }];
    }];
}

- (void)_dismissByExpandingAltTextToOffscreenPosition {
    
    [self.view setUserInteractionEnabled:NO];
    [self setIsAnimatingAPresentationOrDismissal:YES];
    [self setIsDismissing:YES];
    
    __weak JTSImageViewController *weakSelf = self;
    
    CGFloat duration = DEFAULT_TRANSITION_DURATION;
    if (USE_DEBUG_SLOW_ANIMATIONS == 1) {
        duration *= 4;
    }
    
    // Replace the text view with a snapshot of itself,
    // to prevent the text from reflowing during the dismissal animation.
    UIView *textViewSnapshot = [self.textView snapshotViewAfterScreenUpdates:YES];
    [textViewSnapshot setFrame:self.textView.frame];
    [self.textView.superview insertSubview:textViewSnapshot aboveSubview:self.textView];
    [self.textView removeFromSuperview];
    [self.textView setDelegate:nil];
    [self setTextView:nil];

    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut animations:^{
        weakSelf.snapshotView.transform = weakSelf.currentSnapshotRotationTransform;
        [weakSelf removeMotionEffectsFromSnapshotView];
        [weakSelf.blackBackdrop setAlpha:0];
        [textViewSnapshot setAlpha:0];
        if (weakSelf.backgroundStyle == JTSImageViewControllerBackgroundStyle_ScaledDimmedBlurred) {
            [weakSelf.blurredSnapshotView setAlpha:0];
        }
        CGFloat targetScale = TRANSITION_THUMBNAIL_MAX_ZOOM;
        [textViewSnapshot setTransform:CGAffineTransformMakeScale(targetScale, targetScale)];
        if ([UIApplication sharedApplication].jts_usesViewControllerBasedStatusBarAppearance) {
            [weakSelf setNeedsStatusBarAppearanceUpdate];
        } else {
            [[UIApplication sharedApplication] setStatusBarHidden:weakSelf.statusBarHiddenPriorToPresentation
                                                    withAnimation:UIStatusBarAnimationFade];
        }
    } completion:^(BOOL finished) {
        [weakSelf.presentingViewController dismissViewControllerAnimated:NO completion:^{
            [weakSelf.dismissalDelegate imageViewerDidDismiss:weakSelf];
        }];
    }];
}

#pragma mark - Snapshots

- (UIView *)snapshotFromParentmostViewController:(UIViewController *)viewController {
    
    UIViewController *presentingViewController = viewController.view.window.rootViewController;
    while (presentingViewController.presentedViewController) presentingViewController = presentingViewController.presentedViewController;
    UIView *snapshot = [presentingViewController.view snapshotViewAfterScreenUpdates:YES];
    [snapshot setClipsToBounds:NO];
    return snapshot;
}

- (UIView *)blurredSnapshotFromParentmostViewController:(UIViewController *)viewController {
    
    UIViewController *presentingViewController = viewController.view.window.rootViewController;
    while (presentingViewController.presentedViewController) presentingViewController = presentingViewController.presentedViewController;
    
    CGFloat outerBleed = 20.0f;
    CGRect contextBounds = CGRectInset(presentingViewController.view.bounds, -outerBleed, -outerBleed);
    UIGraphicsBeginImageContextWithOptions(contextBounds.size, YES, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextConcatCTM(context, CGAffineTransformMakeTranslation(outerBleed, outerBleed));
    [presentingViewController.view.layer renderInContext:context];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    UIImage *blurredImage = [image JTS_applyBlurWithRadius:3.0f tintColor:nil saturationDeltaFactor:1.0f maskImage:nil];
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:contextBounds];
    [imageView setImage:blurredImage];
    [imageView setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
    [imageView setBackgroundColor:[UIColor blackColor]];
    
    return imageView;
}

#pragma mark - Motion Effects

- (void)addMotionEffectsToSnapshotView {
    UIInterpolatingMotionEffect *verticalEffect;
    verticalEffect = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
    verticalEffect.minimumRelativeValue = @(12);
    verticalEffect.maximumRelativeValue = @(-12);
    
    UIInterpolatingMotionEffect *horizontalEffect;
    horizontalEffect = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.x" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
    horizontalEffect.minimumRelativeValue = @(12);
    horizontalEffect.maximumRelativeValue = @(-12);
    
    UIMotionEffectGroup *effectGroup = [[UIMotionEffectGroup alloc] init];
    [effectGroup setMotionEffects:@[horizontalEffect, verticalEffect]];
    [self.snapshotView addMotionEffect:effectGroup];
}

- (void)removeMotionEffectsFromSnapshotView {
    for (UIMotionEffect *effect in self.snapshotView.motionEffects) {
        [self.snapshotView removeMotionEffect:effect];
    }
}

#pragma mark - Interface Updates

- (void)updateInterfaceWithImage:(UIImage *)image {
    
    if (image) {
        [self setImage:image];
        [self.imageView setImage:image];
        [self.progressContainer setAlpha:0];
        
        // Don't update the layouts during a drag.
        if (self.isDraggingImage == NO) {
            [self updateLayoutsForCurrentOrientation];
        }
    }
}

- (void)updateLayoutsForCurrentOrientation {
    
    if (self.mode == JTSImageViewControllerMode_Image) {
        [self updateScrollViewAndImageViewForCurrentMetrics];
        self.progressContainer.center = CGPointMake(self.view.bounds.size.width/2.0f, self.view.bounds.size.height/2.0f);
    }
    else if (self.mode == JTSImageViewControllerMode_AltText) {
        if (self.isTransitioningFromInitialModalToInteractiveState == NO) {
            [self verticallyCenterTextInTextView];
        }
    }
    
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    if (self.startingInterfaceOrientation == UIInterfaceOrientationPortrait) {
        switch (self.interfaceOrientation) {
            case UIInterfaceOrientationLandscapeLeft:
                transform = CGAffineTransformMakeRotation(M_PI/2.0f);
                break;
            case UIInterfaceOrientationLandscapeRight:
                transform = CGAffineTransformMakeRotation(-M_PI/2.0f);
                break;
            case UIInterfaceOrientationPortrait:
            case UIInterfaceOrientationPortraitUpsideDown:
                transform = CGAffineTransformIdentity;
                break;
            default:
                break;
        }
    }
    else if (self.startingInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
        switch (self.interfaceOrientation) {
            case UIInterfaceOrientationLandscapeLeft:
                transform = CGAffineTransformIdentity;
                break;
            case UIInterfaceOrientationLandscapeRight:
                transform = CGAffineTransformMakeRotation(M_PI);
                break;
            case UIInterfaceOrientationPortrait:
            case UIInterfaceOrientationPortraitUpsideDown:
                transform = CGAffineTransformMakeRotation(-M_PI/2.0f);
                break;
            default:
                break;
        }
    }
    else if (self.startingInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
        switch (self.interfaceOrientation) {
            case UIInterfaceOrientationLandscapeLeft:
                transform = CGAffineTransformMakeRotation(M_PI);
                break;
            case UIInterfaceOrientationLandscapeRight:
                transform = CGAffineTransformIdentity;
                break;
            case UIInterfaceOrientationPortrait:
            case UIInterfaceOrientationPortraitUpsideDown:
                transform = CGAffineTransformMakeRotation(M_PI/2.0f);
                break;
            default:
                break;
        }
    }
    
    self.snapshotView.center = CGPointMake(self.view.bounds.size.width/2.0f, self.view.bounds.size.height/2.0f);
    
    if (self.rotationTransformIsDirty) {
        [self setRotationTransformIsDirty:NO];
        self.currentSnapshotRotationTransform = transform;
        if (self.isPresented) {
            if (self.mode == JTSImageViewControllerMode_Image) {
                self.scrollView.frame = self.view.bounds;
            }
            self.snapshotView.transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(MAX_BACK_SCALING, MAX_BACK_SCALING));
        } else {
            self.snapshotView.transform = transform;
        }
    }
}

- (void)updateScrollViewAndImageViewForCurrentMetrics {
    
    if (self.isAnimatingAPresentationOrDismissal == NO) {
        [self setIsManuallyResizingTheScrollViewFrame:YES];
        self.scrollView.frame = self.view.bounds;
        [self setIsManuallyResizingTheScrollViewFrame:NO];
    }
    
    BOOL usingOriginalPositionTransition = (self.transition == JTSImageViewControllerTransition_FromOriginalPosition);
    BOOL isAnimating = self.isAnimatingAPresentationOrDismissal;
    
    BOOL suppressAdjustments = (usingOriginalPositionTransition && isAnimating);
    
    if (suppressAdjustments == NO) {
        if (self.image) {
            [self.imageView setFrame:[self resizedFrameForAutorotatingImageView:self.image.size]];
        } else {
            [self.imageView setFrame:[self resizedFrameForAutorotatingImageView:self.imageInfo.referenceRect.size]];
        }
        self.scrollView.contentSize = self.imageView.frame.size;
        self.scrollView.contentInset = [self contentInsetForScrollView:self.scrollView.zoomScale];
    }
}

- (void)verticallyCenterTextInTextView {
    CGRect boundingRect = [self.textView.layoutManager usedRectForTextContainer:self.textView.textContainer];
    UIEdgeInsets insets = self.textView.contentInset;
    if (self.view.bounds.size.height > boundingRect.size.height) {
        insets.top = roundf(self.view.bounds.size.height-boundingRect.size.height)/2.0f;
    } else {
        insets.top = 0;
    }
    [self.textView setContentInset:insets];
    [self.textView setContentOffset:CGPointMake(0, 0 - insets.top)];
}

- (UIEdgeInsets)contentInsetForScrollView:(CGFloat)targetZoomScale {
    UIEdgeInsets inset = UIEdgeInsetsZero;
    CGFloat boundsHeight = self.scrollView.bounds.size.height;
    CGFloat boundsWidth = self.scrollView.bounds.size.width;
    CGFloat contentHeight = (self.image.size.height > 0) ? self.image.size.height : boundsHeight;
    CGFloat contentWidth = (self.image.size.width > 0) ? self.image.size.width : boundsWidth;
    CGFloat minContentHeight;
    CGFloat minContentWidth;
    if (contentHeight > contentWidth) {
        if (boundsHeight/boundsWidth < contentHeight/contentWidth) {
            minContentHeight = boundsHeight;
            minContentWidth = contentWidth * (minContentHeight / contentHeight);
        } else {
            minContentWidth = boundsWidth;
            minContentHeight = contentHeight * (minContentWidth / contentWidth);
        }
    } else {
        if (boundsWidth/boundsHeight < contentWidth/contentHeight) {
            minContentWidth = boundsWidth;
            minContentHeight = contentHeight * (minContentWidth / contentWidth);
        } else {
            minContentHeight = boundsHeight;
            minContentWidth = contentWidth * (minContentHeight / contentHeight);
        }
    }
    CGFloat myHeight = self.view.bounds.size.height;
    CGFloat myWidth = self.view.bounds.size.width;
    minContentWidth *= targetZoomScale;
    minContentHeight *= targetZoomScale;
    if (minContentHeight > myHeight && minContentWidth > myWidth) {
        inset = UIEdgeInsetsZero;
    } else {
        CGFloat verticalDiff = boundsHeight - minContentHeight;
        CGFloat horizontalDiff = boundsWidth - minContentWidth;
        verticalDiff = (verticalDiff > 0) ? verticalDiff : 0;
        horizontalDiff = (horizontalDiff > 0) ? horizontalDiff : 0;
        inset.top = verticalDiff/2.0f;
        inset.bottom = verticalDiff/2.0f;
        inset.left = horizontalDiff/2.0f;
        inset.right = horizontalDiff/2.0f;
    }
    return inset;
}

- (CGRect)resizedFrameForAutorotatingImageView:(CGSize)imageSize {
    CGRect frame = self.scrollView.bounds;
    CGFloat screenWidth = frame.size.width * self.scrollView.zoomScale;
    CGFloat screenHeight = frame.size.height * self.scrollView.zoomScale;
    CGFloat targetWidth = screenWidth;
    CGFloat targetHeight = screenHeight;
    CGFloat nativeHeight = screenHeight;
    CGFloat nativeWidth = screenWidth;
    if (imageSize.width > 0 && imageSize.height > 0) {
        nativeHeight = (imageSize.height > 0) ? imageSize.height : screenHeight;
        nativeWidth = (imageSize.width > 0) ? imageSize.width : screenWidth;
    }
    if (nativeHeight > nativeWidth) {
        if (screenHeight/screenWidth < nativeHeight/nativeWidth) {
            targetWidth = screenHeight / (nativeHeight / nativeWidth);
        } else {
            targetHeight = screenWidth / (nativeWidth / nativeHeight);
        }
    } else {
        if (screenWidth/screenHeight < nativeWidth/nativeHeight) {
            targetHeight = screenWidth / (nativeWidth / nativeHeight);
        } else {
            targetWidth = screenHeight / (nativeHeight / nativeWidth);
        }
    }
    frame.size = CGSizeMake(targetWidth, targetHeight);
    frame.origin = CGPointMake(0, 0);
    return frame;
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    
    if (self.imageIsFlickingAwayForDismissal) {
        return;
    }
    
    [scrollView setContentInset:[self contentInsetForScrollView:scrollView.zoomScale]];
    
    if (self.scrollView.scrollEnabled == NO) {
        self.scrollView.scrollEnabled = YES;
    }
    
    if (self.isAnimatingAPresentationOrDismissal == NO && self.isManuallyResizingTheScrollViewFrame == NO) {
        [self updateDimmingViewForCurrentZoomScale:YES];
    }
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale {
    
    if (self.imageIsFlickingAwayForDismissal) {
        return;
    }
    
    self.scrollView.scrollEnabled = (scale > 1);
    self.scrollView.contentInset = [self contentInsetForScrollView:scale];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    
    if (self.imageIsFlickingAwayForDismissal) {
        return;
    }
    
    CGPoint velocity = [scrollView.panGestureRecognizer velocityInView:scrollView.panGestureRecognizer.view];
    if (scrollView.zoomScale == 1 && (fabsf(velocity.x) > 1600 || fabsf(velocity.y) > 1600 ) ) {
        [self dismiss:YES];
    }
}

#pragma mark - Update Dimming View for Zoom Scale

- (void)updateDimmingViewForCurrentZoomScale:(BOOL)animated {
    CGFloat targetAlpha = (self.scrollView.zoomScale > 1) ? 1.0f : BLACK_BACKDROP_ALPHA_NORMAL;
    CGFloat duration = (animated) ? 0.35 : 0;
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState animations:^{
        [self.blackBackdrop setAlpha:targetAlpha];
    } completion:nil];
}

#pragma mark - Gesture Recognizer Actions

- (void)imageDoubleTapped:(UITapGestureRecognizer *)sender {
    
    if (self.scrollViewIsAnimatingAZoom) {
        return;
    }
    
    CGPoint rawLocation = [sender locationInView:sender.view];
    CGPoint point = [self.scrollView convertPoint:rawLocation fromView:sender.view];
    CGRect targetZoomRect;
    UIEdgeInsets targetInsets;
    if (self.scrollView.zoomScale == 1.0f) {
        self.scrollView.accessibilityHint = self.accessibilityHintZoomedIn;
        CGFloat zoomWidth = self.view.bounds.size.width / DOUBLE_TAP_TARGET_ZOOM;
        CGFloat zoomHeight = self.view.bounds.size.height / DOUBLE_TAP_TARGET_ZOOM;
        targetZoomRect = CGRectMake(point.x - (zoomWidth/2.0f), point.y - (zoomHeight/2.0f), zoomWidth, zoomHeight);
        targetInsets = [self contentInsetForScrollView:DOUBLE_TAP_TARGET_ZOOM];
    } else {
        self.scrollView.accessibilityHint = self.accessibilityHintZoomedOut;
        CGFloat zoomWidth = self.view.bounds.size.width * self.scrollView.zoomScale;
        CGFloat zoomHeight = self.view.bounds.size.height * self.scrollView.zoomScale;
        targetZoomRect = CGRectMake(point.x - (zoomWidth/2.0f), point.y - (zoomHeight/2.0f), zoomWidth, zoomHeight);
        targetInsets = [self contentInsetForScrollView:1.0f];
    }
    [self.view setUserInteractionEnabled:NO];
    [self setScrollViewIsAnimatingAZoom:YES];
    [self.scrollView setContentInset:targetInsets];
    [self.scrollView zoomToRect:targetZoomRect animated:YES];
    __weak JTSImageViewController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.35 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [weakSelf.view setUserInteractionEnabled:YES];
        [weakSelf setScrollViewIsAnimatingAZoom:NO];
    });
}

- (void)imageSingleTapped:(id)sender {
    if (self.scrollViewIsAnimatingAZoom) {
        return;
    }
    [self dismiss:YES];
}

- (void)imageLongPressed:(UILongPressGestureRecognizer *)sender {
    
    if (self.scrollViewIsAnimatingAZoom) {
        return;
    }
    
    if (self.image && sender.state == UIGestureRecognizerStateBegan) {
        if ([self.interactionsDelegate respondsToSelector:@selector(imageViewerDidLongPress:)]) {
            [self.interactionsDelegate imageViewerDidLongPress:self];
        }
    }
}

- (void)dismissingPanGestureRecognizerPanned:(UIPanGestureRecognizer *)panner {
    
    if (self.scrollViewIsAnimatingAZoom || self.isAnimatingAPresentationOrDismissal) {
        return;
    }
    
    CGPoint translation = [panner translationInView:panner.view];
    CGPoint locationInView = [panner locationInView:panner.view];
    CGPoint velocity = [panner velocityInView:panner.view];
    CGFloat vectorDistance = sqrtf(powf(velocity.x, 2)+powf(velocity.y, 2));
    
    if (panner.state == UIGestureRecognizerStateBegan) {
        self.isDraggingImage = CGRectContainsPoint(self.imageView.frame, locationInView);
        if (self.isDraggingImage) {
            [self startImageDragging:locationInView translationOffset:UIOffsetZero];
        }
    }
    else if (panner.state == UIGestureRecognizerStateChanged) {
        if (self.isDraggingImage) {
            CGPoint newAnchor = self.imageDragStartingPoint;
            newAnchor.x += translation.x + self.imageDragOffsetFromActualTranslation.horizontal;
            newAnchor.y += translation.y + self.imageDragOffsetFromActualTranslation.vertical;
            [self.attachmentBehavior setAnchorPoint:newAnchor];
        } else {
            self.isDraggingImage = CGRectContainsPoint(self.imageView.frame, locationInView);
            if (self.isDraggingImage) {
                UIOffset translationOffset = UIOffsetMake(-1*translation.x, -1*translation.y);
                [self startImageDragging:locationInView translationOffset:translationOffset];
            }
        }
    }
    else {
        if (vectorDistance > MINIMUM_FLICK_DISMISSAL_VELOCITY) {
            if (self.isDraggingImage) {
                [self dismissImageWithFlick:velocity];
            } else {
                [self dismiss:YES];
            }
        }
        else {
            [self cancelCurrentImageDrag:YES];
        }
    }
}

- (void)textViewSingleTapped:(id)sender {
    [self dismiss:YES];
}

#pragma mark - Dynamic Image Dragging

- (void)startImageDragging:(CGPoint)panGestureLocationInView translationOffset:(UIOffset)translationOffset {
    self.imageDragStartingPoint = panGestureLocationInView;
    self.imageDragOffsetFromActualTranslation = translationOffset;
    CGPoint anchor = self.imageDragStartingPoint;
    CGPoint imageCenter = self.imageView.center;
    UIOffset offset = UIOffsetMake(panGestureLocationInView.x-imageCenter.x, panGestureLocationInView.y-imageCenter.y);
    self.imageDragOffsetFromImageCenter = offset;
    self.attachmentBehavior = [[UIAttachmentBehavior alloc] initWithItem:self.imageView offsetFromCenter:offset attachedToAnchor:anchor];
    [self.animator addBehavior:self.attachmentBehavior];
    UIDynamicItemBehavior *modifier = [[UIDynamicItemBehavior alloc] initWithItems:@[self.imageView]];
    [modifier setAngularResistance:15];
    [modifier setDensity:[self appropriateDensityForView:self.imageView]];
    [self.animator addBehavior:modifier];
}

- (void)cancelCurrentImageDrag:(BOOL)animated {
    [self.animator removeAllBehaviors];
    [self setAttachmentBehavior:nil];
    [self setIsDraggingImage:NO];
    if (animated == NO) {
        self.imageView.transform = CGAffineTransformIdentity;
        self.imageView.center = CGPointMake(self.scrollView.contentSize.width/2.0f, self.scrollView.contentSize.height/2.0f);
    } else {
        [UIView
         animateWithDuration:0.7
         delay:0
         usingSpringWithDamping:0.7
         initialSpringVelocity:0
         options:UIViewAnimationOptionAllowUserInteraction |
         UIViewAnimationOptionBeginFromCurrentState
         animations:^{
             if (self.isDraggingImage == NO) {
                 self.imageView.transform = CGAffineTransformIdentity;
                 if (self.scrollView.dragging == NO && self.scrollView.decelerating == NO) {
                     self.imageView.center = CGPointMake(self.scrollView.contentSize.width/2.0f, self.scrollView.contentSize.height/2.0f);
                     [self updateScrollViewAndImageViewForCurrentMetrics];
                 }
             }
         } completion:nil];
    }
}

- (void)dismissImageWithFlick:(CGPoint)velocity {
    [self setImageIsFlickingAwayForDismissal:YES];
    __weak JTSImageViewController *weakSelf = self;
    UIPushBehavior *push = [[UIPushBehavior alloc] initWithItems:@[self.imageView] mode:UIPushBehaviorModeInstantaneous];
    [push setPushDirection:CGVectorMake(velocity.x*0.1, velocity.y*0.1)];
    [push setTargetOffsetFromCenter:self.imageDragOffsetFromImageCenter forItem:self.imageView];
    [push setAction:^{
        if ([weakSelf imageViewIsOffscreen]) {
            [weakSelf.animator removeAllBehaviors];
            [weakSelf setAttachmentBehavior:nil];
            [weakSelf.imageView removeFromSuperview];
            [weakSelf dismiss:YES];
        }
    }];
    [self.animator removeBehavior:self.attachmentBehavior];
    [self.animator addBehavior:push];
}

- (CGFloat)appropriateDensityForView:(UIView *)view {
    CGFloat height = view.bounds.size.height;
    CGFloat width = view.bounds.size.width;
    CGFloat actualArea = height * width;
    CGFloat referenceArea = self.view.bounds.size.width * self.view.bounds.size.height;
    CGFloat factor = referenceArea / actualArea;
    CGFloat defaultDensity = 0.5f;
    return defaultDensity * factor;
}

- (BOOL)imageViewIsOffscreen {
    CGRect visibleRect = [self.scrollView convertRect:self.view.bounds fromView:self.view];
    return ([self.animator itemsInRect:visibleRect].count == 0);
}

- (CGPoint)targetDismissalPoint:(CGPoint)startingCenter velocity:(CGPoint)velocity {
    return CGPointMake(startingCenter.x + velocity.x/3.0 , startingCenter.y + velocity.y/3.0);
}

#pragma mark - Gesture Recognizer Delegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    BOOL shouldReceiveTouch = YES;
    if (gestureRecognizer == self.panRecognizer) {
        shouldReceiveTouch = (self.scrollView.zoomScale == 1 && self.scrollViewIsAnimatingAZoom == NO);
    }
    else if ([self.interactionsDelegate respondsToSelector:@selector(imageViewerShouldTemporarilyIgnoreTouches:)]) {
        shouldReceiveTouch = ![self.interactionsDelegate imageViewerShouldTemporarilyIgnoreTouches:self];
    }
    return shouldReceiveTouch;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return (gestureRecognizer == self.singleTapperText);
}

#pragma mark - Progress Bar

- (void)startProgressTimer {
    NSTimer *timer = [[NSTimer alloc] initWithFireDate:[NSDate date] interval:0.05 target:self selector:@selector(progressTimerFired:) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    [self setDownloadProgressTimer:timer];
}

- (void)cancelProgressTimer {
    [self.downloadProgressTimer invalidate];
    [self setDownloadProgressTimer:nil];
}

- (void)progressTimerFired:(NSTimer *)timer {
    CGFloat progress = 0;
    CGFloat bytesExpected = self.imageDownloadDataTask.countOfBytesExpectedToReceive;
    if (bytesExpected > 0 && _imageIsBeingReadFromDisk == NO) {
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveLinear animations:^{
            self.spinner.alpha = 0;
            self.progressView.alpha = 1;
        } completion:nil];
        progress = self.imageDownloadDataTask.countOfBytesReceived / bytesExpected;
    }
    [self.progressView setProgress:progress];
}

#pragma mark - Accessibility

- (NSString *)defaultAccessibilityLabelForScrollView {
    
    return @"Full-Screen Image Viewer";
}

- (NSString *)defaultAccessibilityHintForScrollView:(BOOL)zoomedIn {

    NSString *hint = nil;
    
    if (zoomedIn) {
        hint = @"\
                Image is zoomed in. \
                Pan around the image using three fingers. \
                Double tap to dismiss this screen. \
                Double tap and hold for more options. \
                Triple tap the image to zoom out.";
    } else {
        hint = @"\
                Image is zoomed out. \
                Double tap to dismiss this screen. \
                Double tap and hold for more options. \
                Triple tap the image to zoom in.";
    }
    
    return hint;
}

@end



