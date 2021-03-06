//
//  ImageCacher.h
//  PirateRadio
//
//  Created by A-Team User on 22.05.18.
//  Copyright © 2018 A-Team User. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ImageCacher : NSObject

+ (instancetype)sharedInstance;
- (void)cacheImage:(UIImage *)image forSearchResultId:(NSString *)searchResultId;
- (UIImage *)imageForSearchResultId:(NSString *)searchResultId;
- (void)clearCache;

@end
