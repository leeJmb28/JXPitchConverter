//
//  JXMediaDefine.h
//  JXPitchConverter
//
//  Created by JLee21 on 2015/12/17.
//  Copyright © 2015年 VS7X. All rights reserved.
//

#ifndef JXMediaDefine_h
#define JXMediaDefine_h

static const int kDefaultFFTWindowSize = 4096;

#define Freq2Note(X)  69 + 12*log2(X/440.0f)

#endif /* JXMediaDefine_h */
