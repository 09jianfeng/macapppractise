//
//  MacCameraCapture.h
//
//  Created by JFChen on 2019/11/1.
//  Copyright © 2019 JFChen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol MacCameraCaptureDelegate <NSObject>

@required
- (void)didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end

@interface MacCameraCapture : NSObject

@property (nonatomic, assign) AVCaptureVideoOrientation captureOrientation;
@property (nonatomic, assign) AVCaptureDevicePosition cameraPosition;
@property (nonatomic, copy) NSString* preset;
@property (nonatomic, assign) int32_t frameRate;
@property (nonatomic, readonly) int32_t width;
@property (nonatomic, readonly) int32_t height;
@property (nonatomic, assign) AVCaptureTorchMode torchMode;
@property (nonatomic) float videoZoomFactor;

@property (nonatomic, weak) id<MacCameraCaptureDelegate> delegate;

+ (NSString *)maxPresetOfDeviceModel;
- (BOOL)configure:(NSDictionary*)settings;
- (BOOL)start;
- (void)stop;
- (BOOL)isFrontFacingCameraPresent;
- (AVCaptureVideoOrientation)captureOrientation;
@end
