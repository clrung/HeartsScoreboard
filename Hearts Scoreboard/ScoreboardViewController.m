//
//  ViewController.m
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 2/26/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import "ScoreboardViewController.h"
#import "Game.h"
#import "Player.h"
#import "Settings.h"
#import "UIPlayerTextField.h"
#import "ScoreCollectionViewCell.h"

@interface ScoreboardViewController ()

@property (strong, nonatomic) IBOutletCollection(UILabel) NSArray *playerNameLabels;
@property (strong, nonatomic) IBOutletCollection(UILabel) NSArray *playerSumLabels;
@property (strong, nonatomic) IBOutletCollection(UICollectionView) NSArray *scoresCollectionViews;
@property (strong, nonatomic) IBOutlet UIButton *settingsButton;
@property (strong, nonatomic) IBOutlet UIButton *nnewGameButton;
@property (strong, nonatomic) IBOutlet UILabel  *passDirectionLabel;
@property (strong, nonatomic) IBOutlet UIButton *nextRoundButton;

@property (strong, nonatomic) IBOutletCollection(UIPlayerTextField) NSArray *playerTextFields;
@property (strong, nonatomic) NSArray *playerTextFieldYLocations;
@property (strong, nonatomic) IBOutlet UILabel *shootTheMoonLabel;
@property (strong, nonatomic) IBOutlet UISegmentedControl *moonPreferenceSegmentedControl;
@property (strong, nonatomic) IBOutlet UILabel  *dealerLabel;
@property (strong, nonatomic) IBOutlet UILabel  *endingScoreLabel;
@property (strong, nonatomic) IBOutlet UISlider *endingScoreSlider;

@property (strong, nonatomic) IBOutlet UIView *nextRoundView;
@property (strong, nonatomic) IBOutletCollection(UILabel) NSArray *nextRoundPlayerNameLabels;
@property (strong, nonatomic) IBOutletCollection(UILabel) NSArray *nextRoundScoreLabels;
@property (strong, nonatomic) IBOutlet UIButton *nextRoundSubmitButton;
@property (strong, nonatomic) IBOutletCollection(UIButton) NSArray *nextRoundAddScoreButtons;

@property (strong, nonatomic) IBOutlet UILabel *gameOverLabel;

@end

@implementation ScoreboardViewController

static int const dealerFadeStart          = 20;
static int const dealerFadeDistance       = 25;
static int const endScoreSliderStep       = 5;
static NSString* const undoTitleText      = @"Undo last round?";
static NSString* const resetGameTitleText = @"Reset Game?";

static UIAlertView const *invalidScoreAlert;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                                           action:@selector(moveViewWithGestureRecognizer:)];
    [_dealerLabel addGestureRecognizer:panGestureRecognizer];
    [_dealerLabel setUserInteractionEnabled:YES];
    
    [self sortCollectionsByTag];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didUpdateGameData:)
                                                 name:GameDataUpdatedFromiCloud
                                               object:nil];
}

-(void)didUpdateGameData:(NSNotification*)n {
    [self updateUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    for (UIPlayerTextField *textField in _playerTextFields) {
        if ([textField tag] < 3) {
            [textField setNextTextField:[_playerTextFields objectAtIndex:[textField tag] + 1]];
        }
        if ([textField tag] > 0) {
            [textField setPreviousTextField:[_playerTextFields objectAtIndex:[textField tag] - 1]];
        }
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateDealerLabelLocation)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self updateUI];
    
    invalidScoreAlert = [[UIAlertView alloc] initWithTitle:@"Invalid Scores"
                                                   message:@"The sum of the scores must be equal to 26."
                                                  delegate:self
                                         cancelButtonTitle:@"Okay"
                                         otherButtonTitles:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDeviceOrientationDidChangeNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:GameDataUpdatedFromiCloud
                                                  object:nil];
}

#pragma mark - Scoreboard
#pragma mark Button Actions

- (IBAction)touchNextRoundButton:(UIButton *)sender {
    [self resetNextRoundView];
    
    [self setView:_nextRoundView hidden:NO];
}

- (IBAction)touchNewGameButton:(UIButton *)sender {
    [[[UIAlertView alloc] initWithTitle:resetGameTitleText
                                message:@"Are you sure you would like to start a new game?"
                               delegate:self
                      cancelButtonTitle:@"No"
                      otherButtonTitles:@"Yes", nil] show];
}

