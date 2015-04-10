
//
//  SettingsViewController.m
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 4/8/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import "SettingsViewController.h"

@interface SettingsViewController ()

@property (strong, nonatomic) IBOutlet UISegmentedControl *moonBehaviorSegmentedControl;

@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    for(UITextField* field in _nameTextFields) {
        [field setText:[_playerNames objectAtIndex:field.tag]];
    }
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end