//
//  SavedMusicTableViewController.m
//  PirateRadio
//
//  Created by A-Team User on 14.05.18.
//  Copyright © 2018 A-Team User. All rights reserved.
//

#import <MBCircularProgressBar/MBCircularProgressBarView.h>
#import "SavedMusicTableViewController.h"
#import "AllSongsTableViewController.h"
#import "MusicPlayerViewController.h"
#import "SavedMusicTableViewCell.h"
#import "LocalSongModel.h"
#import "PlaylistModel.h"
#import "PlaylistsDatabase.h"
#import "Constants.h"


@interface SavedMusicTableViewController ()

@property (strong, nonatomic) NSArray<LocalSongModel *> *filteredSongs;
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSNumber *> *allSongsDurations;
@property (strong, nonatomic) UIImageView *noSongsImageView;

@end

@implementation SavedMusicTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(didRecieveNewSong:) name:NOTIFICATION_DOWNLOAD_FINISHED object:nil];
    self.songListSearchController = [[UISearchController alloc] initWithSearchResultsController:nil];

    self.tableView.tableHeaderView = self.navigationItem.searchController.searchBar;

    self.allSongsDurations = [[NSMutableDictionary alloc] init];
    [self loadAllSongsDurations];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (self.songs.count == 0) {
        if (![self.view.subviews containsObject:self.noSongsImageView]) {
            self.noSongsImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"empty_chest_image"]];
            self.noSongsImageView.frame = CGRectMake(self.tableView.frame.size.width / 4, self.tableView.frame.size.height / 4, 200, 200);
            [self.view addSubview:self.noSongsImageView];
            [self.view addConstraint:
             [NSLayoutConstraint constraintWithItem:self.noSongsImageView
                                          attribute:NSLayoutAttributeCenterX
                                          relatedBy:0
                                             toItem:self.view
                                          attribute:NSLayoutAttributeCenterX
                                         multiplier:1
                                           constant:0]];
            
            [self.view addConstraint:
             [NSLayoutConstraint constraintWithItem:self.noSongsImageView
                                          attribute:NSLayoutAttributeCenterY
                                          relatedBy:0
                                             toItem:self.view
                                          attribute:NSLayoutAttributeCenterY
                                         multiplier:1
                                           constant:0]];
            
        }
    }
    else {
        [self.noSongsImageView removeFromSuperview];
    }
    
    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadAllSongsDurations {
    
    for (LocalSongModel *song in self.allSongs) {
        AVURLAsset *audioAsset = [[AVURLAsset alloc] initWithURL:song.localSongURL options:nil];
        NSNumber *duration = [NSNumber numberWithDouble:CMTimeGetSeconds(audioAsset.duration)];
        [self.allSongsDurations setObject:duration forKey:song.localSongURL.absoluteString];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.isFiltering) {
        return self.filteredSongs.count;
    }
    return self.songs.count;
}

-(NSString *)properMusicTitleForSong:(LocalSongModel *)song {
    
    NSString *songTitle = [[song.artistName stringByAppendingString:@" - "] stringByAppendingString:song.songTitle];
    if ([song.artistName isEqualToString:@"Unknown artist"]) {
        songTitle = song.songTitle;
    }

    return songTitle;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    SavedMusicTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"savedMusicCell" forIndexPath:indexPath];
    
    LocalSongModel *song = self.songs[indexPath.row];
    cell.musicTitle.text = [self properMusicTitleForSong:song];
    cell.songDurationLabel.text = [self extractSongDurationFromNumber:[self.allSongsDurations objectForKey:song.localSongURL.absoluteString]];
    
    if ([song isEqual:self.musicPlayerDelegate.nowPlaying]) {
        if (self.musicPlayerDelegate.isPlaying) {
            cell.circleProgressBar.unitString = BUTTON_TITLE_PAUSE_STRING;
            cell.circleProgressBar.textOffset = CGPointMake(-1.5, -1.5);
        }
    }
    else {
        cell.circleProgressBar.unitString = BUTTON_TITLE_PLAY_STRING;
        cell.circleProgressBar.textOffset = CGPointMake(0, -0.5);
        cell.circleProgressBar.value = 0;
    }
    
    return cell;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0f;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    LocalSongModel *song = self.songs[indexPath.row];
    if ([song isEqual:self.musicPlayerDelegate.nowPlaying]) {
        [self.musicPlayerDelegate pauseLoadedSong];
        [self.musicPlayerDelegate prepareSong:[self nextSongForSong:self.musicPlayerDelegate.nowPlaying]];
        [self.musicPlayerDelegate setPlayerPlayPauseButtonState:YES];
    }
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSError *error;
        [NSFileManager.defaultManager removeItemAtURL:song.localSongURL error:&error];
        UIImage *artwork = [UIImage imageWithData:[NSData dataWithContentsOfURL:song.localArtworkURL]];
        if (artwork != nil) {
            [NSFileManager.defaultManager removeItemAtURL:song.localArtworkURL error:&error];
        }
        if (error) {
            NSLog(@"Error deleting file from url = %@", error);
        }
        else {
            
//            remove from dataSource
            [self.allSongs removeObjectAtIndex:indexPath.row];
//            post notification that song is deleted and pass it
            [NSNotificationCenter.defaultCenter postNotificationName:NOTIFICATION_REMOVED_SONG_FROM_FILES object:nil userInfo:[NSDictionary dictionaryWithObject:song forKey:@"song"]];
            [PlaylistsDatabase removeSong:song];
            
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self didSelectSongFromCellForIndexPath:indexPath];
}

