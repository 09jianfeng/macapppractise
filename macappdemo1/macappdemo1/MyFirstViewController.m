//
//  MyFirstViewController.m
//  macappdemo1
//
//  Created by JFChen on 2019/11/1.
//  Copyright © 2019 JFChen. All rights reserved.
//

#import "MyFirstViewController.h"
#import "YYOpenGLView.h"
#import "MGLOpenGLView.h"

@interface MyFirstViewController ()
@property (weak) IBOutlet NSButton *buttonTest1;

@end

@implementation MyFirstViewController{
    MGLOpenGLView *_openGLView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    NSLog(@"my first view controller view did load");
    
    self.view.wantsLayer = YES;
    [_buttonTest1 setImage:[NSImage imageNamed:@"container.jpg"]];
    _buttonTest1.layer.backgroundColor = [NSColor whiteColor].CGColor;
}

- (IBAction)tes1BTNPressed:(id)sender {
    NSLog(@"btn pressed");
    
    _openGLView = [[MGLOpenGLView alloc] initWithFrame:CGRectMake(100, 100, 400, 400)];
    [self.view addSubview:_openGLView];
    [_openGLView setNeedsDisplay:YES];
}

- (void)viewWillAppear{
    [super viewWillAppear];
    
    NSLog(@"%@",NSStringFromRect(self.view.frame));
}

@end
