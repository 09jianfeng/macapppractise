//
//  YYOpenGLLayer.m
//  macappdemo1
//
//  Created by JFChen on 2019/11/1.
//  Copyright © 2019 JFChen. All rights reserved.
//

#import "YYOpenGLLayer.h"
#import "MGLProgram.h"
#import "MGLCommon.h"

#define STRINGIZE(x) #x
#define SHADER_STRING(text) @ STRINGIZE(text)

static NSString *const TextureRGBVS = SHADER_STRING
(
 attribute vec3 aPos;
 attribute vec2 aTextCoord;
 attribute vec3 acolor;
 
 //纹理坐标，传给片段着色器的
 varying vec2 TexCoord;
 varying vec3 outColor;
 
 void main() {
     gl_Position = vec4(aPos,1.0);
     TexCoord = aTextCoord.xy;
     outColor = acolor.rgb;
 }
 );

static NSString *const TextureRGBFS = SHADER_STRING
(
 //指明精度
 precision mediump float;
 //纹理坐标，从顶点着色器那里传过来
 varying mediump vec2 TexCoord;
 varying mediump vec3 outColor;
 
 //纹理采样器
 uniform sampler2D texture;
 void main() {
     //从纹理texture中采样纹理
     gl_FragColor = texture2D(texture, TexCoord) * vec4(outColor, 1.0);
 }
 );

static NSString *const ScreenTextureRGBVS = SHADER_STRING
(
 attribute vec3 aPos;
 attribute vec2 aTextCoord;
 
 //纹理坐标，传给片段着色器的
 varying vec2 TexCoord;
 
 void main() {
     gl_Position = vec4(aPos,1.0);
     TexCoord = aTextCoord.xy;
 }
 );

static NSString *const ScreenTextureRGBFS = SHADER_STRING
(
 //指明精度
 precision mediump float;
 //纹理坐标，从顶点着色器那里传过来
 varying mediump vec2 TexCoord;
 
 //纹理采样器
 uniform sampler2D texture;
 void main() {
     //从纹理texture中采样纹理
     gl_FragColor = texture2D(texture, TexCoord);
 }
 );



@interface YYOpenGLLayer()
@end

@implementation YYOpenGLLayer{
    GLProgram *_program;
    GLProgram *_screenProgram;
    
    GLuint aPos;
    GLuint aTextCoord;
    GLuint acolor;
    GLuint VAO,VBO,EBO;
    GLuint texture0;
    
    unsigned int offscreenTextureId;
    unsigned int offscreenTextureIdLoc;
    unsigned int offscreenBufferId;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        // Initialization code here.
        [self setNeedsDisplayOnBoundsChange:YES];
        [self setAsynchronous:YES];
        
        self.openGLPixelFormat = [self openGLPixelFormat];
        self.openGLContext = [[NSOpenGLContext alloc] initWithFormat:self.openGLPixelFormat shareContext:nil];
    }
    return self;
}

- (void)setUpGLBuffers{
    {  //生成并且绑定顶点数据。  VAO、VOB、EBO。  这些顶点数据都会被VAO附带。要用的时候不需要在赋值顶点数据、纹理顶点数据。只需要绑定VAO。就是复带上了所需的顶点数据
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

- (void)setupFramebuffer{
    { // 设置framebuffer。 并且给framebuffer附加上 纹理。  framebuffer必须附加上纹理或者 renderbuffer。
        GLint defaultFramebuffer = 0;
        int scale = 1;
        // use 1K by 1K texture for shadow map
        unsigned int offscreenTextureWidth = CGRectGetWidth(self.frame) * scale;
        unsigned int  offscreenTextureHeight = CGRectGetHeight(self.frame) * scale;
        
        glGenTextures ( 1, &offscreenTextureId );
        glBindTexture ( GL_TEXTURE_2D, offscreenTextureId );
        glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
        glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, offscreenTextureWidth, offscreenTextureHeight, 0, GL_RGB, GL_UNSIGNED_BYTE, NULL);
        
        glBindTexture ( GL_TEXTURE_2D, 0 );
        
        glGetIntegerv ( GL_FRAMEBUFFER_BINDING, &defaultFramebuffer );
        // setup fbo
        glGenFramebuffers ( 1, &offscreenBufferId );
        glBindFramebuffer ( GL_FRAMEBUFFER, offscreenBufferId );
        
        glFramebufferTexture2D ( GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, offscreenTextureId, 0 );
        glBindTexture ( GL_TEXTURE_2D, offscreenTextureId );
        
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, offscreenTextureWidth, offscreenTextureHeight);
        //不用深度缓冲区
//        GLuint depthRenderbuffer;
//        glGenRenderbuffers(1, &depthRenderbuffer);
//        glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
//        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);
        
        if ( GL_FRAMEBUFFER_COMPLETE != glCheckFramebufferStatus ( GL_FRAMEBUFFER ) )
        {
            NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        }
        glBindFramebuffer ( GL_FRAMEBUFFER, defaultFramebuffer );
        
    }
}

