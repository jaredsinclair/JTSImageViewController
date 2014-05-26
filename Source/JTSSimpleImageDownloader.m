//
//  JTSSimpleImageDownloader.m
//
//
//  Created by Jared Sinclair on 3/2/14.
//  Copyright (c) 2014 Nice Boy LLC. All rights reserved.
//

#import "JTSSimpleImageDownloader.h"

#import "JTSAnimatedGIFUtility.h"
#import "JTSDownloaderTask.h"

@interface JTSURLConnectionTask : NSObject <JTSDownloaderTask, NSURLConnectionDataDelegate>
@property (nonatomic) int64_t countOfBytesReceived;
@property (nonatomic) int64_t countOfBytesExpectedToReceive;

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic, copy) void (^completion)(NSData *, NSError *);

- (instancetype)initWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSError *error))completion;
@end

@implementation JTSSimpleImageDownloader

+ (id <JTSDownloaderTask>)downloadImageForURL:(NSURL *)imageURL canonicalURL:(NSURL *)canonicalURL completion:(void (^)(UIImage *))completion {
    id <JTSDownloaderTask> dataTask = nil;

    if (imageURL.absoluteString.length) {
        NSURLRequest *request = [NSURLRequest requestWithURL:imageURL];
        
        if (request == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(nil);
                }
            });
        }
        else {
            void (^dataToImage)(NSData *) = ^(NSData *data) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    UIImage *image = [self imageFromData:data forURL:request.URL canonicalURL:canonicalURL];

                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (completion) {
                            completion(image);
                        }
                    });
                });
            };

            if ([UIDevice currentDevice].systemVersion.intValue >= 7) {
                dataTask = (id <JTSDownloaderTask>) [self sessionDataTaskForRequest:request completion:dataToImage];
            } else {
                dataTask = [self urlConnectionTaskForURL:request completion:dataToImage];
            }
        }
    }
    return dataTask;
}

+ (id <JTSDownloaderTask>)urlConnectionTaskForURL:(NSURLRequest *)request completion:(void (^)(NSData *))completion {
    JTSURLConnectionTask *task = [[JTSURLConnectionTask alloc] initWithRequest:request completionHandler:^(NSData *data, NSError *error) {
        completion(data);
    }];
    return task;
}

+ (NSURLSessionDataTask *)sessionDataTaskForRequest:(NSURLRequest *)request completion:(void (^)(NSData *))completion {
    NSURLSession *sesh = [NSURLSession sharedSession];

    NSURLSessionDataTask *dataTask = [sesh dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        completion(data);
    }];
    [dataTask resume];

    return dataTask;
}

+ (UIImage *)imageFromData:(NSData *)data forURL:(NSURL *)imageURL canonicalURL:(NSURL *)canonicalURL {
    UIImage *image = nil;
    
    if (data) {
        NSString *referenceURL = (canonicalURL.absoluteString.length) ? canonicalURL.absoluteString : imageURL.absoluteString;
        if ([JTSAnimatedGIFUtility imageURLIsAGIF:referenceURL]) {
            image = [JTSAnimatedGIFUtility animatedImageWithAnimatedGIFData:data];
        }
        if (image == nil) {
            image = [[UIImage alloc] initWithData:data];
        }
    }
    
    return image;
}

@end


@implementation JTSURLConnectionTask

- (instancetype)initWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSError *error))completion {
    self = [super init];
    if (self) {
        _connection = [[NSURLConnection alloc]initWithRequest:request delegate:self startImmediately:YES];
        self.completion = completion;
    }
    return self;
}


- (void)cancel {
    [_connection cancel];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    _countOfBytesExpectedToReceive = response.expectedContentLength;
    _data = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_data appendData:data];
    _countOfBytesReceived += data.length;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    _completion(_data, nil);
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    _completion(_data, error);
}

@end





