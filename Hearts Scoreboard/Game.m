//
//  Game.m
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 4/6/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import "Game.h"

static NSString* const playersKey = @"highScore";
static NSString* const numRoundsKey = @"numRounds";

@implementation Game
@synthesize numRounds = _numRounds;
@synthesize players = _players;

- (id)init {
    NSArray *names = [[NSArray alloc] initWithObjects:@"Player 1", @"Player 2", @"Player 3", @"Player 4", nil];
    return [self initWithNames:names];
}

- (id)initWithNames:(NSArray *)names {
    self = [super init];
    if (self) {
        _numRounds = 0;
        
        _players = [[NSArray alloc] init];
        for (NSString *name in names) {
            _players = [_players arrayByAddingObject:[[Player alloc] initWithName:name]];
        }
        
    }
    return self;
}

- (NSUInteger)numRounds {
    return _numRounds;
}

- (void)setNumRounds:(NSUInteger)numRounds {
    _numRounds = numRounds;
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
    _numRounds = 0;
    
    for(Player *p in _players) {
        [p resetPlayer];
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
        _numRounds = [decoder decodeIntegerForKey:numRoundsKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:_players forKey:playersKey];
    [encoder encodeInt:(int)_numRounds forKey:numRoundsKey];
    NSLog(@"Saving numrounds = %lu", (unsigned long)_numRounds);
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
    if (decodedData) {
        Game* game = [NSKeyedUnarchiver unarchiveObjectWithData:decodedData];
        return game;
    }
    
    NSLog(@"Didn't find game data");
    return [[Game alloc] init];
}

- (void)save {
    NSData* encodedData = [NSKeyedArchiver archivedDataWithRootObject: self];
    [encodedData writeToFile:[Game filePath] atomically:YES];
    NSLog(@"Saved!");
}

@end