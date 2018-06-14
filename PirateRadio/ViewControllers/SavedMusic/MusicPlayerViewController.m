//
//  MusicControllerView.m
//  PirateRadio
//
//  Created by A-Team User on 15.05.18.
//  Copyright © 2018 A-Team User. All rights reserved.
//

#import "MusicPlayerViewController.h"
#import "LocalSongModel.h"
#import "Constants.h"
#import "CBAutoScrollLabel.h"
#import "PirateAVPlayer.h"
@import MediaPlayer;
@import AVFoundation;

@interface MusicPlayerViewController ()

@property (strong, nonatomic) PirateAVPlayer *player;
@property BOOL isSeekInProgress;
@property BOOL isSliding;
@property CMTime chaseTime;
@property (weak, nonatomic) IBOutlet UILabel *elapsedTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLeftLabel;

@end

@implementation MusicPlayerViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    self.player = PirateAVPlayer.sharedPlayer;
    
    [self configureMusicControllerView];
    
    __weak MusicPlayerViewController *weakSelf = self;
    [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1.0 / 60.0, NSEC_PER_SEC) queue:NULL usingBlock:^(CMTime time) {
        [weakSelf updateProgressBar];
    }];
    
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(pauseLoadedSong) name:NOTIFICATION_YOUTUBE_VIDEO_STARTED_PLAYING object:nil];

    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self becomeFirstResponder];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self updateMusicPlayerContent];
    
    
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)updateProgressBar {
    double duration = CMTimeGetSeconds(self.player.currentItem.duration);
    double time = CMTimeGetSeconds(self.player.currentTime);
    if (!self.isSliding) {
        
        self.songTimeProgress.value = (time / duration) * 100;
        [self.songListDelegate updateProgress:(time / duration) * 100 forSong:self.player.currentSong];
    }
    [self setTime:time andDuration:duration];
    
}


- (void)configureMusicControllerView {
    [self.songTimeProgress addTarget:self action:@selector(sliderIsSliding) forControlEvents:UIControlEventValueChanged];
    [self.songTimeProgress addTarget:self action:@selector(sliderEndedSliding) forControlEvents:UIControlEventTouchUpInside];
    
    self.songTimeProgress.maximumValue = 100;
    self.songTimeProgress.value = 0.0f;
    self.songName.textAlignment = NSTextAlignmentCenter;
}

- (void)prepareSong:(LocalSongModel *)song {
    
    if (![self.player.currentSong.localSongURL isEqual:song.localSongURL]) {
        self.player.currentSong = song;
        self.player.playerCurrentItemStatus = AVPlayerItemStatusUnknown;
        
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:song.localSongURL options:nil];
        AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(itemDidEndPlaying:) name:AVPlayerItemDidPlayToEndTimeNotification object:item];
        [self.player replaceCurrentItemWithPlayerItem:item];
        NSKeyValueObservingOptions options = NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;
    
        [self updateMPNowPlayingInfoCenterWithLoadedSongInfoAndPlaybackRate:0];
        // setting duration not working.
        
        // Register as an observer of the player item's status property
        [item addObserver:self forKeyPath:@"status" options:options context:nil];
        [self updateMusicPlayerContent];
        [self updateCommandCenterRemoteControlTargets];
    }
}

- (void)updateCommandCenterRemoteControlTargets {

    [MPRemoteCommandCenter.sharedCommandCenter.playCommand removeTarget:nil];
    [MPRemoteCommandCenter.sharedCommandCenter.pauseCommand removeTarget:nil];
    [MPRemoteCommandCenter.sharedCommandCenter.nextTrackCommand removeTarget:nil];
    [MPRemoteCommandCenter.sharedCommandCenter.previousTrackCommand removeTarget:nil];
    [MPRemoteCommandCenter.sharedCommandCenter.changePlaybackPositionCommand removeTarget:nil];

    
    [MPRemoteCommandCenter.sharedCommandCenter.playCommand addTarget:self action:@selector(musicControllerPlayBtnTap:)];
    [MPRemoteCommandCenter.sharedCommandCenter.pauseCommand addTarget:self action:@selector(musicControllerPlayBtnTap:)];
    [MPRemoteCommandCenter.sharedCommandCenter.nextTrackCommand addTarget:self action:@selector(nextBtnTap:)];
    [MPRemoteCommandCenter.sharedCommandCenter.previousTrackCommand addTarget:self action:@selector(previousBtnTap:)];
    [MPRemoteCommandCenter.sharedCommandCenter.changePlaybackPositionCommand addTarget:self action:@selector(changedPlaybackPositionFromCommandCenter:)];
}



