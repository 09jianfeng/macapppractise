//
//  MGLOpenGLView.h
//  macappdemo1
//
//  Created by JFChen on 2019/11/4.
//  Copyright © 2019 JFChen. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MGLOpenGLView : NSOpenGLView

- (void)setPixelbuffer:(CVPixelBufferRef)pixelbuffer;

@end

NS_ASSUME_NONNULL_END
