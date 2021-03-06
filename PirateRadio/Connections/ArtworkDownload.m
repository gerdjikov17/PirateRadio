//
//  ArtworkDownload.m
//  PirateRadio
//
//  Created by A-Team User on 18.05.18.
//  Copyright © 2018 A-Team User. All rights reserved.
//

#import "ArtworkDownload.h"
#import "ArtworkRequest.h"
#import "LocalSongModel.h"
#import "Constants.h"
#import "Reachability.h"
#import "DropBox.h"

@interface ArtworkDownload ()

@property (strong, nonatomic) NSURLSession *session;
@property (strong, nonatomic) NSMutableDictionary<NSNumber *, NSString *> *downloadDict;

@end


@implementation ArtworkDownload

+ (instancetype)sharedInstance {
    static ArtworkDownload *sharedMyManager = nil;
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


- (void)downloadArtworkForLocalSongModelWithUniqueName:(NSString *)localSongUniqueName {
    LocalSongModel *localSong = [LocalSongModel objectForPrimaryKey:localSongUniqueName];
    NSArray *keywords = localSong.keywordsFromAuthorAndTitle;
    [ArtworkRequest makeLastFMSearchRequestWithKeywords:keywords andCompletion:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSError *serializationError;
        NSDictionary<NSString *, id> *responseDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&serializationError];
        if (serializationError) {
            NSLog(@"serializationError = %@", serializationError);
        }
        else {
            if ([[responseDict objectForKey:@"results"] count] > 0) {
                NSArray *track = [[[responseDict objectForKey:@"results"] objectForKey:@"albummatches"] objectForKey:@"album"];
                if (track.count > 0) {
                    NSDictionary *thumbDictionary = [[track[0] objectForKey:@"image"] objectAtIndex:3];
                    
                    NSURL *artworkURL = [NSURL URLWithString:[thumbDictionary objectForKey:@"#text"]];
                    if (artworkURL != nil) {
                        if ([artworkURL.absoluteString isEqualToString:@""]) {
                            [self downloadArtworkByTitleForLocalSongModelWithUniqueName:localSongUniqueName];
                        }
                        else {
                            NSLog(@"Found artwork");
                            NSURLSessionDownloadTask *downloadTask = [self.session downloadTaskWithURL:artworkURL];
                            [self.downloadDict setObject:localSongUniqueName forKey:[NSNumber numberWithUnsignedInteger:downloadTask.taskIdentifier]];
                            [downloadTask resume];
                        }
                    }
                    
                }
            }
        }
    }];
}

- (void)downloadArtworkByTitleForLocalSongModelWithUniqueName:(NSString *)localSongUniqueName {
    NSArray *keywordsFromTitle = [LocalSongModel objectForPrimaryKey:localSongUniqueName].keywordsFromTitle;
    [ArtworkRequest makeLastFMSearchRequestWithKeywords:keywordsFromTitle andCompletion:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSError *serializationError;
        NSDictionary<NSString *, id> *responseDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&serializationError];
        if (serializationError) {
            NSLog(@"serializationError = %@", serializationError);
        }
        else {
            if ([[responseDict objectForKey:@"results"] count] > 0) {
                NSArray *track = [[[responseDict objectForKey:@"results"] objectForKey:@"albummatches"] objectForKey:@"album"];
                if (track.count > 0) {
                    NSDictionary *thumbDictionary = [[track[0] objectForKey:@"image"] objectAtIndex:3];
                    
                    NSURL *artworkURL = [NSURL URLWithString:[thumbDictionary objectForKey:@"#text"]];
                    if (artworkURL != nil && ![artworkURL.absoluteString isEqualToString:@""]) {
                            NSLog(@"Found artwork");
                            NSURLSessionDownloadTask *downloadTask = [self.session downloadTaskWithURL:artworkURL];
                            [self.downloadDict setObject:localSongUniqueName forKey:[NSNumber numberWithUnsignedInteger:downloadTask.taskIdentifier]];
                            [downloadTask resume];
                    }
                    
                }
            }
        }
    }];
}

- (void)URLSession:(nonnull NSURLSession *)session downloadTask:(nonnull NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(nonnull NSURL *)location {
    NSError *err;
    NSString *songUniqueName = [self.downloadDict objectForKey:[NSNumber numberWithUnsignedInteger:downloadTask.taskIdentifier]];
    LocalSongModel *song = [LocalSongModel objectForPrimaryKey:songUniqueName];
    NSURL *urlToSave = song.localArtworkURL;
    [NSFileManager.defaultManager moveItemAtURL:location toURL:urlToSave error:&err];
    if (err) {
        NSLog(@"Error moving item = %@", err);
    }
    else {
        Reachability *reachability = [Reachability reachabilityForInternetConnection];
        if (reachability.isReachable && [NSUserDefaults.standardUserDefaults boolForKey:USER_DEFAULTS_UPLOAD_TO_DROPBOX]) {
            [DropBox uploadArtworkForLocalSong:song];
        }
    }
    
}

@end
