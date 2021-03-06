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
#import "AudioStreamNotificationCenter.h"

@import MediaPlayer;
@import AVFoundation;

@interface MusicPlayerViewController ()

@property (weak, nonatomic) IBOutlet UILabel *elapsedTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLeftLabel;
@property (strong, nonatomic) AVPlayerItem *currentItem;
@property BOOL isSeekInProgress;
@property CMTime chaseTime;
@property BOOL isSliding;

@end

@implementation MusicPlayerViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    [self configureMusicControllerView];
    
    __weak MusicPlayerViewController *weakSelf = self;
    [PirateAVPlayer.sharedPlayer addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1.0 / 60.0, NSEC_PER_SEC) queue:NULL usingBlock:^(CMTime time) {
        [weakSelf updateProgressBar];
    }];
    
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(pauseLoadedSong) name:NOTIFICATION_YOUTUBE_VIDEO_STARTED_PLAYING object:nil];
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self becomeFirstResponder];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self updateCommandCenterRemoteControlTargets];
    [AudioStreamNotificationCenter.defaultCenter addAudioStreamObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self updateMusicPlayerContent];
    
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)dealloc {
    [self.currentItem removeObserver:self forKeyPath:@"status"];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)updateProgressBar {
    double duration = CMTimeGetSeconds(PirateAVPlayer.sharedPlayer.currentItem.duration);
    double time = CMTimeGetSeconds(PirateAVPlayer.sharedPlayer.currentTime);
    if (!self.isSliding) {
        
        self.songTimeProgress.value = (time / duration) * 100;
    }
    [self setTime:time andDuration:duration];
    
}

- (void)configureMusicControllerView {
    [self.songTimeProgress addTarget:self action:@selector(sliderIsSliding) forControlEvents:UIControlEventValueChanged];
    [self.songTimeProgress addTarget:self action:@selector(sliderEndedSliding) forControlEvents:UIControlEventTouchUpInside];
    [self.songTimeProgress addTarget:self action:@selector(sliderEndedSliding) forControlEvents:UIControlEventTouchUpOutside];
    
    self.songTimeProgress.maximumValue = 100;
    self.songTimeProgress.value = 0.0f;
    self.songName.textAlignment = NSTextAlignmentCenter;
}

- (void)prepareSong:(LocalSongModel *)song {
    
    if (![PirateAVPlayer.sharedPlayer.currentSong.localSongURL isEqual:song.localSongURL]) {
        PirateAVPlayer.sharedPlayer.currentSong = song;
        PirateAVPlayer.sharedPlayer.playerCurrentItemStatus = AVPlayerItemStatusUnknown;
        
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:song.localSongURL options:nil];
        self.currentItem = [AVPlayerItem playerItemWithAsset:asset];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(itemDidEndPlaying:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.currentItem];
        [PirateAVPlayer.sharedPlayer replaceCurrentItemWithPlayerItem:self.currentItem];
        NSKeyValueObservingOptions options = NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;
       
        // Register as an observer of the player item's status property
        [self.currentItem addObserver:self forKeyPath:@"status" options:options context:nil];
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
    [self playPauseStream];
}

- (IBAction)previousBtnTap:(id)sender {
    
    [self.songListDelegate didRequestPreviousForSong:PirateAVPlayer.sharedPlayer.currentSong];
}

- (IBAction)nextBtnTap:(id)sender {
    
    [self.songListDelegate didRequestNextForSong:PirateAVPlayer.sharedPlayer.currentSong];
}

- (void)playPauseStream {
    if (PirateAVPlayer.sharedPlayer.currentSong != nil) {
        if (self.isPlaying) {
            
            [self pauseLoadedSong];
            [self.playButton setImage:[UIImage imageNamed:@"play_button_icon"] forState:UIControlStateNormal];
            
            [self.songListDelegate didPauseSong:PirateAVPlayer.sharedPlayer.currentSong];
        }
        else {
            
            [self playLoadedSong];
            [self.playButton setImage:[UIImage imageNamed:@"pause_button_icon"] forState:UIControlStateNormal];
            
            [self.songListDelegate didStartPlayingSong:PirateAVPlayer.sharedPlayer.currentSong];
        }
    }
}

