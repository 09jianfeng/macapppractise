//
//  YYOpenGLView.m
//  macappdemo1
//
//  Created by JFChen on 2019/11/2.
//  Copyright © 2019 JFChen. All rights reserved.
//

#import "YYOpenGLView.h"
#import "MGLProgram.h"
#import "MGLCommon.h"

@implementation YYOpenGLView{
    GLProgram *_program;
    GLProgram *_screenProgram;
    
    GLuint aPos;
    GLuint aTextCoord;
    GLuint acolor;
    GLuint VAO,VBO,EBO;
    GLuint texture0;
    
    GLuint aONPos;
    GLuint aONTextCoord;
    GLuint ONVAO,ONVBO,ONEBO;
    
    unsigned int offscreenTextureId;
    unsigned int offscreenTextureIdLoc;
    unsigned int offscreenBufferId;
}

- (instancetype)init{
    self = [super init];
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
    }
    return self;
}


- (void)prepareOpenGL{
    [super prepareOpenGL];
    [self initGL];
}

- (void)initGL{
    [[self openGLContext] makeCurrentContext];
    GLint swapInt = 1;
    [[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];
    
    [self buildProgram];
    [self setupFramebuffer];
    [self setUpGLBuffers];
    [self setUpTexture];
}

- (void)buildProgram{
    NSString* filePathName = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vs"];
     NSString *vsString = [NSString stringWithContentsOfFile:filePathName encoding:NSUTF8StringEncoding error:nil];
     filePathName = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"frag"];
     NSString *fgString = [NSString stringWithContentsOfFile:filePathName encoding:NSUTF8StringEncoding error:nil];
     _program = [[GLProgram alloc] initWithVertexShaderString:vsString fragmentShaderString:fgString];
    
    if(![_program link]){
        NSLog(@"_program link error %@  fragement log %@  vertext log %@", [_program programLog], [_program fragmentShaderLog], [_program vertexShaderLog]);
        _program = nil;
        NSAssert(NO, @"Falied to link TextureRGBFS shaders");
    }
    aPos = 0;
    aTextCoord = 2;
    acolor = 1;
     
     
     filePathName = [[NSBundle mainBundle] pathForResource:@"screenShader" ofType:@"vs"];
     vsString = [NSString stringWithContentsOfFile:filePathName encoding:NSUTF8StringEncoding error:nil];
     filePathName = [[NSBundle mainBundle] pathForResource:@"screenShader" ofType:@"frag"];
     fgString = [NSString stringWithContentsOfFile:filePathName encoding:NSUTF8StringEncoding error:nil];
     _screenProgram = [[GLProgram alloc] initWithVertexShaderString:vsString fragmentShaderString:fgString];
    //opengl 3.0 在GLSL3.0中，不需要attribute，直接在GLSL中指定location，这样可以直接赋值位置值。addAttribute、getattributeIndex的方式不能再用。
//     [_screenProgram addAttribute:@"aPos"];
//     [_screenProgram addAttribute:@"aTexCoord"];
     if(![_screenProgram link]){
         NSLog(@"_program link error %@  fragement log %@  vertext log %@", [_screenProgram programLog], [_screenProgram fragmentShaderLog], [_screenProgram vertexShaderLog]);
         _screenProgram = nil;
         NSAssert(NO, @"Falied to link TextureRGBFS shaders");
     }
//    aONPos = [_screenProgram attributeIndex:@"aPos"];
//    aONTextCoord = [_screenProgram attributeIndex:@"aTexCoord"];
    aONPos = 0;
    aONTextCoord = 1;
    NSLog(@"aa");
}

- (void)setupFramebuffer{
    { // 设置framebuffer。 并且给framebuffer附加上 纹理。  framebuffer必须附加上纹理或者 renderbuffer。
        // use 1K by 1K texture for shadow map
        unsigned int offscreenTextureWidth = 400;
        unsigned int  offscreenTextureHeight = 400;
        
        glGenTextures ( 1, &offscreenTextureId );
        glBindTexture ( GL_TEXTURE_2D, offscreenTextureId );
        glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
        glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, offscreenTextureWidth, offscreenTextureHeight, 0, GL_RGB, GL_UNSIGNED_BYTE, NULL);
        
        glBindTexture ( GL_TEXTURE_2D, 0 );
        // setup fbo
        glGenFramebuffersEXT ( 1, &offscreenBufferId );
        glBindFramebufferEXT ( GL_FRAMEBUFFER, offscreenBufferId );
        
        glFramebufferTexture2DEXT ( GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, offscreenTextureId, 0 );
        glBindTexture ( GL_TEXTURE_2D, offscreenTextureId );
        
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, offscreenTextureWidth, offscreenTextureHeight);
        //不用深度缓冲区
//        GLuint depthRenderbuffer;
//        glGenRenderbuffers(1, &depthRenderbuffer);
//        glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
//        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);
        
        if ( GL_FRAMEBUFFER_COMPLETE != glCheckFramebufferStatusEXT ( GL_FRAMEBUFFER ) )
        {
            NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        }
        glBindFramebuffer ( GL_FRAMEBUFFER, 0 );
    }
}

