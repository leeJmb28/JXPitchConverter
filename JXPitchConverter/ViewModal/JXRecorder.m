//
//  JXRecorder.m
//  JXPitchConverter
//
//  Created by JLee21 on 2015/12/16.
//  Copyright © 2015年 VS7X. All rights reserved.
//

#import "JXRecorder.h"
#import "JXMediaDefine.h"

@interface JXRecorder()
<EZMicrophoneDelegate,
EZRecorderDelegate,
EZAudioFFTDelegate>

@property (nonatomic, strong) EZMicrophone  *microphone;
@property (nonatomic, strong) EZRecorder    *recorder;
@property (nonatomic, weak)   EZAudioPlotGL *plotGL;
@property (nonatomic, weak)   EZAudioPlot   *plot;

@property (nonatomic, strong) EZAudioFFTRolling *transfer;
@property (nonatomic, weak)   NSFileManager *fsMgr;

@end


@implementation JXRecorder

- (instancetype)initWithPlot:(EZAudioPlot *)plot delegate:(id<JXRecorderDelegate>)delegate
{
    self = [super init];
    if (self) {
        
        _delegate = delegate;
        _plot = plot;
        
        [self setup];
    }
    return self;
}

- (instancetype)initWithGLPlot:(EZAudioPlotGL *)plot delegate:(id<JXRecorderDelegate>)delegate
{
    self = [super init];
    if (self) {
        
        _delegate = delegate;
        _plotGL = plot;
        
        [self setup];
    }
    return self;
}

- (void)dealloc
{
    [_microphone stopFetchingAudio];
}

#pragma mark - Component setup

- (void)setup
{
    [self setupAudioSession];
    [self setupPlot];
    
    _microphone = [EZMicrophone microphoneWithDelegate:self];
    [_microphone startFetchingAudio];
    
    _transfer = [EZAudioFFTRolling fftWithWindowSize:kDefaultFFTWindowSize
                                          sampleRate:_microphone.audioStreamBasicDescription.mSampleRate
                                            delegate:self];
    
    NSError *error;
    _fsMgr = [NSFileManager defaultManager];
    if ([_fsMgr fileExistsAtPath:self.notePath]) {
        BOOL success = [_fsMgr removeItemAtPath:self.notePath error:&error];
        if (!success) {
            NSLog(@"Error on removefile:%@",[error localizedDescription]);
        }
    }
    if (![_fsMgr createFileAtPath:self.notePath contents:nil attributes:nil]) {
        NSLog(@"Error on create file:[%d]%s",errno,strerror(errno));
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
    
    if (session.isInputGainSettable) {
        BOOL success = [session setInputGain:1.0 error:&error];
        if (!success) {
            NSLog(@"Error %@",[error localizedDescription]);
        }
    } else {
        NSLog(@"Error on InputGain is not settable");
    }
}

- (void)setupPlot
{
    if (_plot) {
        _plot.backgroundColor = [UIColor clearColor];
        _plot.color           = [UIColor orangeColor];
        _plot.plotType        = EZPlotTypeBuffer;
        _plot.shouldFill      = YES;
        _plot.shouldMirror    = YES;
        _plot.gain            = 2.0f;
    } else {
        _plotGL.backgroundColor = [UIColor clearColor];
        _plotGL.color           = [UIColor orangeColor];
        _plotGL.plotType        = EZPlotTypeBuffer;
        _plotGL.shouldFill      = YES;
        _plotGL.shouldMirror    = YES;
        _plotGL.gain            = 2.0f;
    }
}

#pragma mark - Public method

- (void)record
{
    if (_isRecording) {
        [self stop];
    }
    
    _isRecording = YES;
    if (_plot) {
        [_plot clear];
        _plot.plotType = EZPlotTypeRolling;
    } else {
        [_plotGL clear];
        _plotGL.plotType = EZPlotTypeRolling;
    }
    _recorder = [EZRecorder recorderWithURL:self.audioPathURL
                               clientFormat:[_microphone audioStreamBasicDescription]
                                   fileType:EZRecorderFileTypeM4A
                                   delegate:self];
}

- (void)stop
{
    _isRecording = NO;
    if (_plot) {
        _plot.plotType = EZPlotTypeBuffer;
    } else {
        _plotGL.plotType = EZPlotTypeBuffer;
    }
    [_recorder closeAudioFile];
}

#pragma mark - Utility

- (NSURL *)audioPathURL
{
    NSArray *userPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [NSURL fileURLWithPath:[userPaths[0] stringByAppendingString:@"/HumQ_Record.m4a"]];
}

- (NSString *)notePath
{
    NSArray *userPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [userPaths[0] stringByAppendingString:@"/HumQ_Record.seq"];
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
        [_transfer computeFFTWithBuffer:buffer[0] withBufferSize:bufferSize];
    }
    __weak typeof (self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (weakSelf.plot) {
            [weakSelf.plot updateBuffer:buffer[0] withBufferSize:bufferSize];
        } else {
            [weakSelf.plotGL updateBuffer:buffer[0] withBufferSize:bufferSize];
        }
    });
}

- (void)  microphone:(EZMicrophone *)microphone
       hasBufferList:(AudioBufferList *)bufferList
      withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels
{
    if (_isRecording && _recorder) {
        [_recorder appendDataFromBufferList:bufferList withBufferSize:bufferSize];
    }
}

#pragma mark - EZRecorderDelegate

- (void)recorderDidClose:(EZRecorder *)recorder
{
    recorder.delegate = nil;
    _recorder = nil;
}

- (void)recorderUpdatedCurrentTime:(EZRecorder *)recorder
{
    if ([_delegate respondsToSelector:@selector(recorder:updatedCurrentTime:)]) {
        [_delegate recorder:self updatedCurrentTime:recorder.formattedCurrentTime];
    }
}

#pragma mark - EZAudioFFTDelegate

- (void)fft:(EZAudioFFT *)fft updatedWithFFTData:(float *)fftData bufferSize:(vDSP_Length)bufferSize
{
    int note = fft.maxFrequencyMagnitude > 0.0001 ? Freq2Note(fft.maxFrequency) : 0;
    NSString *noteString = [NSString stringWithFormat:@"%d\t",note];
    
    NSError *error;
    if (![_fsMgr fileExistsAtPath:self.notePath]) {
        [noteString writeToFile:self.notePath
                     atomically:YES
                       encoding:NSUTF8StringEncoding
                          error:&error];
    } else {
        NSFileHandle *fsHandle = [NSFileHandle fileHandleForUpdatingAtPath:self.notePath];
        [fsHandle seekToEndOfFile];
        [fsHandle writeData:[noteString dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    if (error) {
        NSLog(@"Error : %@",[error localizedDescription]);
    }
    
}


@end
