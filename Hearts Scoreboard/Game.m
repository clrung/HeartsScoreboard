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
    NSArray* playerNames = [[NSArray alloc] init];
    
    for(Player *player in _players) {
        playerNames = [playerNames arrayByAddingObject:[player name]];
    }
    
    return playerNames;
}

- (void)setPlayerNames:(NSArray *)playerNames {
    for(NSUInteger i = 0; i < [playerNames count]; i++) {
        [_players[i] setName:playerNames[i]];
    }
}

- (void)reset {
    NSArray *names = [[NSArray alloc] initWithObjects:@"Player 1", @"Player 2", @"Player 3", @"Player 4", nil];
    
    _players = [[NSArray alloc] init];
    for (NSString *name in names) {
        _players = [_players arrayByAddingObject:[[Player alloc] initWithName:name]];
    }
}

+ (instancetype)sharedGameData {
    static id sharedInstance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [self loadInstance];
    });
    
    return sharedInstance;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if([super init]) {
        _players = [decoder decodeObjectForKey:playersKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:_players forKey:playersKey];
}

+ (NSString*)filePath {
    static NSString* filePath = nil;
    if (!filePath) {
        filePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"gamedata"];
    }
    return filePath;
}

//
// Check if there's a saved game data file already.  If so, return it.  If not,
// allocate a new Game object.
//
+ (instancetype)loadInstance {
    NSData* decodedData = [NSData dataWithContentsOfFile: [Game filePath]];
    Game* game;
    if (decodedData) {
        game = [NSKeyedUnarchiver unarchiveObjectWithData:decodedData];
        return game;
    }
    
    game = [[Game alloc] init];
    [game reset];
    
    return game;
}

- (void)save {
    NSData* encodedData = [NSKeyedArchiver archivedDataWithRootObject: self];
    [encodedData writeToFile:[Game filePath] atomically:YES];
}

@end