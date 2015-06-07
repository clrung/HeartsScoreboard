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

#define kOFFSET_FOR_KEYBOARD 80.0

@interface ScoreboardViewController ()

@property (strong, nonatomic) IBOutletCollection(UILabel) NSArray *playerNameLabels;
@property (strong, nonatomic) IBOutletCollection(UILabel) NSArray *playerSumScoreLabels;
@property (strong, nonatomic) IBOutletCollection(UICollectionView) NSArray *scoresCollectionViews;
@property (strong, nonatomic) IBOutlet UIButton *settingsButton;
@property (strong, nonatomic) IBOutlet UILabel *passDirectionLabel;
@property (strong, nonatomic) IBOutlet UIButton *nnewGameButton;
@property (strong, nonatomic) IBOutlet UIButton *nextRoundButton;

@property (strong, nonatomic) IBOutletCollection(UITextField) NSArray *playerNameFields;
@property (strong, nonatomic) NSArray *playerNameFieldYLocations;
@property (strong, nonatomic) IBOutlet UILabel *shootTheMoonLabel;
@property (strong, nonatomic) IBOutlet UISegmentedControl *moonBehaviorSegmentedControl;
@property (strong, nonatomic) IBOutlet UILabel *dealerLabel;
@property (strong, nonatomic) UITextField *activeTextField;
@property (strong, nonatomic) NSArray *inputAccessoryViews;

@property (strong, nonatomic) IBOutlet UIView *nextRoundView;
@property (strong, nonatomic) IBOutletCollection(UILabel) NSArray *nextRoundPlayerNameLabels;
@property (strong, nonatomic) IBOutletCollection(UILabel) NSArray *nextRoundScoreLabels;
@property (strong, nonatomic) IBOutlet UIButton *nextRoundSubmitButton;
@property (strong, nonatomic) IBOutletCollection(UIButton) NSArray *nextRoundAddScoreButtons;

@property (strong, nonatomic) IBOutlet UILabel *gameOverLabel;
@property (strong, nonatomic) IBOutlet UITextField *endingScoreTextField;

@end

@implementation ScoreboardViewController

static int const dealerFadeStart    = 20;
static int const dealerFadeDistance = 25;
static NSString* const undoTitleText      = @"Undo last round?";
static NSString* const resetGameTitleText = @"Reset Game?";

