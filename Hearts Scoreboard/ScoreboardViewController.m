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

@property (strong, nonatomic) IBOutlet UIView *mainView;
@property (strong, nonatomic) IBOutletCollection(UIView) NSArray *secondaryViews;
@property (strong, nonatomic) IBOutlet UILabel *heartsScoreBoardTitleLabel;
@property (strong, nonatomic) NSMutableArray *colorArray;

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
@property (strong, nonatomic) IBOutlet UISegmentedControl *colorPreferenceSegmentedControl;
@property (strong, nonatomic) IBOutlet UILabel  *endingScoreLabel;
@property (strong, nonatomic) IBOutlet UISlider *endingScoreSlider;
@property (strong, nonatomic) IBOutlet UIButton *infoButton;
@property (strong, nonatomic) IBOutlet UITextView *infoTextView;
@property (strong, nonatomic) IBOutlet UIButton *rateOnAppStoreButton;

@property (strong, nonatomic) IBOutlet UIView *nextRoundView;
@property (strong, nonatomic) IBOutletCollection(UILabel) NSArray *nextRoundPlayerNameLabels;
@property (strong, nonatomic) IBOutletCollection(UILabel) NSArray *nextRoundScoreLabels;
@property (strong, nonatomic) IBOutlet UIButton *nextRoundSubmitButton;
@property (strong, nonatomic) IBOutlet UIButton *nextRoundResetButton;
@property (strong, nonatomic) IBOutlet UIButton *nextRoundBackButton;
@property (strong, nonatomic) IBOutletCollection(UIButton) NSArray *nextRoundAddScoreButtons;
@property (strong, nonatomic) IBOutletCollection(UIButton) NSArray *nextRoundDecrementButtons;
@property (strong, nonatomic) IBOutletCollection(UIButton) NSArray *nextRoundIncrementButtons;
@property NSInteger queenSelectedIndex; // -1 when no Queen is selected

@property (strong, nonatomic) IBOutlet UILabel *gameOverLabel;

@property (strong, nonatomic) UIAlertController *invalidScoreAlert;

@end

@implementation ScoreboardViewController

static int const DEALER_FADE_START           = 20;
static int const DEALER_FADE_DISTANCE        = 25;
static int const END_SCORE_SLIDER_STEP       = 5;

// Colors
static int const TOP_BOTTOM_BOARDER          = 0;
static int const SCORE_CELL_BACKGROUNDS      = 1;
static int const MAIN_BACKGROUND             = 2;
static int const BUTTONS                     = 3;
static int const TEXT                        = 4;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                                           action:@selector(moveViewWithGestureRecognizer:)];
    [_dealerLabel addGestureRecognizer:panGestureRecognizer];
    [_dealerLabel setUserInteractionEnabled:YES];
    
    [self sortCollectionsByTag];
    
    [[NSUbiquitousKeyValueStore defaultStore] synchronize];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didUpdateGameData:)
                                                 name:GameDataUpdatedFromiCloud
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didUpdateSettingsData:)
                                                 name:SettingsDataUpdatedFromiCloud
                                               object:nil];
    
    if (!_colorArray) {
        _colorArray = [[NSMutableArray alloc] initWithArray:[NSArray arrayOfColorsWithColorScheme:ColorSchemeComplementary
                                                                                       usingColor:[UIColor flatGreenColor]
                                                                                   withFlatScheme:YES]];
        [_colorArray replaceObjectAtIndex:TEXT withObject:[_colorArray objectAtIndex:TOP_BOTTOM_BOARDER]];
        [_colorArray replaceObjectAtIndex:BUTTONS withObject:[UIColor colorWithRed:0.0 green:122.0/255.0 blue:1.0 alpha:1.0]]; // blue
    }
    
    UIImage *image = [[UIImage imageNamed:@"settings-icon"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [_settingsButton setImage:image forState:UIControlStateNormal];
}

- (void)didUpdateGameData:(NSNotification*)n {
    [self updateUI];
}

- (void)didUpdateSettingsData:(NSNotification*)n {
    [self updateSettings];
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
    
    _invalidScoreAlert = [UIAlertController alertControllerWithTitle:@"Invalid"
                                                             message:@"The sum of the scores must be equal to 26."
                                                      preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* okay = [UIAlertAction actionWithTitle:@"Okay"
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * action)
                           {
                               [_invalidScoreAlert dismissViewControllerAnimated:YES completion:nil];
                           }];
    
    [_invalidScoreAlert addAction:okay];
    
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDeviceOrientationDidChangeNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:GameDataUpdatedFromiCloud
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:SettingsDataUpdatedFromiCloud
                                                  object:nil];
}

