//
//  MGLTools.m
//  video
//
//  Created by bleach on 16/7/29.
//  Copyright © 2016年 howard_pang. All rights reserved.
//

#import "MGLTools.h"

@implementation MGLTools

+ (CVPixelBufferPoolRef)createPixelBufferPool:(int32_t)width height:(int32_t)height pixelFormat:(FourCharCode)pixelFormat maxBufferCount:(int32_t)maxBufferCount {
    CVPixelBufferPoolRef outputPool = NULL;
    
    NSDictionary* sourcePixelBufferOptions = @{
                                               (id)kCVPixelBufferPixelFormatTypeKey : @(pixelFormat),
                                               (id)kCVPixelBufferWidthKey : @(width),
                                               (id)kCVPixelBufferHeightKey : @(height),
                                               (id)kCVPixelFormatOpenGLCompatibility : @(YES),
                                               (id)kCVPixelBufferIOSurfacePropertiesKey : @{}
                                               };
    
    NSDictionary* pixelBufferPoolOptions = @{ (id)kCVPixelBufferPoolMinimumBufferCountKey : @(maxBufferCount) };
    
    CVPixelBufferPoolCreate(kCFAllocatorDefault, (__bridge CFDictionaryRef)pixelBufferPoolOptions, (__bridge CFDictionaryRef)sourcePixelBufferOptions, &outputPool);
    
    return outputPool;
}

+ (CFDictionaryRef)createPixelBufferPoolAuxAttributes:(int32_t)maxBufferCount {
    /* CVPixelBufferPoolCreatePixelBufferWithAuxAttributes() will return kCVReturnWouldExceedAllocationThreshold if we have already vended the max number of buffers */
    return CFRetain((__bridge CFTypeRef)(@{ (id)kCVPixelBufferPoolAllocationThresholdKey : @(maxBufferCount) }));
}

+ (void)preallocatePixelBuffersInPool:(CVPixelBufferPoolRef)pool auxAttributes:(CFDictionaryRef)auxAttributes {
    /* preallocate buffers in the pool, since this is for real-time display/capture */
    NSMutableArray* pixelBuffers = [[NSMutableArray alloc] init];
    while (YES) {
        CVPixelBufferRef pixelBuffer = NULL;
        OSStatus err = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pool, auxAttributes, &pixelBuffer);
        
        if (err == kCVReturnWouldExceedAllocationThreshold) {
            break;
        }
        assert(err == noErr);
        
        [pixelBuffers addObject:(__bridge id)pixelBuffer];
        CFRelease(pixelBuffer);
    }
}

+ (NSString *)modelName
{
    static NSString *modelName = nil;
    if (!modelName) {
        struct utsname systemInfo;
        uname(&systemInfo);
        modelName = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    }
    return modelName;
}

+ (BOOL)isOrNewerThaniPhone5s
{
    NSString *phoneVersion = [MGLTools modelName];
    BOOL isNewDevice = [phoneVersion hasPrefix:@"iPhone"]
    && [phoneVersion compare:@"iPhone6" options:NSNumericSearch] == NSOrderedDescending;
    return isNewDevice;
}

+ (BOOL)supportsFastTextureUpload {
    return NO;
}

@end