- (IBAction)touchSettingsButton:(UIButton *)sender {
    [self updateDealerLabelLocation];
    
    BOOL isSettingsVisible = ([_shootTheMoonLabel alpha] == 1.0);
    
    // Settings
    
    for (UITextField *field in _playerTextFields) {
        [self setView:field hidden:isSettingsVisible];
    }
    
    [self setView:_shootTheMoonLabel              hidden:isSettingsVisible];
    [self setView:_moonPreferenceSegmentedControl hidden:isSettingsVisible];
    
    [self setView:_endingScoreLabel  hidden:isSettingsVisible];
    [self setView:_endingScoreSlider hidden:isSettingsVisible];
    
    [self setView:_dealerLabel       hidden:isSettingsVisible];
    
    // Main screen
    
    [self setView:_passDirectionLabel hidden:!isSettingsVisible];
    [self setView:_nextRoundButton    hidden:!isSettingsVisible];
    [self setView:_nnewGameButton     hidden:!isSettingsVisible];
    
    for (UILabel *label in _playerNameLabels) {
        [self setView:label hidden:!isSettingsVisible];
    }
    for (UILabel *label in _playerSumLabels) {
        [self setView:label hidden:!isSettingsVisible];
    }
    for (UICollectionView *view in _scoresCollectionViews) {
        [self setView:view hidden:!isSettingsVisible];
    }
    
    [self updateCurrentDealer];
    [[self view] endEditing:YES];
}

#pragma mark Scores Collection

//
// The scores collection view will only have one column.
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
    
    setScoreLabel([collectionView tag]);
    
    return scoreCell;
}

//
// Mirror scrolling of the scores collection view
//
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGPoint offset = [scrollView contentOffset];
    for(UICollectionView *view in _scoresCollectionViews) {
        view.contentOffset = CGPointMake(0, offset.y);
    }
}

- (void)updateUI {
    [self updatePlayerNames];
    [self updatePlayerSumLabels];
    [self updatePassDirectionLabel];
    [self updateCurrentDealer];
    [self updateSettings];
    [self updatePlayerNameFieldYLocations];
    [self checkGameOver];
    
    for(UICollectionView *view in _scoresCollectionViews) {
        [view reloadData];
    }
}

#pragma mark Update Text

- (void)updatePlayerNames {
    for(UILabel *label in _playerNameLabels) {
        [label setText:[[[Game sharedGameData] playerNames] objectAtIndex:[label tag]]];
    }
    for(UILabel *label in _nextRoundPlayerNameLabels) {
        [label setText:[[[Game sharedGameData] playerNames] objectAtIndex:[label tag]]];
    }
    for(UITextField *field in _playerTextFields) {
        [field setText:[[[Game sharedGameData] playerNames] objectAtIndex:[field tag]]];
    }
}

- (void)updatePlayerSumLabels {
    for(UILabel *label in _playerSumLabels) {
        [label setText:[NSString stringWithFormat:@"%ld", (long)[[[[Game sharedGameData] players] objectAtIndex:[label tag]] sumScores]]];
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

//
// Indicate the current dealer by changing the label's font to bold.
//
- (void)updateCurrentDealer {
    for (UILabel *label in _playerNameLabels) {
        if ([[Settings sharedSettingsData] dealerOffset] % 4 == [label tag]) {
            [label setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size: 17]];
        } else {
            [label setFont:[UIFont fontWithName:@"HelveticaNeue" size: 17]];
        }
    }
}

#pragma mark - Next Round View
#pragma mark Button Actions

- (IBAction)touchNextRoundSubmitButton:(UIButton *)sender {
    // The sum must be 26 and a player must have a queen to be valid, unless a player shoots the moon.
    int nextRoundViewSum = [self getNextRoundViewSum];
    if (nextRoundViewSum == 26 || nextRoundViewSum == 78 || nextRoundViewSum == -26) {
        for(int i = 0; i < 4; i++) {
            NSMutableArray *scores = [[[[Game sharedGameData] players] objectAtIndex:i] scores];
            [scores addObject:[NSNumber numberWithInt:[[[_nextRoundScoreLabels objectAtIndex:i] text] intValue]]];
            [[[[Game sharedGameData] players] objectAtIndex:i] setScores:scores];
        }
        [[Game sharedGameData] save];
        
        [self updatePassDirectionLabel];
        [self updatePlayerSumLabels];
        
        for(UICollectionView *view in _scoresCollectionViews) {
            [view reloadData];
        }
        
        [self setView:_nextRoundView hidden:YES];
        
        [[Settings sharedSettingsData] setDealerOffset:[[Settings sharedSettingsData] dealerOffset] + 1];
        [[Settings sharedSettingsData] save];
        [self updateCurrentDealer];
    } else {
        [invalidScoreAlert show];
        [self resetNextRoundView];
    }
    
    [self checkGameOver];
}

- (IBAction)touchNextRoundResetButton:(UIButton *)sender {
    [self resetNextRoundView];
}

- (IBAction)touchAddScore:(UIButton *)sender {
    NSArray *choices = @[@"+1", @"+5", @"Q"];
    NSUInteger item = [choices indexOfObject:[sender currentTitle]];
    
    UILabel *currentScoreLabel = [_nextRoundScoreLabels objectAtIndex:[sender tag]];
    
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
                if ([[button currentTitle] isEqualToString:@"Q"]) {
                    [button setEnabled:NO];
                }
            }
            
            break;
    }
}

