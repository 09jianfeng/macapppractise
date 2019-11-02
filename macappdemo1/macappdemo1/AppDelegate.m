//
//  AppDelegate.m
//  macappdemo1
//
//  Created by JFChen on 2019/11/1.
//  Copyright © 2019 JFChen. All rights reserved.
//

#import "AppDelegate.h"
#import "MyFirstViewController.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    NSViewController *myvc = [MyFirstViewController new];
    self.window.contentViewController = myvc;
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