#pragma mark - Scoreboard
#pragma mark Button Actions

- (IBAction)touchNextRoundButton:(UIButton *)sender {
    [self resetNextRoundView];
    
    [self setView:_nextRoundView hidden:NO];
}

- (IBAction)touchNewGameButton:(UIButton *)sender {
    UIAlertController* resetGameAlert = [UIAlertController alertControllerWithTitle:@"Reset Game"
                                                                            message:@"Are you sure you would like to start a new game?"
                                                                     preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* no = [UIAlertAction actionWithTitle:@"No"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action)
                         {
                             [resetGameAlert dismissViewControllerAnimated:YES completion:nil];
                         }];
    
    UIAlertAction* yes = [UIAlertAction actionWithTitle:@"Yes"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * action)
                          {
                              [[Game sharedGameData] reset];
                              [[Game sharedGameData] save];
                              
                              [[Settings sharedSettingsData] setDealerOffset:0];
                              [[Settings sharedSettingsData] save];
                              
                              [self updatePassDirectionLabel];
                              
                              for (UICollectionView *view in _scoresCollectionViews) {
                                  [self setView:view hidden:NO];
                                  [view reloadData];
                              }
                              
                              [self updatePlayerSumLabels];
                              [self updateCurrentDealer];
                              
                              [_nextRoundButton setEnabled:YES];
                              [_nextRoundButton setTitle:@"Start Game" forState:UIControlStateNormal];
                              [_nnewGameButton  setEnabled:NO];
                              [_settingsButton  setEnabled:YES];
                              
                              [self setView:_gameOverLabel      hidden:YES];
                              [self setView:_passDirectionLabel hidden:NO];
                              
                              [resetGameAlert dismissViewControllerAnimated:YES completion:nil];
                          }];
    
    [resetGameAlert addAction:no];
    [resetGameAlert addAction:yes];
    [self presentViewController:resetGameAlert animated:YES completion:nil];
    
}

- (IBAction)touchSettingsButton:(UIButton *)sender {
    [self updateDealerLabelLocation];
    
    BOOL isSettingsVisible = ([_shootTheMoonLabel alpha] == 1.0);
    
    [self setSettingsVisible:isSettingsVisible];
    [self setView:_infoButton        hidden:isSettingsVisible];
    
    [self setMainScreenVisible:!isSettingsVisible];
    
    [self updateCurrentDealer];
    [[self view] endEditing:YES];
    
    [self updateColors];
}

#pragma mark Scores Collection View

//
// The scores collection view will only have one column.
//
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [[Game sharedGameData] numRounds];
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(collectionView.frame.size.width * .7, collectionView.frame.size.width * .48);
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    ScoreCollectionViewCell *scoreCell = (ScoreCollectionViewCell*)[collectionView dequeueReusableCellWithReuseIdentifier:@"scoreCell" forIndexPath:indexPath];
    
    void (^setScoreLabel)(NSUInteger playerTag) = ^(NSUInteger playerTag) {
        [[scoreCell scoreLabel] setText:[NSString stringWithFormat:@"%@", [[[[[Game sharedGameData] players] objectAtIndex:playerTag] scores] objectAtIndex:[indexPath item]]]];
    };
    
    setScoreLabel([collectionView tag]);
    
    [scoreCell setBackgroundColor:[_colorArray objectAtIndex:SCORE_CELL_BACKGROUNDS]];
    
    return scoreCell;
}

