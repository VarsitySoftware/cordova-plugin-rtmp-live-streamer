//
//  RTMPLiveStreamer.m
//
//  Created by John Weaver on 08/25/18
//
//

#import "RTMPLiveStreamer.h"

@implementation RTMPLiveStreamer 

@synthesize callbackId;

- (void) launch:(CDVInvokedUrlCommand *)command {
    
    NSDictionary *options = [command.arguments objectAtIndex: 0];
  
    self.callbackId = command.callbackId;

    NSLog(@"ALERT: Launching Live Streamer!");
}

@end