-(NSIndexPath *)indexPathOfLastPlayed {
    
    LocalSongModel *nowPlayingSong = self.musicPlayerDelegate.nowPlaying;
    NSIndexPath *indexPath;
    if (nowPlayingSong) {
        
        indexPath = [NSIndexPath indexPathForRow:[self.songs indexOfObject:nowPlayingSong] inSection:0] ;
    }
    
    return indexPath;
}

- (void)didSelectSongFromCellForIndexPath:(NSIndexPath *)indexPath {
    LocalSongModel *songToPlay = self.songs[indexPath.row];
    
    if (![songToPlay isEqual:self.musicPlayerDelegate.nowPlaying]) {
        [self clearProgressForCellAtIndexPath:self.indexPathOfLastPlayed];
        [self.musicPlayerDelegate prepareSong:songToPlay];
        [self.musicPlayerDelegate playLoadedSong];
        
        [self.musicPlayerDelegate setPlayerPlayPauseButtonState:NO];
        [self setMediaPlayBackState:EnumCellMediaPlaybackStatePause forCellAtIndexPath:indexPath];
    }
    else {
        if (self.musicPlayerDelegate.isPlaying) {
            
            [self.musicPlayerDelegate pauseLoadedSong];
            
            [self.musicPlayerDelegate setPlayerPlayPauseButtonState:YES];
            [self setMediaPlayBackState:EnumCellMediaPlaybackStatePlay forCellAtIndexPath:indexPath];
        }
        else {
            [self.musicPlayerDelegate playLoadedSong];
            
            [self.musicPlayerDelegate setPlayerPlayPauseButtonState:NO];
            [self setMediaPlayBackState:EnumCellMediaPlaybackStatePause forCellAtIndexPath:indexPath];
        }
    }
}

- (LocalSongModel *)previousSongForSong:(LocalSongModel *)song {
    
    NSIndexPath *indexPath = [self indexPathForSong:song];
    NSIndexPath *previousIndexPath = [NSIndexPath indexPathForRow:(indexPath.row - 1) inSection:indexPath.section];;
    
    if (previousIndexPath.row < 0) {
        previousIndexPath = [NSIndexPath indexPathForRow:self.songs.count - 1 inSection:indexPath.section];
    }
    
    return self.songs[previousIndexPath.row];
}

- (LocalSongModel *)nextSongForSong:(LocalSongModel *)song {
    
    NSIndexPath *indexPath = [self indexPathForSong:song];
    NSIndexPath *nextIndexPath = [NSIndexPath indexPathForRow:(indexPath.row + 1) % self.songs.count inSection:indexPath.section];
    
    return self.songs[nextIndexPath.row];
}

- (void)clearProgressForCellAtIndexPath:(NSIndexPath *)indexPath {
    SavedMusicTableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    [self setMediaPlayBackState:EnumCellMediaPlaybackStatePlay forCellAtIndexPath:indexPath];
    cell.circleProgressBar.value = 0;
}

- (void)setMediaPlayBackState:(EnumCellMediaPlaybackState) playbackState forCellAtIndexPath:(NSIndexPath *)indexPath {
    
    SavedMusicTableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    if (playbackState == EnumCellMediaPlaybackStatePlay) {
        
        cell.circleProgressBar.unitString = BUTTON_TITLE_PLAY_STRING;
        cell.circleProgressBar.textOffset = CGPointMake(0, -0.5);
    }
    else {
        
        cell.circleProgressBar.unitString = BUTTON_TITLE_PAUSE_STRING;
        cell.circleProgressBar.textOffset = CGPointMake(-1.5, -1.5);
    }
}

