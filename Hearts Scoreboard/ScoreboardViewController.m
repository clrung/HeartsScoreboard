//
//  ViewController.m
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 2/26/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import "ScoreboardViewController.h"
#import "SettingsViewController.h"
#import "ScoreCollectionViewCell.h"
#import "Player.h"

@interface ScoreboardViewController ()

@property (strong, nonatomic) IBOutletCollection(UILabel) NSArray *playerNameLabels;
@property (strong, nonatomic) IBOutletCollection(UILabel) NSArray *playerSumScoreLabels;
@property (strong, nonatomic) IBOutletCollection(UICollectionView) NSArray *scoresCollectionViews;
@property (strong, nonatomic) IBOutlet UILabel *passDirectionLabel;

@property (strong, nonatomic) IBOutlet UIView *nextRoundView;
@property (strong, nonatomic) IBOutletCollection(UILabel) NSArray *nextRoundPlayerNameLabels;
@property (strong, nonatomic) IBOutletCollection(UITextField) NSArray *nextRoundPlayerScoreFields;
@property (strong, nonatomic) IBOutlet UIButton *nextRoundSubmitButton;


@end

@implementation ScoreboardViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _game = [[Game alloc] init];
    
    
    // TODO blur edges of the top and bottom of the scoresCollectionViews.
//    for(UICollectionView *view in _scoresCollectionViews) {
//        CAGradientLayer *gradient = [CAGradientLayer layer];
//        gradient.frame = view.bounds;
//        gradient.colors = @[(id)[UIColor clearColor].CGColor, (id)[UIColor blackColor].CGColor];
//        gradient.locations = @[@0.0, @(.1)];
//        view.layer.mask = gradient;
//    }
    
    // TODO uncomment this once I figure out custom ScoreCollectionViewCell
//    for(UICollectionView *view in _scoresCollectionViews) {
//        [view registerClass:[ScoreCollectionViewCell class] forCellWithReuseIdentifier:@"scoreCell"];
//    }

}

//- (void)viewWillAppear:(BOOL)animated {
//    [super viewWillAppear:animated];
//    [self updatePlayerNameLabels:[_game playerNames]];
//}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Update Labels

- (void)updatePlayerNameLabels {
    for(UILabel *label in _playerNameLabels) {
        [label setText:[[_game playerNames] objectAtIndex:label.tag]];
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

#pragma mark Button Actions

- (IBAction)touchNextRoundButton:(UIButton *)sender {
    [_game setNumRounds:[_game numRounds] + 1];

    [self setView:_nextRoundView hidden:NO];
    
    
    // TESTING
    for(int i = 0; i < 4; i++) {
        NSMutableArray *scores = [[[_game players] objectAtIndex:i] scores];
        [scores addObject:[NSNumber numberWithInt:(i * 2 * + 1)]];
        [[[_game players] objectAtIndex:i] setScores:scores];
    }
    // END TESTING
    
    
    
    [self updatePassDirectionLabel];
    [self updatePlayerSumScoreLabels];
    
    for(UICollectionView *view in _scoresCollectionViews) {
        [view reloadData];
    }
}

- (void)setView:(UIView*)view hidden:(BOOL)hidden {
    [UIView transitionWithView:view duration:0.5 options:UIViewAnimationOptionTransitionCrossDissolve animations:^(void){
        [view setHidden:hidden];
    } completion:nil];
}

#pragma mark - Next Round View
- (IBAction)touchNextRoundSubmitButton:(UIButton *)sender {
    [self setView:_nextRoundView hidden:YES];
}

#pragma mark - Navigation

//
// Provides the settings view with the players' names.
//
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"showSettingsSegue"]){
        SettingsViewController *controller = (SettingsViewController *)segue.destinationViewController;

        [controller setPlayerNames:[_game playerNames]];
    }
}

//
// Populates the Scoreboard's names with the names provided in the Settings view.
//
- (IBAction)unwindToScoreBoard:(UIStoryboardSegue *)unwindSegue {
    SettingsViewController* sourceViewController = unwindSegue.sourceViewController;
    
    if ([sourceViewController isKindOfClass:[SettingsViewController class]]) {
        NSArray* names = [[NSArray alloc] init];
        
        for(UITextField *field in [sourceViewController nameTextFields]) {
            names = [names arrayByAddingObject:[field text]];
        }
        
        [_game setPlayerNames: names];
        [self updatePlayerNameLabels];
    }
}

@end