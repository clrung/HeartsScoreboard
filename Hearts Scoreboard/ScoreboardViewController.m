//
//  ViewController.m
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 2/26/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import "ScoreboardViewController.h"
#import "ScoreCollectionViewCell.h"
#import "Player.h"

@interface ScoreboardViewController ()

@property (strong, nonatomic) IBOutletCollection(UILabel) NSArray *playerNameLabels;
@property (strong, nonatomic) IBOutletCollection(UITextField) NSArray *playerNameFields;
@property (strong, nonatomic) IBOutletCollection(UILabel) NSArray *playerSumScoreLabels;
@property (strong, nonatomic) IBOutletCollection(UICollectionView) NSArray *scoresCollectionViews;

@property (strong, nonatomic) IBOutlet UILabel *passDirectionLabel;
@property (strong, nonatomic) IBOutlet UIButton *nextRoundButton;

@property (strong, nonatomic) IBOutlet UILabel *shootTheMoonLabel;
@property (strong, nonatomic) IBOutlet UISegmentedControl *moonBehaviorSegmentedControl;

@property (strong, nonatomic) IBOutlet UIView *nextRoundView;
@property (strong, nonatomic) IBOutletCollection(UILabel) NSArray *nextRoundPlayerNameLabels;
@property (strong, nonatomic) IBOutletCollection(UILabel) NSArray *nextRoundScoreLabels;
@property (strong, nonatomic) IBOutlet UIButton *nextRoundSubmitButton;
@property (strong, nonatomic) IBOutletCollection(UIButton) NSArray *nextRoundAddScoreButtons;

@property (strong, nonatomic) UITextField *activeTextField;
@property (strong, nonatomic) NSArray *inputAccessoryViews;

@end

@implementation ScoreboardViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _game = [[Game alloc] init];
    
    [self setupInputAccessoryViews];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Update Text

- (void)updatePlayerNames {
    for(UILabel *label in _playerNameLabels) {
        [label setText:[[_game playerNames] objectAtIndex:label.tag]];
    }
    for(UILabel *label in _nextRoundPlayerNameLabels) {
        [label setText:[[_game playerNames] objectAtIndex:label.tag]];
    }
    for(UITextField *field in _playerNameFields) {
        [field setText:[[_game playerNames] objectAtIndex:field.tag]];
    }
}

- (void)updatePlayerSumScoreLabels {
    for(UILabel *label in _playerSumScoreLabels) {
        [label setText:[NSString stringWithFormat:@"%ld", [[[_game players] objectAtIndex:label.tag] sumScores]]];
    }
}

- (void)updatePassDirectionLabel {
    switch([_game numRounds] % 4) {
        case 0:
            [_passDirectionLabel setText:@"Pass to the left"];
            break;
        case 1:
            [_passDirectionLabel setText:@"Pass to the right"];
            break;
        case 2:
            [_passDirectionLabel setText:@"Pass across"];
            break;
        case 3:
            [_passDirectionLabel setText:@"Hold on tight!"];
            break;
    }
}

- (void)updateDealer {
    for (UILabel *label in _playerNameLabels) {
        if ([_game numRounds] % 4 == label.tag) {
            label.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size: 17];
        } else {
            label.font = [UIFont fontWithName:@"HelveticaNeue" size: 17];
        }
    }
}

#pragma mark Collection View

//
// The scores collection view will only have one row/column.
//
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [_game numRounds];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    ScoreCollectionViewCell *scoreCell = (ScoreCollectionViewCell*)[collectionView dequeueReusableCellWithReuseIdentifier:@"scoreCell" forIndexPath:indexPath];
    
    void (^setScoreLabel)(NSUInteger playerIndex) = ^(NSUInteger playerIndex) {
        [[scoreCell scoreLabel] setText:[NSString stringWithFormat:@"%@", [[[[_game players] objectAtIndex:playerIndex] scores] objectAtIndex:[indexPath item]]]];
    };
    
    setScoreLabel(collectionView.tag);
    
    // TODO move cell appearance code to ScoreCollectionViewCell
    // round the cell's corners
    scoreCell.layer.cornerRadius = 15;
    // add drop shadow
    scoreCell.layer.shadowOffset = CGSizeMake(3, 3);
    scoreCell.layer.shadowRadius = 5;
    scoreCell.layer.shadowOpacity = .2;
    scoreCell.layer.masksToBounds = NO;
    
    
    return scoreCell;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self synchronizeCollectionViewContentOffsets:scrollView];
}

//
// Mirrors scrolling of the scores collection view
//
- (void)synchronizeCollectionViewContentOffsets:scrollView {
    CGPoint offset = [scrollView contentOffset];
    for(UICollectionView *view in _scoresCollectionViews) {
        view.contentOffset = CGPointMake(0, offset.y);
    }
}

#pragma mark - Main Button Actions

