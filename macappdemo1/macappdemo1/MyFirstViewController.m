//
//  MyFirstViewController.m
//  macappdemo1
//
//  Created by JFChen on 2019/11/1.
//  Copyright © 2019 JFChen. All rights reserved.
//

#import "MyFirstViewController.h"
#import "YYOpenGLLayer.h"
#import "YYOpenGLView.h"

@interface MyFirstViewController ()
@property (weak) IBOutlet NSButton *buttonTest1;

@end

@implementation MyFirstViewController{
//    YYOpenGLLayer *_glLayer;
    YYOpenGLView *_openGLView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    NSLog(@"my first view controller view did load");
    
//    _glLayer = [[YYOpenGLLayer alloc] init];
//    _glLayer.backgroundColor = [NSColor blueColor].CGColor;
//    [self.view.layer addSublayer:_glLayer];
//    self.view.layer.backgroundColor = [NSColor blueColor].CGColor;
    
    self.view.wantsLayer = YES;
    
    _openGLView = [[YYOpenGLView alloc] init];
    _openGLView.frame = CGRectMake(100, 100, 400, 400);
    [self.view addSubview:_openGLView];
    
    [_buttonTest1 setImage:[NSImage imageNamed:@"container.jpg"]];
    _buttonTest1.layer.backgroundColor = [NSColor whiteColor].CGColor;
}

- (IBAction)tes1BTNPressed:(id)sender {
    NSLog(@"btn pressed");
    
//    [_glLayer openGLRender];
    [_openGLView setNeedsDisplay:YES];
}

- (void)viewWillAppear{
    [super viewWillAppear];
    
//    _glLayer.frame = self.view.bounds;
    NSLog(@"%@",NSStringFromRect(self.view.frame));
}

@end
