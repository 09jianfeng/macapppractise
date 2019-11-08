//
//  MacCameraCapture.m
//
//  Created by JFChen on 2019/11/1.
//  Copyright © 2019 JFChen. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <sys/utsname.h>
#import <AppKit/AppKit.h>
#import "MacCameraCapture.h"
#include <sys/sysctl.h>
#include <assert.h>
#include <CoreServices/CoreServices.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <unistd.h>
#import <OpenGL/gl3.h>

@interface MacCameraCapture()<AVCaptureVideoDataOutputSampleBufferDelegate> {
    BOOL                        _cameraJustChanged;
    int    _abandonFrame;
    AVCaptureSession *          _captureSession;
    AVCaptureDevice *           _device;
    AVCaptureDeviceInput *      _deviceInput;
    AVCaptureVideoDataOutput *  _dataOutput;
    AVCaptureConnection *       _captureConnection;
    AVCaptureVideoOrientation   _captureOrientation;
    AVCaptureDevicePosition     _cameraPosition;
    
    NSMutableDictionary *       _videoConfig;
    NSMutableDictionary *       _newVideoConfig;
    int32_t                     _frameRate;
    NSString*                   _preset;
    OSType _pixelForamt;
    dispatch_queue_t            _captureQueue;
    CGPoint _exposPt;
    
    // device ative format, may be change by system.
    AVCaptureDeviceFormat *     _currentActiveFormat;
    // the actually setting active format that according to the preset we want.
    // normally , settingActiveFormat is equal to currentActiveFormat
    AVCaptureDeviceFormat *     _settingActiveFormat;
    BOOL _bColorBarTest;
    uint8_t* _pColorBarBuffer;
    uint8_t* _pOutputBuffer;
    int _captureDeviceErrorRetryCount;
    
    // videoConfig由于上层可以在Main Thread进行修改，而在摄像头
    // 数据回调的线程中也有被使用，需要使用lock保持线程读写互斥
    NSLock* _videoConfigLock;
}
@property (readonly, getter = isFrontFacingCameraPresent) BOOL frontFacingCameraPresent;
@property (nonatomic, assign) BOOL lowLatency;
@property (readonly) CMSampleBufferRef colorBarSampleBuffer;
@property (atomic, copy) NSArray* metaArray;

@end

@implementation MacCameraCapture

+ (CMVideoDimensions)getDimensionsFromPreset:(NSString*)preset {
    CMVideoDimensions dimensions;
    if ([preset isEqualToString:AVCaptureSessionPreset352x288]) {
        dimensions.width  = 352;
        dimensions.height = 288;
    }
    
    if ([preset isEqualToString:AVCaptureSessionPreset640x480]) {
        dimensions.width  = 640;
        dimensions.height = 480;
    }
    
    if ([preset isEqualToString:AVCaptureSessionPreset960x540]) {
        dimensions.width  = 960;
        dimensions.height = 540;
    }
    
    if ([preset isEqualToString:AVCaptureSessionPreset1280x720]) {
        dimensions.width  = 1280;
        dimensions.height = 720;
    }
    
    return dimensions;
}

+ (NSString *)maxPresetOfDeviceModel {
    return AVCaptureSessionPreset1280x720;
}

- (id)init {
    if (self = [super init]) {
        _captureQueue = dispatch_queue_create("com.yy.yyvideolib.cameracapture", DISPATCH_QUEUE_SERIAL);
        _captureOrientation = AVCaptureVideoOrientationPortrait;
        _cameraPosition = AVCaptureDevicePositionFront;
        _frameRate = 24;
        _preset = [MacCameraCapture maxPresetOfDeviceModel];
        _captureDeviceErrorRetryCount = 3;
        _videoConfig = [NSMutableDictionary new];
        _videoConfigLock = [[NSLock alloc] init];
        _lowLatency = NO;
        _pixelForamt = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
        _captureSession = [[AVCaptureSession alloc] init];
        if (!_captureSession) {
        }
    }
    return self;
}

- (BOOL)start {
    NSLog(@"start capture");
    _cameraJustChanged = NO;
    if (![_captureSession isRunning]) {
        [_captureSession startRunning];
    }
    return YES;
}

- (void)stop {
    NSLog(@" stop capture");
    if ([_captureSession isRunning]) {
        [_captureSession stopRunning];
    }
}

- (void)doSetCaptureOrientation:(AVCaptureVideoOrientation)orientation {
    NSLog(@"videocapture rotateorientation:%td",orientation);
    [_captureSession beginConfiguration];
    if (_captureConnection.supportsVideoOrientation) {
        [_captureConnection setVideoOrientation:orientation];
        // update member var
        _captureOrientation = orientation;
        // _cameraJustChanged = YES;
    } else {
        NSLog(@"video orientaion not supported");
    }
    [_captureSession commitConfiguration];
}


- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    NSLog(@"%@",sampleBuffer);
    [_delegate didOutputSampleBuffer:sampleBuffer];
}

- (BOOL)isCaptureParam:(NSString*)key {
    return NO;
}