static UIAlertView const *invalidScoreAlert;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveViewWithGestureRecognizer:)];
    [_dealerLabel addGestureRecognizer:panGestureRecognizer];
    [_dealerLabel setUserInteractionEnabled:YES];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self setupInputAccessoryViews];
    
    [self updatePlayerNames];
    [self updatePlayerSumScoreLabels];
    [self updateDealerLabel];
    [_endingScoreTextField setText:[NSString stringWithFormat:@"%ld", (long)[[Game sharedGameData] endingScore]]];
    [_endingScoreTextField addTarget:self action:@selector(fieldSelected:) forControlEvents:UIControlEventEditingDidBegin];
    for(UICollectionView *view in _scoresCollectionViews) {
        [view reloadData];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self initPlayerNameFieldYLocations];
    
    invalidScoreAlert = [[UIAlertView alloc] initWithTitle:@"Invalid Scores"
                                                   message:@"The sum of the scores must be equal to 26."
                                                  delegate:self
                                         cancelButtonTitle:@"Okay"
                                         otherButtonTitles:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Update Text

- (void)updatePlayerNames {
    for(UILabel *label in _playerNameLabels) {
        [label setText:[[[Game sharedGameData] playerNames] objectAtIndex:label.tag]];
    }
    for(UILabel *label in _nextRoundPlayerNameLabels) {
        [label setText:[[[Game sharedGameData] playerNames] objectAtIndex:label.tag]];
    }
    for(UITextField *field in _playerNameFields) {
        [field setText:[[[Game sharedGameData] playerNames] objectAtIndex:field.tag]];
    }
}

- (void)updatePlayerSumScoreLabels {
    for(UILabel *label in _playerSumScoreLabels) {
        [label setText:[NSString stringWithFormat:@"%ld", [[[[Game sharedGameData] players] objectAtIndex:label.tag] sumScores]]];
    }
}

- (void)updatePassDirectionLabel {
    switch([[Game sharedGameData] numRounds] % 4) {
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

- (void)updateDealerLabel {
    for (UILabel *label in _playerNameLabels) {
        if ([[Game sharedGameData] dealerOffset] % 4 == label.tag) {
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
    return [[Game sharedGameData] numRounds];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    ScoreCollectionViewCell *scoreCell = (ScoreCollectionViewCell*)[collectionView dequeueReusableCellWithReuseIdentifier:@"scoreCell" forIndexPath:indexPath];
    
    void (^setScoreLabel)(NSUInteger playerTag) = ^(NSUInteger playerTag) {
        [[scoreCell scoreLabel] setText:[NSString stringWithFormat:@"%@", [[[[[Game sharedGameData] players] objectAtIndex:playerTag] scores] objectAtIndex:[indexPath item]]]];
    };
    
    setScoreLabel(collectionView.tag);
    
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
    [[Game sharedGameData] setNumRounds:[[Game sharedGameData] numRounds] + 1];
    
    [self resetNextRoundView];
    
    [self setView:_nextRoundView hidden:NO];
}

- (IBAction)touchNewGameButton:(UIButton *)sender {
    if (UIEventSubtypeMotionShake) {
        [[[UIAlertView alloc] initWithTitle:resetGameTitleText
                                    message:@"Are you sure you would like to start a new game?"
                                   delegate:self
                          cancelButtonTitle:@"No"
                          otherButtonTitles:@"Yes", nil] show];
    }
}

- (IBAction)touchSettingsButton:(UIButton *)sender {
    CGRect frame = _dealerLabel.frame;
    
    frame.origin.y = [[_playerNameFieldYLocations objectAtIndex:[[Game sharedGameData] dealerOffset] % 4] floatValue] - frame.size.height / 2;
    
    _dealerLabel.frame= frame;
    _dealerLabel.translatesAutoresizingMaskIntoConstraints = YES;
    
    BOOL isSettingsVisible = ([_shootTheMoonLabel alpha] == 1.0);
    
    [self setView:_shootTheMoonLabel hidden:isSettingsVisible];
    [self setView:_moonBehaviorSegmentedControl hidden:isSettingsVisible];
    
    [self setView:_passDirectionLabel hidden:!isSettingsVisible];
    [self setView:_nextRoundButton hidden:!isSettingsVisible];
    [self setView:_nnewGameButton hidden:!isSettingsVisible];
    
    for (UITextField *field in _playerNameFields) {
        [self setView:field hidden:isSettingsVisible];
    }
    [self setView:_endingScoreTextField hidden:isSettingsVisible];
    for (UILabel *label in _playerNameLabels) {
        [self setView:label hidden:!isSettingsVisible];
    }
    for (UILabel *label in _playerSumScoreLabels) {
        [self setView:label hidden:!isSettingsVisible];
    }
    for (UICollectionView *view in _scoresCollectionViews) {
        [self setView:view hidden:!isSettingsVisible];
    }
    [self setView:_dealerLabel hidden:isSettingsVisible];
    
    
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
    
    [[Game sharedGameData] setPlayerNames: names];
    
    [self updatePlayerNames];
    [self updateDealerLabel];
    [self dismissKeyboard];
    
    [[Game sharedGameData] setEndingScore:[[_endingScoreTextField text] intValue]];
    [[Game sharedGameData] save];
}

#pragma mark - Next Round View
#pragma mark Actions

- (IBAction)touchNextRoundSubmitButton:(UIButton *)sender {
    // the sum must be 26 and a player must have a queen to be valid, unless a player shoots the moon.
    int nextRoundViewSum = [self getNextRoundViewSum];
    if (nextRoundViewSum == 26 || nextRoundViewSum == 78 || nextRoundViewSum == -26) {
        for(int i = 0; i < 4; i++) {
            NSMutableArray *scores = [[[[Game sharedGameData] players] objectAtIndex:i] scores];
            [scores addObject:[NSNumber numberWithInt:[[[_nextRoundScoreLabels objectAtIndex:i] text] intValue]]];
            [[[[Game sharedGameData] players] objectAtIndex:i] setScores:scores];
        }
        
        [self updatePassDirectionLabel];
        [self updatePlayerSumScoreLabels];
        
        for(UICollectionView *view in _scoresCollectionViews) {
            [view reloadData];
        }
        
        [self setView:_nextRoundView hidden:YES];
        
        [[Game sharedGameData] setDealerOffset:[[Game sharedGameData] dealerOffset] + 1];
        [self updateDealerLabel];
        [[Game sharedGameData] save];
    } else {
        [invalidScoreAlert show];
        [self resetNextRoundView];
    }
    
    for (Player *p in [[Game sharedGameData] players]) {
        if ([p sumScores] >= [[_endingScoreTextField text] intValue]) {
            [_gameOverLabel setText:[NSString stringWithFormat:@"%@ won the game!", [self getLowestScorerName]]];
            
            [self setView:_passDirectionLabel hidden:YES];
            
            for (UICollectionView *view in _scoresCollectionViews) {
                [self setView:view hidden:NO];
            }
            
            [_nextRoundButton setEnabled:NO];
            [_settingsButton setEnabled:NO];
        }
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
    
    BOOL isAQueenDisabled = false;
    
    for (UIButton* button in _nextRoundAddScoreButtons) {
        if ([[button currentTitle] isEqualToString:@"Q"]) {
            if (![button isEnabled]) {
                isAQueenDisabled = true;
            }
        }
    }
    
    if ([self getNextRoundViewSum] < 27) {
        [currentScoreLabel setText:[NSString stringWithFormat:@"%d", currentScore + value]];
    }
    if ([self getNextRoundViewSum] == 26) {
        if(isAQueenDisabled) {
            for (UIButton *button in _nextRoundAddScoreButtons) {
                [button setEnabled:NO];
            }
            
            [_nextRoundSubmitButton setEnabled:YES];
        } else {
            [[[UIAlertView alloc] initWithTitle:@"Invalid"
                                        message:@"A Queen must be played."
                                       delegate:self
                              cancelButtonTitle:@"Okay"
                              otherButtonTitles:nil] show];
            [self resetNextRoundView];
        }
    } else if ([self getNextRoundViewSum] > 27) {
        [invalidScoreAlert show];
        [self resetNextRoundView];
    }
}

- (NSString *)getLowestScorerName {
    Player *lowestScorer = [[[Game sharedGameData] players] objectAtIndex:0];
    
    for(Player *p in [[Game sharedGameData] players]) {
        if ([p sumScores] < [lowestScorer sumScores]) {
            lowestScorer = p;
        }
    }
    
    return [lowestScorer name];
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
// Hides the keyboard
//
- (void)dismissKeyboard {
    [_activeTextField resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    // if currently focused on first three text fields, go to the next text field
    if (textField.tag < 3) {
        [[_playerNameFields objectAtIndex:(textField.tag + 1)] becomeFirstResponder];
        // if currently focused on either Player 4 or ending score's text field, dismiss the keyboard.
    } else if (textField.tag == 3) {
        [self dismissKeyboard];
    }
    
    return YES;
}

- (void)moveViewWithGestureRecognizer:(UIPanGestureRecognizer *)panGestureRecognizer {
    CGPoint touchLocation = [panGestureRecognizer locationInView:self.view];
    
    CGRect frame = _dealerLabel.frame;
    
    // effectively detects a touch up
    // snaps dealer label to the closest player field
    if (panGestureRecognizer.state == UIGestureRecognizerStateEnded) {
        if (touchLocation.y < ([[_playerNameFieldYLocations objectAtIndex:0] floatValue] + [[_playerNameFieldYLocations objectAtIndex:1] floatValue]) / 2) {
            frame.origin.y = [[_playerNameFieldYLocations objectAtIndex:0] floatValue] - frame.size.height / 2;
            [[Game sharedGameData] setDealerOffset:0];
        } else if (touchLocation.y > ([[_playerNameFieldYLocations objectAtIndex:0] floatValue] + [[_playerNameFieldYLocations objectAtIndex:1] floatValue]) / 2 && touchLocation.y < ([[_playerNameFieldYLocations objectAtIndex:1] floatValue] + [[_playerNameFieldYLocations objectAtIndex:2] floatValue]) / 2) {
            frame.origin.y = [[_playerNameFieldYLocations objectAtIndex:1] floatValue] - frame.size.height / 2;
            [[Game sharedGameData] setDealerOffset:1];
        } else if (touchLocation.y > ([[_playerNameFieldYLocations objectAtIndex:1] floatValue] + [[_playerNameFieldYLocations objectAtIndex:2] floatValue]) / 2 && touchLocation.y < ([[_playerNameFieldYLocations objectAtIndex:2] floatValue] + [[_playerNameFieldYLocations objectAtIndex:3] floatValue]) / 2) {
            frame.origin.y = [[_playerNameFieldYLocations objectAtIndex:2] floatValue] - frame.size.height / 2;
            [[Game sharedGameData] setDealerOffset:2];
        } else if (touchLocation.y > ([[_playerNameFieldYLocations objectAtIndex:2] floatValue] + [[_playerNameFieldYLocations objectAtIndex:3] floatValue]) / 2) {
            frame.origin.y = [[_playerNameFieldYLocations objectAtIndex:3] floatValue] - frame.size.height / 2;
            [[Game sharedGameData] setDealerOffset:3];
        }
        
        [_dealerLabel setAlpha: 1.0];
        
        [[Game sharedGameData] save];
        
        // allow the dealer button to move freely in the y-plane while it is being dragged.
    } else {
        frame.origin.y = touchLocation.y - frame.size.height / 2;
        
        // fades dealer label out as it is dragged away from the first player text field.
        // the dealer label will begin to fade out when it reaches dealerFadeStart pixels above the first player text field's location,
        // and will completely fade out when it reaches dealerFadeStart + dealerFadeDistance pixels above the first player text field's location.
        if (touchLocation.y < ([[_playerNameFieldYLocations objectAtIndex:0] floatValue] - dealerFadeStart)) {
            [_dealerLabel setAlpha: MAX(1 - ([[_playerNameFieldYLocations objectAtIndex:0] floatValue] - touchLocation.y - dealerFadeStart) / dealerFadeDistance, 0)];
        }
        // fades dealer label out as it is dragged away from the last player's text field.
        if (touchLocation.y > ([[_playerNameFieldYLocations objectAtIndex:3] floatValue] + 20)) {
            [_dealerLabel setAlpha: MAX(1 + ([[_playerNameFieldYLocations objectAtIndex:3] floatValue] - touchLocation.y + dealerFadeStart) / dealerFadeDistance, 0)];
        }
    }
    
    _dealerLabel.frame = frame;
}

- (void)initPlayerNameFieldYLocations {
    CGFloat textFieldHeight = ((UITextField*)([_playerNameFields objectAtIndex:0])).frame.size.height;
    
    CGFloat firstYLocation = ((UITextField*)([_playerNameFields objectAtIndex:0])).frame.origin.y + textFieldHeight / 2;
    CGFloat secondYLocation = ((UITextField*)([_playerNameFields objectAtIndex:1])).frame.origin.y + textFieldHeight / 2;
    CGFloat thirdYLocation = ((UITextField*)([_playerNameFields objectAtIndex:2])).frame.origin.y + textFieldHeight / 2;
    CGFloat fourthYLocation = ((UITextField*)([_playerNameFields objectAtIndex:3])).frame.origin.y + textFieldHeight / 2;
    
    _playerNameFieldYLocations = [[NSArray alloc] initWithObjects:[NSNumber numberWithFloat:firstYLocation], [NSNumber numberWithFloat:secondYLocation], [NSNumber numberWithFloat:thirdYLocation], [NSNumber numberWithFloat:fourthYLocation], nil];
}

//
// Moves the view up/down whenever the keyboard is shown/dismissed
//
- (void)setViewMovedUp:(BOOL)movedUp
{
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3]; // if you want to slide up the view
    
    CGRect rect = self.view.frame;
    if (movedUp)
    {
        // 1. move the view's origin up so that the text field that will be hidden come above the keyboard
        // 2. increase the size of the view so that the area behind the keyboard is covered up.
        rect.origin.y -= kOFFSET_FOR_KEYBOARD;
        rect.size.height += kOFFSET_FOR_KEYBOARD;
    }
    else
    {
        // revert back to the normal state.
        rect.origin.y += kOFFSET_FOR_KEYBOARD;
        rect.size.height -= kOFFSET_FOR_KEYBOARD;
    }
    self.view.frame = rect;
    
    [UIView commitAnimations];
}

#pragma mark - Undo Last Round

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if ([[Game sharedGameData] numRounds] > 0) {
        if (UIEventSubtypeMotionShake) {
            [[[UIAlertView alloc] initWithTitle:undoTitleText
                                        message:@"Are you sure you would like to undo the last round?"
                                       delegate:self
                              cancelButtonTitle:@"No"
                              otherButtonTitles:@"Yes", nil] show];
        }
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if ([[alertView title] isEqualToString:undoTitleText]) {
        if (buttonIndex == [alertView firstOtherButtonIndex]) {
            for(int i = 0; i < 4; i++) {
                NSMutableArray *scores = [[[[Game sharedGameData] players] objectAtIndex:i] scores];
                [scores removeLastObject];
                [[[[Game sharedGameData] players] objectAtIndex:i] setScores:scores];
            }
            
            [self updatePassDirectionLabel];
            [self updatePlayerSumScoreLabels];
            
            [[Game sharedGameData] setNumRounds:[[Game sharedGameData] numRounds] - 1];
            
            for(UICollectionView *view in _scoresCollectionViews) {
                [view reloadData];
            }
            
            [[Game sharedGameData] setDealerOffset:[[Game sharedGameData] dealerOffset] - 1];
            [self updateDealerLabel];
        }
    } else if ([[alertView title] isEqualToString:resetGameTitleText]) {
        if (buttonIndex == [alertView firstOtherButtonIndex]) {
            [[Game sharedGameData] reset];
            
            [self updatePlayerNames];
            [self updatePassDirectionLabel];
            
            for(UICollectionView *view in _scoresCollectionViews) {
                [view reloadData];
            }
            
            [self updatePlayerSumScoreLabels];
            
            [_nextRoundButton setEnabled:YES];
            [_settingsButton setEnabled:YES];
            
            [self setView:_gameOverLabel hidden:YES];
            [self setView:_passDirectionLabel hidden:NO];
            
            [[Game sharedGameData] setDealerOffset:0];
            [self updateDealerLabel];
            [[Game sharedGameData] save];
        }
    }
}

@end