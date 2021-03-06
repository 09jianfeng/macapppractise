//
//  MGLOpenGLView.m
//  macappdemo1
//
//  Created by JFChen on 2019/11/4.
//  Copyright © 2019 JFChen. All rights reserved.
//

#import "MGLOpenGLView.h"
#import "MGLFrameBuffer.h"
#import "MGLProgram.h"
#import "MGLTools.h"

typedef struct GPUTextureOptions {
    GLenum minFilter;
    GLenum magFilter;
    GLenum wrapS;
    GLenum wrapT;
    GLenum internalFormat;
    GLenum format;
    GLenum type;
} GPUTextureOptions;

@interface MGLOpenGLView()
@property(nonatomic , strong) MGLFrameBuffer *frameBuffer;
@property(nonatomic , strong) GLProgram *program;
@property(nonatomic , strong) GLProgram *screenProgram;
@end

@implementation MGLOpenGLView{
    GLuint aPos,aColor,aTextCood;
    GLuint aOnPos,aOnTextCood;
    
    GLuint VAO,VBO,EBO;
    GLuint OnVAO,OnVBO,OnEBO;
    GLuint wmVAO,wmVBO,wmEBO;
    
    GLuint texture0,texturewm,texturepixel;
    
    CVPixelBufferRef _pixelbuffer;
    CVOpenGLTextureCacheRef _textureCache;
    CVOpenGLTextureRef _renderTexture;
    CVPixelBufferRef _renderTarget;
}

- (instancetype)initWithFrame:(NSRect)frameRect{
    self = [super initWithFrame:frameRect];
    if (self) {
        NSOpenGLPixelFormatAttribute attrs[] =
        {
            NSOpenGLPFADoubleBuffer,
            NSOpenGLPFADepthSize, 24,
            // Must specify the 3.2 Core Profile to use OpenGL 3.2.
            NSOpenGLPFAOpenGLProfile,
            //set opengl vesion
            NSOpenGLProfileVersion3_2Core,
            0
        };

        NSOpenGLPixelFormat *pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
        if (!pf)
        {
            NSLog(@"No OpenGL pixel format");
        }

        NSOpenGLContext* context = [[NSOpenGLContext alloc] initWithFormat:pf shareContext:nil];
        [self setPixelFormat:pf];
        [self setOpenGLContext:context];
        
        _frameBuffer = [[MGLFrameBuffer alloc] initWithSize:frameRect.size context:[self.openGLContext CGLContextObj]];
    }
    return self;
}

-(void)prepareOpenGL{
    [super prepareOpenGL];
    [self.openGLContext makeCurrentContext];
    
    GLint swapInt = 1;
    [[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];
    
    [self buildPrograme];
    [self setupGLBufferObject];
    
    [self loadTexture];
    
    NSImage *image = [NSImage imageNamed:@"container.jpg"];
    _pixelbuffer = imageToRGBAPixelBuffer(image);
    [self loadPixelBufferTexture];
}

- (void)buildPrograme{
    NSString* filePathName;
    NSString *vsString;
    NSString *fgString;
    if (!_program) {
        filePathName = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vs"];
        vsString = [NSString stringWithContentsOfFile:filePathName encoding:NSUTF8StringEncoding error:nil];
         filePathName = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"frag"];
         fgString = [NSString stringWithContentsOfFile:filePathName encoding:NSUTF8StringEncoding error:nil];
         _program = [[GLProgram alloc] initWithVertexShaderString:vsString fragmentShaderString:fgString];
        
        if(![_program link]){
            NSLog(@"_program link error %@  fragement log %@  vertext log %@", [_program programLog], [_program fragmentShaderLog], [_program vertexShaderLog]);
            _program = nil;
            NSAssert(NO, @"Falied to link TextureRGBFS shaders");
        }
        aPos = 0;
        aTextCood = 2;
        aColor = 1;
    }
    
    if (!_screenProgram) {
        filePathName = [[NSBundle mainBundle] pathForResource:@"screenShader" ofType:@"vs"];
        vsString = [NSString stringWithContentsOfFile:filePathName encoding:NSUTF8StringEncoding error:nil];
        filePathName = [[NSBundle mainBundle] pathForResource:@"screenShader" ofType:@"frag"];
        fgString = [NSString stringWithContentsOfFile:filePathName encoding:NSUTF8StringEncoding error:nil];
        _screenProgram = [[GLProgram alloc] initWithVertexShaderString:vsString fragmentShaderString:fgString];
        if(![_screenProgram link]){
            NSLog(@"_program link error %@  fragement log %@  vertext log %@", [_screenProgram programLog], [_screenProgram fragmentShaderLog], [_screenProgram vertexShaderLog]);
            _screenProgram = nil;
            NSAssert(NO, @"Falied to link TextureRGBFS shaders");
        }
        aOnPos = 0;
        aOnTextCood = 1;
    }
}

