//
//  ScoreCollectionViewCell.m
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 4/6/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import "ScoreCollectionViewCell.h"

@implementation ScoreCollectionViewCell

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    self.layer.cornerRadius = 15;
}

@end