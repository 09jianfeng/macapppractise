//
//  MacCameraCaptureFilter.h
//
//  Created by JFChen on 2019/11/1.
//  Copyright © 2019 JFChen. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^GetCMSampleBufferRef)(CMSampleBufferRef sampleBuffer);

@interface MacCameraCaptureFilter : NSObject

@property (nonatomic, assign) AVCaptureVideoOrientation captureOrientation;
@property (nonatomic, assign) AVCaptureDevicePosition cameraPosition;
@property (nonatomic) NSString* preset;
@property (nonatomic, assign) int32_t frameRate;
@property (nonatomic, readonly) int32_t width;
@property (nonatomic, readonly) int32_t height;
@property (nonatomic, assign) AVCaptureTorchMode torchMode;
@property (nonatomic) float videoZoomFactor;

+ (NSString *)maxPresetOfDeviceModel;
- (BOOL)configure:(NSDictionary*)settings;
- (BOOL)start;
- (void)stop;
- (BOOL)isFrontFacingCameraPresent;
- (AVCaptureVideoOrientation)captureOrientation;
- (void)setGetCMSampleBufferRefBlock:(GetCMSampleBufferRef) block;
@end