- (void)setupGLBufferObject{
    {
        float vertices[] = {
            // positions          // colors           // texture coords
            1.f,  1.0f, 0.0f,   1.0f, 0.0f, 0.0f,   1.0f, 1.0f, // top right
            1.0f, -1.0f, 0.0f,   0.0f, 1.0f, 0.0f,   1.0f, 0.0f, // bottom right
            -1.0f, -1.0f, 0.0f,   0.0f, 0.0f, 1.0f,   0.0f, 0.0f, // bottom left
            -1.0f,  1.0f, 0.0f,   1.0f, 1.0f, 0.0f,   0.0f, 1.0f  // top left
        };
        unsigned int indices[] = {
            0, 1, 3, // first triangle
            1, 2, 3  // second triangle
        };
        
        glGenVertexArrays(1, &VAO);
        glGenBuffers(1, &VBO);
        glGenBuffers(1, &EBO);

        glBindVertexArray(VAO);
        glBindBuffer(GL_ARRAY_BUFFER, VBO);
        glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);

        glVertexAttribPointer(aPos, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void *)0);
        glEnableVertexAttribArray(aPos);
        glVertexAttribPointer(aColor, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void *)(3 * sizeof(float)));
        glEnableVertexAttribArray(aColor);
        glVertexAttribPointer(aTextCood, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void *)(6 * sizeof(float)));
        glEnableVertexAttribArray(aTextCood);
        glBindVertexArray(0);
    }
    
    {
        float vertices1[] = {
            // positions          // colors           // texture coords
            0.8f,  0.8f, 0.0f,   1.0f, 0.0f, 0.0f,   1.0f, 1.0f, // top right
            0.8f, -0.8f, 0.0f,   0.0f, 1.0f, 0.0f,   1.0f, 0.0f, // bottom right
            -0.8f, -0.8f, 0.0f,   0.0f, 0.0f, 1.0f,   0.0f, 0.0f, // bottom left
            -0.8f,  0.8f, 0.0f,   1.0f, 1.0f, 0.0f,   0.0f, 1.0f  // top left
        };
        unsigned int indices[] = {
            0, 1, 3, // first triangle
            1, 2, 3  // second triangle
        };
        glGenVertexArrays(1, &OnVAO);
        glGenBuffers(1, &OnVBO);
        glGenBuffers(1, &OnEBO);
        
        glBindVertexArray(OnVAO);
        glBindBuffer(GL_ARRAY_BUFFER, OnVBO);
        glBufferData(GL_ARRAY_BUFFER, sizeof(vertices1), vertices1, GL_STATIC_DRAW);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, OnEBO);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
        
        glVertexAttribPointer(aOnPos, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void *)0);
        glEnableVertexAttribArray(aOnPos);
        glVertexAttribPointer(aOnTextCood, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void *)(6 * sizeof(float)));
        glEnableVertexAttribArray(aOnTextCood);
        glBindVertexArray(0);
    }
    
    {
        float vertices[] = {
            // positions          // colors           // texture coords
            0.4f,  0.4f, 0.0f,   1.0f, 0.0f, 0.0f,   1.0f, 1.0f, // top right
            0.4f, -0.4f, 0.0f,   0.0f, 1.0f, 0.0f,   1.0f, 0.0f, // bottom right
            -0.4f, -0.4f, 0.0f,   0.0f, 0.0f, 1.0f,   0.0f, 0.0f, // bottom left
            -0.4f,  0.4f, 0.0f,   1.0f, 1.0f, 0.0f,   0.0f, 1.0f  // top left
        };
        unsigned int indices[] = {
            0, 1, 3, // first triangle
            1, 2, 3  // second triangle
        };
        glGenVertexArrays(1, &wmVAO);
        glGenBuffers(1, &wmVBO);
        glGenBuffers(1, &wmEBO);
        
        glBindVertexArray(wmVAO);
        glBindBuffer(GL_ARRAY_BUFFER, wmVBO);
        glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, wmEBO);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
        
        glVertexAttribPointer(aOnPos, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void *)0);
        glEnableVertexAttribArray(aOnPos);
        glVertexAttribPointer(aOnTextCood, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void *)(6 * sizeof(float)));
        glEnableVertexAttribArray(aOnTextCood);
        glBindVertexArray(0);
    }
    
}

- (void)loadTexture{
    {
        // load image, create texture and generate mipmaps
        NSImage *image = [NSImage imageNamed:@"container.jpg"];
        MImageData* imageData = mglImageDataFromUIImage(image, YES);
        
        glActiveTexture(GL_TEXTURE0);
        glGenTextures(1, &texture0);
        glBindTexture(GL_TEXTURE_2D, texture0);
        // set the texture wrapping parameters
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);    // set texture wrapping to GL_REPEAT (default wrapping method)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        // set texture filtering parameters
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        
        glTexImage2D(GL_TEXTURE_2D, 0, imageData->format, imageData->width, imageData->height, 0, imageData->format, imageData->type, imageData->data);
        glGenerateMipmap(GL_TEXTURE_2D);
        
        mglDestroyImageData(imageData);
    }
    
    {
        // load image, create texture and generate mipmaps
        NSImage *image = [NSImage imageNamed:@"window.png"];
        MImageData* imageData = mglImageDataFromUIImage(image, YES);
        
        glActiveTexture(GL_TEXTURE0);
        glGenTextures(1, &texturewm);
        glBindTexture(GL_TEXTURE_2D, texturewm);
        // set the texture wrapping parameters
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);    // set texture wrapping to GL_REPEAT (default wrapping method)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        // set texture filtering parameters
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        
        glTexImage2D(GL_TEXTURE_2D, 0, imageData->format, imageData->width, imageData->height, 0, imageData->format, imageData->type, imageData->data);
        glGenerateMipmap(GL_TEXTURE_2D);
        
        mglDestroyImageData(imageData);
    }
}

