//
//  SearchTableViewController.m
//  PirateRadio
//
//  Created by A-Team User on 10.05.18.
//  Copyright © 2018 A-Team User. All rights reserved.
//

#import "SearchTableViewController.h"
#import "YoutubeConnectionManager.h"
#import "SearchResultTableViewCell.h"
#import "VideoModel.h"
#import "ThumbnailModel.h"
#import "YoutubePlayerViewController.h"
#import "SearchSuggestionsTableViewController.h"
#import "ImageCacher.h"
#import "DGActivityIndicatorView.h"
#import "YoutubePlaylistModel.h"
#import "Toast.h"
#import "Reachability.h"
#import <YLImageView.h>

typedef enum {
    EnumLastSearchTypeWithKeywords,
    EnumLastSearchTypeSuggestions,
    EnumLastSearchTypeNone
}EnumLastSearchType;


@interface SearchTableViewController ()<UISearchBarDelegate, UIPopoverPresentationControllerDelegate>

@property (strong, nonatomic) NSMutableDictionary<NSString *, VideoModel *> *videoModelsDict;
@property (strong, nonatomic) NSMutableDictionary<NSString *, YoutubePlaylistModel *> *youtubePlaylistsDict;
@property (strong, nonatomic) NSMutableArray<YoutubeEntityModel *> *youtubeSearchEntities;
@property (strong, nonatomic) id<SearchSuggestionsDelegate> searchSuggestionsDelegate;
@property (strong, nonatomic) DGActivityIndicatorView *activityIndicatorView;
@property (strong, nonatomic) UIVisualEffectView *blurEffectView;
@property (strong, nonatomic) Reachability *reachability;
@property (strong, nonatomic) NSString *nextPageToken;
@property (weak, nonatomic) UISearchBar *searchBar;
@property BOOL isNextPageEnabled;
@property EnumLastSearchType lastSearchType;

@end

