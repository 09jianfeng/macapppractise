//
//  MGLCommon.m
//  video
//
//  Created by bleach on 16/7/29.
//  Copyright © 2016年 howard_pang. All rights reserved.
//

#import "MGLCommon.h"
#import <Cocoa/Cocoa.h>

void mglRunAsyncOnMainQueueWithoutDeadlocking(void (^block)(void)) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

CGImageRef convertNSImageToCGImageref(NSImage * image)
{
    NSBitmapImageRep *imageClass = [[NSBitmapImageRep alloc] initWithData:[image TIFFRepresentation]];
    CGImageRef cgImage = imageClass.CGImage;
    return cgImage;
}

MImageData* mglImageDataFromUIImage(NSImage* image, BOOL flipVertical) {
    CGImageRef cgImage = convertNSImageToCGImageref(image);
    if (!cgImage) {
        return NULL;
    }
    return mglImageDataFromCGImage(cgImage, flipVertical);
}

MImageData* mglImageDataFromCGImage(CGImageRef cgImage, BOOL flipVertical) {
    CGFloat scale = 1;
    GLuint width = (GLuint)CGImageGetWidth(cgImage) * scale;
    GLuint height = (GLuint)CGImageGetHeight(cgImage) * scale;
    
    MImageData* imageData = (MImageData *)malloc(sizeof(MImageData));
    imageData->width = width;
    imageData->height = height;
    imageData->rowByteSize = width * 4;
    imageData->data = (GLubyte *)malloc(height * imageData->rowByteSize);
    imageData->format = GL_RGBA;
    imageData->type = GL_UNSIGNED_BYTE;
    
    CGContextRef context = CGBitmapContextCreate(imageData->data, imageData->width, imageData->height, 8, imageData->rowByteSize, CGImageGetColorSpace(cgImage), kCGBitmapAlphaInfoMask & kCGImageAlphaNoneSkipLast);
    CGContextSetBlendMode(context, kCGBlendModeCopy);
    if (flipVertical) {
        CGContextTranslateCTM(context, 0.0f, imageData->height);
        CGContextScaleCTM(context, 1.0, -1.0);
    }
    CGContextDrawImage(context, CGRectMake(0.0, 0.0, imageData->width, imageData->height), cgImage);
    CGContextRelease(context);
    
    if (NULL == imageData->data) {
        mglDestroyImageData(imageData);
        return NULL;
    }
    
    return imageData;
}

void mglDestroyImageData(MImageData* imageData) {
    if (imageData == NULL) {
        return;
    }
    free(imageData->data);
    imageData->data = NULL;
    free(imageData);
    imageData = NULL;
}

//nv12 rotate 90
typedef struct NV12Frame{
    int width;
    int height;
    int linesize[3];
    uint8_t *data[3];
}NV12Frame;

void NV12_frame_rotate_90(CVPixelBufferRef source, CVPixelBufferRef target)
{
    NV12Frame* des;
    NV12Frame *src;
    
    int n = 0;
    int hw = src->width>>1;
    int hh = src->height>>1;
    int size = src->width * src->height;
    int hsize = size>>2;
    
    int pos = 0;
    //copy y
    for(int j = 0; j < src->width;j++)
    {
        pos = size;
        for(int i = src->height - 1; i >= 0; i--)
        {   pos-=src->width;
            des->data[0][n++] = src->data[0][pos + j];
        }
    }
    //copy uv
    n = 0;
    for(int j = 0;j < hw;j++)
    {   pos= hsize;
        for(int i = hh - 1;i >= 0;i--)
        {
            pos-=hw;
            des->data[1][n] = src->data[1][ pos + j];
            des->data[2][n] = src->data[2][ pos + j];
            n++;
        }
    }
    
    des->linesize[0] = src->height;
    des->linesize[1] = src->height>>1;
    des->linesize[2] = src->height>>1;
    des->height = src->width;
    des->width = src->height;
}

