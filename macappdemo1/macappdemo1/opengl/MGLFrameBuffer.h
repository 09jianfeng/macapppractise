//
//  MGLFrameBuffer.h
//  video
//
//  Created by bleach on 16/8/2.
//  Copyright © 2016年 howard_pang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MGLCommon.h"

/**
 * 此类可用于离屏渲染,也可用于纹理更新
 */
@interface MGLFrameBuffer : NSObject

@property (nonatomic, assign) GLuint bindTexture;
@property (nonatomic, assign) CGLContextObj cglContext;

/**
 * @brief 设置帧缓冲区大小(使用默认的纹理配置和FBO)
 */
- (id)initWithSize:(CGSize)framebufferSize context:(CGLContextObj)cglContext;

/**
 * @brief 设置帧缓冲区大小
 * @param fboTextureOptions 指定纹理配置
 * @parma onlyTexture       是否不是用FBO
 */
- (id)initWithSize:(CGSize)framebufferSize textureOptions:(MGLTextureOptions)fboTextureOptions context:(CGLContextObj)cglContext;

/**
 * @brief 设置帧缓冲区大小(完全当做一个纹理管理工具)
 * @param inputTexture 指定纹理
 */
- (id)initWithSize:(CGSize)framebufferSize inputTexture:(GLuint)inputTexture context:(CGLContextObj)cglContext;

/**
 * @brief 激活FBO
 */
- (void)activateFramebuffer;

/**
 * @brief 不激活FBO
 */
- (void)deactiveFramebuffer;

/**
 * @brief 每行字节数
 */
- (NSInteger)bytesPerRow;

/**
 * @brief 像素数据
 */
- (CVPixelBufferRef)pixelBuffer;

/**
 * @brief 字节数据
 */
- (GLubyte *)byteBuffer;

/**
 * @brief 清理
 */
- (void)deInit;

@end