//
// Mirror scrolling of the scores collection view
//
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGPoint offset = [scrollView contentOffset];
    for (UICollectionView *view in _scoresCollectionViews) {
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
    [self updateColors];
    
    for (UICollectionView *view in _scoresCollectionViews) {
        [view reloadData];
    }
    
    if ([[Game sharedGameData] numRounds] == 0) {
        [_nextRoundButton setTitle:@"Start Game" forState:UIControlStateNormal];
        [_nnewGameButton setEnabled:NO];
    } else {
        [_nextRoundButton setTitle:@"Next Round" forState:UIControlStateNormal];
        [_nnewGameButton setEnabled:YES];
    }
    
}

- (void)updateColors {
    BOOL isSettingsVisible = ([_shootTheMoonLabel alpha] == 1.0);
    
    [_mainView setBackgroundColor:[_colorArray objectAtIndex:MAIN_BACKGROUND]];
    [_nextRoundView setBackgroundColor:[_colorArray objectAtIndex:MAIN_BACKGROUND]];
    for (UIView *view in _secondaryViews) {
        [view setBackgroundColor:[_colorArray objectAtIndex:TOP_BOTTOM_BOARDER]];
    }
    
    [_nnewGameButton setTintColor:[_colorArray objectAtIndex:MAIN_BACKGROUND]];
    [_nextRoundButton setTintColor:[_colorArray objectAtIndex:MAIN_BACKGROUND]];
    
    // Buttons
    isSettingsVisible ? [_settingsButton setTintColor:[_colorArray objectAtIndex:BUTTONS]] : [_settingsButton setTintColor:[_colorArray objectAtIndex:MAIN_BACKGROUND]];;
    
    for (UIButton *button in _nextRoundAddScoreButtons) {
        [button setTintColor:[_colorArray objectAtIndex:BUTTONS]];
    }
    
    // next round view
    for (UIButton *button in _nextRoundDecrementButtons) {
        [button setTintColor:[_colorArray objectAtIndex:BUTTONS]];
    }
    for (UIButton *button in _nextRoundIncrementButtons) {
        [button setTintColor:[_colorArray objectAtIndex:BUTTONS]];
    }
    for (UIButton *button in _nextRoundAddScoreButtons) {
        [button setTintColor:[_colorArray objectAtIndex:BUTTONS]];
    }
    [_nextRoundSubmitButton setTintColor:[_colorArray objectAtIndex:BUTTONS]];
    [_nextRoundResetButton setTintColor:[_colorArray objectAtIndex:BUTTONS]];
    [_nextRoundBackButton setTintColor:[_colorArray objectAtIndex:BUTTONS]];
    
    // settings
    [_colorPreferenceSegmentedControl setTintColor:[_colorArray objectAtIndex:BUTTONS]];
    [_moonPreferenceSegmentedControl setTintColor:[_colorArray objectAtIndex:BUTTONS]];
    [_endingScoreSlider setTintColor:[_colorArray objectAtIndex:BUTTONS]];
    [_infoButton setTintColor:[_colorArray objectAtIndex:BUTTONS]];
    
    [_rateOnAppStoreButton setTintColor:[_colorArray objectAtIndex:BUTTONS]];
    
    // Text
    isSettingsVisible ? [_heartsScoreBoardTitleLabel setTextColor:[_colorArray objectAtIndex:TOP_BOTTOM_BOARDER]] : [_heartsScoreBoardTitleLabel setTextColor:[UIColor whiteColor]];
    for (UITextField *field in _playerTextFields) {
        [field setBackgroundColor:[_colorArray objectAtIndex:SCORE_CELL_BACKGROUNDS]];
    }
    [_dealerLabel setTextColor:[_colorArray objectAtIndex:TEXT]];
    [_endingScoreLabel setTextColor:[_colorArray objectAtIndex:TEXT]];
    [_shootTheMoonLabel setTextColor:[_colorArray objectAtIndex:TEXT]];
    
    for (UILabel *label in _nextRoundPlayerNameLabels) {
        [label setTextColor:[_colorArray objectAtIndex:TEXT]];
    }
    for (UILabel *label in _nextRoundScoreLabels) {
        [label setTextColor:[_colorArray objectAtIndex:TEXT]];
    }
    
    [_infoTextView setTextColor:[_colorArray objectAtIndex:TEXT]];
    
    for (UICollectionView *view in _scoresCollectionViews) {
        [view reloadData];
    }
}