//TODO: Add optimisations for index path getting here
-(NSIndexPath *)indexPathForSong:(LocalSongModel *)song {
    
    NSInteger row = [self.songs indexOfObject:song];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
    
    return indexPath;
}

-(SavedMusicTableViewCell *)cellForSong:(LocalSongModel *)song {
    
    NSIndexPath *indexPath = [self indexPathForSong:song];
    SavedMusicTableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    return cell;
}

- (void)updateProgress:(double)progress forSong:(LocalSongModel *)song {
    
    SavedMusicTableViewCell *cell = [self cellForSong:song];
    cell.circleProgressBar.value = progress;
    if (progress >= 10) {
        cell.circleProgressBar.textOffset = CGPointMake(-3.5, -1.5);
    }
    else {
        cell.circleProgressBar.textOffset = CGPointMake(-2.5, -1.5);
    }
}

#pragma mark songListDelegate

- (void)didPauseSong:(LocalSongModel *)song {
    
    NSIndexPath *indexPath = [self indexPathForSong:song];
    [self setMediaPlayBackState:EnumCellMediaPlaybackStatePlay forCellAtIndexPath:indexPath];
}

- (void)didStartPlayingSong:(LocalSongModel *)song {
    
    NSIndexPath *indexPath = [self indexPathForSong:song];
    [self setMediaPlayBackState:EnumCellMediaPlaybackStatePause forCellAtIndexPath:indexPath];
}

- (void)didRequestNextForSong:(LocalSongModel *)song {
    
    NSIndexPath *indexPath = [self indexPathForSong:song];
    if (indexPath.row <= self.songs.count) {
        
        [self clearProgressForCellAtIndexPath:indexPath];
        
        LocalSongModel *nextSong = [self nextSongForSong:song];
        [self.musicPlayerDelegate prepareSong:nextSong];
        
        indexPath = [self indexPathForSong:nextSong];
        [self setMediaPlayBackState:EnumCellMediaPlaybackStatePause forCellAtIndexPath:indexPath];
    }
}

- (void)didRequestPreviousForSong:(LocalSongModel *)song {
    
    NSIndexPath *indexPath = [self indexPathForSong:song];
    if (indexPath.row <= self.songs.count) {
        
        [self clearProgressForCellAtIndexPath:indexPath];
        
        LocalSongModel *previousSong = [self previousSongForSong:song];
        [self.musicPlayerDelegate prepareSong:previousSong];
        
        indexPath = [self indexPathForSong:previousSong];
        [self setMediaPlayBackState:EnumCellMediaPlaybackStatePause forCellAtIndexPath:indexPath];
    }
}

- (void)didRecieveNewSong:(NSNotification *)notification {
    LocalSongModel *newSong = [notification.userInfo objectForKey:@"song"];
    [self.allSongs addObject:newSong];
    NSArray *paths = @[[NSIndexPath indexPathForRow:self.songs.count - 1 inSection:0]];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView insertRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationAutomatic];
    });
}

#pragma mark searchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    
    if (searchText.length > 0) {
        self.filteredSongs = [self.allSongs filteredArrayUsingPredicate:
                               [NSPredicate predicateWithBlock:^BOOL(LocalSongModel *evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            
            return ([[self properMusicTitleForSong:evaluatedObject].lowercaseString containsString:searchText.lowercaseString] ||
                    [evaluatedObject.songTitle.lowercaseString containsString:searchText.lowercaseString] ||
                    [evaluatedObject.artistName.lowercaseString containsString:searchText.lowercaseString]);
        }]];
    }
    [self.tableView reloadData];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = @"";
    [self.tableView reloadData];
}

- (BOOL)isFiltering {
    return ![self.songListSearchController.searchBar.text isEqualToString:@""];
}

- (NSArray<LocalSongModel *> *)songs {
    if (self.isFiltering) {
        return self.filteredSongs;
    }
    return self.allSongs;
}

#pragma mark Calculating Methods

- (NSString *)extractSongDurationFromNumber:(NSNumber *)duration {
    int songDuration = duration.intValue;
    int hours = songDuration / 3600;
    int minutes = (songDuration / 60) % 60;
    int seconds = songDuration % 60;
    
    if (hours == 0) {
        return [NSString stringWithFormat:@"%d:%d%d", minutes, (seconds / 10), (seconds % 10)];
    }
    else {
        return [NSString stringWithFormat:@"%d:%d%d:%d%d", hours, (minutes / 10), (minutes % 10), (seconds / 10), (seconds % 10)];
    }
}

@end