- (IBAction)musicControllerPlayBtnTap:(id)sender {
    if (self.isPlaying) {
        
        [self pauseLoadedSong];
        [self.playButton setImage:[UIImage imageNamed:@"play_button_icon"] forState:UIControlStateNormal];
        
        [self.songListDelegate didPauseSong:self.player.currentSong];
    }
    else {
        
        [self playLoadedSong];
        [self.playButton setImage:[UIImage imageNamed:@"pause_button_icon"] forState:UIControlStateNormal];
        
        [self.songListDelegate didStartPlayingSong:self.player.currentSong];
    }
}

- (IBAction)previousBtnTap:(id)sender {
    
    [self.songListDelegate didRequestPreviousForSong:self.player.currentSong];
}

- (IBAction)nextBtnTap:(id)sender {
    
    [self.songListDelegate didRequestNextForSong:self.player.currentSong];
}

- (void)itemDidEndPlaying:(NSNotification *)notification {
    
    
    //    I will hate myself for doing this....
    [self.player play];
    //    it's ok for now
    [self.songListDelegate didRequestNextForSong:self.player.currentSong];
    [self.player play];
    
    // this is for testing
//    [self startAudioSession];
    [MPNowPlayingInfoCenter.defaultCenter setPlaybackState:MPNowPlayingPlaybackStatePlaying];
}

- (void)updateMusicPlayerContent {
    
    UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:self.player.currentSong.localArtworkURL]];
    if (image) {
        
        self.songImage.image = image;
    }
    else {
        
        self.songImage.image = [UIImage imageNamed:@"unknown_artist_transperent"];
    }
    self.songName.text = self.player.currentSong.songTitle;
    
    if (self.player.currentSong && self.isPlaying) {
        [self.playButton setImage:[UIImage imageNamed:@"pause_button_icon"] forState:UIControlStateNormal];
    }
    else {
        [self.playButton setImage:[UIImage imageNamed:@"play_button_icon"] forState:UIControlStateNormal];
        
        //        tell the songList that song is paused;
        [self.songListDelegate didPauseSong:self.player.currentSong];
    }
    
}


- (void)sliderIsSliding {
    
    self.isSliding = YES;
}

-(void) sliderEndedSliding {
    
    [self stopPlayingAndSeekSmoothlyToTime:CMTimeMake((self.songTimeProgress.value * CMTimeGetSeconds(self.player.currentItem.duration) / 100) * 600, 600)];
    self.isSliding = NO;
}


- (void)stopPlayingAndSeekSmoothlyToTime:(CMTime)newChaseTime {
    
    [self.player pause];
    
    NSLog(@"time = %lf", CMTimeGetSeconds(newChaseTime));
    if (CMTIME_COMPARE_INLINE(newChaseTime, !=, self.chaseTime)) {
        
        self.chaseTime = newChaseTime;
        if (!self.isSeekInProgress) {
            
            [self trySeekToChaseTime];
        }
    }
}

- (void)trySeekToChaseTime {
    
    if (self.player.playerCurrentItemStatus == AVPlayerItemStatusUnknown) {
        // wait until item becomes ready (KVO player.currentItem.status)
    }
    else if (self.player.playerCurrentItemStatus == AVPlayerItemStatusReadyToPlay) {
        [self actuallySeekToTime];
    }
}

- (void)actuallySeekToTime {
    
    self.isSeekInProgress = YES;
    CMTime seekTimeInProgress = self.chaseTime;
    [self.player seekToTime:seekTimeInProgress toleranceBefore:kCMTimeZero
             toleranceAfter:kCMTimeZero completionHandler:
     ^(BOOL isFinished) {
         if (CMTIME_COMPARE_INLINE(seekTimeInProgress, ==, self.chaseTime)) {
             
             [self updateMPNowPlayingInfoCenterWithLoadedSongInfoAndPlaybackRate:1.0];
             
             self.isSeekInProgress = NO;
             
             if ([self.playButton.currentImage isEqual:[UIImage imageNamed:@"pause_button_icon"]]) {
                 [self.player play];
             }
         }
         else{
             [self trySeekToChaseTime];
         }
     }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItemStatus status = AVPlayerItemStatusUnknown;
        // Get the status change from the change dictionary
        NSNumber *statusNumber = change[NSKeyValueChangeNewKey];
        if ([statusNumber isKindOfClass:[NSNumber class]]) {
            status = statusNumber.integerValue;
        }
        // Switch over the status
        switch (status) {
            case AVPlayerItemStatusReadyToPlay:
                // Ready to Play
                self.player.playerCurrentItemStatus = AVPlayerStatusReadyToPlay;
                [self updateMPNowPlayingInfoCenterWithLoadedSongInfoAndPlaybackRate:1.0];
                [self setTime:CMTimeGetSeconds(self.player.currentTime) andDuration:CMTimeGetSeconds(self.player.currentItem.duration)];
                break;
            case AVPlayerItemStatusFailed:
                // Failed. Examine AVPlayerItem.error
                break;
            case AVPlayerItemStatusUnknown:
                // Not ready
                break;
        }
    }
}

