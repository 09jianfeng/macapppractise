//
//  MGLTools.h
//  video
//
//  Created by bleach on 16/7/29.
//  Copyright © 2016年 howard_pang. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <sys/utsname.h>



@interface MGLTools : NSObject

/**
 * @brief 创建一个pixelBuffer的缓冲区
 * @param width width
 * @param height height
 * @param pixelFormat pixelFormat
 * @param maxBufferCount 缓冲区大小
 */
+ (CVPixelBufferPoolRef)createPixelBufferPool:(int32_t)width height:(int32_t)height pixelFormat:(FourCharCode)pixelFormat maxBufferCount:(int32_t)maxBufferCount;

/**
 * @brief 设置缓冲区大小阀值(注意需要release)
 */
+ (CFDictionaryRef)createPixelBufferPoolAuxAttributes:(int32_t)maxBufferCount;

/**
 * @brief 预先创建pixelBuffer,直到达到阀值
 */
+ (void)preallocatePixelBuffersInPool:(CVPixelBufferPoolRef)pool auxAttributes:(CFDictionaryRef)auxAttributes;

/**
 * @brief 是否支持加速
 */
+ (BOOL)supportsFastTextureUpload;

+ (NSString *)modelName;

+ (BOOL)isOrNewerThaniPhone5s;

uint32_t GetTickCount();
@end
