//
//  JXPlayer.m
//  JXPitchConverter
//
//  Created by JLee21 on 2015/12/16.
//  Copyright © 2015年 VS7X. All rights reserved.
//

#import "JXPlayer.h"
#import "JXMediaDefine.h"

@interface JXPlayer()
<EZAudioPlayerDelegate,
EZAudioFFTDelegate>
@property (nonatomic, strong) EZAudioPlayer *player;
@property (nonatomic, weak)   EZAudioPlotGL *plotGL;
@property (nonatomic, weak)   EZAudioPlot   *plot;

@property (nonatomic, strong) EZAudioFFTRolling *transfer;

@end

@implementation JXPlayer

- (instancetype)initWithPlot:(EZAudioPlot *)plot delegate:(id<JXPlayerDelegate>)delegate
{
    self = [super init];
    if (self) {
        
        _delegate = delegate;
        _plot = plot;
        
        [self setup];
    }
    return self;
}

- (instancetype)initWithGLPlot:(EZAudioPlotGL *)plot delegate:(id<JXPlayerDelegate>)delegate
{
    self = [super init];
    if (self) {
        
        _delegate = delegate;
        _plotGL = plot;
        
        [self setup];
    }
    return self;
}

#pragma mark - Component setup

- (void)setup
{
    [self setupAudioSession];
    [self setupPlot];
    
    _player = [EZAudioPlayer audioPlayerWithDelegate:self];
}

- (void)setupPlot
{
    if (_plot) {
        _plot.backgroundColor   = [UIColor clearColor];
        _plot.color             = [UIColor redColor];
        _plot.plotType          = EZPlotTypeRolling;
        _plot.shouldFill        = NO;
        _plot.shouldMirror      = NO;
        _plot.shouldCenterYAxis = NO;
        _plot.gain              = 1.0f;
    } else {
        _plotGL.backgroundColor = [UIColor clearColor];
        _plotGL.color           = [UIColor redColor];
        _plotGL.plotType        = EZPlotTypeRolling;
        _plotGL.shouldFill      = NO;
        _plotGL.shouldMirror    = NO;
        _plotGL.gain            = 1.0f;
    }
}

- (void)setupAudioSession
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
}

#pragma mark - Public method

- (void)playAudioFile:(NSURL *)filePath
{
    if (_isPlaying) {
        [self stop];
    }
    
    [_plot clear];
    if (filePath) {
        EZAudioFile *audioFile = [EZAudioFile audioFileWithURL:filePath];
        _transfer = [EZAudioFFTRolling fftWithWindowSize:kDefaultFFTWindowSize
                                              sampleRate:audioFile.clientFormat.mSampleRate
                                                delegate:self];
        [_player playAudioFile:audioFile];
        _isPlaying = YES;
    }
}

- (void)stop
{
    _isPlaying = NO;
    [_player pause];
}

#pragma mark - EZAudioPlayerDelegate

- (void) audioPlayer:(EZAudioPlayer *)audioPlayer
         playedAudio:(float **)buffer
      withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels
         inAudioFile:(EZAudioFile *)audioFile
{
    [_transfer computeFFTWithBuffer:buffer[0] withBufferSize:bufferSize];
}

- (void)audioPlayer:(EZAudioPlayer *)audioPlayer reachedEndOfAudioFile:(EZAudioFile *)audioFile
{
    if ([_delegate respondsToSelector:@selector(player:statusCallback:)]) {
        [_delegate player:self statusCallback:EPlayerStatusEOF];
    }
}

- (void)audioPlayer:(EZAudioPlayer *)audioPlayer
    updatedPosition:(SInt64)framePosition
        inAudioFile:(EZAudioFile *)audioFile
{
    if ([_delegate respondsToSelector:@selector(player:updatedCurrentTime:)]) {
        [_delegate player:self updatedCurrentTime:audioPlayer.formattedCurrentTime];
    }
}

#pragma mark - EZAudioFFTDelegate

- (void)       fft:(EZAudioFFT *)fft
updatedWithFFTData:(float *)fftData
        bufferSize:(vDSP_Length)bufferSize
{
    int note = fft.maxFrequencyMagnitude > 0.0001 ? Freq2Note(fft.maxFrequency) : 0;
    float normalizedNote = (float)note / 127;
    
    for (int n=0; n<bufferSize; n++) {
        fftData[n] = normalizedNote;
    }
    
    __weak typeof (self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (weakSelf.plot) {
            [weakSelf.plot updateBuffer:fftData withBufferSize:(UInt32)bufferSize];
        } else {
            [weakSelf.plotGL updateBuffer:fftData withBufferSize:(UInt32)bufferSize];
        }
    });
}
@end
