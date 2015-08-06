//
//  UIPlayerTextField.m
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 6/7/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import "UIPlayerTextField.h"

@interface UIPlayerTextField ()
@property (strong, nonatomic) UIPlayerTextField *nextTextField;
@property (strong, nonatomic) UIPlayerTextField *previousTextField;
@end

@implementation UIPlayerTextField

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
        [self setupInputAccessoryView];
    }
    return self;
}

- (void)setNextTextField:(UIPlayerTextField *)nextTextField {
    _nextTextField = nextTextField;
}

- (void)setPreviousTextField:(UIPlayerTextField *)previousTextField {
    _previousTextField = previousTextField;
}

- (void)setupInputAccessoryView {
    UIToolbar *inputAccessoryView = [[UIToolbar alloc] init];
    
    UIBarButtonItem *prevButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:101 target:nil action:@selector(goToPrevField)]; // 101 is the < character
    UIBarButtonItem *nextButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:102 target:nil action:@selector(goToNextField)]; // 102 is the > character
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStylePlain target:nil action:@selector(dismissKeyboard)];
    UIBarButtonItem *flexSpace  = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *fake       = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    
    [inputAccessoryView sizeToFit];
    [inputAccessoryView setItems:[NSArray arrayWithObjects: prevButton, fake, nextButton, fake, flexSpace, fake, doneButton, nil] animated:YES];
    
    // disable the previous button in the first accessory view
    if ([self tag] == 0) {
        ((UIBarButtonItem *)[inputAccessoryView.items objectAtIndex:0]).enabled = NO;
    // disable the next button in the last accessory view
    } else if ([self tag] == 3) {
        ((UIBarButtonItem *)[inputAccessoryView.items objectAtIndex:2]).enabled = NO;
    }
    
    [self setInputAccessoryView:inputAccessoryView];
}

//
// Focus on the previous UITextField
//
- (void)goToPrevField {
    [_previousTextField becomeFirstResponder];
}

//
// Focus on the next UITextField
//
- (void)goToNextField {
    [_nextTextField becomeFirstResponder];
}

- (void)dismissKeyboard {
    [self resignFirstResponder];
}

@end