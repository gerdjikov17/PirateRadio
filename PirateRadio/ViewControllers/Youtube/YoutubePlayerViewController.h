//
//  YoutubePlayerViewController.h
//  PirateRadio
//
//  Created by A-Team User on 10.05.18.
//  Copyright © 2018 A-Team User. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "YTPlayerView.h"

@class VideoModel;
@class DownloadButtonWebView;
@class CBAutoScrollLabel;

@interface YoutubePlayerViewController : UIViewController <YTPlayerViewDelegate, UITableViewDelegate, UITableViewDataSource>

@property (strong, nonatomic) VideoModel *videoModel;
@property (weak, nonatomic) IBOutlet YTPlayerView *youtubePlayer;


@end
