//
//  JTSImageInfo.h
//
//
//  Created by Jared Sinclair on 3/2/14.
//  Copyright (c) 2014 Nice Boy LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JTSImageInfo : NSObject

@property (copy, nonatomic) NSString *imageURL;
@property (copy, nonatomic) NSString *canonicalImageURL; // since `imageURL` might be a filesystem URL from the local cache.
@property (copy, nonatomic) NSString *altText;
@property (copy, nonatomic) NSString *title;
@property (assign, nonatomic) CGRect referenceRect;
@property (assign, nonatomic) CGRect documentRect;
@property (strong, nonatomic) UIView *referenceView;
@property (copy, nonatomic) NSMutableDictionary *userInfo;

- (NSString *)displayableTitleAltTextSummary;
- (NSString *)combinedTitleAndAltText;

@end
