//
//  Settings.h
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 6/10/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString* const SettingsDataUpdatedFromiCloud = @"SettingsDataUpdatedFromiCloud";

@interface Settings : NSObject <NSCoding>

@property (nonatomic) int dealerOffset;
@property (nonatomic) int endingScore;
@property (nonatomic) BOOL moonBehaviorIsAdd;

- (int)dealerOffset;
- (void)setDealerOffset:(int)dealerOffset;

- (int)endingScore;
- (void)setEndingScore:(int)endingScore;

- (BOOL)moonBehaviorIsAdd;
- (void)setMoonBehaviorIsAdd:(BOOL)moonBehaviorIsAdd;

+ (instancetype)sharedSettingsData;

- (id)initWithCoder:(NSCoder *)decoder;
- (void)encodeWithCoder:(NSCoder *)encoder;

- (void)save;

@end