- (void)itemDidEndPlaying:(NSNotification *)notification {
    
    
//        I will hate myself for doing this....
    [PirateAVPlayer.sharedPlayer play];
    //    it's ok for now
    [self.songListDelegate didRequestNextForSong:PirateAVPlayer.sharedPlayer.currentSong];
    [PirateAVPlayer.sharedPlayer play];
    
    [MPNowPlayingInfoCenter.defaultCenter setPlaybackState:MPNowPlayingPlaybackStatePlaying];
}

- (void)updateMusicPlayerContent {
    
    UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:PirateAVPlayer.sharedPlayer.currentSong.localArtworkURL]];
    if (!image) {
        self.songImage.image = [UIImage imageNamed:@"unknown_artist"];
    }
    else {
        self.songImage.image = image;
    }
    self.songName.text = PirateAVPlayer.sharedPlayer.currentSong.songTitle;
    
    if (PirateAVPlayer.sharedPlayer.currentSong && self.isPlaying) {
        [self.playButton setImage:[UIImage imageNamed:@"pause_button_icon"] forState:UIControlStateNormal];
    }
    else {
        [self.playButton setImage:[UIImage imageNamed:@"play_button_icon"] forState:UIControlStateNormal];
//                tell the songList that song is paused;
        [self.songListDelegate didPauseSong:PirateAVPlayer.sharedPlayer.currentSong];
    }
    
    UIGraphicsBeginImageContext(self.view.frame.size);
    [image drawInRect:self.view.bounds blendMode:kCGBlendModeNormal alpha:0.15f];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    self.view.backgroundColor = [UIColor colorWithPatternImage:image];

}

- (void)sliderIsSliding {
    
    self.isSliding = YES;
}

-(void) sliderEndedSliding {
    
    [self stopPlayingAndSeekSmoothlyToTime:CMTimeMake((self.songTimeProgress.value * CMTimeGetSeconds(PirateAVPlayer.sharedPlayer.currentItem.duration) / 100) * 600, 600)];
    self.isSliding = NO;
}


- (void)stopPlayingAndSeekSmoothlyToTime:(CMTime)newChaseTime {
    
    [PirateAVPlayer.sharedPlayer pause];

    if (CMTIME_COMPARE_INLINE(newChaseTime, !=, self.chaseTime)) {
        
        self.chaseTime = newChaseTime;
        if (!self.isSeekInProgress) {
            
            [self trySeekToChaseTime];
        }
    }
}

- (void)trySeekToChaseTime {
    
    if (PirateAVPlayer.sharedPlayer.playerCurrentItemStatus == AVPlayerItemStatusUnknown) {
        // wait until item becomes ready (KVO player.currentItem.status)
    }
    else if (PirateAVPlayer.sharedPlayer.playerCurrentItemStatus == AVPlayerItemStatusReadyToPlay) {
        [self actuallySeekToTime];
    }
}