- (IBAction)touchNextRoundButton:(UIButton *)sender {
    [_game setNumRounds:[_game numRounds] + 1];
    
    [self resetNextRoundView];
    
    [self setView:_nextRoundView hidden:NO];
}

- (IBAction)touchSettings:(UIButton *)sender {
    
    BOOL settingsVisible = ([_shootTheMoonLabel alpha] == 1.0);
    
    [UIView animateWithDuration:0.5 animations:^() {
        settingsVisible ? [_shootTheMoonLabel setAlpha:0.0] : [_shootTheMoonLabel setAlpha:1.0];
        settingsVisible ? [_moonBehaviorSegmentedControl setAlpha:0.0] : [_moonBehaviorSegmentedControl setAlpha:1.0];
        
        settingsVisible ? [_passDirectionLabel setAlpha:1.0] : [_passDirectionLabel setAlpha:0.0];
        settingsVisible ? [_nextRoundButton setAlpha:1.0] : [_nextRoundButton setAlpha:0.0];
        
        for (UITextField *field in _playerNameFields) {
            settingsVisible ? [field setAlpha:0.0] : [field setAlpha:1.0];
        }
        for (UILabel *label in _playerNameLabels) {
            settingsVisible ? [label setAlpha:1.0] : [label setAlpha:0.0];
        }
        for (UILabel *label in _playerSumScoreLabels) {
            settingsVisible ? [label setAlpha:1.0] : [label setAlpha:0.0];
        }
        for (UICollectionView *view in _scoresCollectionViews) {
            settingsVisible ? [view setAlpha:1.0] : [view setAlpha:0.0];
        }
    }];
    
    NSArray* names = [[NSArray alloc] init];
    
    for(UITextField *field in _playerNameFields) {
        NSString *newName = [[NSString alloc] init];
        
        if (([[field text] isEqualToString:@""])) {
            newName = [NSString stringWithFormat:@"Player %ld", (long)field.tag + 1];
        } else {
            newName = [field text];
        }
        
        names = [names arrayByAddingObject:newName];
    }
    
    [_game setPlayerNames: names];
    [self updatePlayerNames];
}

#pragma mark - Next Round View
#pragma mark Actions

- (IBAction)touchNextRoundSubmitButton:(UIButton *)sender {
    // the sum must be 26 to be valid, unless a player shoots the moon.
    // and the subtract 26 option is selected.
    if ([self getNextRoundViewSum] == 26 || [self getNextRoundViewSum] == 78 || [self getNextRoundViewSum] == -26) {
        for(int i = 0; i < 4; i++) {
            NSMutableArray *scores = [[[_game players] objectAtIndex:i] scores];
            [scores addObject:[NSNumber numberWithInt:[[[_nextRoundScoreLabels objectAtIndex:i] text] intValue]]];
            [[[_game players] objectAtIndex:i] setScores:scores];
        }
        
        [self updatePassDirectionLabel];
        [self updatePlayerSumScoreLabels];
        [self updateDealer];
        
        for(UICollectionView *view in _scoresCollectionViews) {
            [view reloadData];
        }
        
        [self setView:_nextRoundView hidden:YES];
    } else {
        [[[UIAlertView alloc] initWithTitle:@"Invalid Scores"
                                    message:@"The sum of the scores must be equal to 26."
                                   delegate:self
                          cancelButtonTitle:@"Okay"
                          otherButtonTitles:nil, nil] show];
        [self resetNextRoundView];
    }
}

- (IBAction)touchNextRoundResetButton:(UIButton *)sender {
    [self resetNextRoundView];
}

- (IBAction)touchAddScore:(UIButton *)sender {
    UIButton *button = (UIButton *)sender;
    
    NSArray *choices = @[@"+1", @"+5", @"Q"];
    NSUInteger item = [choices indexOfObject:button.currentTitle];
    
    UILabel *currentScoreLabel = [_nextRoundScoreLabels objectAtIndex:button.tag];
    
    switch (item) {
        case 0:     // +1
            [self addToCurrentScoreLabel:currentScoreLabel withValue:1];
            break;
        case 1:     // +5
            [self addToCurrentScoreLabel:currentScoreLabel withValue:5];
            break;
        case 2:     // Q
            [self addToCurrentScoreLabel:currentScoreLabel withValue:13];
            
            // disable the Q buttons; there is only one Queen of Spades
            for (UIButton *button in _nextRoundAddScoreButtons) {
                if ([button.currentTitle isEqualToString:@"Q"]) {
                    [button setEnabled:NO];
                }
            }
            
            break;
    }
}

- (IBAction)touchShootMoon:(UIButton *)sender {
    if([_moonBehaviorSegmentedControl selectedSegmentIndex] == 0) { // add 26
        for (UILabel *label in _nextRoundScoreLabels) {
            [label setText:@"26"];
        }
        [(UILabel *)[_nextRoundScoreLabels objectAtIndex:sender.tag] setText:@"0"];
    } else { // subtract 26
        for (UILabel *label in _nextRoundScoreLabels) {
            [label setText:@"0"];
        }
        [(UILabel *)[_nextRoundScoreLabels objectAtIndex:sender.tag] setText:@"-26"];
    }
    
    for (UIButton *button in _nextRoundAddScoreButtons) {
        [button setEnabled:NO];
    }
    
    [_nextRoundSubmitButton setEnabled:YES];
}