- (void)buildProgram{
    _program = [[GLProgram alloc] initWithVertexShaderString:TextureRGBVS fragmentShaderString:TextureRGBFS];
    [_program addAttribute:@"aPos"];
    [_program addAttribute:@"aTextCoord"];
    [_program addAttribute:@"acolor"];
    
    if(![_program link]){
        NSLog(@"_program link error %@  fragement log %@  vertext log %@", [_program programLog], [_program fragmentShaderLog], [_program vertexShaderLog]);
        _program = nil;
        NSAssert(NO, @"Falied to link TextureRGBFS shaders");
    }
    
    aPos = [_program attributeIndex:@"aPos"];
    aTextCoord = [_program attributeIndex:@"aTextCoord"];
    acolor = [_program attributeIndex:@"acolor"];
    
    _screenProgram = [[GLProgram alloc] initWithVertexShaderString:ScreenTextureRGBVS fragmentShaderString:ScreenTextureRGBFS];
    [_screenProgram addAttribute:@"aPos"];
    [_screenProgram addAttribute:@"aTextCoord"];
    
    if(![_screenProgram link]){
        NSLog(@"_program link error %@  fragement log %@  vertext log %@", [_screenProgram programLog], [_screenProgram fragmentShaderLog], [_screenProgram vertexShaderLog]);
        _screenProgram = nil;
        NSAssert(NO, @"Falied to link TextureRGBFS shaders");
    }
}


- (void)openGLRender{
    
    [self.openGLContext makeCurrentContext];
    
    demoSource *vtxSource = NULL;
    demoSource *frgSource = NULL;
    
    NSString* filePathName = nil;
    filePathName = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vs"];
    vtxSource = srcLoadSource([filePathName cStringUsingEncoding:NSASCIIStringEncoding]);
    
    filePathName = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"frag"];
    frgSource = srcLoadSource([filePathName cStringUsingEncoding:NSASCIIStringEncoding]);
    
    // Build Program
    [self buildProgramWithVertexSource:vtxSource
                                        withFragmentSource:frgSource];
    
    return;
    
    [self setUpTexture];
    [self setupFramebuffer];
    [self buildProgram];
    [self setUpGLBuffers];
    
    [self setNeedsDisplay];
}

- (NSOpenGLPixelFormat *)openGLPixelFormatForDisplayMask:(uint32_t)mask
{
    NSOpenGLPixelFormatAttribute attrs[] = {
        // Specifying "NoRecovery" gives us a context that cannot fall back to the software renderer.  This makes the View-based context a compatible with the layer-backed context, enabling us to use the "shareContext" feature to share textures, display lists, and other OpenGL objects between the two.
        NSOpenGLPFANoRecovery, // Enable automatic use of OpenGL "share" contexts.
        NSOpenGLPFAColorSize, 24,
        NSOpenGLPFAAlphaSize, 8,
        NSOpenGLPFADepthSize, 16,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAScreenMask,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFAOpenGLProfile,
        NSOpenGLProfileVersionLegacy,
        // If you want OpenGL 3.2 support replace NSOpenGLProfileVersionLegacy with
        // NSOpenGLProfileVersion3_2Core,
        0
    };
    
    NSOpenGLPixelFormat* pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
    
    return pixelFormat;
}

- (BOOL)canDrawInOpenGLContext:(NSOpenGLContext *)context pixelFormat:(NSOpenGLPixelFormat *)pixelFormat forLayerTime:(CFTimeInterval)timeInterval displayTime:(const CVTimeStamp *)timeStamp
{
    return YES;
}

