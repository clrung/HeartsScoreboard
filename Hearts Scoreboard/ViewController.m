//
//  ViewController.m
//  Hearts Scoreboard
//
//  Created by Christopher Rung on 2/26/15.
//  Copyright (c) 2015 Christopher Rung. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
@property (strong, nonatomic) IBOutlet UICollectionView *scoresCollectionView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _numRounds = 1;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Collection View

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _numRounds;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"scoreCell" forIndexPath:indexPath];
    return cell;
}

#pragma mark Button Actions

- (IBAction)touchAddCell:(UIButton *)sender {
    _numRounds++;
    NSLog(@"numRounds = %ld", (long)_numRounds);
    [_scoresCollectionView reloadData];
}

@end
