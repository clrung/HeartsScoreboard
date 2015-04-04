//
//  Player.m
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 4/2/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import "Player.h"

@implementation Player
@synthesize name = _name;
@synthesize scores = _scores;

- (instancetype)initWithName:(NSString*)name {
    self = [super init];
    if (self != nil) {
        _name = name;
        _scores = [[NSMutableArray alloc] init];
        [_scores addObject:0];
    }
    return self;
}

- (void)setName:(NSString*)name {
    _name = name;
}

- (NSString*)name {
    return _name;
}

- (void)setScores:(NSMutableArray*)scores {
    _scores = scores;
}

- (NSMutableArray*)scores {
    return _scores;
}

- (NSUInteger)sumScores {
    NSInteger sum = 0;
    NSInteger sum2 = 0;
    
    for (NSInteger i = 0; i < [_scores count]; i++) {
        sum += (NSInteger)[_scores objectAtIndex:i];
    }
    
    for (NSObject *i in _scores) {
        sum2 += (NSInteger)i;
    }
    
    NSLog(@"sum = %ld", (long)sum);
    NSLog(@"sum2 = %ld", (long)sum2);
    
    return sum;
}

@end