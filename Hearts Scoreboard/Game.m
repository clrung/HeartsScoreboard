//
//  Game.m
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 4/6/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import "Game.h"

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
    for(NSUInteger i = 0; i < 4; i++) {
        [_players[i] setName:playerNames[i]];
    }
}

- (void)resetGame {
    _numRounds = 0;
    
    for(Player *p in _players) {
        [p resetPlayer];
    }
}

@end