//
//  ProfileViewController.m
//  PirateRadio
//
//  Created by A-Team User on 28.06.18.
//  Copyright © 2018 A-Team User. All rights reserved.
//

#import "ProfileViewController.h"
#import <CoreData/CoreData.h>
#import "VideoModel.h"
#import "FavouriteVideoTableViewCell.h"
#import "LoginViewController.h"
#import "DataBase.h"
#import "ThumbnailModel.h"
#import "YoutubePlaylistModel.h"
#import "YoutubePlayerViewController.h"

@interface ProfileViewController ()

@property (weak, nonatomic) IBOutlet UILabel *favouriteVideosLabel;
@property (weak, nonatomic) IBOutlet UITableView *favouriteVideosTableView;
@property (weak, nonatomic) IBOutlet UIButton *logOutButton;

@property (strong, nonatomic) NSArray<VideoModel *> *favouriteVideos;
@property (strong, nonatomic) NSString *username;

@end

@implementation ProfileViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.username = [NSUserDefaults.standardUserDefaults valueForKey:@"loggedUsername"];
    self.favouriteVideosTableView.delegate = self;
    self.favouriteVideosTableView.dataSource = self;
    

    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.favouriteVideos = [[NSArray alloc] initWithArray:[DataBase.sharedManager favouriteVideosForUsername:self.username]];
    [self.favouriteVideosTableView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)logOutButtonTap:(id)sender {
    [NSUserDefaults.standardUserDefaults setBool:NO forKey:@"isLogged"];
    [NSUserDefaults.standardUserDefaults setValue:@"" forKey:@"loggedUsername"];
    LoginViewController *loginVC = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"LoginViewController"];
    [self.navigationController setViewControllers:@[loginVC]];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.favouriteVideos.count;
}

- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    FavouriteVideoTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FavouriteVideoCell" forIndexPath:indexPath];
    VideoModel *video = self.favouriteVideos[indexPath.row];
    ThumbnailModel *thumbnail = [video.thumbnails objectForKey:@"high"];
    NSURL *imageURL = thumbnail.url;
    cell.videoThumbnail.image = [UIImage imageWithData:[NSData dataWithContentsOfURL:imageURL]];
    
    cell.videoTitle.text = video.title;
    cell.channelTitle.text = video.channelTitle;
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    NSString *groupingSeparator = [[NSLocale currentLocale] objectForKey:NSLocaleGroupingSeparator];
    numberFormatter.groupingSeparator = groupingSeparator;
    numberFormatter.groupingSize = 3;
    numberFormatter.alwaysShowsDecimalSeparator = NO;
    numberFormatter.usesGroupingSeparator = YES;

    if ([video.videoDuration isEqualToString:@"PT0S"]) {
        cell.videoDuration.text = @"Live";
    }
    else {
        cell.videoDuration.text = video.formattedDuration;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    VideoModel *video = self.favouriteVideos[indexPath.row];
    [self.tabBarController setSelectedIndex:0];
    YoutubePlaylistModel *playlist = [[YoutubePlaylistModel alloc] initWithVideoModel:video];
    YoutubePlayerViewController *youtubeVC;
    if (self.tabBarController.selectedViewController.childViewControllers.count > 1) {
        youtubeVC = (YoutubePlayerViewController *)self.tabBarController.selectedViewController.childViewControllers[1];
        [youtubeVC reloadVCWithNewYoutubePlaylist:playlist];
    }
    else {
        youtubeVC = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"YoutubePlayerViewController"];
        youtubeVC.youtubePlaylist = playlist;
        [self.tabBarController.selectedViewController pushViewController:youtubeVC animated:NO];
    }
    
    
}


@end