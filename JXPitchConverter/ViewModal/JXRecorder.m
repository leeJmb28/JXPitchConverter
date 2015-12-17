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
EZRecorderDelegate>

@property (nonatomic, strong) EZMicrophone  *microphone;
@property (nonatomic, strong) EZRecorder    *recorder;
@property (nonatomic, weak)   EZAudioPlotGL *plotGL;
@property (nonatomic, weak)   EZAudioPlot   *plot;

@end


@implementation JXRecorder

- (instancetype)initWithPlot:(EZAudioPlot *)plot delegate:(id<JXRecorderDelegate>)delegate
{
    self = [super init];
    if (self) {
        
        _delegate = delegate;
        _plot = plot;
        
        [self setupAudioSession];
        [self setupPlot];

        _microphone = [EZMicrophone microphoneWithDelegate:self];
        [_microphone startFetchingAudio];
    }
    return self;
}

- (instancetype)initWithGLPlot:(EZAudioPlotGL *)plot delegate:(id<JXRecorderDelegate>)delegate
{
    self = [super init];
    if (self) {
        
        _delegate = delegate;
        _plotGL = plot;
        
        [self setupAudioSession];
        [self setupPlot];
        
        _microphone = [EZMicrophone microphoneWithDelegate:self];
        [_microphone startFetchingAudio];
    }
    return self;
}

- (void)dealloc
{
    [_microphone stopFetchingAudio];
}

#pragma mark - Component setup

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
    _recorder = [EZRecorder recorderWithURL:self.audioPath
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

#pragma mark - Utility

- (NSURL *)audioPath
{
    NSArray *userPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *directory = userPaths.count > 0 ? userPaths[0] : nil;
    return [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/HumQ_Record.m4a",directory]];
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
    if ([_delegate respondsToSelector:@selector(recorder:updatedCurrentTime:)]) {
        [_delegate recorder:self updatedCurrentTime:recorder.formattedCurrentTime];
    }
}


@end
