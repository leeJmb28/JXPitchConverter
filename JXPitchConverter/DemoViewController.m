//
//  DemoViewController.m
//  JXPitchConverter
//
//  Created by JLee21 on 2015/12/14.
//  Copyright © 2015年 VS7X. All rights reserved.
//

#import "DemoViewController.h"
#import "JXRecorder.h"
#import "JXPlayer.h"

@interface DemoViewController ()
<JXRecorderDelegate,JXPlayerDelegate>

@property (nonatomic, weak) IBOutlet UIButton      *recordBtn;
@property (nonatomic, weak) IBOutlet UIButton      *playBtn;

@property (nonatomic, weak) IBOutlet UILabel       *recordTimeLbl;
@property (nonatomic, weak) IBOutlet UILabel       *playTimeLbl;

@property (nonatomic, weak) IBOutlet EZAudioPlotGL *recordPlot;
@property (nonatomic, weak) IBOutlet EZAudioPlot   *playPlot;

@property (nonatomic, strong) JXRecorder           *recorder;
@property (nonatomic, strong) JXPlayer             *player;

@end

@implementation DemoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    
    /*
     * Setup recorder and player
     */
    _recorder = [[JXRecorder alloc] initWithGLPlot:_recordPlot delegate:self];
    _player = [[JXPlayer alloc] initWithPlot:_playPlot delegate:self];
    
    /*
     * Setup customize UI
     */
    [_recordBtn setTitle:@"Record" forState:UIControlStateNormal];
    [_recordBtn setBackgroundImage:[self imageFromColor:[UIColor darkGrayColor]] forState:UIControlStateNormal];
    [_recordBtn setTitle:@"Stop" forState:UIControlStateSelected];
    [_recordBtn setBackgroundImage:[self imageFromColor:[UIColor redColor]] forState:UIControlStateSelected];
    
    [_playBtn setTitle:@"Play" forState:UIControlStateNormal];
    [_playBtn setBackgroundImage:[self imageFromColor:[UIColor darkGrayColor]] forState:UIControlStateNormal];
    [_playBtn setTitle:@"Playing" forState:UIControlStateSelected];
    [_playBtn setBackgroundImage:[self imageFromColor:[UIColor redColor]] forState:UIControlStateSelected];
}

- (void)dealloc
{
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions

- (IBAction)recordButtonPressed:(id)sender
{
    if (_player.isPlaying) {
        [self playButtonPressed:_playBtn];
    }
    
    BOOL isSelected = _recordBtn.selected;
    if (!isSelected) {
        [_recorder record];
    } else {
        [_recorder stop];
    }
    
    _recordBtn.selected = !isSelected;
}

- (IBAction)playButtonPressed:(id)sender
{
    if (_recorder.isRecording) {
        [self recordButtonPressed:_recordBtn];
    }
    
    BOOL isSelected = _playBtn.selected;
    if (!isSelected) {
        [_player playAudioFile:_recorder.audioPathURL];
    } else {
        [_player stop];
    }
    _playBtn.selected = !isSelected;
}

#pragma mark - JXRecorderDelegate

- (void)recorder:(JXRecorder *)recorder updatedCurrentTime:(NSString *)formattedTime
{
    __weak typeof (self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf.recordTimeLbl setText:formattedTime];
    });
}

#pragma mark - JXPlayerDelegate

- (void)player:(JXPlayer *)player updatedCurrentTime:(NSString *)formattedTime
{
    __weak typeof (self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf.playTimeLbl setText:formattedTime];
    });
}

- (void)player:(JXPlayer *)player statusCallback:(EPlayerStatus)status
{
    __weak typeof (self) weakSelf = self;
    switch (status) {
        case EPlayerStatusEOF:
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf playButtonPressed:weakSelf.playBtn];
            });
        }
            break;
            
        default:
            break;
    }
}

#pragma mark - Utility

- (UIImage *)imageFromColor:(UIColor *)color
{
    CGRect rect = CGRectMake(0, 0, 1, 1);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end
