//
//  JXRecorder.h
//  JXPitchConverter
//
//  Created by JLee21 on 2015/12/16.
//  Copyright © 2015年 VS7X. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EZAudio.h"

@class JXRecorder;

@protocol JXRecorderDelegate <NSObject>
- (void)recorder:(JXRecorder *)recorder updatedCurrentTime:(NSString *)formattedTime;
@end





@interface JXRecorder : NSObject

@property (nonatomic, readonly) NSURL         *audioPathURL;
@property (nonatomic, readonly) NSString      *notePath;
@property (nonatomic)           BOOL          isRecording;
@property (nonatomic, assign)   id<JXRecorderDelegate> delegate;

- (instancetype)initWithPlot:(EZAudioPlot *)plot delegate:(id<JXRecorderDelegate>)delegate;
- (instancetype)initWithGLPlot:(EZAudioPlotGL *)plot delegate:(id<JXRecorderDelegate>)delegate;
- (void)record;
- (void)stop;

@end
