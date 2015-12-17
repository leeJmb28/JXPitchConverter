//
//  JXPlayer.h
//  JXPitchConverter
//
//  Created by JLee21 on 2015/12/16.
//  Copyright © 2015年 VS7X. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EZAudio.h"

typedef NS_ENUM(int, EPlayerStatus)
{
    EPlayerStatusPlaying,
    EPlayerStatusStop,
    EPlayerStatusEOF,
};

@class JXPlayer;

@protocol JXPlayerDelegate <NSObject>
- (void)player:(JXPlayer *)player updatedCurrentTime:(NSString *)formattedTime;
- (void)player:(JXPlayer *)player statusCallback:(EPlayerStatus)status;
@end

@interface JXPlayer : NSObject

@property (nonatomic, readonly)     NSURL         *audioPath;
@property (nonatomic)               BOOL          isPlaying;
@property (nonatomic, assign)       id<JXPlayerDelegate> delegate;

- (instancetype)initWithPlot:(EZAudioPlot *)plot delegate:(id<JXPlayerDelegate>)delegate;
- (instancetype)initWithGLPlot:(EZAudioPlotGL *)plot delegate:(id<JXPlayerDelegate>)delegate;
- (void)playAudioFile:(NSURL *)filePath;
- (void)stop;

@end
