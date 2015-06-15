//
//  Player.h
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 4/2/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Player : NSObject <NSCoding>

@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSMutableArray *scores;

- (id)initWithName:(NSString*)name;

- (void)resetPlayerWithName:(NSString*)name;

- (NSString*)name;
- (void)setName:(NSString*)name;

- (NSMutableArray*)scores;
- (void)setScores:(NSMutableArray*)scores;

- (int)sumScores;

- (id)initWithCoder:(NSCoder *)decoder;
- (void)encodeWithCoder:(NSCoder *)encoder;

@end