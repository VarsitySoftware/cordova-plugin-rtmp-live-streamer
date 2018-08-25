//
//  RTMPLiveStreamer.h
//  
//
//  Created by John Weaver on 08/25/2018.
//
//

#import <Cordova/CDVPlugin.h>

@interface RTMPLiveStreamer : CDVPlugin < UINavigationControllerDelegate, UIScrollViewDelegate>

@property (copy)   NSString* callbackId;

- (void) launch:(CDVInvokedUrlCommand *)command;

@end