@implementation SearchTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UISearchController *searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    
    self.navigationItem.searchController = searchController;
    self.searchBar = self.navigationItem.searchController.searchBar;
    self.searchBar.delegate = self;
    
    UIBarButtonItem *searchButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(displaySearchBar)];
    self.navigationItem.rightBarButtonItem = searchButton;
    UIBarButtonItem *homeButton = [[UIBarButtonItem alloc] initWithTitle:@"Home" style:UIBarButtonItemStylePlain target:self action:@selector(homeButtonPressed)];
    self.navigationItem.leftBarButtonItem = homeButton;
    

    self.isNextPageEnabled = NO;
    self.videoModelsDict = [[NSMutableDictionary alloc] init];

    self.youtubePlaylistsDict = [[NSMutableDictionary alloc] init];
    self.youtubeSearchEntities = [[NSMutableArray alloc] init];
    self.tableView.showsVerticalScrollIndicator = YES;
    
    self.reachability = [Reachability reachabilityForInternetConnection];
    if (self.reachability.isReachable) {
        [self makeSearchForMostPopularVideos];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
    [self.reachability startNotifier];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)reachabilityChanged:(NSNotification *)notification {
    if (self.reachability.isReachable) {
        self.lastSearchType = EnumLastSearchTypeNone;
        self.tableView.allowsSelection = YES;
        self.tableView.scrollEnabled = YES;
        [self.view makeToast:@"Connection established"];
    }
    else {
        [self.view makeToast:@"No internet connection"];
        self.tableView.allowsSelection = NO;
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.youtubeSearchEntities.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation) | ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)) {
        return 185.0f;
    }
    return 255.0f;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation) | ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)) {
        return 185.0f;
    }
    return 255.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row > self.youtubeSearchEntities.count) {
        return [[UITableViewCell alloc] init];
    }
    SearchResultTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"videoCell" forIndexPath:indexPath];
    YoutubeEntityModel *entityModel = self.youtubeSearchEntities[indexPath.row];
    UIImage *thumbnail = [ImageCacher.sharedInstance imageForSearchResultId:entityModel.entityId];
    if (!thumbnail) {
        thumbnail = [UIImage imageWithData:[NSData dataWithContentsOfURL:[entityModel.thumbnails objectForKey:@"high"].url]];
    }
    cell.videoImage.image = thumbnail;
    cell.videoTitle.text = entityModel.title;
    cell.channelTitle.text = entityModel.channelTitle;
    
    if([entityModel.kind isEqualToString:@"youtube#video"]) {
        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
        NSString *groupingSeparator = [[NSLocale currentLocale] objectForKey:NSLocaleGroupingSeparator];
        numberFormatter.groupingSeparator = groupingSeparator;
        numberFormatter.groupingSize = 3;
        numberFormatter.alwaysShowsDecimalSeparator = NO;
        numberFormatter.usesGroupingSeparator = YES;
        VideoModel *videoModel = [self.videoModelsDict objectForKey:entityModel.entityId];
        
        cell.views.text = [numberFormatter stringFromNumber:[numberFormatter numberFromString:videoModel.videoViews]];
        
        if ([videoModel.videoDuration isEqualToString:@"PT0S"]) {
            cell.duration.text = @"Live";
        }
        else {
            cell.duration.text = videoModel.formattedDuration;
        }
            
        
    }
    else {
        YoutubePlaylistModel *playlistModel = (YoutubePlaylistModel *)entityModel;
        cell.views.text = @"Playlist";
        cell.duration.text = [[NSString stringWithFormat:@"%lu",playlistModel.itemsCount] stringByAppendingString:@" items"];
    }
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZ"];
    NSDate *date = [dateFormatter dateFromString:entityModel.publishedAt];
    cell.dateUploaded.text = [[dateFormatter stringFromDate:date] componentsSeparatedByString:@"T"][0];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    if (self.reachability.isReachable) {
        YoutubeEntityModel *entity = self.youtubeSearchEntities[indexPath.row];
        
        YoutubePlaylistModel *youtubePlaylistModel;
        
        if ([entity.kind isEqualToString:@"youtube#video"]) {
            VideoModel *videoModel = (VideoModel *)entity;
            youtubePlaylistModel = [[YoutubePlaylistModel alloc] initWithVideoModel:videoModel];
            YoutubePlayerViewController *youtubePlayer = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"YoutubePlayerViewController"];
            youtubePlayer.youtubePlaylist = youtubePlaylistModel;
            [self.navigationController pushViewController:youtubePlayer animated:YES];
        }
        else if ([entity.kind isEqualToString:@"youtube#playlist"]) {
            youtubePlaylistModel = (YoutubePlaylistModel *)entity;
            [self makeSearchForPlaylistItemsWithPlaylist:youtubePlaylistModel andNextPageToken:@""];
        }
    }
    else {
        [self.view makeToast:@"No internet connection"];
    }
    
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat offset = scrollView.contentOffset.y;
    CGFloat maximumOffset = scrollView.contentSize.height - scrollView.frame.size.height;
    
    if (self.isNextPageEnabled && ((maximumOffset - offset) <= 200)) {
        self.isNextPageEnabled = NO;
        if (self.lastSearchType == EnumLastSearchTypeSuggestions) {
            [self makeSearchForMostPopularVideos];
        }
        else if (self.lastSearchType == EnumLastSearchTypeWithKeywords) {
            [self startAnimation];
            self.lastSearchType = EnumLastSearchTypeWithKeywords;
            NSArray<NSString *> *keywords = [self.searchBar.text componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            [self makeSearchWithKeywords:keywords];
        }
    }
}

#pragma mark Animation

- (void)startAnimation {
    self.isNextPageEnabled = NO;
    if (!UIAccessibilityIsReduceTransparencyEnabled()) {
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        self.blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        self.blurEffectView.frame = self.navigationController.view.bounds;
        [self.navigationController.view addSubview:self.blurEffectView];
        [self.navigationController.view bringSubviewToFront:self.blurEffectView];
    }
    self.activityIndicatorView = [[DGActivityIndicatorView alloc] initWithType:DGActivityIndicatorAnimationTypeFiveDots];
    self.activityIndicatorView.tintColor = [UIColor blackColor];
    self.activityIndicatorView.frame = CGRectMake((self.tableView.frame.origin.x - self.activityIndicatorView.frame.size.width) / 2, self.tableView.frame.origin.y / 2, self.view.bounds.size.width, self.view.bounds.size.height);
    [self.navigationController.view addSubview:self.activityIndicatorView];
    [self.activityIndicatorView startAnimating];
}