#pragma mark Update Text

- (void)updatePlayerNames {
    for (UILabel *label in _playerNameLabels) {
        [label setText:[[[Game sharedGameData] playerNames] objectAtIndex:[label tag]]];
    }
    for (UILabel *label in _nextRoundPlayerNameLabels) {
        [label setText:[[[Game sharedGameData] playerNames] objectAtIndex:[label tag]]];
    }
    for (UITextField *field in _playerTextFields) {
        [field setText:[[[Game sharedGameData] playerNames] objectAtIndex:[field tag]]];
    }
}

- (void)updatePlayerSumLabels {
    for (UILabel *label in _playerSumLabels) {
        [label setText:[NSString stringWithFormat:@"%ld", (long)[[[[Game sharedGameData] players] objectAtIndex:[label tag]] sumScores]]];
    }
}

- (void)updatePassDirectionLabel {
    switch ([[Game sharedGameData] numRounds] % 4) {
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
    int size = 0;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        size = 24;
    } else {
        size = 15;
    }
    
    for (UILabel *label in _playerNameLabels) {
        if ([[Settings sharedSettingsData] dealerOffset] % 4 == [label tag]) {
            [label setFont:[UIFont boldSystemFontOfSize:size]];
        } else {
            [label setFont:[UIFont systemFontOfSize:size]];
        }
    }
}

#pragma mark - Next Round View
#pragma mark Button Actions

- (IBAction)touchNextRoundSubmitButton:(UIButton *)sender {
    // The sum must be 26 and a player must have a queen to be valid, unless a player shoots the moon.
    int nextRoundViewSum = [self getNextRoundViewSum];
    
    if (nextRoundViewSum == 26 || nextRoundViewSum == 78 || nextRoundViewSum == -26) {
        for (int i = 0; i < 4; i++) {
            NSMutableArray *scores = [[[[Game sharedGameData] players] objectAtIndex:i] scores];
            [scores addObject:[NSNumber numberWithInt:[[[_nextRoundScoreLabels objectAtIndex:i] text] intValue]]];
            [[[[Game sharedGameData] players] objectAtIndex:i] setScores:scores];
        }
        
        [[Game sharedGameData] save];
        
        [self updatePassDirectionLabel];
        [self updatePlayerSumLabels];
        
        for (UICollectionView *view in _scoresCollectionViews) {
            [view reloadData];
        }
        
        [self setView:_nextRoundView hidden:YES];
        
        [[Settings sharedSettingsData] setDealerOffset:[[Settings sharedSettingsData] dealerOffset] + 1];
        [[Settings sharedSettingsData] save];
        
        [self updateCurrentDealer];
        
        [_nextRoundButton setTitle:@"Next Round" forState:UIControlStateNormal];
        [_nnewGameButton setEnabled:YES];
    } else {
        [self presentViewController:_invalidScoreAlert animated:YES completion:nil];
    }
    
    [self checkGameOver];
}

- (IBAction)touchNextRoundResetButton:(UIButton *)sender {
    [self resetNextRoundView];
}