- (void)drawInOpenGLContext:(NSOpenGLContext *)context pixelFormat:(NSOpenGLPixelFormat *)pixelFormat forLayerTime:(CFTimeInterval)t displayTime:(const CVTimeStamp *)ts{
    
    int scale = 1;
    int width = CGRectGetWidth(self.frame) * scale;
    int heigh = CGRectGetHeight(self.frame) * scale;
    
    GLint defaultFramebuffer = 0;
    glGetIntegerv ( GL_FRAMEBUFFER_BINDING, &defaultFramebuffer );
    
    glBindFramebuffer ( GL_FRAMEBUFFER, offscreenBufferId );
    GLint setFrameBufferid = 0;
    glGetIntegerv ( GL_FRAMEBUFFER_BINDING, &setFrameBufferid );
//    glViewport ( 0, 0, (unsigned int)self.glkView.drawableWidth, (unsigned int)self.glkView.drawableHeight);
    glViewport ( 0, 0, width, heigh);
    
    // render
    // ------
    glClearColor(0.2f, 0.3f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // render container
    [_program use];
    glBindVertexArray(VAO);
    //bind 了framebuffer后要记得绑过一次texture0；要跟对应着对应的framebuffer
    glBindTexture ( GL_TEXTURE_2D, texture0);
    
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    
    
    
    
    
    
    
    glBindFramebuffer ( GL_FRAMEBUFFER, defaultFramebuffer );
    glViewport ( 0, 0, width, heigh);
    
    // render
    // ------
    glClearColor(1.0f, 1.0f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    // render container
    [_screenProgram use];
    glBindVertexArray(VAO);
    glActiveTexture ( GL_TEXTURE0 );
    glBindTexture ( GL_TEXTURE_2D, offscreenTextureId );
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
}



-(GLuint) buildProgramWithVertexSource:(demoSource*)vertexSource
                    withFragmentSource:(demoSource*)fragmentSource
{
    GLuint prgName;
    
    GLint logLength, status;
    
    // String to pass to glShaderSource
    GLchar* sourceString = NULL;
    
    // Determine if GLSL version 140 is supported by this context.
    //  We'll use this info to generate a GLSL shader source string
    //  with the proper version preprocessor string prepended
    float  glLanguageVersion;
    
#if TARGET_IOS
    sscanf((char *)glGetString(GL_SHADING_LANGUAGE_VERSION), "OpenGL ES GLSL ES %f", &glLanguageVersion);
#else
//    char *version = (char *)glGetString(GL_SHADING_LANGUAGE_VERSION);
//    sscanf(version, "%f", &glLanguageVersion);
#endif
    
    // Get the size of the version preprocessor string info so we know
    //  how much memory to allocate for our sourceString
    
    // Create a program object
    prgName = glCreateProgram();
    
    
    //////////////////////////////////////
    // Specify and compile VertexShader //
    //////////////////////////////////////
    
    
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, (const GLchar **)&(vertexSource->string), NULL);
    glCompileShader(vertexShader);
    glGetShaderiv(vertexShader, GL_INFO_LOG_LENGTH, &logLength);
    
    if (logLength > 0)
    {
        GLchar *log = (GLchar*) malloc(logLength);
        glGetShaderInfoLog(vertexShader, logLength, &logLength, log);
        NSLog(@"Vtx Shader compile log:%s\n", log);
        free(log);
    }
    
    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &status);
    if (status == 0)
    {
        NSLog(@"Failed to compile vtx shader:\n%s\n", sourceString);
        return 0;
    }
    
    free(sourceString);
    sourceString = NULL;
    
    // Attach the vertex shader to our program
    glAttachShader(prgName, vertexShader);
    
    // Delete the vertex shader since it is now attached
    // to the program, which will retain a reference to it
    glDeleteShader(vertexShader);
    
    /////////////////////////////////////////
    // Specify and compile Fragment Shader //
    /////////////////////////////////////////
    
    GLuint fragShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragShader, 1, (const GLchar **)&(fragmentSource->string), NULL);
    glCompileShader(fragShader);
    glGetShaderiv(fragShader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar*)malloc(logLength);
        glGetShaderInfoLog(fragShader, logLength, &logLength, log);
        NSLog(@"Frag Shader compile log:\n%s\n", log);
        free(log);
    }
    
    glGetShaderiv(fragShader, GL_COMPILE_STATUS, &status);
    if (status == 0)
    {
        NSLog(@"Failed to compile frag shader:\n%s\n", sourceString);
        return 0;
    }
    
    free(sourceString);
    sourceString = NULL;
    
    // Attach the fragment shader to our program
    glAttachShader(prgName, fragShader);
    
    // Delete the fragment shader since it is now attached
    // to the program, which will retain a reference to it
    glDeleteShader(fragShader);
    
    //////////////////////
    // Link the program //
    //////////////////////
    
    glLinkProgram(prgName);
    glGetProgramiv(prgName, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar*)malloc(logLength);
        glGetProgramInfoLog(prgName, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s\n", log);
        free(log);
    }
    
    glGetProgramiv(prgName, GL_LINK_STATUS, &status);
    if (status == 0)
    {
        NSLog(@"Failed to link program");
        return 0;
    }
    
    glValidateProgram(prgName);
    
    glGetProgramiv(prgName, GL_VALIDATE_STATUS, &status);
    if (status == 0)
    {
        // 'status' set to 0 here does NOT indicate the program itself is invalid,
        //   but rather the state OpenGL was set to when glValidateProgram was called was
        //   not valid for this program to run (i.e. Given the CURRENT openGL state,
        //   draw call with this program will fail).  You may still be able to use this
        //   program if certain OpenGL state is set before a draw is made.  For instance,
        //   'status' could be 0 because no VAO was bound and so long as one is bound
        //   before drawing with this program, it will not be an issue.
        NSLog(@"Program cannot run with current OpenGL State");
    }
    
    glGetProgramiv(prgName, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar*)malloc(logLength);
        glGetProgramInfoLog(prgName, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s\n", log);
        free(log);
    }
    
    glUseProgram(prgName);
    
    GetGLError();
    
    return prgName;
    
}

@end
