//
//  AllSongsTableViewController.m
//  PirateRadio
//
//  Created by A-Team User on 5.06.18.
//  Copyright © 2018 A-Team User. All rights reserved.
//

#import "AllSongsTableViewController.h"
#import "PlaylistModel.h"
#import "LocalSongModel.h"
#import "SongListPlusPlayerViewController.h"
#import "Constants.h"
#import "PlaylistsDatabase.h"

@interface AllSongsTableViewController ()<UISearchBarDelegate>

@property (strong, nonatomic) NSMutableArray<LocalSongModel *> *allSongs;
@property (strong, nonatomic) NSArray<LocalSongModel *> *filteredSongs;
@property (strong, nonatomic) NSMutableArray<LocalSongModel *> *selectedSongs;
@property (strong, nonatomic) UISearchController *searchController;

@end

@implementation AllSongsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadSongsFromDisk];
    self.selectedSongs = [[NSMutableArray alloc] init];
    self.navigationItem.title = @"Songs to add";
    
    UIBarButtonItem *commitSelectedButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(commitSelected)];
    self.navigationItem.rightBarButtonItem = commitSelectedButton;
    
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.dimsBackgroundDuringPresentation = NO;
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.searchController.searchBar.delegate = self;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadSongsFromDisk {
    
    self.allSongs = [[NSMutableArray alloc] init];
    NSURL *sourcePath = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask][0];
    sourcePath = [sourcePath URLByAppendingPathComponent:@"songs"];
    NSArray* dirs = [NSFileManager.defaultManager contentsOfDirectoryAtURL:sourcePath includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    [dirs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *filePath = ((NSURL *)obj).absoluteString;
        NSString *extension = [[filePath pathExtension] lowercaseString];
        if ([extension isEqualToString:@"mp3"]) {
            LocalSongModel *localSong = [[LocalSongModel alloc] initWithLocalSongURL:[NSURL URLWithString:filePath]];
            if (![self.playlist.songs containsObject:localSong]) {
                [self.allSongs addObject:localSong];
            }
        }
    }];
    
    [self.tableView reloadData];
}

- (void)commitSelected {
    [self.playlist.songs addObjectsFromArray:self.selectedSongs];
//    get playlists
    [PlaylistsDatabase updateDatabaseForChangedPlaylist:self.playlist];
    
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.songs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"allSongsCell" forIndexPath:indexPath];
    LocalSongModel *song = self.songs[indexPath.row];
    if (![song.artistName isEqualToString:@"Unknown artist"]) {
        cell.textLabel.text = [[song.artistName stringByAppendingString: @" - "] stringByAppendingString:song.songTitle];
    }
    else {
        cell.textLabel.text = song.songTitle;
    }
    
    if ([self.selectedSongs containsObject:self.songs[indexPath.row]]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (![self.selectedSongs containsObject:self.songs[indexPath.row]]) {
        [self.selectedSongs addObject:self.songs[indexPath.row]];
    }
    else {
        [self.selectedSongs removeObject:self.songs[indexPath.row]];
    }
    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark searchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    
    if (searchText.length > 0) {
        
        self.filteredSongs = [self.allSongs filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(LocalSongModel *evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            
            return ([evaluatedObject.songTitle.lowercaseString containsString:searchText.lowercaseString] ||
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
    return ![self.searchController.searchBar.text isEqualToString:@""];
}

- (NSArray<LocalSongModel *> *)songs {
    if (self.isFiltering) {
        return self.filteredSongs;
    }
    return self.allSongs;
}

@end