- (IBAction)touchNextRoundBackButton:(UIButton *)sender {
    [self setView:_nextRoundView hidden:YES];
}

- (IBAction)touchAddScore:(UIButton *)sender {
    NSArray *choices = @[@"+5", @"Q♠︎", @"     -", @"+     "];
    NSUInteger item = [choices indexOfObject:[sender currentTitle]];
    
    UILabel *currentScoreLabel = [_nextRoundScoreLabels objectAtIndex:[sender tag]];
    
    switch (item) {
        case 0:     // +5
            [self addToCurrentScoreLabel:currentScoreLabel withValue:5];
            
            [[_nextRoundDecrementButtons objectAtIndex:sender.tag] setEnabled:YES];
            break;
        case 1:     // Q♠︎
        {
            int scoreBefore = [[currentScoreLabel text] intValue];
            [self addToCurrentScoreLabel:currentScoreLabel withValue:13];
            int scoreAfter = [[currentScoreLabel text] intValue];
            BOOL queenWasAdded = scoreAfter == scoreBefore + 13;
            
            // disable the Q buttons; there is only one Queen of Spades
            // only disable if the Queen was added to the score
            if (queenWasAdded) {
                _queenSelectedIndex = [sender tag];
                
                for (UIButton *button in _nextRoundAddScoreButtons) {
                    if ([[button currentTitle] isEqualToString:@"Q♠︎"]) {
                        [button setEnabled:NO];
                    }
                }
            }
            
            break;
        }
        case 2:     // -
            [self addToCurrentScoreLabel:currentScoreLabel withValue:-1];
            
            if ([[currentScoreLabel text] isEqualToString:@"0"] || ([[currentScoreLabel text] isEqualToString:@"13"] && _queenSelectedIndex == [sender tag])) {
                [[_nextRoundDecrementButtons objectAtIndex:sender.tag] setEnabled:NO];
            }
            for (UIButton *button in _nextRoundIncrementButtons) {
                [button setEnabled:YES];
            }
            break;
        case 3:     // +
            [self addToCurrentScoreLabel:currentScoreLabel withValue:1];
            
            [[_nextRoundDecrementButtons objectAtIndex:sender.tag] setEnabled:YES];
            break;
    }
    
    [_nextRoundResetButton setEnabled:YES];
}

