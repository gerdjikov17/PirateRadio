//
//  ITunesDownloadManager.m
//  PirateRadio
//
//  Created by A-Team User on 18.05.18.
//  Copyright © 2018 A-Team User. All rights reserved.
//

#import "ITunesDownloadManager.h"
#import "ITunesRequestManager.h"
#import "LocalSongModel.h"

@interface ITunesDownloadManager ()

@property (strong, nonatomic) NSURLSession *session;
@property (strong, nonatomic) NSMutableDictionary<NSURLSessionDownloadTask *, LocalSongModel *> *downloadDict;

@end


@implementation ITunesDownloadManager

+ (instancetype)sharedInstance {
    static ITunesDownloadManager *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

- (instancetype) init {
    self = [super init];
    if (self) {
        self.downloadDict = [[NSMutableDictionary alloc] init];
        self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"itunesDownload"] delegate:self delegateQueue:nil];
    }
    return self;
}


- (void)downloadArtworkForLocalSongModel:(LocalSongModel *)localSong {
    [ITunesRequestManager makeLastFMSearchRequestWithKeywords:localSong.keywordsFromAuthorAndTitle andCompletion:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSError *serializationError;
        NSDictionary<NSString *, id> *responseDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&serializationError];
        if (serializationError) {
            NSLog(@"serializationError = %@", serializationError);
        }
        else {
            if ([[responseDict objectForKey:@"results"] count] > 0) {
                NSLog(@"Found artwork");
                NSArray *track = [[[responseDict objectForKey:@"results"] objectForKey:@"albummatches"] objectForKey:@"album"];
                if (track.count > 0) {
                    NSDictionary *thumbDictionary = [[track[0] objectForKey:@"image"] objectAtIndex:3];
                    
                    NSURL *artworkURL = [NSURL URLWithString:[thumbDictionary objectForKey:@"#text"]];
                    NSURLSessionDownloadTask *downloadTask = [self.session downloadTaskWithURL:artworkURL];
                    [self.downloadDict setObject:localSong forKey:downloadTask];
                    [downloadTask resume];
                }
            }
        }
    }];
}


- (void)URLSession:(nonnull NSURLSession *)session downloadTask:(nonnull NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(nonnull NSURL *)location {
    NSError *err;
    NSURL *urlToSave = self.downloadDict[downloadTask].localArtworkURL;
    [NSFileManager.defaultManager moveItemAtURL:location toURL:urlToSave error:&err];
    if (err) {
        NSLog(@"Error moving item = %@", err);
    }
    
}

@end
