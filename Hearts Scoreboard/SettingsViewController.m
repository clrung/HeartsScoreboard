
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
    
    // nameTextFields is in the reverse order; reverse the array to put it in order
    _nameTextFields = [[_nameTextFields reverseObjectEnumerator] allObjects];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{   
    if (textField.tag == 0) {
        [[_nameTextFields objectAtIndex:1] becomeFirstResponder];
    } else if (textField.tag == 1) {
        [[_nameTextFields objectAtIndex:2] becomeFirstResponder];
    } else if (textField.tag == 2) {
        [[_nameTextFields objectAtIndex:3] becomeFirstResponder];
    } else if (textField.tag == 3) {
        [[_nameTextFields objectAtIndex:3] resignFirstResponder];
    }
    
    return YES;
}

@end