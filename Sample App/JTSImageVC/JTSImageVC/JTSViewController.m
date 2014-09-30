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
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] init];
    [tapRecognizer addTarget:self action:@selector(bigButtonTapped:)];
    [self.bigImageButton addGestureRecognizer:tapRecognizer];
    [self.bigImageButton setAccessibilityLabel:@"Photo of a cat wearing a Bane costume."];
    self.bigImageButton.layer.cornerRadius = self.bigImageButton.bounds.size.width/2.0f;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (void)bigButtonTapped:(id)sender {
    
    // Create image info
    JTSImageInfo *imageInfo = [[JTSImageInfo alloc] init];
    imageInfo.image = self.bigImageButton.image;
    imageInfo.referenceRect = self.bigImageButton.frame;
    imageInfo.referenceView = self.bigImageButton.superview;
    imageInfo.referenceContentMode = self.bigImageButton.contentMode;
    imageInfo.referenceCornerRadius = self.bigImageButton.layer.cornerRadius;
    
    // Setup view controller
    JTSImageViewController *imageViewer = [[JTSImageViewController alloc]
                                           initWithImageInfo:imageInfo
                                           mode:JTSImageViewControllerMode_Image
                                           backgroundStyle:JTSImageViewControllerBackgroundStyle_ScaledDimmed];
    
    // Present the view controller.
    [imageViewer showFromViewController:self transition:JTSImageViewControllerTransition_FromOriginalPosition];
}

@end





