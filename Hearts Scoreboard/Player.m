//
//  Player.m
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 4/2/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import "Player.h"

static NSString* const nameKey   = @"name";
static NSString* const scoresKey = @"scores";

@implementation Player
@synthesize name   = _name;
@synthesize scores = _scores;

- (id)initWithName:(NSString*)name {
    self = [super init];
    if (self) {
        _name   = [[NSString alloc] initWithString:name];
        _scores = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)resetPlayerWithName:(NSString*)name {
    _name   = name;
    _scores = [[NSMutableArray alloc] init];
}

- (NSString*)name {
    return _name;
}

- (void)setName:(NSString*)name {
    _name = name;
}

- (NSMutableArray*)scores {
    return _scores;
}

- (void)setScores:(NSMutableArray*)scores {
    _scores = scores;
}

- (int)sumScores {
    return (int)[[_scores valueForKeyPath:@"@sum.self"] integerValue];
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if (self) {
        _name   = [decoder decodeObjectForKey:nameKey];
        _scores = [decoder decodeObjectForKey:scoresKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:_name   forKey:nameKey];
    [encoder encodeObject:_scores forKey:scoresKey];
}

@end