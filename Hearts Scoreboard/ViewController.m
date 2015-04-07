//
//  ViewController.m
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 2/26/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import "ViewController.h"
#import "ScoreCollectionViewCell.h"
#import "Player.h"

@interface ViewController ()
@property (strong, nonatomic) IBOutletCollection(UILabel) NSArray *playerNames;
@property (strong, nonatomic) IBOutletCollection(UILabel) NSArray *playerSumScores;
@property (strong, nonatomic) IBOutletCollection(UICollectionView) NSArray *scoresCollectionViews;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    
    // temporary testing
    NSArray *names = [[NSArray alloc] initWithObjects:@"Christopher", @"Mary", @"Mom", @"Dad", nil];
    [self updatePlayerNameLabels:names];
    _game = [[Game alloc] initWithNames:names];
    
    NSMutableArray *scores = [[NSMutableArray alloc] init];
    for(int i = 0; i < 5; i++) {
        [scores addObject:[NSNumber numberWithInt:i]];
    }
    
    for(Player *p in [_game players]) {
        [p setScores:scores];
    }
    // end of temporary testing
    
    
    // TODO uncomment this once I figure out custom ScoreCollectionViewCell
//    for(UICollectionView *view in _scoresCollectionViews) {
//        [view registerClass:[ScoreCollectionViewCell class] forCellWithReuseIdentifier:@"scoreCell"];
//    }

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Update Labels

- (void)updatePlayerNameLabels:(NSArray*)names {
    for(UILabel *label in _playerNames) {
        switch(label.tag) {
        case 0:
            [label setText:[names objectAtIndex:0]];
            break;
        case 1:
            [label setText:[names objectAtIndex:1]];
            break;
        case 2:
            [label setText:[names objectAtIndex:2]];
            break;
        case 3:
            [label setText:[names objectAtIndex:3]];
            break;
        }
    }
}

- (void)updatePlayerSumScoreLabels {
    for(UILabel *label in _playerSumScores) {
        switch(label.tag) {
            case 0:
                [label setText:[NSString stringWithFormat:@"%ld", [[[_game players] objectAtIndex:0] sumScores]]];
                break;
            case 1:
                [label setText:[NSString stringWithFormat:@"%ld", [[[_game players] objectAtIndex:1] sumScores]]];
                break;
            case 2:
                [label setText:[NSString stringWithFormat:@"%ld", [[[_game players] objectAtIndex:2] sumScores]]];
                break;
            case 3:
                [label setText:[NSString stringWithFormat:@"%ld", [[[_game players] objectAtIndex:3] sumScores]]];
                break;
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
    
    
    // TODO move cell appearance code to ScoreCollectionViewCell
    // round the cell's corners
    scoreCell.layer.cornerRadius = 15;
    // add drop shadow
    scoreCell.layer.shadowOffset = CGSizeMake(3, 3);
    scoreCell.layer.shadowRadius = 5;
    scoreCell.layer.shadowOpacity = .2;
    scoreCell.layer.masksToBounds = NO;
    

    [[scoreCell scoreLabel] setText:[NSString stringWithFormat:@"%ld", (long)[indexPath item]]];
    
    return scoreCell;
}

//
// Mirrors scrolling of the scores collection view
//
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self synchronizeCollectionViewContentOffsets:scrollView];
}

- (void)synchronizeCollectionViewContentOffsets:scrollView {
    CGPoint offset = [scrollView contentOffset];
    for(UICollectionView *view in _scoresCollectionViews) {
        view.contentOffset = CGPointMake(0, offset.y);
    }
}

#pragma mark Button Actions

- (IBAction)touchAddCell:(UIButton *)sender {
    [_game setNumRounds:[_game numRounds] + 1];
    for(UICollectionView *view in _scoresCollectionViews) {
        [view reloadData];
    }
}

@end