- (IBAction)touchShootMoon:(UIButton *)sender {
    if([_moonPreferenceSegmentedControl selectedSegmentIndex] == 0) { // add 26
        for (UILabel *label in _nextRoundScoreLabels) {
            [label setText:@"26"];
        }
        [(UILabel *)[_nextRoundScoreLabels objectAtIndex:[sender tag]] setText:@"0"];
    } else { // subtract 26
        for (UILabel *label in _nextRoundScoreLabels) {
            [label setText:@"0"];
        }
        [(UILabel *)[_nextRoundScoreLabels objectAtIndex:[sender tag]] setText:@"-26"];
    }
    
    for (UIButton *button in _nextRoundAddScoreButtons) {
        [button setEnabled:NO];
    }
    
    [_nextRoundSubmitButton setEnabled:YES];
}

#pragma mark Helper Methods

- (void)resetNextRoundView {
    [_nextRoundSubmitButton setEnabled:NO];
    
    for (UILabel *label in _nextRoundScoreLabels) {
        [label setText:@"0"];
    }
    
    for (UIButton *button in _nextRoundAddScoreButtons) {
        [button setEnabled:YES];
    }
}

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

#pragma mark - Settings
#pragma mark End Score Slider

- (IBAction)endScoreSliderDidTouchUpInside:(UISlider *)slider {
    [[Settings sharedSettingsData] setEndingScore:[slider value]];
    [[Settings sharedSettingsData] save];
}

- (IBAction)endScoreSliderDidTouchUpOutside:(UISlider *)slider {
    [self endScoreSliderDidTouchUpInside:slider];
}

- (IBAction)endScoreSliderValueDidChange:(UISlider *)slider {
    [slider setValue:roundf([slider value] / endScoreSliderStep) * endScoreSliderStep];
    
    [_endingScoreLabel setText:[NSString stringWithFormat:@"Ending Score: %d", (int)[slider value]]];
}

#pragma mark Dealer Label

- (void)updateDealerLabelLocation {
    [self updatePlayerNameFieldYLocations];
    CGRect frame = [_dealerLabel frame];
    
    frame.origin.y = [[_playerTextFieldYLocations objectAtIndex:[[Settings sharedSettingsData] dealerOffset] % 4] intValue] - frame.size.height / 2;
    frame.origin.x = ((UITextField*)([_playerTextFields objectAtIndex:0])).frame.origin.x + ((UITextField*)([_playerTextFields objectAtIndex:0])).frame.size.width + 15;
    
    _dealerLabel.translatesAutoresizingMaskIntoConstraints = YES;
    _dealerLabel.frame= frame;
}

