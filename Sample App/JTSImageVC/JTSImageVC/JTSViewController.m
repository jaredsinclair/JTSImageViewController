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

@interface JTSViewController ()

@end

@implementation JTSViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.bigImageButton addTarget:self action:@selector(bigButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (void)bigButtonTapped:(id)sender {
    
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

@end





