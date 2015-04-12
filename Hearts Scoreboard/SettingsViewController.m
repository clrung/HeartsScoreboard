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

@property (strong, nonatomic) UITextField *activeTextField;
@property (strong, nonatomic) NSArray *inputAccessoryViews;

@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // nameTextFields is in the reverse order; reverse the array to put it in order
    _nameTextFields = [[_nameTextFields reverseObjectEnumerator] allObjects];
    
    [self setupInputAccessoryViews];
    
    for(UITextField *field in _nameTextFields) {
        [field addTarget:self action:@selector(fieldSelected:) forControlEvents:UIControlEventEditingDidBegin];
        [field setText:[_playerNames objectAtIndex:field.tag]];
        [field setInputAccessoryView:[_inputAccessoryViews objectAtIndex:field.tag]];
    }
}

- (void)setupInputAccessoryViews {
    _inputAccessoryViews = [[NSArray alloc] initWithObjects:[[UIToolbar alloc] init], [[UIToolbar alloc] init], [[UIToolbar alloc] init], [[UIToolbar alloc] init], nil];
    
    for(UIToolbar *accessoryView in _inputAccessoryViews) {
        UIBarButtonItem *prevButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:101 target:nil action:@selector(goToPrevField)]; // 101 is the < character
        UIBarButtonItem *nextButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:102 target:nil action:@selector(goToNextField)]; // 102 is the > character
        UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:nil action:@selector(dismissKeyboard)];
        UIBarButtonItem *flexSpace  = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        UIBarButtonItem *fake       = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
        
        [accessoryView sizeToFit];
        [accessoryView setItems:[NSArray arrayWithObjects: prevButton, fake, nextButton, fake, flexSpace, fake, doneButton, nil] animated:YES];
    }
    
    // disable the previous button in the first accessory view
    ((UIBarButtonItem*)[((UIToolbar*)[_inputAccessoryViews objectAtIndex:0]).items objectAtIndex:0]).enabled = NO;
    // disable the next button in the last accessory view
    ((UIBarButtonItem*)[((UIToolbar*)[_inputAccessoryViews objectAtIndex:3]).items objectAtIndex:2]).enabled = NO;
}

- (void)fieldSelected:(UITextField*)selectedField {
    _activeTextField = selectedField;
}

//
// Focus on the previous UITextField
//
- (void)goToPrevField {
    [[_nameTextFields objectAtIndex:(_activeTextField.tag - 1)] becomeFirstResponder];
}

//
// Focus on the next UITextField
//
- (void)goToNextField {
    [[_nameTextFields objectAtIndex:(_activeTextField.tag + 1)] becomeFirstResponder];
}

//
// Dismiss the keyboard when done is tapped.
//
- (void)dismissKeyboard {
    [[_nameTextFields objectAtIndex:_activeTextField.tag] resignFirstResponder];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField {
    // if currently focused on first three textboxes, go to the next text box
    if (textField.tag < 3) {
        [[_nameTextFields objectAtIndex:(textField.tag + 1)] becomeFirstResponder];
    // if currently focused on last textbox, dismiss the keyboard.
    } else if (textField.tag == 3) {
        [[_nameTextFields objectAtIndex:3] resignFirstResponder];
    }
    
    return YES;
}

@end