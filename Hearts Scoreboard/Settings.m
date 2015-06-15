//
//  Settings.m
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 6/10/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import "Settings.h"

static NSString* const dealerOffsetKey      = @"dealerOffset";
static NSString* const endingScoreKey       = @"endingScore";
static NSString* const moonBehaviorIsAddKey = @"moonBehaviorIsAdd";

@implementation Settings
@synthesize dealerOffset      = _dealerOffset;
@synthesize endingScore       = _endingScore;
@synthesize moonBehaviorIsAdd = _moonBehaviorIsAdd;

- (id)init {
    self = [super init];
    _dealerOffset      = 0;
    _endingScore       = 100;
    _moonBehaviorIsAdd = YES;
    return self;
}

- (int)dealerOffset {
    return _dealerOffset;
}

- (void)setDealerOffset:(int)dealerOffset {
    _dealerOffset = dealerOffset;
}

- (int)endingScore {
    return _endingScore;
}

- (void)setEndingScore:(int)endingScore {
    _endingScore = endingScore;
}

- (BOOL)moonBehaviorIsAdd {
    return _moonBehaviorIsAdd;
}

- (void)setMoonBehaviorIsAdd:(BOOL)moonBehaviorIsAdd {
    _moonBehaviorIsAdd = moonBehaviorIsAdd;
}

+ (instancetype)sharedSettingsData {
    static id sharedInstance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [self loadInstance];
    });
    
    return sharedInstance;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if([super init]) {
        _dealerOffset       = [decoder decodeIntForKey:dealerOffsetKey];
        _endingScore        = [decoder decodeIntForKey:endingScoreKey];
        _moonBehaviorIsAdd  = [decoder decodeBoolForKey:moonBehaviorIsAddKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeInt:(int)_dealerOffset   forKey:dealerOffsetKey];
    [encoder encodeInt:(int)_endingScore    forKey:endingScoreKey];
    [encoder encodeBool:_moonBehaviorIsAdd  forKey:moonBehaviorIsAddKey];
}

+ (NSString*)filePath {
    static NSString* filePath = nil;
    if (!filePath) {
        filePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"settingsdata"];
    }
    return filePath;
}

//
// Check if there's a saved game data file already.  If so, return it.  If not,
// allocate a new Game object.
//
+ (instancetype)loadInstance {
    NSData* decodedData = [NSData dataWithContentsOfFile: [Settings filePath]];
    if (decodedData) {
        Settings* settings = [NSKeyedUnarchiver unarchiveObjectWithData:decodedData];
        return settings;
    }
    
    return [[Settings alloc] init];
}

- (void)save {
    NSData* encodedData = [NSKeyedArchiver archivedDataWithRootObject: self];
    [encodedData writeToFile:[Settings filePath] atomically:YES];
}

@end