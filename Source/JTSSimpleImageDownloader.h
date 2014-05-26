//
//  JTSSimpleImageDownloader.h
//  
//
//  Created by Jared Sinclair on 3/2/14.
//  Copyright (c) 2014 Nice Boy LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol JTSDownloaderTask;

@interface JTSSimpleImageDownloader : NSObject

+ (id <JTSDownloaderTask>)downloadImageForURL:(NSURL *)imageURL
                                 canonicalURL:(NSURL *)canonicalURL
                                   completion:(void(^)(UIImage *image))completion;

@end
