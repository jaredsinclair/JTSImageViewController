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
#import "JTSAnimatedGIFUtility.h"

@interface JTSViewController ()

@property NSProgress *customProgress;
@property JTSImageViewController * imageViewerForCustomLoading;

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
    imageInfo.referenceContentMode = self.bigImageButton.contentMode;
    imageInfo.referenceCornerRadius = self.bigImageButton.layer.cornerRadius;
    
    // Setup view controller
    JTSImageViewController *imageViewer = [[JTSImageViewController alloc]
                                           initWithImageInfo:imageInfo
                                           mode:JTSImageViewControllerMode_Image
                                           backgroundStyle:JTSImageViewControllerBackgroundOption_Scaled];
    
    
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
                                           backgroundStyle:JTSImageViewControllerBackgroundOption_Blurred];
    
    
    // Present the view controller.
    [imageViewer showFromViewController:self transition:JTSImageViewControllerTransition_FromOriginalPosition];
}

- (IBAction)customBigButtonTapped:(id)sender {
    //download image with custom progress from SDWebImage
    
    // Create image info
    JTSImageInfo *imageInfo = [[JTSImageInfo alloc] init];
    imageInfo.referenceRect = self.customBigImageButton.frame;
    imageInfo.referenceView = self.customBigImageButton.superview;
    imageInfo.referenceContentMode = self.bigImageButton.contentMode;
    imageInfo.referenceCornerRadius = self.bigImageButton.layer.cornerRadius;
    
    NSProgress * customProgress = [NSProgress progressWithTotalUnitCount:0];
    customProgress.kind = NSProgressKindFile;
    self.customProgress = customProgress;
    
    //with custom progress
    JTSImageViewController *imageViewer = [[JTSImageViewController alloc]
                                           initWithImageInfo:imageInfo
                                           mode:JTSImageViewControllerMode_Image
                                           backgroundStyle:JTSImageViewControllerBackgroundOption_Blurred
                                           customImageLoadingProgress:self.customProgress];
    NSURLSessionConfiguration * sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    [sessionConfig setRequestCachePolicy:NSURLRequestReloadIgnoringCacheData];//no cache to allow repeatable testing
    NSURLSession * session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:[NSOperationQueue mainQueue]];    //main thread response for delegates
    NSURLSessionDownloadTask * task = [session downloadTaskWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://i.imgur.com/iGRxQNb.gif"]]];
    
    self.imageViewerForCustomLoading = imageViewer;
    
    [task resume];
    // Present the view controller.
    [imageViewer showFromViewController:self transition:JTSImageViewControllerTransition_FromOriginalPosition];
    
}
#pragma mark - url session download delegate
-(void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes{
    
    _customProgress.totalUnitCount = expectedTotalBytes;
    _customProgress.completedUnitCount = 0;

}

-(void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite{
    
    _customProgress.totalUnitCount = totalBytesExpectedToWrite;
    _customProgress.completedUnitCount = totalBytesWritten;
}

-(void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location{
    
    UIImage * image = [JTSAnimatedGIFUtility animatedImageWithAnimatedGIFURL:location];
    [self.imageViewerForCustomLoading customImageLoadingDidFinish:image];
}

@end





