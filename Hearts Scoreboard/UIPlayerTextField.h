//
//  UIPlayerTextField.h
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 6/7/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIPlayerTextField : UITextField

- (void)setNextTextField:(UIPlayerTextField *)nextTextField;
- (void)setPreviousTextField:(UIPlayerTextField *)previousTextField;

- (void)goToNextField;

@end