- (void)stopAnimation {
    self.isNextPageEnabled = YES;
    [self.activityIndicatorView stopAnimating];
    [self.activityIndicatorView removeFromSuperview];
    [self.blurEffectView removeFromSuperview];
}

#pragma mark HistoryAndSearchBarDelegate

- (void)displaySearchBar {
    self.navigationItem.hidesSearchBarWhenScrolling = !self.navigationItem.hidesSearchBarWhenScrolling;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    self.nextPageToken = @"";
    [self makeSearchWithString:searchBar.text];
    [self stopAnimation];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [self presentSearchSuggestoinsTableView];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (self.reachability.isReachable) {
        [self.searchSuggestionsDelegate didChangeText:searchText];
    }
    else {
        [self.view makeToast:@"No internet connection"];
    }
}

#pragma mark Searching

- (void)makeSearchWithString:(NSString *)string {
    [self stopAnimation];
    if (self.reachability.isReachable) {
        if (![string isEqualToString:@""]) {
            [self.tableView scrollRectToVisible:CGRectZero animated:YES];
            [self startAnimation];
            [ImageCacher.sharedInstance clearCache];
            self.nextPageToken = nil;
            self.lastSearchType = EnumLastSearchTypeWithKeywords;
            NSArray<NSString *> *keywords = [string componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            [self.videoModelsDict removeAllObjects];
            [self.youtubeSearchEntities removeAllObjects];
            [self.tableView reloadData];
            [self makeSearchWithKeywords:keywords];
        }
    }
    else {
        [self.view makeToast:@"No internet connection"];
    }
    
    [self.searchSuggestionsDelegate didMakeSearchWithText:string];
    [self dismissViewControllerAnimated:NO completion:nil];
    self.navigationItem.searchController.active = NO;
    self.searchBar.text = string;
}

- (void)makeSearchWithKeywords:(NSArray<NSString *> *)keywords {
    if (self.reachability.isReachable) {
        [YoutubeConnectionManager makeSearchWithNextPageToken:self.nextPageToken andKeywords:keywords andCompletion:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                NSLog(@"Error = %@", error.localizedDescription);
            }
            else {
                NSError *serializationError;
                NSDictionary<NSString *, id> *responseDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&serializationError];
                if (serializationError) {
                    NSLog(@"Error = %@", serializationError.localizedDescription);
                    [self stopAnimation];
                }
                else {
                    NSArray *items = [responseDict objectForKey:@"items"];
                    self.nextPageToken = [responseDict objectForKey:@"nextPageToken"];
                    if (items.count == 0) {
                        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"WTF" message:@"What the hell are you trying to find? Please use normal keywords (e.g. Azis, Mile Kitic etc)." preferredStyle:UIAlertControllerStyleAlert];
                        [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                        [self presentViewController:alertController animated:YES completion:^{
                            [self stopAnimation];
                        }];
                    }
                    else {
                        for (NSDictionary *item in items) {
                            NSDictionary<NSString *, NSString *> *itemId = [item objectForKey:@"id"];
                            //                        if it is a video
                            if ([[itemId objectForKey:@"kind"] isEqualToString:@"youtube#video"]) {
                                NSString *videoId = [itemId objectForKey:@"videoId"];
                                NSDictionary *snippet = [item objectForKey:@"snippet"];
                                VideoModel *videoModel = [[VideoModel alloc] initWithSnippet:snippet andVideoId:videoId];
                                [self.youtubeSearchEntities addObject:videoModel];
                                [self.videoModelsDict setObject:videoModel forKey:videoId];
                            }
                            //                        if it is a playlist
                            else if ([[itemId objectForKey:@"kind"] isEqualToString:@"youtube#playlist"]) {
                                NSString *playlistId = [itemId objectForKey:@"playlistId"];
                                NSDictionary *snippet = [item objectForKey:@"snippet"];
                                YoutubePlaylistModel *youtubePlaylist = [[YoutubePlaylistModel alloc] initWithSnippet:snippet andPlaylistId:playlistId];
                                [self.youtubeSearchEntities addObject:youtubePlaylist];
                                [self.youtubePlaylistsDict setObject:youtubePlaylist forKey:playlistId];
                            }
                        }
                        NSString *resultsPerPage = [[responseDict objectForKey:@"pageInfo"] objectForKey:@"resultsPerPage"];
                        if ((self.youtubeSearchEntities.count - resultsPerPage.integerValue) < self.youtubeSearchEntities.count) {
                            NSRange subArrayRange = NSMakeRange(self.youtubeSearchEntities.count - resultsPerPage.integerValue, resultsPerPage.integerValue);
                            [self makeSearchForVideoDurationsWithVideoModels:[self.youtubeSearchEntities subarrayWithRange:subArrayRange]];
                            [self makeSearchForPlaylistContentDetailsForPlaylists:[self.youtubeSearchEntities subarrayWithRange:subArrayRange]];
                        }
                        else {
                            [self makeSearchForVideoDurationsWithVideoModels:self.youtubeSearchEntities];
                            [self makeSearchForPlaylistContentDetailsForPlaylists:self.youtubeSearchEntities];
                        }
                        
                    }
                }
            }
        }];
    }
    else {
        [self.view makeToast:@"No internet connection"];
    }
}

