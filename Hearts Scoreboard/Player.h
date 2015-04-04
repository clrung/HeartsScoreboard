//
//  Player.h
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 4/2/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Player : NSObject

@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSMutableArray *scores;

- (instancetype)initWithName:(NSString*)name;

- (void)setName:(NSString*)name;
- (NSString*)name;

- (void)setScores:(NSMutableArray*)scores;
- (NSMutableArray*)scores;

@end