- (void)actuallySeekToTime {
    
    self.isSeekInProgress = YES;
    CMTime seekTimeInProgress = self.chaseTime;
    [PirateAVPlayer.sharedPlayer seekToTime:seekTimeInProgress toleranceBefore:kCMTimeZero
             toleranceAfter:kCMTimeZero completionHandler:
     ^(BOOL isFinished) {
         if (CMTIME_COMPARE_INLINE(seekTimeInProgress, ==, self.chaseTime)) {
             
             self.isSeekInProgress = NO;
             if ([self.playButton.currentImage isEqual:[UIImage imageNamed:@"pause_button_icon"]]) {
                 [PirateAVPlayer.sharedPlayer play];
             }
             [self updateMPNowPlayingInfoCenterWithLoadedSongInfo];
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
                PirateAVPlayer.sharedPlayer.playerCurrentItemStatus = AVPlayerStatusReadyToPlay;
                [self updateMPNowPlayingInfoCenterWithLoadedSongInfo];
                [self setTime:CMTimeGetSeconds(PirateAVPlayer.sharedPlayer.currentTime) andDuration:CMTimeGetSeconds(PirateAVPlayer.sharedPlayer.currentItem.duration)];
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
    
    [NSNotificationCenter.defaultCenter postNotificationName:NOTIFICATION_AVPLAYER_STARTED_PLAYING object:nil];
    
    [PirateAVPlayer.sharedPlayer play];
    
    [self updateMPNowPlayingInfoCenterWithLoadedSongInfo];
}

- (void)pauseLoadedSong {
    
    [PirateAVPlayer.sharedPlayer pause];
    
    [self updateMPNowPlayingInfoCenterWithLoadedSongInfo];
}

- (BOOL)isPlaying {
    
    return PirateAVPlayer.sharedPlayer.timeControlStatus == AVPlayerTimeControlStatusPlaying | PirateAVPlayer.sharedPlayer.timeControlStatus == AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate;
}

- (LocalSongModel *)nowPlaying {
    return PirateAVPlayer.sharedPlayer.currentSong;
}

- (void)setPlayerPlayPauseButtonState:(BOOL)play {
    
    [self.playButton setImage:[UIImage imageNamed:@"play_button_icon"] forState:UIControlStateNormal];
    if (!play) {
        
        [self.playButton setImage:[UIImage imageNamed:@"pause_button_icon"] forState:UIControlStateNormal];
    }
}

- (void)updateMPNowPlayingInfoCenterWithLoadedSongInfo {
    if ([MPNowPlayingInfoCenter class])  {
        double playbackRate;
        if ([self isPlaying]) {
            playbackRate = 1;
            [MPNowPlayingInfoCenter.defaultCenter setPlaybackState:MPNowPlayingPlaybackStatePlaying];
        }
        else {
            playbackRate = 0;
            [MPNowPlayingInfoCenter.defaultCenter setPlaybackState:MPNowPlayingPlaybackStatePaused];
        }
        
        NSNumber *elapsedTime = [NSNumber numberWithDouble:CMTimeGetSeconds(PirateAVPlayer.sharedPlayer.currentTime)];
        NSNumber *duration = [NSNumber numberWithDouble:CMTimeGetSeconds(PirateAVPlayer.sharedPlayer.currentItem.duration)];
        __block UIImage *image = [[UIImage alloc] initWithData:[NSData dataWithContentsOfURL:PirateAVPlayer.sharedPlayer.currentSong.localArtworkURL]];
        MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithBoundsSize:CGSizeMake(50, 50) requestHandler:^UIImage * _Nonnull(CGSize size) {
            if (!image) {
                image = [UIImage imageNamed:@"unknown_artist"];
            }
            return image;
        }];
        NSDictionary *info = @{ MPMediaItemPropertyArtist: PirateAVPlayer.sharedPlayer.currentSong.artistName,
                                MPMediaItemPropertyTitle: PirateAVPlayer.sharedPlayer.currentSong.songTitle,
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
    int elapsedHours = (int)time / 3600;
    int elapsedMinutes = ((int)time / 60) % 60;
    int elapsedSeconds = (int)time % 60;
    int hoursLeft = ((int)duration - (int)time) / 3600;
    int minutesLeft = (((int)duration - (int)time) / 60) % 60;
    int secondsLeft = ((int)duration - (int)time) % 60;
    
    if (elapsedHours + hoursLeft > 0) {
        self.elapsedTimeLabel.text = [NSString stringWithFormat:@"%d:%d%d:%d%d", elapsedHours, (elapsedMinutes / 10), (elapsedMinutes % 10), (elapsedSeconds / 10), (elapsedSeconds % 10)];
        self.timeLeftLabel.text = [NSString stringWithFormat:@"%d:%d%d:%d%d", hoursLeft, (minutesLeft / 10), (minutesLeft % 10), (secondsLeft / 10), (secondsLeft % 10)];
    }
    else {
        self.elapsedTimeLabel.text = [NSString stringWithFormat:@"%d:%d%d", elapsedMinutes, (elapsedSeconds / 10), (elapsedSeconds % 10)];
        self.timeLeftLabel.text = [NSString stringWithFormat:@"-%d:%d%d", minutesLeft, (secondsLeft / 10), (secondsLeft % 10)];
    }
}

@end