/*
* UIImage to RGBA Pixelbuffer
*/
CVPixelBufferRef imageToRGBAPixelBuffer(NSImage *image){
    // convert to CGImage & dump to bitmapData
    
    CGImageRef imageRef = convertNSImageToCGImageref(image);
    int width  = (int)CGImageGetWidth(imageRef);
    int height = (int)CGImageGetHeight(imageRef);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = ((bytesPerPixel*width+255)/256)*256;
    NSUInteger bitsPerComponent = 8;
    GLubyte* bitmapData = (GLubyte *)malloc(bytesPerRow*height); // if 4 components per pixel (RGBA)
    CGContextRef context = CGBitmapContextCreate(bitmapData, width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    
    
    
    // 创建RGB pixelbuffer
    CVPixelBufferRef rgbPixelBuffer;
    CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, (void*)[NSDictionary dictionary]);
    CFDictionarySetValue(attrs, kCVPixelBufferOpenGLCompatibilityKey, (void*)[NSNumber numberWithBool:YES]);
    
    CVReturn err = CVPixelBufferCreate(kCFAllocatorDefault, (int)image.size.width, (int)image.size.height, kCVPixelFormatType_32BGRA, attrs, &rgbPixelBuffer);
    if (err) {
        return NULL;
    }
    CFRelease(attrs);
    
    CVPixelBufferLockBaseAddress(rgbPixelBuffer, 0);
    uint8_t * bgra = (uint8_t*)CVPixelBufferGetBaseAddress(rgbPixelBuffer);
    int bgraStride = (int)CVPixelBufferGetBytesPerRow(rgbPixelBuffer);
    if (bgraStride == width * 4) {
       memcpy(bgra, bitmapData, bgraStride * height);
    }else{
        for (int i = 0; i < height; i++) {
            for (int j = 0; j < bgraStride; j++) {
                bgra[i * bgraStride + j] = bitmapData[i * bgraStride + j];
            }
        }
    }
    CVPixelBufferUnlockBaseAddress(rgbPixelBuffer, 0);
    
    return rgbPixelBuffer;
}

/*
 * UIImage to yuv420f nv12格式。
 */
CVPixelBufferRef imageToYUVPixelBuffer(NSImage *image){
    // convert to CGImage & dump to bitmapData
    
    CGImageRef imageRef = convertNSImageToCGImageref(image);
    int width  = (int)CGImageGetWidth(imageRef);
    int height = (int)CGImageGetHeight(imageRef);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = ((bytesPerPixel*width+255)/256)*256;
    NSUInteger bitsPerComponent = 8;
    GLubyte* bitmapData = (GLubyte *)malloc(bytesPerRow*height); // if 4 components per pixel (RGBA)
    CGContextRef context = CGBitmapContextCreate(bitmapData, width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    
    // 创建YUV pixelbuffer
    
    CVPixelBufferRef yuvPixelBuffer;
    CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, (void*)[NSDictionary dictionary]);
    CFDictionarySetValue(attrs, kCVPixelBufferOpenGLCompatibilityKey, (void*)[NSNumber numberWithBool:YES]);
    
    CVReturn err = CVPixelBufferCreate(kCFAllocatorDefault, (int)image.size.width, (int)image.size.height, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, attrs, &yuvPixelBuffer);
    if (err) {
        return NULL;
    }
    CFRelease(attrs);
    
    CVPixelBufferLockBaseAddress(yuvPixelBuffer, 0);
    
    uint8_t * yPtr = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(yuvPixelBuffer, 0);
    size_t strideY = CVPixelBufferGetBytesPerRowOfPlane(yuvPixelBuffer, 0);
    
    uint8_t * uvPtr = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(yuvPixelBuffer, 1);
    size_t strideUV = CVPixelBufferGetBytesPerRowOfPlane(yuvPixelBuffer, 1);
    
    for (int j = 0; j < image.size.height; j++) {
        for (int i = 0; i < image.size.width; i++) {
            float r  = bitmapData[j*bytesPerRow + i*4 + 0];
            float g  = bitmapData[j*bytesPerRow + i*4 + 1];
            float b  = bitmapData[j*bytesPerRow + i*4 + 2];
            
            int16_t y = 0.299*r + 0.587*g + 0.114*b;
            if (y > 255) {
                y = 255;
            } else if (y < 0) {
                y = 0;
            }
            
            yPtr[j*strideY + i] = (uint8_t)y;
        }
    }
    
    for (int j = 0; j < image.size.height; j+=2)
    {
        for (int i = 0; i < image.size.width; i+=2)
        {
            float r  = bitmapData[j*bytesPerRow + i*4 + 0];
            float g  = bitmapData[j*bytesPerRow + i*4 + 1];
            float b  = bitmapData[j*bytesPerRow + i*4 + 2];
            
            int16_t u = (-0.1145*r - 0.3855*g + 0.500*b) + 128;
            int16_t v = (0.500*r - 0.4543*g - 0.0457*b) + 128;
            
            if (u > 255) {
                u = 255;
            } else if (u < 0) {
                u = 0;
            }
            
            if (v > 255) {
                v = 255;
            } else if (v < 0) {
                v = 0;
            }
            
            uvPtr[j/2*strideUV + i + 0] = (uint8_t)u;
            uvPtr[j/2*strideUV + i + 1] = (uint8_t)v;
        }
    }
    
    free(bitmapData);
    CVPixelBufferUnlockBaseAddress(yuvPixelBuffer, 0);
    
    return yuvPixelBuffer;
}