- (void)setUpGLBuffers{
    // offsceeen
    {  //生成并且绑定顶点数据。  VAO、VOB、EBO。  这些顶点数据都会被VAO附带。要用的时候不需要在赋值顶点数据、纹理顶点数据。只需要绑定VAO。就是复带上了所需的顶点数据
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
        
        // position attribute
        glVertexAttribPointer(aPos, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)0);
        glEnableVertexAttribArray(aPos);
        
        // color attribute
        glVertexAttribPointer(acolor, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(3 * sizeof(float)));
        glEnableVertexAttribArray(acolor);
        
        // texture coord attribute
        glVertexAttribPointer(aTextCoord, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(6 * sizeof(float)));
        glEnableVertexAttribArray(aTextCoord);
        
        glBindVertexArray(0);
    }
    
    //on screen
    {
        //生成并且绑定顶点数据。  VAO、VOB、EBO。  这些顶点数据都会被VAO附带。要用的时候不需要在赋值顶点数据、纹理顶点数据。只需要绑定VAO。就是复带上了所需的顶点数据
        float vertices[] = {
            // positions          // colors           // texture coords
            0.5f,  0.5f, 0.0f,   1.0f, 0.0f, 0.0f,   1.0f, 1.0f, // top right
            0.5f, -0.5f, 0.0f,   0.0f, 1.0f, 0.0f,   1.0f, 0.0f, // bottom right
            -0.5f, -0.5f, 0.0f,   0.0f, 0.0f, 1.0f,   0.0f, 0.0f, // bottom left
            -0.5f,  0.5f, 0.0f,   1.0f, 1.0f, 0.0f,   0.0f, 1.0f  // top left
        };
        unsigned int indices[] = {
            0, 1, 3, // first triangle
            1, 2, 3  // second triangle
        };
        
        glGenVertexArrays(1, &ONVAO);
        glGenBuffers(1, &ONVBO);
        glGenBuffers(1, &ONEBO);
        glBindVertexArray(ONVAO);
        
        glBindBuffer(GL_ARRAY_BUFFER, ONVBO);
        glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
        
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ONEBO);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
        
        // position attribute
        glVertexAttribPointer(aONPos, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)0);
        glEnableVertexAttribArray(aONPos);
        
        // texture coord attribute
        glVertexAttribPointer(aONTextCoord, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(6 * sizeof(float)));
        glEnableVertexAttribArray(aONTextCoord);
        glBindVertexArray(0);
    }
}

// 生成并且绑定纹理
- (void)setUpTexture{
    glActiveTexture(GL_TEXTURE0);
    glGenTextures(1, &texture0);
    glBindTexture(GL_TEXTURE_2D, texture0);
    // set the texture wrapping parameters
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);    // set texture wrapping to GL_REPEAT (default wrapping method)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    // set texture filtering parameters
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    // load image, create texture and generate mipmaps
    NSImage *image = [NSImage imageNamed:@"container.jpg"];
    MImageData* imageData = mglImageDataFromUIImage(image, YES);
    glTexImage2D(GL_TEXTURE_2D, 0, imageData->format, (GLint)imageData->width, (GLint)imageData->height, 0, imageData->format, imageData->type, imageData->data);
    glGenerateMipmap(GL_TEXTURE_2D);
    
    mglDestroyImageData(imageData);
}

- (void)render{
    int scale = 1;
    int width = CGRectGetWidth(self.frame) * scale;
    int heigh = CGRectGetHeight(self.frame) * scale;
    
    glBindFramebuffer ( GL_FRAMEBUFFER, offscreenBufferId );
    GLint setFrameBufferid = 0;
    glGetIntegerv ( GL_FRAMEBUFFER_BINDING, &setFrameBufferid );
//    glViewport ( 0, 0, (unsigned int)self.glkView.drawableWidth, (unsigned int)self.glkView.drawableHeight);
    glViewport ( 0, 0, width, heigh);
    
    // render
    // ------
    glClearColor(0.2f, 0.8f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // render container
    [_program use];
    glBindVertexArray(VAO);
    //bind 了framebuffer后要记得绑过一次texture0；要跟对应着对应的framebuffer
    glBindTexture ( GL_TEXTURE_2D, texture0);
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    
    
    
    glBindFramebuffer ( GL_FRAMEBUFFER, 0 );
    glViewport ( 0, 0, width, heigh);
    // render
    // ------
    glClearColor(1.0f, 0.2f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    // render container
    [_screenProgram use];
    glBindVertexArray(ONVAO);
    glActiveTexture ( GL_TEXTURE0 );
    glBindTexture ( GL_TEXTURE_2D, offscreenTextureId );
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
}

- (void)drawRect:(NSRect)dirtyRect {
//    [super drawRect:dirtyRect];
    
    // Drawing code here.
    
    CGLLockContext([[self openGLContext] CGLContextObj]);
    [[self openGLContext] makeCurrentContext];
    [self render];
    [[self openGLContext] flushBuffer];
    CGLUnlockContext([[self openGLContext] CGLContextObj]);
}

@end
