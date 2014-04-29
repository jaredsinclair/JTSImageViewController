//
//  JTSViewController.m
//  JTSImageVC
//
//  Created by Jared on 3/29/14.
//  Copyright (c) 2014 Nice Boy, LLC. All rights reserved.
//

#import "JTSViewController.h"

#import "JTSImageViewController.h"
#import "JTSImageInfo.h"

#import "SDWebImageManager.h"

@interface JTSViewController ()

@end

@implementation JTSViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.bigImageButton setAccessibilityLabel:@"Photo of a cat wearing a Bane costume."];
    [self.simpleImageButton setAccessibilityLabel:@"Photo of jim and pam in love"];
    [self.customBigImageButton setAccessibilityLabel:@"Photo of jim and pam in love"];
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (IBAction)bigButtonTapped:(id)sender {
    
    // Create image info
    JTSImageInfo *imageInfo = [[JTSImageInfo alloc] init];
    imageInfo.image = [self.bigImageButton backgroundImageForState:UIControlStateNormal];
    imageInfo.referenceRect = self.bigImageButton.frame;
    imageInfo.referenceView = self.bigImageButton.superview;
    
    // Setup view controller
    JTSImageViewController *imageViewer = [[JTSImageViewController alloc]
                                           initWithImageInfo:imageInfo
                                           mode:JTSImageViewControllerMode_Image
                                           backgroundStyle:JTSImageViewControllerBackgroundStyle_ScaledDimmedBlurred];
    
    
    // Present the view controller.
    [imageViewer showFromViewController:self transition:JTSImageViewControllerTransition_FromOriginalPosition];
}

- (IBAction)simpleButtonTapped:(id)sender {
    // Create image info
    JTSImageInfo *imageInfo = [[JTSImageInfo alloc] init];
    imageInfo.imageURL = [NSURL URLWithString:@"http://i.imgur.com/iGRxQNb.gif"];
    imageInfo.referenceRect = self.simpleImageButton.frame;
    imageInfo.referenceView = self.simpleImageButton.superview;
    
    // Setup view controller
    JTSImageViewController *imageViewer = [[JTSImageViewController alloc]
                                           initWithImageInfo:imageInfo
                                           mode:JTSImageViewControllerMode_Image
                                           backgroundStyle:JTSImageViewControllerBackgroundStyle_ScaledDimmedBlurred];
    
    
    // Present the view controller.
    [imageViewer showFromViewController:self transition:JTSImageViewControllerTransition_FromOriginalPosition];
}

- (IBAction)customBigButtonTapped:(id)sender {
    //download image with custom progress from SDWebImage
    
    // Create image info
    JTSImageInfo *imageInfo = [[JTSImageInfo alloc] init];
    imageInfo.referenceRect = self.customBigImageButton.frame;
    imageInfo.referenceView = self.customBigImageButton.superview;
    
    SDWebImageManager * manage= [SDWebImageManager sharedManager];
    //clear memory to test progress
    SDImageCache *imageCache = [SDImageCache sharedImageCache];
    [imageCache clearMemory];
    [imageCache clearDisk];
    [imageCache cleanDisk];
    
    __block NSProgress * progress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
    
    SDWebImageDownloaderProgressBlock sdBlock = ^(NSInteger receivedSize, NSInteger expectedSize) {
        
        [progress setCompletedUnitCount:receivedSize];
        [progress setTotalUnitCount:expectedSize];
    };
    
    //with custom progress
    JTSImageViewController *imageViewer = [[JTSImageViewController alloc]
                                           initWithImageInfo:imageInfo
                                           mode:JTSImageViewControllerMode_Image
                                           backgroundStyle:JTSImageViewControllerBackgroundStyle_ScaledDimmedBlurred
                                           customImageProgress:progress];
    
    //hopefully url does not disappear
    [manage downloadWithURL:[NSURL URLWithString:@"http://i.imgur.com/iGRxQNb.gif"] options:0 progress:sdBlock completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished) {
        
        [imageViewer customImageSetter:image];
    }];
    
    // Present the view controller.
    [imageViewer showFromViewController:self transition:JTSImageViewControllerTransition_FromOriginalPosition];
    
}

@end





