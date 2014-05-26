//
// Created by ReDetection on 26/05/14.
//


@protocol JTSDownloaderTask <NSObject>

@property (readonly, nonatomic) int64_t countOfBytesReceived;
@property (readonly, nonatomic) int64_t countOfBytesExpectedToReceive;

- (void)cancel;

@end
