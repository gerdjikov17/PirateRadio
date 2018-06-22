//
//  YoutubeDownloadManager.m
//  PirateRadio
//
//  Created by A-Team User on 11.05.18.
//  Copyright © 2018 A-Team User. All rights reserved.
//

#import "YoutubeDownloadManager.h"
#import "DownloadModel.h"
#import "ITunesRequestManager.h"
#import "ITunesDownloadManager.h"
#import "LocalSongModel.h"
#import "Constants.h"

@interface YoutubeDownloadManager ()

@property (strong, nonatomic) NSMutableDictionary<id, DownloadModel *> *downloads;
@property (strong, nonatomic) NSURLSession *youtubeSession;

@end

@implementation YoutubeDownloadManager

+ (instancetype)sharedInstance {
    static YoutubeDownloadManager *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.downloads = [[NSMutableDictionary alloc] init];
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"youtubeDownload"];
        configuration.waitsForConnectivity = YES;
        configuration.shouldUseExtendedBackgroundIdleMode = YES;
        self.youtubeSession = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    }
    return self;
}

- (void)downloadVideoWithDownloadModel:(DownloadModel *)download {
    
    NSURLSessionDownloadTask *downloadTask = [self.youtubeSession downloadTaskWithURL:download.URL];
    [self.downloads setObject:download forKey:downloadTask];
    
    [downloadTask resume];
}

- (void)URLSession:(nonnull NSURLSession *)session downloadTask:(nonnull NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(nonnull NSURL *)location {
    
    NSFileManager *fileManager = NSFileManager.defaultManager;
    
    DownloadModel *download = self.downloads[downloadTask];
    NSURL *localURL = download.localURLWithTimeStamp;
    
    NSError *error;
    [fileManager moveItemAtURL:location toURL:localURL.absoluteURL error:&error];
    
    if (error) {
        NSLog(@"error = %@", error.localizedDescription);
    }
    else {
        LocalSongModel *song = [[LocalSongModel alloc] initWithLocalSongURL:localURL];
        [ITunesDownloadManager.sharedInstance downloadArtworkForLocalSongModel:song];
        [self.downloads removeObjectForKey:downloadTask];
        [NSNotificationCenter.defaultCenter postNotificationName:NOTIFICATION_DOWNLOAD_FINISHED object:nil userInfo:[NSDictionary dictionaryWithObject:song forKey:@"song"]];
    }
    [self.youtubeSession resetWithCompletionHandler:^{
        
    }];
}


@end