- (void)makeSearchForVideoDurationsWithVideoModels:(NSArray<YoutubeEntityModel *> *)entities {
    NSArray<NSString *> *entitiesIds = [[NSArray alloc] initWithArray:[entities valueForKey:@"entityId"]];
    [YoutubeConnectionManager makeYoutubeRequestForVideoDurationsWithVideoIds:entitiesIds andCompletion:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"Error searching for video durations = %@", error);
            [self stopAnimation];
        }
        else {
            
            NSError *serializationError;
            NSDictionary<NSString *, id> *responseDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&serializationError];
            if (serializationError) {
                NSLog(@"Error = %@", serializationError.localizedDescription);
            }
            
            else {
                NSArray *items = [responseDict objectForKey:@"items"];
                for (NSDictionary *item in items) {
                    NSString *duration = [[item objectForKey:@"contentDetails"] objectForKey:@"duration"];
                    NSString *views = [[item objectForKey:@"statistics"] objectForKey:@"viewCount"];
                    NSString *entityId = [item objectForKey:@"id"];
                    self.videoModelsDict[entityId].videoViews = views;
                    self.videoModelsDict[entityId].videoDuration = duration;
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self stopAnimation];
                [self.tableView reloadData];
            });
        }
    }];
}

- (void)makeSearchForPlaylistContentDetailsForPlaylists:(NSArray<YoutubeEntityModel *> *)entities {
    NSArray<NSString *> *playlistIds = [entities valueForKey:@"entityId"];
    [YoutubeConnectionManager makeSearchForPlaylistItemsCountForPlaylistIds:playlistIds andCompletion:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"Error searching for playlistContentDetails = %@", error);
            [self stopAnimation];
        }
        else {
            
            NSError *serializationError;
            NSDictionary<NSString *, id> *responseDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&serializationError];
            if (serializationError) {
                NSLog(@"Error = %@", serializationError.localizedDescription);
            }
            
            else {
                NSArray *items = [responseDict objectForKey:@"items"];
                for (NSDictionary *item in items) {
                    NSString *itemsCount = [[item objectForKey:@"contentDetails"] objectForKey:@"itemCount"];
                    NSString *entityId = [item objectForKey:@"id"];
                    self.youtubePlaylistsDict[entityId].itemsCount = itemsCount.integerValue;
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self stopAnimation];
                [self.tableView reloadData];
            });
        }
    }];
}