- (IBAction)touchShootMoon:(UIButton *)sender {
    if ([_moonPreferenceSegmentedControl selectedSegmentIndex] == 0) { // add 26
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
    for (UIButton *button in _nextRoundDecrementButtons) {
        [button setEnabled:NO];
    }
    for (UIButton *button in _nextRoundIncrementButtons) {
        [button setEnabled:NO];
    }
    
    [_nextRoundSubmitButton setEnabled:YES];
    [_nextRoundResetButton setEnabled:YES];
}

#pragma mark Helper Methods

- (void)resetNextRoundView {
    [_nextRoundSubmitButton setEnabled:NO];
    [_nextRoundResetButton setEnabled:NO];
    _queenSelectedIndex = -1;
    
    for (UILabel *label in _nextRoundScoreLabels) {
        [label setText:@"0"];
    }
    
    for (UIButton *button in _nextRoundAddScoreButtons) {
        [button setEnabled:YES];
    }
    
    for (UIButton *button in _nextRoundDecrementButtons) {
        [button setEnabled:NO];
    }
    
    for (UIButton *button in _nextRoundIncrementButtons) {
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
    
    BOOL scoreIncludesQueen = ([currentScoreLabel tag] == _queenSelectedIndex) && (currentScore > 12);
    
    if ((value > 0 && [self getNextRoundViewSum] + value < 27) || (value < 0 && ((currentScore > 0 && !scoreIncludesQueen) || (currentScore > 13 && scoreIncludesQueen)))) {
        [currentScoreLabel setText:[NSString stringWithFormat:@"%d", currentScore + value]];
    }
    
    if ([self getNextRoundViewSum] == 26) {
        for (UIButton *button in _nextRoundAddScoreButtons) {
            if (![[button currentTitle] isEqualToString:@"Moon"]) {
                [button setEnabled:NO];
            }
        }
        for (UIButton *button in _nextRoundIncrementButtons) {
            [button setEnabled:NO];
        }
        
        [_nextRoundSubmitButton setEnabled:YES];
    } else {
        if ([self getNextRoundViewSum] > 26) {
            if (value > 0) {
                [self presentViewController:_invalidScoreAlert animated:YES completion:nil];
            }
            
            for (UIButton *button in _nextRoundAddScoreButtons) {
                [button setEnabled:NO];
            }
        } else {
            for (UIButton *button in _nextRoundAddScoreButtons) {
                if (value < 0) {
                    if ([[button currentTitle] isEqualToString:@"Q♠︎"] && _queenSelectedIndex == -1 && [self getNextRoundViewSum] < 14) {
                        [button setEnabled:YES];
                    } else if ([[button currentTitle] isEqualToString:@"+5"] && [self getNextRoundViewSum] < 22) {
                        [button setEnabled:YES];
                    }
                } else {
                    if ([[button currentTitle] isEqualToString:@"Q♠︎"] && _queenSelectedIndex == -1 && [self getNextRoundViewSum] > 13) {
                        [button setEnabled:NO];
                    } else if ([[button currentTitle] isEqualToString:@"+5"] && [self getNextRoundViewSum] > 21) {
                        [button setEnabled:NO];
                    }
                }
            }
        }
        
        [_nextRoundSubmitButton setEnabled:NO];
        
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
    [slider setValue:roundf([slider value] / END_SCORE_SLIDER_STEP) * END_SCORE_SLIDER_STEP];
    
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
    
    [self updateCurrentDealer];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self updateDealerLabelLocation];
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
        
        [_dealerLabel setAlpha:1.0];
        
        [[Settings sharedSettingsData] save];
        
        // allow the dealer button to move freely in the y-plane while it is being dragged.
    } else {
        frame.origin.y = touchLocation.y - frame.size.height / 2;
        
        // fades dealer label out as it is dragged away from the first player text field
        // The dealer label will begin to fade out when it reaches DEALER_FADE_START pixels above the first player text field's location,
        // and will completely fade out when it reaches DEALER_FADE_START + DEALER_FADE_DISTANCE pixels above the first player text field's location.
        if (touchLocation.y < ([[_playerTextFieldYLocations objectAtIndex:0] floatValue] - DEALER_FADE_START)) {
            [_dealerLabel setAlpha:MAX(1 - ([[_playerTextFieldYLocations objectAtIndex:0] floatValue] - touchLocation.y - DEALER_FADE_START) / DEALER_FADE_DISTANCE, 0)];
        }
        // fades dealer label out as it is dragged away from the last player's text field
        if (touchLocation.y > ([[_playerTextFieldYLocations objectAtIndex:3] floatValue] + 20)) {
            [_dealerLabel setAlpha:MAX(1 + ([[_playerTextFieldYLocations objectAtIndex:3] floatValue] - touchLocation.y + DEALER_FADE_START) / DEALER_FADE_DISTANCE, 0)];
        }
    }
    
    _dealerLabel.frame = frame;
}

#pragma mark Other

- (IBAction)touchInfoButton:(UIButton *)sender {
    BOOL isInfoVisible = [_infoTextView alpha] == 1.0;
    
    [self setSettingsVisible:!isInfoVisible];
    [self setView:_settingsButton hidden:!isInfoVisible];
    
    [self setView:_infoTextView hidden:isInfoVisible];
    [self setView:_rateOnAppStoreButton hidden:isInfoVisible];
    
    [self.view bringSubviewToFront:_rateOnAppStoreButton];
}

- (IBAction)touchRateOnStoreButton:(UIButton *)sender {
    NSString *appId = @"1033609492";
    NSString *theUrl = [NSString  stringWithFormat:@"itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=%@&onlyLatestVersion=true&pageNumber=0&sortOrdering=1&type=Purple+Software",appId];
    if ([[UIDevice currentDevice].systemVersion integerValue] > 6) theUrl = [NSString stringWithFormat:@"itms-apps://itunes.apple.com/app/id%@",appId];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:theUrl]];
}

