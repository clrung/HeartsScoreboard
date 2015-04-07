//
//  Game.h
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 4/6/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Player.h"

@interface Game : NSObject

@property (nonatomic) NSUInteger numRounds;
@property (strong, nonatomic) NSArray *players;

- (id)initWithNames:(NSArray*) names;

- (NSUInteger)numRounds;
- (void)setNumRounds:(NSUInteger)numRounds;

- (NSArray*)players;
- (void)setPlayers:(NSArray *)players;

- (void)resetGame;

@end