- (void)makeSearchForPlaylistItemsWithPlaylist:(YoutubePlaylistModel *)youtubePlaylistModel andNextPageToken:(NSString *)nextPageToken {
    [YoutubeConnectionManager makeYoutubeRequestForPlaylistItemsForPlaylistId:youtubePlaylistModel.entityId withNextPageToken:nextPageToken andCompletion:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"Error searching for playlist items = %@", error);
        }
        else {
            
            NSError *serializationError;
            NSDictionary<NSString *, id> *responseDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&serializationError];
            if (serializationError) {
                NSLog(@"Error = %@", serializationError.localizedDescription);
            }
            
            else {
                
                NSArray *items = [responseDict objectForKey:@"items"];
                for (NSDictionary *item in items) {
                    NSDictionary *snippet = [item objectForKey:@"snippet"];
                    NSDictionary *contentDetails = [item objectForKey:@"contentDetails"];
                    NSString *entityId = [contentDetails objectForKey:@"videoId"];
                    VideoModel *entity = [[VideoModel alloc] initWithSnippet:snippet entityId:entityId andKind:@"youtube#video"];
                    [youtubePlaylistModel addPlaylistItem:entity];
                }
                NSString *totalResults = [[responseDict objectForKey:@"pageInfo"] objectForKey:@"totalResults"];
                NSString *newNextPageToken;
                if (totalResults.integerValue != youtubePlaylistModel.playlistItems.count) {
                    newNextPageToken = [responseDict objectForKey:@"nextPageToken"];
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    YoutubePlayerViewController *youtubePlayer = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"YoutubePlayerViewController"];
                    youtubePlayer.youtubePlaylist = youtubePlaylistModel;
                    youtubePlayer.nextPageToken = newNextPageToken;
                    [self.navigationController pushViewController:youtubePlayer animated:YES];
                });
            }
        }
    }];
}

- (void)makeSearchForMostPopularVideos {
    if (self.reachability.isReachable) {
        self.lastSearchType = EnumLastSearchTypeSuggestions;
        [self startAnimation];
        [YoutubeConnectionManager makeYoutubeRequestForMostPopularVideosWithNextPageToken:self.nextPageToken andCompletion:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                NSLog(@"Error = %@", error.localizedDescription);
                [self stopAnimation];
                
            }
            else {
                NSError *serializationError;
                NSDictionary<NSString *, id> *responseDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&serializationError];
                if (serializationError) {
                    NSLog(@"Error = %@", serializationError.localizedDescription);
                }
                else {
                    NSArray *items = [responseDict objectForKey:@"items"];
                    self.nextPageToken = [responseDict objectForKey:@"nextPageToken"];
                    for (NSDictionary *item in items) {
                        NSString *videoId = [item objectForKey:@"id"];
                        NSDictionary *snippet = [item objectForKey:@"snippet"];
                        VideoModel *videoModel = [[VideoModel alloc] initWithSnippet:snippet andVideoId:videoId];
                        NSString *duration = [[item objectForKey:@"contentDetails"] objectForKey:@"duration"];
                        NSString *views = [[item objectForKey:@"statistics"] objectForKey:@"viewCount"];
                        videoModel.videoDuration = duration;
                        videoModel.videoViews = views;
                        [self.youtubeSearchEntities addObject:videoModel];
                        [self.videoModelsDict setObject:videoModel forKey:videoId];
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self stopAnimation];
                        [self.tableView reloadData];
                    });
                }
            }
        }];
    }
    else {
        [self.view makeToast:@"No internet connection"];
    }
}

- (void)homeButtonPressed {
    if (self.reachability.isReachable) {
        if (self.lastSearchType != EnumLastSearchTypeSuggestions) {
            [self.youtubeSearchEntities removeAllObjects];
            self.nextPageToken = nil;
            [self makeSearchForMostPopularVideos];
        }
    }
    else {
        [self.view makeToast:@"No internet connection"];
    }
}

- (void)presentSearchSuggestoinsTableView {
    SearchSuggestionsTableViewController *searchSuggestionsTable = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"SearchSuggestionsTableViewController"];
    searchSuggestionsTable.delegate = self;
    self.searchSuggestionsDelegate = searchSuggestionsTable;
    searchSuggestionsTable.modalPresentationStyle = UIModalPresentationPopover;
    searchSuggestionsTable.popoverPresentationController.sourceView = self.searchBar;
    searchSuggestionsTable.popoverPresentationController.sourceRect = CGRectMake(self.searchBar.frame.origin.x, self.searchBar.frame.origin.y, self.searchBar.frame.size.width, self.searchBar.frame.size.height);
    searchSuggestionsTable.popoverPresentationController.delegate = self;
    [self presentViewController:searchSuggestionsTable animated:YES completion:nil];
}


- (UIModalPresentationStyle) adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller {
    return UIModalPresentationNone;
}

- (void)popoverPresentationControllerDidDismissPopover:(UIPopoverPresentationController *)popoverPresentationController {
    self.navigationItem.searchController.active = NO;
}


@end