- (void)playLoadedSong {
    
    [MPNowPlayingInfoCenter.defaultCenter setPlaybackState:MPNowPlayingPlaybackStatePlaying];
    
    [self updateMPNowPlayingInfoCenterWithLoadedSongInfoAndPlaybackRate:1.0];
    
    [self.player play];
    
    
}

- (void)pauseLoadedSong {
    
    [MPNowPlayingInfoCenter.defaultCenter setPlaybackState:MPNowPlayingPlaybackStatePaused];
    
    [self updateMPNowPlayingInfoCenterWithLoadedSongInfoAndPlaybackRate:0.0];
    
    [self.player pause];
}

- (BOOL)isPlaying {
    
    return self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying;
}

- (LocalSongModel *)nowPlaying {
    return self.player.currentSong;
}

- (void)setPlayerPlayPauseButtonState:(BOOL)play {
    
    [self.playButton setImage:[UIImage imageNamed:@"play_button_icon"] forState:UIControlStateNormal];
    if (!play) {
        
        [self.playButton setImage:[UIImage imageNamed:@"pause_button_icon"] forState:UIControlStateNormal];
    }
}

- (void)startAudioSession {
    AVAudioSession *session = AVAudioSession.sharedInstance;
    NSError *error;
    [session setCategory:AVAudioSessionCategoryPlayback error:&error];
    [session setMode:AVAudioSessionModeDefault error:nil];
    
    if (error) {
        NSLog(@"Error = %@", error);
    }
    else {
        [session setActive:YES error:&error];
    }
    if (error) {
        NSLog(@"Error = %@", error);
    }
}

- (void)updateMPNowPlayingInfoCenterWithLoadedSongInfoAndPlaybackRate:(double)playbackRate {
    if ([MPNowPlayingInfoCenter class])  {
        
        NSNumber *elapsedTime = [NSNumber numberWithDouble:CMTimeGetSeconds(self.player.currentTime)];
        NSNumber *duration = [NSNumber numberWithDouble:CMTimeGetSeconds(self.player.currentItem.duration)];
        MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithBoundsSize:CGSizeMake(50, 50) requestHandler:^UIImage * _Nonnull(CGSize size) {
            UIImage *image = [[UIImage alloc] initWithData:[NSData dataWithContentsOfURL:self.player.currentSong.localArtworkURL]];
            if (!image) {
                image = [UIImage imageNamed:@"unknown_artist_transperent"];
            }
            return image;
        }];
        NSDictionary *info = @{ MPMediaItemPropertyArtist: self.player.currentSong.artistName,
                                MPMediaItemPropertyTitle: self.player.currentSong.songTitle,
                                MPMediaItemPropertyPlaybackDuration: duration,
                                MPMediaItemPropertyArtwork: artwork,
                                MPNowPlayingInfoPropertyPlaybackRate: [NSNumber numberWithDouble:playbackRate],
                                MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsedTime,
                                };
        [MPNowPlayingInfoCenter.defaultCenter setNowPlayingInfo:info];
        
    }
}

- (void)changedPlaybackPositionFromCommandCenter:(MPChangePlaybackPositionCommandEvent *)event {
    CMTime time = CMTimeMake((double)event.positionTime * 600, 600);
    [self stopPlayingAndSeekSmoothlyToTime:time];
}

- (void)setTime:(double)time andDuration:(double)duration {
    int elapsedMinutes = ((int)time / 60) % 60;
    int elapsedSeconds = (int)time % 60;
    int minutesLeft = (((int)duration - (int)time) / 60) % 60;
    int secondsLeft = ((int)duration - (int)time) % 60;
    
    self.elapsedTimeLabel.text = [NSString stringWithFormat:@"%d:%d%d", elapsedMinutes, (elapsedSeconds / 10), (elapsedSeconds % 10)];
    self.timeLeftLabel.text = [NSString stringWithFormat:@"-%d:%d%d", minutesLeft, (secondsLeft / 10), (secondsLeft % 10)];
}

@end
