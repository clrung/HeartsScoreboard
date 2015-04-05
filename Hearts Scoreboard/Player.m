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

- (id)initWithName:(NSString*)name {
    self = [super init];
    if (self) {
        _name = [[NSString alloc] initWithString:name];
        _scores = [[NSMutableArray alloc] init];
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

- (NSInteger)sumScores {
//    This works, but valueForKeyPath is more efficient
//    NSInteger sum = 0;
//    
//    for (NSNumber *i in _scores) {
//        sum += [i integerValue];
//    }

    return [[_scores valueForKeyPath:@"@sum.self"] integerValue];
}

@end