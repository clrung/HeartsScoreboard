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

- (id)initWithNames:(NSArray *)names {
    self = [super init];
    if (self) {
        _numRounds = 0;
        
        _players = [[NSArray alloc] init];
        for (NSString *name in names) {
            Player *player = [[Player alloc] initWithName:name];
            _players = [_players arrayByAddingObject:player];
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