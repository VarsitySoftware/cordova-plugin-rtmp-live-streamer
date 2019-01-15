//
//  RTMPLiveStreamer.h
//  
//
//  Created by John Weaver on 08/25/2018.
// 
//

#import <Cordova/CDVPlugin.h>
#import <UIKit/UIKit.h>

@interface RTMPLiveStreamer : CDVPlugin < UINavigationControllerDelegate, UIScrollViewDelegate>

- (void) start:(CDVInvokedUrlCommand *)command;
- (void) stop:(CDVInvokedUrlCommand *)command;
- (void) addQuestionsToList:(CDVInvokedUrlCommand *)command;
- (void) updateViewerCount:(CDVInvokedUrlCommand *)command;
- (void) forceQuit:(CDVInvokedUrlCommand *)command;

@property (copy)   NSString* callbackId;

@property (nonatomic, assign) NSInteger videoWidth;
@property (nonatomic, assign) NSInteger videoHeight;
@property (nonatomic, assign) NSInteger videoBitRate;
@property (nonatomic, assign) NSInteger videoMaxBitRate;
@property (nonatomic, assign) NSInteger videoMinBitRate;
@property (nonatomic, assign) NSInteger videoFrameRate;
@property (nonatomic, assign) NSInteger videoMaxKeyframeInterval;
@property (nonatomic, assign) NSInteger videoOrientation;

@property (copy) NSString* rtmpServerURL;
//@property (copy) NSString* buttonTextStart;
//@property (copy) NSString* buttonTextStop;
//@property (copy) NSString* buttonTextWaiting;
//@property (copy) NSString* buttonTextError;

@property (copy) NSString* labelLive;
@property (copy) NSString* labelViewers;
@property (copy) NSString* labelNoQuestions;

@property (copy) NSString* alertStopSessionTitle;
@property (copy) NSString* alertStopSessionYes;
@property (copy) NSString* alertStopSessionNo;
@property (copy) NSString* alertStopSessionMessage;

@property (copy) NSString* alertStartSessionTitle;
@property (copy) NSString* alertStartSessionMessage;
@property (copy) NSString* alertStartSessionOK;

@property (copy) NSString* videoTitleStart;
@property (copy) NSString* videoTitlePaused;
@property (copy) NSString* videoTitleEnd;

@end