#pragma mark Misc

- (void)resetNextRoundView {
    [_nextRoundSubmitButton setEnabled:NO];
    
    for (UILabel *label in _nextRoundScoreLabels) {
        [label setText:@"0"];
    }
    
    for (UIButton *button in _nextRoundAddScoreButtons) {
        [button setEnabled:YES];
    }
}

- (void)setView:(UIView*)view hidden:(BOOL)hidden {
    [UIView animateWithDuration:0.5 animations:^() {
        if (hidden) {
            [view setAlpha:0.0];
        } else {
            [view setAlpha:1.0];
        }
    }];
}

#pragma mark Helper Methods

- (int)getNextRoundViewSum {
    int sum = 0;
    
    for (UILabel *label in _nextRoundScoreLabels) {
        sum += [[label text] intValue];
    }
    
    return sum;
}

- (void)addToCurrentScoreLabel:(UILabel *)currentScoreLabel withValue:(int)value {
    int currentScore = [[currentScoreLabel text] intValue];

    if ([self getNextRoundViewSum] + value < 26) {
        [currentScoreLabel setText:[NSString stringWithFormat:@"%d", currentScore + value]];
    } else if ([self getNextRoundViewSum] + value == 26) {
        [currentScoreLabel setText:[NSString stringWithFormat:@"%d", currentScore + value]];
        
        for (UIButton *button in _nextRoundAddScoreButtons) {
            [button setEnabled:NO];
        }
        
        [_nextRoundSubmitButton setEnabled:YES];
    } else if ([self getNextRoundViewSum] + value > 26) {
        [[[UIAlertView alloc] initWithTitle:@"Invalid"
                                    message:@"The sum of the scores may not exceed 26."
                                   delegate:self
                          cancelButtonTitle:@"Okay"
                          otherButtonTitles:nil, nil] show];
    }
}

#pragma mark - Input Accessory View

- (void)setupInputAccessoryViews {
    _inputAccessoryViews = [[NSArray alloc] initWithObjects:[[UIToolbar alloc] init], [[UIToolbar alloc] init], [[UIToolbar alloc] init], [[UIToolbar alloc] init], nil];
    
    for(UIToolbar *accessoryView in _inputAccessoryViews) {
        UIBarButtonItem *prevButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:101 target:nil action:@selector(goToPrevField)]; // 101 is the < character
        UIBarButtonItem *nextButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:102 target:nil action:@selector(goToNextField)]; // 102 is the > character
        UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStylePlain target:nil action:@selector(dismissKeyboard)];
        UIBarButtonItem *flexSpace  = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        UIBarButtonItem *fake       = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
        
        [accessoryView sizeToFit];
        [accessoryView setItems:[NSArray arrayWithObjects: prevButton, fake, nextButton, fake, flexSpace, fake, doneButton, nil] animated:YES];
    }
    
    // disable the previous button in the first accessory view
    ((UIBarButtonItem*)[((UIToolbar*)[_inputAccessoryViews objectAtIndex:0]).items objectAtIndex:0]).enabled = NO;
    // disable the next button in the last accessory view
    ((UIBarButtonItem*)[((UIToolbar*)[_inputAccessoryViews objectAtIndex:3]).items objectAtIndex:2]).enabled = NO;
    
    // add the input accessory view to each text field's keyboard.
    for(UITextField *field in _playerNameFields) {
        [field addTarget:self action:@selector(fieldSelected:) forControlEvents:UIControlEventEditingDidBegin];
        [field setInputAccessoryView:[_inputAccessoryViews objectAtIndex:field.tag]];
    }
}

- (void)fieldSelected:(UITextField*)selectedField {
    _activeTextField = selectedField;
}

//
// Focus on the previous UITextField
//
- (void)goToPrevField {
    [[_playerNameFields objectAtIndex:(_activeTextField.tag - 1)] becomeFirstResponder];
}

//
// Focus on the next UITextField
//
- (void)goToNextField {
    [[_playerNameFields objectAtIndex:(_activeTextField.tag + 1)] becomeFirstResponder];
}

//
// Dismiss the keyboard when done is tapped.
//
- (void)dismissKeyboard {
    [[_playerNameFields objectAtIndex:_activeTextField.tag] resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    // if currently focused on first three textboxes, go to the next text box
    if (textField.tag < 3) {
        [[_playerNameFields objectAtIndex:(textField.tag + 1)] becomeFirstResponder];
        // if currently focused on last textbox, dismiss the keyboard.
    } else if (textField.tag == 3) {
        [[_playerNameFields objectAtIndex:3] resignFirstResponder];
    }
    
    return YES;
}

@end