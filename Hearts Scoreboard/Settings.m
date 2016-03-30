//
//  Settings.m
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 6/10/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import "Settings.h"

static NSString* const dealerOffsetKey      = @"dealerOffset";
static NSString* const themeKey             = @"theme";
static NSString* const endingScoreKey       = @"endingScore";
static NSString* const moonBehaviorIsAddKey = @"moonBehaviorIsAdd";

@implementation Settings
@synthesize dealerOffset      = _dealerOffset;
@synthesize theme             = _theme;
@synthesize endingScore       = _endingScore;
@synthesize moonBehaviorIsAdd = _moonBehaviorIsAdd;

- (id)init {
    self = [super init];
    if (self) {
        _dealerOffset      = 0;
        _theme             = 1;     // green
        _endingScore       = 100;
        _moonBehaviorIsAdd = YES;
        
        if ([NSUbiquitousKeyValueStore defaultStore]) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(updateFromiCloud:)
                                                         name:NSUbiquitousKeyValueStoreDidChangeExternallyNotification
                                                       object:nil];
        }
    }
    return self;
}

- (int)dealerOffset {
    return _dealerOffset;
}

- (void)setDealerOffset:(int)dealerOffset {
    _dealerOffset = dealerOffset;
    
    if ([NSUbiquitousKeyValueStore defaultStore]) {
        NSUbiquitousKeyValueStore *iCloudStore = [NSUbiquitousKeyValueStore defaultStore];
        
        [iCloudStore setObject:[NSNumber numberWithInt:_dealerOffset] forKey:dealerOffsetKey];
        [iCloudStore synchronize];
    }
}

- (int)theme {
    return _theme;
}

- (void)setTheme:(int)theme {
    _theme = theme;
    
    if ([NSUbiquitousKeyValueStore defaultStore]) {
        NSUbiquitousKeyValueStore *iCloudStore = [NSUbiquitousKeyValueStore defaultStore];
        
        [iCloudStore setObject:[NSNumber numberWithInt:_theme] forKey:themeKey];
        [iCloudStore synchronize];
    }
}

- (int)endingScore {
    return _endingScore;
}

- (void)setEndingScore:(int)endingScore {
    _endingScore = endingScore;
    
    if ([NSUbiquitousKeyValueStore defaultStore]) {
        NSUbiquitousKeyValueStore *iCloudStore = [NSUbiquitousKeyValueStore defaultStore];
        
        [iCloudStore setObject:[NSNumber numberWithInt:_endingScore] forKey:endingScoreKey];
        [iCloudStore synchronize];
    }
}

- (BOOL)moonBehaviorIsAdd {
    return _moonBehaviorIsAdd;
}

- (void)setMoonBehaviorIsAdd:(BOOL)moonBehaviorIsAdd {
    _moonBehaviorIsAdd = moonBehaviorIsAdd;
    
    if ([NSUbiquitousKeyValueStore defaultStore]) {
        NSUbiquitousKeyValueStore *iCloudStore = [NSUbiquitousKeyValueStore defaultStore];
        
        [iCloudStore setBool:_moonBehaviorIsAdd forKey:moonBehaviorIsAddKey];
        [iCloudStore synchronize];
    }
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
    if ([super init]) {
        _dealerOffset       = [decoder decodeIntForKey:dealerOffsetKey];
        _theme              = [decoder decodeIntForKey:themeKey];
        _endingScore        = [decoder decodeIntForKey:endingScoreKey];
        _moonBehaviorIsAdd  = [decoder decodeBoolForKey:moonBehaviorIsAddKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeInt:(int)_dealerOffset   forKey:dealerOffsetKey];
    [encoder encodeInt:(int)_theme          forKey:themeKey];
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
    NSData* decodedData = [NSData dataWithContentsOfFile:[Settings filePath]];
    if (decodedData) {
        Settings* settings = [NSKeyedUnarchiver unarchiveObjectWithData:decodedData];
        return settings;
    }
    
    return [[Settings alloc] init];
}

- (void)save {
    NSData* encodedData = [NSKeyedArchiver archivedDataWithRootObject:self];
    [encodedData writeToFile:[Settings filePath] atomically:YES];
}

- (void)updateFromiCloud:(NSNotification*) notificationObject {
    NSUbiquitousKeyValueStore *iCloudStore = [NSUbiquitousKeyValueStore defaultStore];
    
    if ([iCloudStore objectForKey:dealerOffsetKey]) {
        NSNumber *cloudDealerOffset = [iCloudStore objectForKey:dealerOffsetKey];
        _dealerOffset = [cloudDealerOffset intValue];
    }
    
    if ([iCloudStore objectForKey:themeKey]) {
        NSNumber *cloudTheme = [iCloudStore objectForKey:themeKey];
        _theme = [cloudTheme intValue];
    }
    
    if ([iCloudStore objectForKey:endingScoreKey]) {
        NSNumber *cloudEndingScore = [iCloudStore objectForKey:endingScoreKey];
        _endingScore = [cloudEndingScore intValue];
    }
    
    if ([iCloudStore objectForKey:moonBehaviorIsAddKey]) {
        _moonBehaviorIsAdd = [iCloudStore boolForKey:moonBehaviorIsAddKey];
    }
    
    [self save];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SettingsDataUpdatedFromiCloud object:nil];
}

@end