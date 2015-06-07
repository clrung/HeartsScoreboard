//
//  Game.h
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 4/6/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Player.h"

@interface Game : NSObject <NSCoding>

@property (nonatomic) NSInteger numRounds;
@property (nonatomic) NSInteger dealerOffset;
@property (nonatomic) NSInteger endingScore;
@property (strong, nonatomic) NSArray *players;

- (id)init;
- (id)initWithNames:(NSArray *)names;

- (NSInteger)numRounds;
- (void)setNumRounds:(NSInteger)numRounds;

- (NSInteger)dealerOffset;
- (void)setDealerOffset:(NSInteger)dealerOffset;

- (NSInteger)endingScore;
- (void)setEndingScore:(NSInteger)endingScore;

- (NSArray *)players;
- (void)setPlayers:(NSArray *)players;

- (NSArray *)playerNames;
- (void)setPlayerNames:(NSArray *)playerNames;

+ (instancetype)sharedGameData;
- (void)reset;

- (id)initWithCoder:(NSCoder *)decoder;
- (void)encodeWithCoder:(NSCoder *)encoder;

-(void)save;

@end