- (void)moveViewWithGestureRecognizer:(UIPanGestureRecognizer *)panGestureRecognizer {
    CGPoint touchLocation = [panGestureRecognizer locationInView:self.view];
    
    CGRect frame = _dealerLabel.frame;
    
    // effectively detects a touch up
    // snaps dealer label to the closest player field
    if (panGestureRecognizer.state == UIGestureRecognizerStateEnded) {
        if (touchLocation.y < ([[_playerTextFieldYLocations objectAtIndex:0] floatValue] + [[_playerTextFieldYLocations objectAtIndex:1] floatValue]) / 2) {
            frame.origin.y = [[_playerTextFieldYLocations objectAtIndex:0] floatValue] - frame.size.height / 2;
            [[Settings sharedSettingsData] setDealerOffset:0];
        } else if (touchLocation.y > ([[_playerTextFieldYLocations objectAtIndex:0] floatValue] + [[_playerTextFieldYLocations objectAtIndex:1] floatValue]) / 2 && touchLocation.y < ([[_playerTextFieldYLocations objectAtIndex:1] floatValue] + [[_playerTextFieldYLocations objectAtIndex:2] floatValue]) / 2) {
            frame.origin.y = [[_playerTextFieldYLocations objectAtIndex:1] floatValue] - frame.size.height / 2;
            [[Settings sharedSettingsData] setDealerOffset:1];
        } else if (touchLocation.y > ([[_playerTextFieldYLocations objectAtIndex:1] floatValue] + [[_playerTextFieldYLocations objectAtIndex:2] floatValue]) / 2 && touchLocation.y < ([[_playerTextFieldYLocations objectAtIndex:2] floatValue] + [[_playerTextFieldYLocations objectAtIndex:3] floatValue]) / 2) {
            frame.origin.y = [[_playerTextFieldYLocations objectAtIndex:2] floatValue] - frame.size.height / 2;
            [[Settings sharedSettingsData] setDealerOffset:2];
        } else if (touchLocation.y > ([[_playerTextFieldYLocations objectAtIndex:2] floatValue] + [[_playerTextFieldYLocations objectAtIndex:3] floatValue]) / 2) {
            frame.origin.y = [[_playerTextFieldYLocations objectAtIndex:3] floatValue] - frame.size.height / 2;
            [[Settings sharedSettingsData] setDealerOffset:3];
        }
        
        [_dealerLabel setAlpha: 1.0];
        
        [[Settings sharedSettingsData] save];
        
        // allow the dealer button to move freely in the y-plane while it is being dragged.
    } else {
        frame.origin.y = touchLocation.y - frame.size.height / 2;
        
        // fades dealer label out as it is dragged away from the first player text field
        // The dealer label will begin to fade out when it reaches dealerFadeStart pixels above the first player text field's location,
        // and will completely fade out when it reaches dealerFadeStart + dealerFadeDistance pixels above the first player text field's location.
        if (touchLocation.y < ([[_playerTextFieldYLocations objectAtIndex:0] floatValue] - dealerFadeStart)) {
            [_dealerLabel setAlpha: MAX(1 - ([[_playerTextFieldYLocations objectAtIndex:0] floatValue] - touchLocation.y - dealerFadeStart) / dealerFadeDistance, 0)];
        }
        // fades dealer label out as it is dragged away from the last player's text field
        if (touchLocation.y > ([[_playerTextFieldYLocations objectAtIndex:3] floatValue] + 20)) {
            [_dealerLabel setAlpha: MAX(1 + ([[_playerTextFieldYLocations objectAtIndex:3] floatValue] - touchLocation.y + dealerFadeStart) / dealerFadeDistance, 0)];
        }
    }
    
    _dealerLabel.frame = frame;
}

#pragma mark Other

- (IBAction)playerNameFieldsEditingDidEnd:(UIPlayerTextField *)sender {
    NSArray* names = [[NSArray alloc] init];
    
    for(UITextField *field in _playerTextFields) {
        names = [names arrayByAddingObject:[field text]];
    }
    
    [[Game sharedGameData] setPlayerNames: names];
    [[Game sharedGameData] save];
    
    [self updatePlayerNames];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    // if currently focused on first three text fields, go to the next text field
    if ([textField tag] < 3) {
        [[_playerTextFields objectAtIndex:([textField tag] + 1)] becomeFirstResponder];
        // if currently focused on either Player 4 or ending score's text field, dismiss the keyboard.
    } else if ([textField tag] == 3) {
        [textField resignFirstResponder];
    }
    
    return YES;
}

