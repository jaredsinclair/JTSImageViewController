//
//  JTSSimpleImageDownloader.m
//
//
//  Created by Jared Sinclair on 3/2/14.
//  Copyright (c) 2014 Nice Boy LLC. All rights reserved.
//

#import "JTSSimpleImageDownloader.h"

#import "JTSAnimatedGIFUtility.h"

@implementation JTSSimpleImageDownloader

+ (NSURLSessionDataTask *)downloadImageForURL:(NSString *)imageURL canonicalURL:(NSString *)canonicalURL completion:(void (^)(UIImage *))completion {
    
    NSURLSessionDataTask *dataTask = nil;
    
    if (imageURL.length) {
        
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:imageURL]];
        
        if (request == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(nil);
                }
            });
        }
        else {
            
            NSURLSession *sesh = [NSURLSession sharedSession];
            
            dataTask = [sesh dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    
                    UIImage *image = [self imageFromData:data forURL:imageURL canonicalURL:canonicalURL];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (completion) {
                            completion(image);
                        }
                    });
                    
                });
                
            }];
            
            [dataTask resume];
        }
    }
    
    return dataTask;
}

+ (UIImage *)imageFromData:(NSData *)data forURL:(NSString *)imageURL canonicalURL:(NSString *)canonicalURL {
    UIImage *image = nil;
    
    if (data) {
        NSString *referenceURL = (canonicalURL.length) ? canonicalURL : imageURL;
        if ([JTSAnimatedGIFUtility imageURLIsAGIF:referenceURL] == YES) {
            image = [JTSAnimatedGIFUtility animatedImageWithAnimatedGIFData:data];
        }
        if (image == nil) {
            image = [[UIImage alloc] initWithData:data];
        }
    }
    
    return image;
}

@end






