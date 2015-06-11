//
//  Settings.h
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 6/10/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Settings : NSObject <NSCoding>

@property (nonatomic) NSInteger dealerOffset;
@property (nonatomic) NSInteger endingScore;
@property (nonatomic) BOOL moonBehaviorIsAdd;

- (NSInteger)dealerOffset;
- (void)setDealerOffset:(NSInteger)dealerOffset;

- (NSInteger)endingScore;
- (void)setEndingScore:(NSInteger)endingScore;

- (BOOL)moonBehaviorIsAdd;
- (void)setMoonBehaviorIsAdd:(BOOL)moonBehaviorIsAdd;

+ (instancetype)sharedSettingsData;
- (void)reset;

- (id)initWithCoder:(NSCoder *)decoder;
- (void)encodeWithCoder:(NSCoder *)encoder;

- (void)save;

@end