CVPixelBufferRef pixelBufferCreateFromCGImage(CGImageRef ciImage)
{
    CGSize frameSize = CGSizeMake(CGImageGetWidth(ciImage), CGImageGetHeight(ciImage));
    NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:NO], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:NO], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, frameSize.width, frameSize.height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)options, &pxbuffer);
    if(status != 0){
        NSLog(@"status is not 0, status:%d",status);
    }
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void* pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, frameSize.width, frameSize.height, 8, 4 * frameSize.width, rgbColorSpace, kCGImageAlphaNoneSkipLast);
    
    CGContextTranslateCTM(context, 0, frameSize.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(ciImage), CGImageGetHeight(ciImage)), ciImage);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}

//从image到CVPixelBuffer需要注意性能，如果使用context的话和使用memcpy都有一样的性能支出，但是使用CVPixelBufferCreateWithBytes这个可以在时间上提高好几个数量级别，这是因为这里没有渲染也没有内存拷贝能耗时的操作而只是将data的指针进行了修改
CVPixelBufferRef pixelBufferCreateFromCGImageFaster(NSImage *image){
    CGImageRef cgImage = convertNSImageToCGImageref(image);
    CVPixelBufferRef pxbuffer = NULL;
    NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    
    size_t width =  CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    size_t bytesPerRow = CGImageGetBytesPerRow(cgImage);
    
    CFDataRef dataFromImageDataProvider = CGDataProviderCopyData(CGImageGetDataProvider(cgImage));
    GLubyte* imageData = (GLubyte *)CFDataGetBytePtr(dataFromImageDataProvider);
    
    CVPixelBufferCreateWithBytes(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, imageData,bytesPerRow, NULL, NULL, (__bridge CFDictionaryRef)options, &pxbuffer);
    
    CFRelease(dataFromImageDataProvider);
    
    return pxbuffer;
}


demoSource* srcLoadSource(const char* filepathname)
{
    demoSource* source = (demoSource*) calloc(sizeof(demoSource), 1);
    
    // Check the file name suffix to determine what type of shader this is
    const char* suffixBegin = filepathname + strlen(filepathname) - 4;
    
    if(0 == strncmp(suffixBegin, ".fsh", 4))
    {
        source->shaderType = GL_FRAGMENT_SHADER;
    }
    else if(0 == strncmp(suffixBegin, ".vsh", 4))
    {
        source->shaderType = GL_VERTEX_SHADER;
    }
    else
    {
        // Unknown suffix
        source->shaderType = 0;
    }
    
    FILE* curFile = fopen(filepathname, "r");
    
    // Get the size of the source
    fseek(curFile, 0, SEEK_END);
    long fileSize = ftell (curFile);
    
    // Add 1 to the file size to include the null terminator for the string
    source->byteSize =  (GLsizei)fileSize + 1;
    
    // Alloc memory for the string
    source->string = (GLchar* )malloc(source->byteSize);
    
    // Read entire file into the string from beginning of the file
    fseek(curFile, 0, SEEK_SET);
    fread(source->string, 1, fileSize, curFile);
    
    fclose(curFile);
    
    // Insert null terminator
    source->string[fileSize] = 0;
    
    return source;
}

void srcDestroySource(demoSource* source)
{
    free(source->string);
    free(source);
}