- (IBAction)playerNameFieldsEditingDidEnd:(UIPlayerTextField *)sender {
    NSArray* names = [[NSArray alloc] init];
    
    for (UITextField *field in _playerTextFields) {
        names = [names arrayByAddingObject:[field text]];
    }
    
    [[Game sharedGameData] setPlayerNames:names];
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

- (IBAction)colorValueChanged:(UISegmentedControl *)sender {
    UIColor *newColor = nil;
    switch ([sender selectedSegmentIndex]) {
        case 0: // light
            newColor = [UIColor flatWhiteColor];
            break;
        case 1: // green
            newColor = [UIColor flatGreenColor];
            break;
        case 2: // dark
            newColor = [UIColor flatBlackColor];
            break;
        default:
            break;
    }
    
    _colorArray = [[NSMutableArray alloc] initWithArray:[NSArray arrayOfColorsWithColorScheme:ColorSchemeComplementary
                                                                                   usingColor:newColor
                                                                               withFlatScheme:YES]];
    
    switch ([sender selectedSegmentIndex]) {
        case 0: // light
            [_colorArray replaceObjectAtIndex:TEXT withObject:[_colorArray objectAtIndex:TOP_BOTTOM_BOARDER]];
            [_colorArray replaceObjectAtIndex:BUTTONS withObject:[UIColor colorWithRed:0.0 green:122.0/255.0 blue:1.0 alpha:1.0]]; // blue
            break;
        case 1: // green
            [_colorArray replaceObjectAtIndex:TEXT withObject:[_colorArray objectAtIndex:TOP_BOTTOM_BOARDER]];
            [_colorArray replaceObjectAtIndex:BUTTONS withObject:[UIColor colorWithRed:0.0 green:122.0/255.0 blue:1.0 alpha:1.0]]; // blue
            break;
        case 2: // dark
            [_colorArray replaceObjectAtIndex:TEXT withObject:[UIColor flatWhiteColor]];
            [_colorArray replaceObjectAtIndex:BUTTONS withObject:[UIColor colorWithRed:216.0/255.0 green:23.0/255.0 blue:23.0/255.0 alpha:1.0]]; // red
            [_colorArray replaceObjectAtIndex:MAIN_BACKGROUND withObject:[[_colorArray objectAtIndex:MAIN_BACKGROUND] lightenByPercentage:.20]];
            [_colorArray replaceObjectAtIndex:TOP_BOTTOM_BOARDER withObject:[[_colorArray objectAtIndex:TOP_BOTTOM_BOARDER] lightenByPercentage:.05]];
            break;
        default:
            break;
    }
    
    [self updateColors];
}

- (IBAction)shootTheMoonBehaviorValueChanged:(UISegmentedControl *)sender {
    ([sender selectedSegmentIndex] == 0) ? [[Settings sharedSettingsData] setMoonBehaviorIsAdd:YES] : [[Settings sharedSettingsData] setMoonBehaviorIsAdd:NO];
    
    [[Settings sharedSettingsData] save];
}

- (void)updateSettings {
    [self updateDealerLabelLocation];
    
    [_endingScoreSlider setValue:[[Settings sharedSettingsData] endingScore]];
    [_endingScoreLabel  setText:[NSString stringWithFormat:@"Ending Score: %d", [[Settings sharedSettingsData] endingScore]]];
    
    [[Settings sharedSettingsData] moonBehaviorIsAdd] ? [_moonPreferenceSegmentedControl setSelectedSegmentIndex:0] : [_moonPreferenceSegmentedControl setSelectedSegmentIndex:1];
}

- (void)setSettingsVisible:(BOOL)isVisible {
    for (UITextField *field in _playerTextFields) {
        [self setView:field hidden:isVisible];
    }
    
    [self setView:_shootTheMoonLabel               hidden:isVisible];
    [self setView:_moonPreferenceSegmentedControl  hidden:isVisible];
    [self setView:_colorPreferenceSegmentedControl hidden:isVisible];
    
    [self setView:_endingScoreLabel  hidden:isVisible];
    [self setView:_endingScoreSlider hidden:isVisible];
    
    [self setView:_dealerLabel       hidden:isVisible];
}

- (void)setMainScreenVisible:(BOOL)isVisible {
    [self setView:_passDirectionLabel hidden:isVisible];
    [self setView:_nextRoundButton    hidden:isVisible];
    [self setView:_nnewGameButton     hidden:isVisible];
    
    for (UILabel *label in _playerNameLabels) {
        [self setView:label hidden:isVisible];
    }
    for (UILabel *label in _playerSumLabels) {
        [self setView:label hidden:isVisible];
    }
    for (UICollectionView *view in _scoresCollectionViews) {
        [self setView:view hidden:isVisible];
    }
    for (UIView *view in _secondaryViews) {
        [self setView:view hidden:isVisible];
    }
}

#pragma mark

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if ([[Game sharedGameData] numRounds] > 0) {
        if ([event subtype] == UIEventSubtypeMotionShake) {
            UIAlertController* undoRoundAlert = [UIAlertController alertControllerWithTitle:@"Undo last round"
                                                                                    message:@"Are you sure you would like to undo the last round?"
                                                                             preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* no = [UIAlertAction actionWithTitle:@"No"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * action)
                                 {
                                     [undoRoundAlert dismissViewControllerAnimated:YES completion:nil];
                                 }];
            
            UIAlertAction* yes = [UIAlertAction actionWithTitle:@"Yes"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * action)
                                  {
                                      for (int i = 0; i < 4; i++) {
                                          NSMutableArray *scores = [[[[Game sharedGameData] players] objectAtIndex:i] scores];
                                          [scores removeLastObject];
                                          [[[[Game sharedGameData] players] objectAtIndex:i] setScores:scores];
                                      }
                                      
                                      [self updatePassDirectionLabel];
                                      [self updatePlayerSumLabels];
                                      
                                      for (UICollectionView *view in _scoresCollectionViews) {
                                          [view reloadData];
                                      }
                                      
                                      [[Settings sharedSettingsData] setDealerOffset:[[Settings sharedSettingsData] dealerOffset] - 1];
                                      [[Settings sharedSettingsData] save];
                                      [self updateCurrentDealer];
                                      
                                      [undoRoundAlert dismissViewControllerAnimated:YES completion:nil];
                                  }];
            
            [undoRoundAlert addAction:no];
            [undoRoundAlert addAction:yes];
            [self presentViewController:undoRoundAlert animated:YES completion:nil];
            
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
    _nextRoundDecrementButtons = [_nextRoundDecrementButtons sortedArrayUsingComparator:^NSComparisonResult(id objA, id objB){
        return(
               ([objA tag] < [objB tag]) ? NSOrderedAscending  :
               ([objA tag] > [objB tag]) ? NSOrderedDescending :
               NSOrderedSame);
    }];
    _nextRoundIncrementButtons = [_nextRoundIncrementButtons sortedArrayUsingComparator:^NSComparisonResult(id objA, id objB){
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
    
    for (Player *p in [[Game sharedGameData] players]) {
        if ([p sumScores] < [lowestScorer sumScores]) {
            lowestScorer = p;
        }
    }
    
    return [lowestScorer name];
}

@end