- (void)loadPixelBufferTexture{
    int width = (int)CVPixelBufferGetWidth(_pixelbuffer);
    int heigh = (int)CVPixelBufferGetHeight(_pixelbuffer);
    
    glActiveTexture(GL_TEXTURE0);
    glGenTextures(1, &texturepixel);
    glBindTexture(GL_TEXTURE_2D, texturepixel);
    // set the texture wrapping parameters
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);    // set texture wrapping to GL_REPEAT (default wrapping method)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    // set texture filtering parameters
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    
    CVPixelBufferLockBaseAddress(_pixelbuffer, 0);
    uint8_t *data = CVPixelBufferGetBaseAddress(_pixelbuffer);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, heigh, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
    CVPixelBufferUnlockBaseAddress(_pixelbuffer, 0);
}

- (void)renderPixelBuffer{
    
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(0, 0, CGRectGetWidth(self.frame), CGRectGetHeight(self.frame));
    glClearColor(0.2f, 0.8f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    [_screenProgram use];
    glBindVertexArray(OnVAO);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texturepixel);
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    
    
    
    CGSize _size = CGSizeMake(CGRectGetWidth(self.frame), CGRectGetHeight(self.frame));
    
    CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, (void*)[NSDictionary dictionary]);
    CFDictionarySetValue(attrs, kCVPixelBufferOpenGLCompatibilityKey, (void*)[NSNumber numberWithBool:YES]);
    CVPixelBufferCreate(kCFAllocatorDefault, (int)_size.width, (int)_size.height, kCVPixelFormatType_32BGRA, attrs, &_renderTarget);
    NSUInteger totalBytesForImage = (int)_size.width * (int)_size.height * 4;
    // It appears that the width of a texture must be padded out to be a multiple of 8 (32 bytes) if reading from it using a texture cache
    GLubyte *rawImagePixels;
    rawImagePixels = (GLubyte *)malloc(totalBytesForImage);
    glReadPixels(0, 0, (int)_size.width, (int)_size.height, GL_BGRA, GL_UNSIGNED_BYTE, rawImagePixels);
    
    CVPixelBufferLockBaseAddress(_renderTarget, 0);
    uint8_t * bgra = (uint8_t*)CVPixelBufferGetBaseAddress(_renderTarget);
    int bgraStride = (int)CVPixelBufferGetBytesPerRow(_renderTarget);
    if (bgraStride == _size.width * 4) {
       memcpy(bgra, rawImagePixels, bgraStride*_size.height);
    }else{
        for (int i = 0; i < _size.height; i++) {
            for (int j = 0; j < bgraStride; j++) {
                bgra[i * bgraStride + j] = rawImagePixels[i * bgraStride + j];
            }
        }
    }
    CVPixelBufferUnlockBaseAddress(_renderTarget, 0);
    
    NSLog(@"");
}

- (void)renderOffscreenTexture{
    
    [_frameBuffer activateFramebuffer];
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

    glViewport(0, 0, CGRectGetWidth(self.frame), CGRectGetHeight(self.frame));
    glClearColor(0.2f, 0.8f, 0.4f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    [_program use];
    glBindVertexArray(VAO);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D,texture0);
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    glBindVertexArray(0);

    [_screenProgram use];
    glBindVertexArray(wmVAO);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texturewm);
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    glBindVertexArray(0);

    
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(0, 0, CGRectGetWidth(self.frame), CGRectGetHeight(self.frame));
    glClearColor(0.2f, 0.8f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    [_screenProgram use];
    glBindVertexArray(OnVAO);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _frameBuffer.bindTexture);
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
}

- (void)drawRect:(NSRect)dirtyRect {
    
    // Drawing code here.
    CGLLockContext([[self openGLContext] CGLContextObj]);
    [[self openGLContext] makeCurrentContext];
    
//    [self renderPixelBuffer];
    [self renderOffscreenTexture];
    
    [[self openGLContext] flushBuffer];
    CGLUnlockContext([[self openGLContext] CGLContextObj]);
    
//    NSLog(@"pixelbuffer %@",_frameBuffer.pixelBuffer);
}

- (void)setPixelbuffer:(CVPixelBufferRef)pixelbuffer{
    
    if (_pixelbuffer) {
        CVPixelBufferRelease(_pixelbuffer);
    }
    _pixelbuffer = CVPixelBufferRetain(pixelbuffer);
    [self setNeedsDisplay:true];
}

@end
