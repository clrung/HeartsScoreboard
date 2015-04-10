//
//  SettingsViewController.h
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 4/8/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SettingsViewController : UIViewController

@property (strong, nonatomic) IBOutletCollection(UITextField) NSArray *nameTextFields;

@property (strong, nonatomic) NSArray* playerNames;

- (void)setPlayerNames:(NSArray *)playerNames;
- (NSArray *)playerNames;

@end