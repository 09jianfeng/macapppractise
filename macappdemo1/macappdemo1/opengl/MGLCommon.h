//
//  MGLCommon.h
//  video
//
//  Created by bleach on 16/7/29.
//  Copyright © 2016年 howard_pang. All rights reserved.
//

#ifndef MGLCommon_h
#define MGLCommon_h

#import <Foundation/Foundation.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl3.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AVFoundation/AVFoundation.h>

void mglRunOnMainQueueWithoutDeadlocking(void (^block)(void));

typedef struct MGLTextureOptions {
    GLenum minFilter;
    GLenum magFilter;
    GLenum wrapS;
    GLenum wrapT;
    GLenum internalFormat;
    GLenum format;
    GLenum type;
} MGLTextureOptions;

typedef struct MGLColor {
    GLfloat red;
    GLfloat green;
    GLfloat blue;
    GLfloat alpha;
} MGLColor;

typedef struct MGLVertex4 {
    GLfloat vx;
    GLfloat vy;
    GLfloat vz;
    GLfloat vw;
} MGLVertex4;

typedef struct MGLTexcoord2 {
    GLfloat tx;
    GLfloat ty;
} MGLTexcoord2;

typedef struct MGLPackData {
    MGLVertex4 vertex;
    MGLTexcoord2 texcoord;
} MGLPackData;

typedef struct MGLTexcoordQuad {
    MGLTexcoord2 data[4];
} MGLTexcoordQuad;

typedef struct MGLQuad {
    MGLPackData data[4];
} MGLQuad;

typedef struct MImageData {
    GLubyte* data;
    GLuint width;
    GLuint height;
    GLenum format;
    GLenum type;
    GLuint rowByteSize;
} MImageData;

/**
 * 将UIImage转化成MImageData
 */
MImageData* mglImageDataFromUIImage(NSImage* uiImage, BOOL flipVertical);
MImageData* mglImageDataFromCGImage(CGImageRef cgImage, BOOL flipVertical);
void mglDestroyImageData(MImageData* imageData);

CVPixelBufferRef imageToYUVPixelBuffer(NSImage *image);

#pragma mark - GL
#define STRINGIZE(x) #x
#define SHADER_STRING(text) @ STRINGIZE(text)

static inline const char * GetGLErrorString(GLenum error) {
    const char *str;
    switch(error) {
        case GL_NO_ERROR:
            str = "GL_NO_ERROR";
            break;
        case GL_INVALID_ENUM:
            str = "GL_INVALID_ENUM";
            break;
        case GL_INVALID_VALUE:
            str = "GL_INVALID_VALUE";
            break;
        case GL_INVALID_OPERATION:
            str = "GL_INVALID_OPERATION";
            break;
#if defined __gl_h_ || defined __gl3_h_
        case GL_OUT_OF_MEMORY:
            str = "GL_OUT_OF_MEMORY";
            break;
        case GL_INVALID_FRAMEBUFFER_OPERATION:
            str = "GL_INVALID_FRAMEBUFFER_OPERATION";
            break;
#endif
#if defined __gl_h_
        case GL_STACK_OVERFLOW:
            str = "GL_STACK_OVERFLOW";
            break;
        case GL_STACK_UNDERFLOW:
            str = "GL_STACK_UNDERFLOW";
            break;
        case GL_TABLE_TOO_LARGE:
            str = "GL_TABLE_TOO_LARGE";
            break;
#endif
        default:
            str = "(ERROR: Unknown Error Enum)";
            break;
    }
    return str;
}

#define GetGLError()                                        \
{                                                           \
    GLenum err = glGetError();                              \
    while (err != GL_NO_ERROR) {                            \
        NSLog(@"GLError %s set in File:%s Line:%d\n",       \
        GetGLErrorString(err), __FILE__, __LINE__);         \
        err = glGetError();                                 \
    }                                                       \
}

#endif /* MGLCommon_h */


typedef struct demoSourceRec
{
    GLchar* string;
    
    GLsizei byteSize;
    
    GLenum shaderType; // Vertex or Fragment
    
} demoSource;

demoSource* srcLoadSource(const char* filepathname);

void srcDestroySource(demoSource* source);
