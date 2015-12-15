//
//  DemoViewController.m
//  JXPitchConverter
//
//  Created by JLee21 on 2015/12/14.
//  Copyright © 2015年 VS7X. All rights reserved.
//

#import "DemoViewController.h"
#import "EZAudio.h"

#define kFFTWindowSize  4096

@interface DemoViewController ()
<EZAudioPlayerDelegate,
EZMicrophoneDelegate,
EZRecorderDelegate,
EZAudioFFTDelegate>

@property (nonatomic, weak) IBOutlet UIButton      *recordBtn;
@property (nonatomic, weak) IBOutlet UIButton      *playBtn;

@property (nonatomic, weak) IBOutlet UILabel       *recordTimeLbl;
@property (nonatomic, weak) IBOutlet UILabel       *playTimeLbl;

@property (nonatomic, weak) IBOutlet EZAudioPlotGL *recordingPlot;
@property (nonatomic, weak) IBOutlet EZAudioPlot   *playingPlot;

@property (nonatomic, strong) EZMicrophone         *microphone;
@property (nonatomic, strong) EZRecorder           *recorder;
@property (nonatomic, strong) EZAudioPlayer        *player;
@property (nonatomic, strong) EZAudioFFTRolling    *fft;

@property (nonatomic) BOOL  isRecording;   // It should be integrated into EZRecorder :(
@end

@implementation DemoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self setupAudioPlots];
    [self setupRecorderAndPlayer];
    [self setupFFT];
    
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
    [_microphone stopFetchingAudio];
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
        _isRecording = YES;
        _recorder = [EZRecorder recorderWithURL:[self recordedFileURL]
                                   clientFormat:[_microphone audioStreamBasicDescription]
                                       fileType:EZRecorderFileTypeM4A
                                       delegate:self];
    } else {
        _isRecording = NO;
        [_recorder closeAudioFile];
    }
    [self setRecordingPlotFFTMode:!isSelected];
    _recordBtn.selected = !isSelected;
}

- (IBAction)playButtonPressed:(id)sender
{
    if (_isRecording) {
        [self recordButtonPressed:_recordBtn];
    }
    
    BOOL isSelected = _playBtn.selected;
    if (!isSelected) {
        [_playingPlot clear];
        EZAudioFile *audioFile = [EZAudioFile audioFileWithURL:[self recordedFileURL]];
        [_player playAudioFile:audioFile];
    } else {
        [_player pause];
    }
    _playBtn.selected = !isSelected;
}

#pragma mark - Configure EZAudio components

- (void)setupAudioPlots
{
    /*
     * Customizing the audio plot of microphone input
     */
    [self setRecordingPlotFFTMode:NO];
    
    /*
     * Customizing the audio plot of player output
     */
    _playingPlot.backgroundColor   = [UIColor clearColor];
    _playingPlot.color             = [UIColor redColor];
    _playingPlot.plotType          = EZPlotTypeRolling;
    _playingPlot.shouldFill        = YES;
    _playingPlot.shouldMirror      = YES;
    _playingPlot.gain              = 3.0f;
}

- (void)setRecordingPlotFFTMode:(BOOL)isFFTMode
{
    [_recordingPlot clear];
    _recordingPlot.backgroundColor = [UIColor clearColor];
    _recordingPlot.color           = [UIColor orangeColor];
    
    if (isFFTMode) {
        _recordingPlot.plotType        = EZPlotTypeRolling;
        _recordingPlot.shouldFill      = NO;
        _recordingPlot.shouldMirror    = NO;
        _recordingPlot.gain            = 1.0f;
    } else {
        _recordingPlot.plotType        = EZPlotTypeBuffer;
        _recordingPlot.shouldFill      = YES;
        _recordingPlot.shouldMirror    = YES;
        _recordingPlot.gain            = 3.0f;
    }
}