- (BOOL)isConfigsContainCaptureParam:(NSDictionary*)configs {
    for (NSString *key in configs.allKeys) {
        if ([self isCaptureParam:key]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)supportsVideoFrameRate:(NSInteger)videoFrameRate {
    NSLog(@"");
    if (!_device) {
        return NO;
    }
    AVCaptureDeviceFormat* format = [_device activeFormat];
    NSArray *videoSupportedFrameRateRanges = [format videoSupportedFrameRateRanges];
    for (AVFrameRateRange *frameRateRange in videoSupportedFrameRateRanges) {
        if ( (frameRateRange.minFrameRate <= videoFrameRate) && (videoFrameRate <= frameRateRange.maxFrameRate) ) {
            return YES;
        }
    }
    return NO;
}

- (void)doSetFrameRate:(int32_t)frameRate {
    NSLog(@"");
    if (![self supportsVideoFrameRate:frameRate]) {
        NSLog(@"CameraCaptureFilter not support framerate %d",  frameRate);
        return;
    }
    NSLog(@"liuxinyang, do set capture frame rate = %d", frameRate);
    AVCaptureDevice *videoDevice = _device;
    if ([videoDevice lockForConfiguration:NULL]) {
        [videoDevice setActiveVideoMinFrameDuration:CMTimeMake(1, frameRate)];
        if (@available(macOS 10.9, *)) {
            [videoDevice setActiveVideoMaxFrameDuration:CMTimeMake(1, frameRate)];
        } else {
            // Fallback on earlier versions
        }
        [videoDevice unlockForConfiguration];
        _frameRate = frameRate;
        // _cameraJustChanged = YES;
        NSLog(@"doSetFrameRate %d", _frameRate);
    }
}

- (void)doApplyPreset:(NSString*)preset frameRate:(int32_t)frameRate {
    NSLog(@"");
    if (!_device) {
        return;
    }
    CMVideoDimensions presetDimensions = [MacCameraCapture getDimensionsFromPreset:preset];
    int32_t presetWidth  = presetDimensions.width;
    int32_t presetHeight = presetDimensions.height;
    AVCaptureDevice *videoDevice = _device;
    for (AVCaptureDeviceFormat *videoFormat in [videoDevice formats]) {
        CMFormatDescriptionRef description = videoFormat.formatDescription;
        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(description);
        FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(description);
        if (presetWidth  == dimensions.width &&
            presetHeight == dimensions.height &&
            mediaSubType  == _pixelForamt) {
            if ([videoDevice lockForConfiguration:NULL]) {
                int32_t actuallyFrameRate = frameRate;
                _currentActiveFormat = videoFormat;
                _settingActiveFormat = videoFormat;
                videoDevice.activeFormat = videoFormat;
                if (![self supportsVideoFrameRate:frameRate]) {
                    //use the max frame rate
                    NSArray *videoSupportedFrameRateRanges = [videoFormat videoSupportedFrameRateRanges];
                    Float64 maxFrameRate = 0;
                    for (AVFrameRateRange *frameRateRange in videoSupportedFrameRateRanges){
                        if (maxFrameRate < frameRateRange.maxFrameRate) {
                            maxFrameRate = frameRateRange.maxFrameRate;
                        }
                    }
                    actuallyFrameRate  = (int32_t)maxFrameRate;
                    NSLog(@"capture device doesn't support frame rate %d, then set actual frame rate as %d", frameRate, actuallyFrameRate);
                }
                [videoDevice unlockForConfiguration];
                _frameRate = actuallyFrameRate;
                _preset = preset;
                NSLog(@"change camera preset %@,actuallyFrameRate=%d", _preset,actuallyFrameRate);
            }
            break;
        }
    }

    if (_captureOrientation == AVCaptureVideoOrientationPortrait ||
        _captureOrientation == AVCaptureVideoOrientationPortraitUpsideDown) {
        _width  = presetHeight;
        _height = presetWidth;
    } else {
        _width  = presetWidth;
        _height = presetHeight;
    }
}

- (void)openAndConfigureDevice:(AVCaptureDevicePosition)cameraPosition
            captureOrientation:(AVCaptureVideoOrientation)captureOrientation
                        preset:(NSString*)preset
                     frameRate:(int32_t)frameRate
                    openOutput:(BOOL)openOutput {
    NSLog(@"");
    AVCaptureDevicePosition currentCameraPosition = [[_deviceInput device] position];
    if (cameraPosition == currentCameraPosition) {
        //        return;
    }
    AVCaptureDevice *newDevice = nil;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        AVCaptureDevicePosition pos = [device position];
        if (pos == cameraPosition) {
            newDevice = device;
            NSLog(@"set camera position %td", cameraPosition);
            break;
        }
    }
    
    NSError* error;
    if (!newDevice) {
        // try default device
        newDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    
    AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:newDevice error:&error];
    if (newVideoInput) {
        [_captureSession beginConfiguration];
        [_captureSession removeInput:_deviceInput];
        if ([_captureSession canAddInput:newVideoInput]) {
            [_captureSession addInput:newVideoInput];
            _deviceInput = newVideoInput;
        } else {
            NSLog(@"AVCaptureSession can add input return NO");
            if (_deviceInput) {
                [_captureSession addInput:_deviceInput];
            } else {
                NSLog(@"_deviceInput is nil, can not be add into AVCaptureSession");
            }
        }
        
        if (_dataOutput) {
            [_captureSession removeOutput:_dataOutput];
        }
        // add the video output
        _dataOutput = [[AVCaptureVideoDataOutput alloc] init];
        if (_dataOutput) {
            [_dataOutput setAlwaysDiscardsLateVideoFrames:YES];
            [_dataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:_pixelForamt] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
            [_dataOutput setSampleBufferDelegate:self queue:_captureQueue];
            if ([_captureSession canAddOutput:_dataOutput]) {
                [_captureSession addOutput:_dataOutput];
                _captureConnection = [_dataOutput connectionWithMediaType:AVMediaTypeVideo];
                if (_captureConnection.supportsVideoMirroring && cameraPosition == AVCaptureDevicePositionFront) {
                    _captureConnection.videoMirrored = YES;
                }
                [self doSetCaptureOrientation:captureOrientation];
            }
        }
        
        [_captureSession commitConfiguration];
    }
    _device = newDevice;
    _exposPt = CGPointMake( 0.51, 0.49 );
    if ([_device lockForConfiguration:nil]) {
        if ( [_device isFocusModeSupported:AVCaptureFocusModeAutoFocus] ){
            if (_device.focusPointOfInterestSupported) {
                _device.focusPointOfInterest= _exposPt;
            }
            _device.focusMode = AVCaptureFocusModeAutoFocus;
        }
        if ([_device isExposureModeSupported:AVCaptureExposureModeAutoExpose]) {
            if (_device.isExposurePointOfInterestSupported) {
                _device.exposurePointOfInterest = _exposPt;
            }
            _device.exposureMode = AVCaptureExposureModeAutoExpose;
        }
        [_device unlockForConfiguration];
    }
    
    [self doApplyPreset:preset frameRate:frameRate];
    
    _cameraPosition = cameraPosition;
    _cameraJustChanged = YES;
}

- (void)doSetCameraPosition:(AVCaptureDevicePosition)cameraPosition
         captureOrientation:(AVCaptureVideoOrientation)captureOrientation
                     preset:(NSString*)preset
                  frameRate:(int32_t)frameRate {
    NSLog(@"");
    [self openAndConfigureDevice:cameraPosition
              captureOrientation:captureOrientation
                          preset:preset
                       frameRate:frameRate
                      openOutput:NO];
}

- (BOOL)configure:(NSDictionary*)settings {
    //if ([self isConfigsContainCaptureParam:settings]) {
    AVCaptureDevicePosition cameraPosition = _cameraPosition;
    AVCaptureVideoOrientation captureOrientation = _captureOrientation;
    NSString* preset = _preset;
    int32_t frameRate = _frameRate;
    NSNumber* number;
    number = [settings objectForKey:@"kVLVideo_CameraPosition"];
    if (number) {
        cameraPosition = (AVCaptureDevicePosition)[number integerValue];
    }
    number = [settings objectForKey:@"kVLVideo_CaptureOrientation"];
    if (number) {
        captureOrientation = (AVCaptureVideoOrientation)[number integerValue];
    }
    NSString *settingPreset = [settings objectForKey:@"kVLVideo_CapturePreset"];
    if (settingPreset) {
        preset = settingPreset;
    }
    else if (preset == nil) {
        preset = [MacCameraCapture maxPresetOfDeviceModel];
    }
    number = [settings objectForKey:@"kVLVideo_CaptureFrameRate"];
    if (number) {
        frameRate = [number intValue];
    }
    
    
    if ([_captureSession isRunning]) {
        [self doSetFrameRate:frameRate];
        if (cameraPosition != _cameraPosition) {
            [self doSetCameraPosition:cameraPosition
                   captureOrientation:captureOrientation
                               preset:preset
                            frameRate:frameRate];
        } else {
            if (captureOrientation != _captureOrientation) {
                [self doSetCaptureOrientation:captureOrientation];
            }
            
            if (preset && (![preset isEqualToString:_preset] ||
                           ![[_currentActiveFormat description] isEqual:[_settingActiveFormat description]])) {
                [self doApplyPreset:preset
                          frameRate:frameRate];
            }
        }
    } else {
        if ([[_captureSession inputs] count] <= 0
            || [[_captureSession outputs] count] <= 0) {
            NSLog(@"call openAndConfigureDevice");
            [self openAndConfigureDevice:cameraPosition
                      captureOrientation:captureOrientation
                                  preset:preset
                               frameRate:frameRate
                              openOutput:YES];
        }
    }
    
    [_videoConfigLock lock];
    for (id key in settings) {
        [_videoConfig setObject:[settings objectForKey:key] forKey:key];
    }
    [_videoConfigLock unlock];
    return YES;
}

@end
