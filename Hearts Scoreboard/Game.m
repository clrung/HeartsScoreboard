//
//  Game.m
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 4/6/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import "Game.h"

static NSString* const playersKey = @"players";

@implementation Game
@synthesize players = _players;

- (id)init {
    self = [super init];
    if (self) {
        // if the players array already exists, keep the players' names.
        if (_players) {
            for (Player *p in _players) {
                NSString *name = [p name];
                [p resetPlayerWithName:name];
            }
        } else {
            _players = [[NSArray alloc] initWithObjects:[[Player alloc] initWithName:@"Player 1"], [[Player alloc] initWithName:@"Player 2"], [[Player alloc] initWithName:@"Player 3"], [[Player alloc] initWithName:@"Player 4"], nil];
        }
        
        if ([NSUbiquitousKeyValueStore defaultStore]) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(updateFromiCloud:)
                                                         name:NSUbiquitousKeyValueStoreDidChangeExternallyNotification
                                                       object:nil];
        }
    }
    
    return self;
}

# pragma mark - Accessors

- (NSUInteger)numRounds {
    return [[[_players objectAtIndex:0] scores] count];
}

- (NSArray *)players {
    return _players;
}

- (void)setPlayers:(NSArray *)players {
    _players = players;
}

- (NSArray *)playerNames {
    NSArray *playerNames = [[NSArray alloc] init];
    
    for (Player *player in _players) {
        playerNames = [playerNames arrayByAddingObject:[player name]];
    }
    
    return playerNames;
}

- (void)setPlayerNames:(NSArray *)playerNames {
    for (int i = 0; i < [playerNames count]; i++) {
        [_players[i] setName:playerNames[i]];
    }
}

#pragma mark

- (void)reset {
    for (Player *p in _players) {
        NSString *name = [p name];
        [p resetPlayerWithName:name];
    }
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
    if ([super init]) {
        _players = [decoder decodeObjectForKey:playersKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:_players forKey:playersKey];
}

+ (instancetype)sharedGameData {
    static id sharedInstance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [self loadInstance];
    });
    
    return sharedInstance;
}


/**
 * Check if there's a saved game data file already.  If so, return it.  If not,
 * allocate a new Game object.
 * @return The Game singleton
 */
+ (instancetype)loadInstance {
    NSData *decodedData = [NSData dataWithContentsOfFile:[Game filePath]];
    Game *game;
    if (decodedData) {
        game = [NSKeyedUnarchiver unarchiveObjectWithData:decodedData];
        return game;
    }
    
    game = [[Game alloc] init];
    
    return game;
}

+ (NSString*)filePath {
    static NSString *filePath = nil;
    
    if (!filePath) {
        filePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"gamedata"];
    }
    return filePath;
}

- (void)save {
    NSData *encodedData = [NSKeyedArchiver archivedDataWithRootObject:self];
    [encodedData writeToFile:[Game filePath] atomically:YES];
    
    if ([NSUbiquitousKeyValueStore defaultStore]) {
        [self updateiCloud];
    }
}

#pragma mark - iCloud
- (void)updateiCloud {
    if ([NSUbiquitousKeyValueStore defaultStore]) {
        NSUbiquitousKeyValueStore *iCloudStore = [NSUbiquitousKeyValueStore defaultStore];
        
        NSData *playersData = [NSKeyedArchiver archivedDataWithRootObject:_players];
        
        [iCloudStore setData:playersData forKey:playersKey];
        [iCloudStore synchronize];
    }
}

- (void)updateFromiCloud:(NSNotification*) notificationObject {
    NSUbiquitousKeyValueStore *iCloudStore = [NSUbiquitousKeyValueStore defaultStore];
    
    if ([iCloudStore objectForKey:playersKey]) {
        NSData *cloudPlayersData = [iCloudStore objectForKey:playersKey];
        NSArray *cloudPlayers = [NSKeyedUnarchiver unarchiveObjectWithData:cloudPlayersData];
        
        if (cloudPlayers) {
            _players = cloudPlayers;
        }
    }
    
    [self save];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:GameDataUpdatedFromiCloud object:nil];
}

@end