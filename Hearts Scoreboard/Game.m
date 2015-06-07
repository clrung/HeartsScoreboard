//
//  Game.m
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 4/6/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import "Game.h"

static NSString* const numRoundsKey     = @"numRounds";
static NSString* const dealerOffsetKey  = @"dealerOffset";
static NSString* const endingScoreKey   = @"endingScore";
static NSString* const playersKey       = @"players";

@implementation Game
@synthesize numRounds = _numRounds;
@synthesize dealerOffset = _dealerOffset;
@synthesize endingScore = _endingScore;
@synthesize players = _players;

- (id)init {
    NSArray *names = [[NSArray alloc] initWithObjects:@"Player 1", @"Player 2", @"Player 3", @"Player 4", nil];
    return [self initWithNames:names];
}

- (id)initWithNames:(NSArray *)names {
    self = [super init];
    if (self) {
        _numRounds = 0;
        _dealerOffset = 0;
        
        _players = [[NSArray alloc] init];
        for (NSString *name in names) {
            _players = [_players arrayByAddingObject:[[Player alloc] initWithName:name]];
        }
    }
    return self;
}

- (NSInteger)numRounds {
    return _numRounds;
}

- (void)setNumRounds:(NSInteger)numRounds {
    _numRounds = numRounds;
}

- (NSInteger)dealerOffset {
    return _dealerOffset;
}

- (void)setDealerOffset:(NSInteger)dealerOffset {
    _dealerOffset = dealerOffset;
}

- (NSInteger)endingScore {
    return _endingScore;
}

- (void)setEndingScore:(NSInteger)endingScore {
    _endingScore = endingScore;
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
    _numRounds      = 0;
    _dealerOffset   = 0;
    
    NSArray *names = [[NSArray alloc] initWithObjects:@"Player 1", @"Player 2", @"Player 3", @"Player 4", nil];
    for(NSUInteger i = 0; i < [_players count]; i++) {
        [_players[i] resetPlayerWithName:names[i]];
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
        _numRounds      = [decoder decodeIntegerForKey:numRoundsKey];
        _dealerOffset   = [decoder decodeIntegerForKey:dealerOffsetKey];
        _endingScore    = [decoder decodeIntegerForKey:endingScoreKey];
        _players        = [decoder decodeObjectForKey:playersKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeInt:(int)_numRounds      forKey:numRoundsKey];
    [encoder encodeInt:(int)_dealerOffset   forKey:dealerOffsetKey];
    [encoder encodeInt:(int)_endingScore    forKey:endingScoreKey];
    [encoder encodeObject:_players          forKey:playersKey];
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

    return [[Game alloc] init];
}

- (void)save {
    NSData* encodedData = [NSKeyedArchiver archivedDataWithRootObject: self];
    [encodedData writeToFile:[Game filePath] atomically:YES];
}

@end