- (void)setupRecorderAndPlayer
{
    /*
     * Setup the AVAudioSession. EZMicrophone will not work properly on iOS
     * if you don't do this!
     */
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error;
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (error)
    {
        NSLog(@"Error setting up audio session category: %@", error.localizedDescription);
    }
    [session setActive:YES error:&error];
    if (error)
    {
        NSLog(@"Error setting up audio session active: %@", error.localizedDescription);
    }
    
    /*
     * Setup microphone
     */
    _microphone = [EZMicrophone microphoneWithDelegate:self];
    [_microphone startFetchingAudio];
    NSLog(@"%@",[self recordedFileURL].absoluteString);
    
    /*
     * Setup player
     */
    _player = [EZAudioPlayer audioPlayerWithDelegate:self];
}

- (void)setupFFT
{
    /*
     * Create an instance of the EZAudioFFTRolling to keep a history of the incoming audio data and calculate the FFT.
     */
    _fft = [EZAudioFFTRolling fftWithWindowSize:kFFTWindowSize
                                     sampleRate:_microphone.audioStreamBasicDescription.mSampleRate
                                       delegate:self];
}

#pragma mark - EZMicrophoneDelegate

- (void)microphone:(EZMicrophone *)microphone changedPlayingState:(BOOL)isPlaying
{
}

- (void)  microphone:(EZMicrophone *)microphone
    hasAudioReceived:(float **)buffer
      withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels
{
    if (_isRecording) {
        [_fft computeFFTWithBuffer:buffer[0] withBufferSize:bufferSize];
    } else {
        __weak typeof (self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.recordingPlot updateBuffer:buffer[0] withBufferSize:bufferSize];
        });

    }
}

- (void)  microphone:(EZMicrophone *)microphone
       hasBufferList:(AudioBufferList *)bufferList
      withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels
{
    if (_isRecording) {
        [_recorder appendDataFromBufferList:bufferList withBufferSize:bufferSize];
    }
}

#pragma mark - EZRecorderDelegate

- (void)recorderDidClose:(EZRecorder *)recorder
{
    recorder.delegate = nil;
}

- (void)recorderUpdatedCurrentTime:(EZRecorder *)recorder
{
    __weak typeof (self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        weakSelf.recordTimeLbl.text = [recorder formattedCurrentTime];
    });
}

#pragma mark - EZAudioPlayerDelegate

- (void) audioPlayer:(EZAudioPlayer *)audioPlayer
         playedAudio:(float **)buffer
      withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels
         inAudioFile:(EZAudioFile *)audioFile
{
    __weak typeof (self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf.playingPlot updateBuffer:buffer[0]
                            withBufferSize:bufferSize];
    });
}

- (void)audioPlayer:(EZAudioPlayer *)audioPlayer reachedEndOfAudioFile:(EZAudioFile *)audioFile
{
    if (_playBtn.selected) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self playButtonPressed:_playBtn];
        });
    }
}

- (void)audioPlayer:(EZAudioPlayer *)audioPlayer
    updatedPosition:(SInt64)framePosition
        inAudioFile:(EZAudioFile *)audioFile
{
    __weak typeof (self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        weakSelf.playTimeLbl.text = [audioPlayer formattedCurrentTime];
    });
}

#pragma mark - EZAudioFFTDelegate

- (void)       fft:(EZAudioFFT *)fft
updatedWithFFTData:(float *)fftData
        bufferSize:(vDSP_Length)bufferSize
{
    int note = fft.maxFrequencyMagnitude > 0.0001 ? [self noteFromFrequency:fft.maxFrequency] : 0;
    float normalizedNote = (float)note / 127;
    
    for (int n=0; n<bufferSize; n++) {
        fftData[n] = normalizedNote;
    }
    
    __weak typeof (self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf.recordingPlot updateBuffer:fftData
                              withBufferSize:(UInt32)bufferSize];
    });
}

#pragma mark - Utility

- (NSURL *)recordedFileURL
{
    NSArray *userPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *directory = userPaths.count > 0 ? userPaths[0] : nil;
    return [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/HumQ_Record.m4a",directory]];
}

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

- (int)noteFromFrequency:(float)frequency
{
    return 69 + 12 * log2(frequency/440.0f);
}

@end