- (void)updatePlayerNameFieldYLocations {
    CGFloat textFieldHeight = ((UITextField*)([_playerTextFields objectAtIndex:0])).frame.size.height;
    
    CGFloat firstYLocation  = ((UITextField*)([_playerTextFields objectAtIndex:0])).frame.origin.y + textFieldHeight / 2;
    CGFloat secondYLocation = ((UITextField*)([_playerTextFields objectAtIndex:1])).frame.origin.y + textFieldHeight / 2;
    CGFloat thirdYLocation  = ((UITextField*)([_playerTextFields objectAtIndex:2])).frame.origin.y + textFieldHeight / 2;
    CGFloat fourthYLocation = ((UITextField*)([_playerTextFields objectAtIndex:3])).frame.origin.y + textFieldHeight / 2;
    
    
    _playerTextFieldYLocations = [[NSArray alloc] initWithObjects:[NSNumber numberWithFloat:firstYLocation],
                                  [NSNumber numberWithFloat:secondYLocation],
                                  [NSNumber numberWithFloat:thirdYLocation],
                                  [NSNumber numberWithFloat:fourthYLocation], nil];
}

- (IBAction)shootTheMoonBehaviorValueChanged:(UISegmentedControl *)sender {
    [sender selectedSegmentIndex] == 0 ? [[Settings sharedSettingsData] setMoonBehaviorIsAdd:YES] : [[Settings sharedSettingsData] setMoonBehaviorIsAdd:NO];
    [[Settings sharedSettingsData] save];
}

- (void)updateSettings {
    [_endingScoreSlider setValue:[[Settings sharedSettingsData] endingScore]];
    [_endingScoreLabel setText:[NSString stringWithFormat:@"Ending Score: %d", [[Settings sharedSettingsData] endingScore]]];
    
    [_moonPreferenceSegmentedControl setSelectedSegmentIndex:![[Settings sharedSettingsData] moonBehaviorIsAdd]];
}

#pragma mark

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if ([[Game sharedGameData] numRounds] > 0) {
        if ([event subtype] == UIEventSubtypeMotionShake) {
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
            [self updatePlayerSumLabels];
            
            for(UICollectionView *view in _scoresCollectionViews) {
                [view reloadData];
            }
            
            [[Settings sharedSettingsData] setDealerOffset:[[Settings sharedSettingsData] dealerOffset] - 1];
            [[Settings sharedSettingsData] save];
            [self updateCurrentDealer];
        }
    } else if ([[alertView title] isEqualToString:resetGameTitleText]) {
        if (buttonIndex == [alertView firstOtherButtonIndex]) {
            [[Game sharedGameData] reset];
            [[Game sharedGameData] save];
            
            [[Settings sharedSettingsData] setDealerOffset:0];
            [[Settings sharedSettingsData] save];
            
            [self updatePassDirectionLabel];
            
            for(UICollectionView *view in _scoresCollectionViews) {
                [self setView:view hidden:NO];
                [view reloadData];
            }
            
            [self updatePlayerSumLabels];
            [self updateCurrentDealer];
            
            [_nextRoundButton setEnabled:YES];
            [_settingsButton  setEnabled:YES];
            
            [self setView:_gameOverLabel      hidden:YES];
            [self setView:_passDirectionLabel hidden:NO];
        }
    }
}

- (void)setView:(UIView*)view hidden:(BOOL)hidden {
    [UIView animateWithDuration:0.5 animations:^() {
        hidden ? [view setAlpha:0.0] : [view setAlpha:1.0];
    }];
}

//
// Ensure the UICollections are sorted in tag order.
//
- (void)sortCollectionsByTag {
    _playerTextFields = [_playerTextFields sortedArrayUsingComparator:^NSComparisonResult(id objA, id objB){
        return(
               ([objA tag] < [objB tag]) ? NSOrderedAscending  :
               ([objA tag] > [objB tag]) ? NSOrderedDescending :
               NSOrderedSame);
    }];
    _nextRoundScoreLabels = [_nextRoundScoreLabels sortedArrayUsingComparator:^NSComparisonResult(id objA, id objB){
        return(
               ([objA tag] < [objB tag]) ? NSOrderedAscending  :
               ([objA tag] > [objB tag]) ? NSOrderedDescending :
               NSOrderedSame);
    }];
}

- (void)checkGameOver {
    for (Player *p in [[Game sharedGameData] players]) {
        if ([p sumScores] >= [_endingScoreSlider value]) {
            [_gameOverLabel setText:[NSString stringWithFormat:@"%@ won!", [self getLowestScorerName]]];
            
            [self setView:_passDirectionLabel hidden:YES];
            [self setView:_gameOverLabel      hidden:NO];
            
            for (UICollectionView *view in _scoresCollectionViews) {
                [self setView:view hidden:YES];
            }
            
            [_nextRoundButton setEnabled:NO];
            [_settingsButton  setEnabled:NO];
        }
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

@end