//
//  RTMPLiveStreamer.m
//
//  Created by John Weaver on 08/25/18
//
//

#import "RTMPLiveStreamer.h"
//#import "LFLivePreview.h"
#import "UIControl+YYAdd.h"
#import "UIView+YYAdd.h"
#import "LFLiveKit.h"


#define VIDEO_WIDTH 720
#define VIDEO_HEIGHT 1280
#define VIDEO_BITRATE 800*1024
#define VIDEO_MAX_BITRATE 1000*1024
#define VIDEO_MIN_BITRATE 500*1024
#define VIDEO_FRAMERATE 24
#define VIDEO_MAX_KEYFRAME_INTERVAL 48
#define VIDEO_ORIENTATION 1

//#define BUTTON_TEXT_START @"START STREAM"
//#define BUTTON_TEXT_STOP @"STOP STREAM"
//#define BUTTON_TEXT_WAITING @"WAITING" 
//#define BUTTON_TEXT_ERROR @"ERROR"

#define LABEL_LIVE @"LIVE"
#define LABEL_VIEWERS @"VIEWERS: 0"
#define LABEL_NO_QUESTIONS @"NO QUESTIONS HAVE BEEN ASKED YET"

#define ALERT_STOP_SESSION_TITLE @"ALERT"
#define ALERT_STOP_SESSION_YES @"YES"
#define ALERT_STOP_SESSION_NO @"NO"
#define ALERT_STOP_SESSION_MESSAGE @"Are you sure you want to stop the session?"

#define ALERT_START_SESSION_TITLE @"ALERT"
#define ALERT_START_SESSION_OK @"OK"
#define ALERT_START_SESSION_MESSAGE @"Please press the red start button when you are ready to start broadcasting."

#define VIDEO_TITLE_START @"WAITING FOR LIVESTREAM TO BEGIN"
#define VIDEO_TITLE_PAUSED @"LIVESTREAM HAS BEEN PAUSED"
#define VIDEO_TITLE_END @"LIVESTREAM HAS ENDED"

static BOOL blinkStatus = FALSE;
static BOOL isStreaming = FALSE;
static BOOL isMuted = NO;

NSTimer *blinkTimer;
NSTimer *recordingTimer;
int recordingTime;


inline static NSString *formatedSpeed(float bytes, float elapsed_milli) 
{
    if (elapsed_milli <= 0) {
        return @"N/A";
    }

    if (bytes <= 0) {
        return @"0 KB/s";
    }

    float bytes_per_sec = ((float)bytes) * 1000.f /  elapsed_milli;
    if (bytes_per_sec >= 1000 * 1000) {
        return [NSString stringWithFormat:@"%.2f MB/s", ((float)bytes_per_sec) / 1000 / 1000];
    } else if (bytes_per_sec >= 1000) {
        return [NSString stringWithFormat:@"%.1f KB/s", ((float)bytes_per_sec) / 1000];
    } else {
        return [NSString stringWithFormat:@"%ld B/s", (long)bytes_per_sec];
    }
}

@interface RTMPLiveStreamer()<LFLiveSessionDelegate>

@property (nonatomic, strong) UIButton *micButton;
@property (nonatomic, strong) UIButton *beautyButton;
@property (nonatomic, strong) UIButton *cameraButton;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIButton *startLiveButton;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) LFLiveDebug *debugInfo;
@property (nonatomic, strong) LFLiveSession *session;
@property (nonatomic, strong) UILabel *stateLabel;
@property (nonatomic, strong) UILabel *viewersLabel;
//@property (nonatomic, strong) UILabel *viewersCount;

@property (nonatomic, strong) UILabel *circleLabel;
@property (nonatomic, strong) UILabel *recordingTimeLabel;
@property (nonatomic, strong) UILabel *noQuestionsLabel;

@property (nonatomic, retain) UIView * mainView;
@property (nonatomic, retain) UIScrollView * scrollView;
@property (nonatomic, strong) UIView *slideView;

@property (nonatomic, strong) UIView *viewersView;

@property (nonatomic, assign) int slideCount;

@end

@implementation RTMPLiveStreamer 

@synthesize callbackId;

- (void) start:(CDVInvokedUrlCommand *)command {
    
	NSLog(@"Starting RTMP Live Streamer!");

    NSDictionary *options = [command.arguments objectAtIndex: 0];
  
	NSInteger intVideoWidth = [[options objectForKey:@"videoWidth"] integerValue];
	NSInteger intVideoHeight = [[options objectForKey:@"videoHeight"] integerValue];
	NSInteger intVideoBitRate = [[options objectForKey:@"videoBitRate"] integerValue];
	NSInteger intVideoMaxBitRate = [[options objectForKey:@"videoMaxBitRate"] integerValue];
	NSInteger intVideoMinBitRate = [[options objectForKey:@"videoMinBitRate"] integerValue];
	NSInteger intVideoFrameRate = [[options objectForKey:@"videoFrameRate"] integerValue];
	NSInteger intVideoOrientation = [[options objectForKey:@"videoOrientation"] integerValue];
	NSInteger intVideoMaxKeyFrameInterval = [[options objectForKey:@"videoMaxKeyframeInterval"] integerValue];

	NSString* strRTMPServerURL = [options objectForKey:@"rtmpServerURL"];
	NSString* strLabelLive = [options objectForKey:@"labelLive"];
	NSString* strLabelViewers = [options objectForKey:@"labelViewers"];
	NSString* strLabelNoQuestions = [options objectForKey:@"labelNoQuestions"];

	//NSString* strButtonTextStart = [options objectForKey:@"buttonTextStart"];
	//NSString* strButtonTextStop = [options objectForKey:@"buttonTextStop"];
	//NSString* strButtonTextWaiting = [options objectForKey:@"buttonTextWaiting"];
	//NSString* strButtonTextError = [options objectForKey:@"buttonTextError"];	

	NSString* strAlertStopSessionTitle = [options objectForKey:@"alertStopSessionTitle"];	
	NSString* strAlertStopSessionYes = [options objectForKey:@"alertStopSessionYes"];	
	NSString* strAlertStopSessionNo = [options objectForKey:@"alertStopSessionNo"];	
	NSString* strAlertStopSessionMessage = [options objectForKey:@"alertStopSessionMessage"];	

	NSString* strAlertStartSessionTitle = [options objectForKey:@"alertStartSessionTitle"];	
	NSString* strAlertStartSessionOK = [options objectForKey:@"alertStartSessionOK"];	
	NSString* strAlertStartSessionMessage = [options objectForKey:@"alertStartSessionMessage"];	
	
	NSString* strVideoTitleStart = [options objectForKey:@"videoTitleStart"];	
	NSString* strVideoTitlePaused = [options objectForKey:@"videoTitlePaused"];	
	NSString* strVideoTitleEnd = [options objectForKey:@"videoTitleEnd"];	

	self.videoWidth = VIDEO_WIDTH;
	self.videoHeight = VIDEO_HEIGHT;
	self.videoBitRate = VIDEO_BITRATE;
	self.videoMaxBitRate = VIDEO_MAX_BITRATE;
	self.videoMinBitRate = VIDEO_MIN_BITRATE;
	self.videoFrameRate = VIDEO_FRAMERATE;
	self.videoMaxKeyframeInterval = VIDEO_MAX_KEYFRAME_INTERVAL;
	self.videoOrientation = VIDEO_ORIENTATION;

	self.labelLive = LABEL_LIVE;
	self.labelViewers = LABEL_VIEWERS;
	self.labelNoQuestions = LABEL_NO_QUESTIONS;

	//self.buttonTextStart = BUTTON_TEXT_START;
	//self.buttonTextStop = BUTTON_TEXT_STOP;
	//self.buttonTextWaiting = BUTTON_TEXT_WAITING;
	//self.buttonTextError = BUTTON_TEXT_ERROR;

	self.alertStopSessionTitle = ALERT_STOP_SESSION_TITLE;
	self.alertStopSessionYes = ALERT_STOP_SESSION_YES;
	self.alertStopSessionNo = ALERT_STOP_SESSION_NO;
	self.alertStopSessionMessage = ALERT_STOP_SESSION_MESSAGE;

	self.alertStartSessionTitle = ALERT_START_SESSION_TITLE;
	self.alertStartSessionOK = ALERT_START_SESSION_OK;
	self.alertStartSessionMessage = ALERT_START_SESSION_MESSAGE;

	self.videoTitleStart = VIDEO_TITLE_START;
	self.videoTitlePaused = VIDEO_TITLE_PAUSED;
	self.videoTitleEnd = VIDEO_TITLE_END;

	if (intVideoWidth > 0)
	{
		self.videoWidth = intVideoWidth;
	}
	if (intVideoHeight > 0)
	{
		self.videoHeight = intVideoHeight;
	}
	if (intVideoBitRate > 0)
	{
		self.videoBitRate = intVideoBitRate;
	}
	if (intVideoMaxBitRate > 0)
	{
		self.videoMaxBitRate = intVideoMaxBitRate;
	}
	if (intVideoMinBitRate > 0)
	{
		self.videoMinBitRate = intVideoMinBitRate;
	}
	if (intVideoFrameRate > 0)
	{
		self.videoFrameRate = intVideoFrameRate;
	}
	if (intVideoMaxKeyFrameInterval > 0)
	{
		self.videoMaxKeyframeInterval = intVideoMaxKeyFrameInterval;
	}
	if (intVideoOrientation > 0)
	{
		self.videoOrientation = intVideoOrientation;
	}

	if (strRTMPServerURL)
	{
		self.rtmpServerURL = strRTMPServerURL;
	}
	if (strLabelLive)
	{
		self.labelLive = strLabelLive;
	}
	if (strLabelViewers)
	{
		self.labelViewers = strLabelViewers;
	}
	if (strLabelNoQuestions)
	{
		self.labelNoQuestions = strLabelNoQuestions;
	}
	
	if (strAlertStopSessionTitle)
	{
		self.alertStopSessionTitle = strAlertStopSessionTitle;
	}
	if (strAlertStopSessionYes)
	{
		self.alertStopSessionYes = strAlertStopSessionYes;
	}
	if (strAlertStopSessionNo)
	{
		self.alertStopSessionNo = strAlertStopSessionNo;
	}
	if (strAlertStopSessionMessage)
	{
		self.alertStopSessionMessage = strAlertStopSessionMessage;
	}

	if (strAlertStartSessionTitle)
	{
		self.alertStartSessionTitle = strAlertStartSessionTitle;
	}
	if (strAlertStartSessionOK)
	{
		self.alertStartSessionOK = strAlertStartSessionOK;
	}
	if (strAlertStartSessionMessage)
	{
		self.alertStartSessionMessage = strAlertStartSessionMessage;
	}

	if (strVideoTitleStart)
	{
		self.videoTitleStart = strVideoTitleStart;
	}
	if (strVideoTitlePaused)
	{
		self.videoTitlePaused = strVideoTitlePaused;
	}
	if (strVideoTitleEnd)
	{
		self.videoTitleEnd = strVideoTitleEnd;
	}

    self.callbackId = command.callbackId;

	self.slideCount = 0;
	[self initWithFrame:self.viewController.view.bounds];
	
	[self recordingTimerStart];
	
	LFLiveStreamInfo *stream = [LFLiveStreamInfo new];
	stream.url = self.rtmpServerURL;
	[self.session setMuted:YES];
	[self.session setVideoState:1]; //SESSION JUST STARTED, WAITING FOR VIDEO BROADCAST TO BEGIN
	[self.session startLive:stream];

	[self showVideoStartAlert];

	//NSLog(@"ADDED SUBVIEW!!");
}

- (void) stop:(CDVInvokedUrlCommand *)command 
{
	NSLog(@"STOPPING!!");

	CDVPluginResult* pluginResult = nil;
	pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"STOPPED"];

	[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) updateViewerCount:(CDVInvokedUrlCommand *)command 
{
	NSLog(@"UPDATE VIEWERS LABEL!!");

	NSDictionary *options = [command.arguments objectAtIndex: 0];

	NSString* strViewersLabel = [options objectForKey:@"viewersLabel"];

	if (strViewersLabel)
	{
		self.viewersLabel.text = strViewersLabel;
	}
  
}

- (void) addQuestionsToList:(CDVInvokedUrlCommand *)command 
{
	NSLog(@"ADDING QUESTIONS TO LIST!!");

	NSDictionary *options = [command.arguments objectAtIndex: 0];
  
	NSArray* arrQuestions = [options objectForKey:@"questions"];

	if (arrQuestions)
	{
		for (id objQuestions in arrQuestions) 
		{
			self.noQuestionsLabel.hidden = YES;

			NSDictionary *dicQuestion = objQuestions;
			NSString *strImageURL = [dicQuestion objectForKey:@"image_url"];
			NSString *strFrom  = [dicQuestion objectForKey:@"from"];
			NSString *strQuestion = [dicQuestion objectForKey:@"question"];

			NSMutableString *strQuestionWithIndex = [[NSMutableString alloc] initWithString:strQuestion];
			[strQuestionWithIndex insertString:@". " atIndex:0];
			[strQuestionWithIndex insertString: [NSString stringWithFormat:@"%d", self.slideCount + 1] atIndex:0];
			
			NSLog(@"image url: %@", strImageURL);
			NSLog(@"from: %@", strFrom);
			NSLog(@"question: %@", strQuestion);

			[self.scrollView addSubview:[self slideView:strFrom question:strQuestionWithIndex imageURL:strImageURL]];
		}
	}

	CDVPluginResult* pluginResult = nil;
	pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"ADD_MESSAGE"];

	[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

	//[self.scrollView addSubview:self.slideView];

}

- (void)initWithFrame:(CGRect)frame {
	
	recordingTime = 0;
	self.session = NULL;

	self.mainView = [[UIView alloc] initWithFrame:frame];
	self.mainView.backgroundColor = [UIColor clearColor];

	[self requestAccessForVideo];
    [self requestAccessForAudio];

    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0,self.viewController.view.bounds.size.height - 120,self.viewController.view.bounds.size.width, 100)];
    self.scrollView.backgroundColor = [UIColor colorWithHue:(1.0) saturation:(1.0) brightness:(0) alpha:(CGFloat)0.5];
    //self.scrollView.contentSize = CGSizeMake(self.viewController.view.bounds.size.width * (self.slideCount + 1), self.viewController.view.bounds.size.height - 575);
    self.scrollView.showsVerticalScrollIndicator = YES;
    self.scrollView.showsHorizontalScrollIndicator = YES;
    self.scrollView.pagingEnabled = YES;

	self.noQuestionsLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, 30, self.viewController.view.bounds.size.width, 30)];
	//lblFrom.text = @"Steven (5 mins ago)";
	self.noQuestionsLabel.text = self.labelNoQuestions;
	//self.noQuestionsLabel.font = [UIFont systemFontOfSize:14];
	self.noQuestionsLabel.font = [UIFont boldSystemFontOfSize:14.f];
	self.noQuestionsLabel.textColor = [UIColor whiteColor];
    self.noQuestionsLabel.textAlignment = NSTextAlignmentCenter;	
	
	[self.scrollView addSubview:self.noQuestionsLabel];

	//[self.scrollView addSubview:self.slideView];
	//self.slideCount = 1;
	//[self.scrollView addSubview:self.slideView];

	[self.mainView addSubview:self.containerView];
	[self.containerView addSubview:self.stateLabel];
	[self.containerView addSubview:self.viewersView];
    [self.containerView addSubview:self.closeButton];
    [self.containerView addSubview:self.cameraButton];
    [self.containerView addSubview:self.beautyButton];
	[self.containerView addSubview:self.micButton];
    [self.containerView addSubview:self.startLiveButton];
    [self.containerView addSubview:self.circleLabel];
	[self.containerView addSubview:self.recordingTimeLabel];

    [self.mainView addSubview:self.scrollView];
    

	[self.viewController.view addSubview:self.mainView];

	//NSTimer *yourtimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)(20.0 / 60.0)  target:self selector:@selector(blink) userInfo:nil repeats:TRUE];
    blinkStatus = FALSE;	
	

}

- (UIView *)slideView:(NSString*)strFrom question:(NSString*)strQuestion imageURL:(NSString*)strImageURL {
	
	self.scrollView.contentSize = CGSizeMake(self.viewController.view.bounds.size.width * (self.slideCount + 1), self.viewController.view.bounds.size.height - 575);
    //self.scrollView.contentOffset = CGPointMake(self.viewController.view.bounds.size.width * (self.slideCount),0);

	// ONLY DO ANIMATED OFFSET TO LATEST SLIDE IF ALREADY ON LAST SLIDE!
	CGFloat xOffset = self.scrollView.contentOffset.x;
	if (xOffset == self.viewController.view.bounds.size.width * (self.slideCount - 1))
	{
		[self.scrollView setContentOffset:CGPointMake(self.viewController.view.bounds.size.width * (self.slideCount),0) animated:YES];
	}

	//CGRect newFrame = self.scrollView.frame;

	//newFrame.size.width = self.viewController.view.bounds.size.width * (self.slideCount + 1);
	//newFrame.size.height = newFrame.size.width + 200;
	//[self.scrollView setFrame:newFrame];

	UILabel *lblFrom = [[UILabel alloc]initWithFrame:CGRectMake(55, 0, 300, 30)];
	//lblFrom.text = @"Steven (5 mins ago)";
	lblFrom.text = strFrom;
	lblFrom.font = [UIFont systemFontOfSize:14];
	lblFrom.textColor = [UIColor whiteColor];

	UILabel *lblMessage = [[UILabel alloc]initWithFrame:CGRectMake(55, 24, 300, 70)];
	//lblMessage.text = @"Is our existence just a product of a sequence of random events or is this all meant to be?";	
	lblMessage.text = strQuestion;	
	[lblMessage setFont:[UIFont fontWithName:@"Arial-BoldMT" size:16]];
    lblMessage.textColor = [UIColor whiteColor];
	//lblMessage.numberOfLines = 3;
	lblMessage.numberOfLines = 0;
	[lblMessage sizeToFit];

	//NSString* imgURL =  @"https://png.icons8.com/color/1600/avatar.png";

	UIImageView *imgV = [[UIImageView alloc]initWithFrame:CGRectMake(0, 5, 50, 50)];
	imgV.layer.cornerRadius = 50.0;
	imgV.layer.masksToBounds = YES;
	//imgV.backgroundColor = [UIColor clearColor];
	imgV.backgroundColor = [UIColor colorWithHue:(1.0) saturation:(1.0) brightness:(0) alpha:(CGFloat)0.5];

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            //NSURL *url = [NSURL URLWithString:imgURL];
			NSURL *url = [NSURL URLWithString:strImageURL];
            NSData *data = [NSData dataWithContentsOfURL:url];
            UIImage* image = [[UIImage alloc]initWithData:data];
			//NSLog(@"GET IMAGE!");
			
            dispatch_async(dispatch_get_main_queue(), ^{
                [imgV setImage:image];
				//NSLog(@"SET IMAGE!");
            });
        });

	UIView * slideView = [[UIView alloc] initWithFrame:CGRectMake(self.viewController.view.bounds.size.width * (self.slideCount), 0, self.viewController.view.bounds.size.width, 200)];
	[slideView addSubview:lblMessage];
    [slideView addSubview:lblFrom];
	[slideView addSubview:imgV];	

	self.slideCount += 1;

	return slideView;

}


#pragma mark -- Public Method
- (void)requestAccessForVideo {
    __weak typeof(self) _self = self;
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (status) {
    case AVAuthorizationStatusNotDetermined: 
	{        
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if (granted) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [_self.session setRunning:YES];
                    });
                }
            }];
        break;
    }
    case AVAuthorizationStatusAuthorized: 
	{        
        dispatch_async(dispatch_get_main_queue(), ^{
            [_self.session setRunning:YES];
        });
        break;
    }
    case AVAuthorizationStatusDenied:
    case AVAuthorizationStatusRestricted:        
        break;
    default:
        break;
    }
}

- (void)requestAccessForAudio {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    switch (status) {
    case AVAuthorizationStatusNotDetermined: {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
            }];
        break;
    }
    case AVAuthorizationStatusAuthorized: {
        break;
    }
    case AVAuthorizationStatusDenied:
    case AVAuthorizationStatusRestricted:
        break;
    default:
        break;
    }
}

#pragma mark -- LFStreamingSessionDelegate
/** live status changed will callback */
- (void)liveSession:(nullable LFLiveSession *)session liveStateDidChange:(LFLiveState)state {
    NSLog(@"liveStateDidChange: %ld", state);
    switch (state) {
    case LFLiveReady:
        //_stateLabel.text = @"ready";
		//_stateLabel.text = @"";
        break;
    case LFLivePending:
        //_stateLabel.text = @"pending";
        break;
    case LFLiveStart:
        //_stateLabel.text = @"start";
        break;
    case LFLiveError:
        //_stateLabel.text = @"error";
        break;
    case LFLiveStop:
        //_stateLabel.text = @"stop";
        break;
    default:
        break;
    }
}

/** live debug info callback */
- (void)liveSession:(nullable LFLiveSession *)session debugInfo:(nullable LFLiveDebug *)debugInfo {
    NSLog(@"debugInfo uploadSpeed: %@", formatedSpeed(debugInfo.currentBandwidth, debugInfo.elapsedMilli));
}

/** callback socket errorcode */
- (void)liveSession:(nullable LFLiveSession *)session errorCode:(LFLiveSocketErrorCode)errorCode {
    NSLog(@"errorCode: %ld", errorCode);
}

#pragma mark -- Getter Setter
- (LFLiveSession *)session {
    if (!_session) {
       
	   //NSLog(@"SETTING SESSION!");

        /***  †?????368 ? 640  ???44.1 iphone6??48  ???  ???? ***/
        LFLiveVideoConfiguration *videoConfiguration = [LFLiveVideoConfiguration new];

        videoConfiguration.videoSize = CGSizeMake(self.videoWidth, self.videoHeight);
        videoConfiguration.videoBitRate = self.videoBitRate;
        videoConfiguration.videoMaxBitRate = self.videoMaxBitRate;
        videoConfiguration.videoMinBitRate = self.videoMinBitRate;
        videoConfiguration.videoFrameRate = self.videoFrameRate;
        videoConfiguration.videoMaxKeyframeInterval = self.videoMaxKeyframeInterval;
        //videoConfiguration.outputImageOrientation = UIInterfaceOrientationLandscapeLeft;

		if (self.videoOrientation == 2) // LANDSCAPE
		{
			videoConfiguration.outputImageOrientation = UIInterfaceOrientationLandscapeLeft;
		}
		else
		{
			videoConfiguration.outputImageOrientation = UIInterfaceOrientationPortrait;
		}

		//videoConfiguration.outputImageOrientation = UIInterfaceOrientationPortrait;
        videoConfiguration.autorotate = NO;

		//videoConfiguration.videoTitleStart = @"WAITING FOR LIVESTREAM TO BEGIN";
		//videoConfiguration.videoTitlePaused = @"LIVESTREAM HAS BEEN PAUSED";
		//videoConfiguration.videoTitleEnd = @"LIVESTREAM HAS ENDED";

		videoConfiguration.videoTitleStart = self.videoTitleStart;
		videoConfiguration.videoTitlePaused = self.videoTitlePaused;
		videoConfiguration.videoTitleEnd = self.videoTitleEnd;
		
        //videoConfiguration.sessionPreset = LFCaptureSessionPreset720x1280;

		//OPTIONS
		//videoConfiguration.sessionPreset = LFCaptureSessionPreset360x640;
		//videoConfiguration.sessionPreset = LFCaptureSessionPreset540x960;
		//videoConfiguration.sessionPreset = LFCaptureSessionPreset720x1280;
		//videoConfiguration.sessionPreset = AVCaptureSessionPreset640x480;
		
        _session = [[LFLiveSession alloc] initWithAudioConfiguration:[LFLiveAudioConfiguration defaultConfiguration] videoConfiguration:videoConfiguration captureType:LFLiveCaptureDefaultMask];


		_session.delegate = self.mainView;        
        _session.preView = self.mainView; 
		_session.showDebugInfo = YES;

		//_session.videoWidth = (int)self.videoWidth;
		//_session.videoHeight = (int)self.videoHeight;

		//[_session setVideoSize];
    }
    return _session;
}

- (UIView *)containerView {
    if (!_containerView) {
        _containerView = [UIView new];
        //_containerView.frame = self.bounds;
		_containerView.frame = self.mainView.bounds;
        _containerView.backgroundColor = [UIColor clearColor];
        _containerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return _containerView;
}

- (UILabel *)stateLabel {
    if (!_stateLabel) {
        _stateLabel = [[UILabel alloc] initWithFrame:CGRectMake(100, 20, 120, 40)];
        //_stateLabel.text = @"READY";
		_stateLabel.text = @"";
        _stateLabel.textColor = [UIColor whiteColor];
        _stateLabel.font = [UIFont boldSystemFontOfSize:14.f];
    }
    return _stateLabel;
}

- (UIView *)viewersView{
	
	UIView * viewersView = [[UIView alloc] initWithFrame:CGRectMake(0, self.viewController.view.bounds.size.height - 30, self.viewController.view.bounds.size.width, 30)];
	viewersView.backgroundColor = [UIColor blackColor];

	self.viewersLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, self.viewController.view.bounds.size.width, 30)];
	//lblFrom.text = @"Steven (5 mins ago)";
	self.viewersLabel.text = self.labelViewers;
	self.viewersLabel.textColor = [UIColor whiteColor];
	self.viewersLabel.font = [UIFont systemFontOfSize:14];
	self.viewersLabel.textAlignment = NSTextAlignmentCenter;	
	
	[viewersView addSubview:self.viewersLabel];    
	
	return viewersView;

}


- (UILabel *)recordingTimeLabel {
    if (!_recordingTimeLabel) {
        _recordingTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 20, 120, 40)]; 
        _recordingTimeLabel.text = @"00:00:00";
        _recordingTimeLabel.textColor = [UIColor whiteColor];
        _recordingTimeLabel.font = [UIFont boldSystemFontOfSize:14.f];
    }
    return _recordingTimeLabel;
}

- (UILabel *)circleLabel {
    if (!_circleLabel) {
        _circleLabel = [[UILabel alloc] initWithFrame:CGRectMake(80, 30, 18, 18)];
        //_circleLabel.text = @"READY";
        _circleLabel.textColor = [UIColor redColor];
		_circleLabel.backgroundColor = [UIColor redColor];
        //_circleLabel.font = [UIFont boldSystemFontOfSize:14.f];
		_circleLabel.layer.masksToBounds = YES;
		_circleLabel.layer.cornerRadius = 18.0;
		_circleLabel.hidden = YES;
    }
    return _circleLabel;
}

-(void)blink
{
    if(blinkStatus == FALSE)
	{
        _circleLabel.hidden = NO;
        blinkStatus = TRUE;
    }
	else
	{
        _circleLabel.hidden = YES;
        blinkStatus = FALSE;
    }
}

-(void)blinkTimerStart
{
	blinkTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)(30.0 / 60.0)  target:self selector:@selector(blink) userInfo:nil repeats:TRUE];
}

-(void)blinkTimerStop
{
	[blinkTimer invalidate];
    blinkTimer = nil;
}

-(void)recordingTimerStart
{
	recordingTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)(1.0)  target:self selector:@selector(updateRecordingTime) userInfo:nil repeats:TRUE];
}

-(void)recordingTimerStop
{
	[recordingTimer invalidate];
    recordingTimer = nil;
}

-(void)updateRecordingTime
{
	recordingTime += 1;

	NSMutableString *strRecordingTime = [[NSMutableString alloc] initWithString:@""];

	if (recordingTime < 10) // 10 secs
	{
		[strRecordingTime insertString: [NSString stringWithFormat:@"%d", recordingTime] atIndex:0];
		[strRecordingTime insertString:@"00:00:0" atIndex:0];
	}
	else if (recordingTime < 60) // 60 secs
	{
		[strRecordingTime insertString: [NSString stringWithFormat:@"%d", recordingTime] atIndex:0];
		[strRecordingTime insertString:@"00:00:" atIndex:0];
	}
	else if (recordingTime < 3600) // 60 mins
	{
		int intHours = (int)recordingTime / 3600.0;
		int intMins = (int)recordingTime / 60.0;
		int intSecs = (int)recordingTime % 60;		

		if (intSecs < 10)
		{
			[strRecordingTime insertString: [NSString stringWithFormat:@"%d", intSecs] atIndex:0];
			[strRecordingTime insertString:@":0" atIndex:0];
		}
		else if (intSecs < 60)
		{
			[strRecordingTime insertString: [NSString stringWithFormat:@"%d", intSecs] atIndex:0];
			[strRecordingTime insertString:@":" atIndex:0];
		}

		if (intMins < 10)
		{
			[strRecordingTime insertString: [NSString stringWithFormat:@"%d", intMins] atIndex:0];
			[strRecordingTime insertString:@":0" atIndex:0];
		}
		else if (intMins < 60)
		{
			[strRecordingTime insertString: [NSString stringWithFormat:@"%d", intMins] atIndex:0];
			[strRecordingTime insertString:@":" atIndex:0];
		}

		if (intHours == 0)
		{
			[strRecordingTime insertString:@"00" atIndex:0];
		}
		else if (intHours > 0 && intHours < 10)
		{
			[strRecordingTime insertString: [NSString stringWithFormat:@"%d", intHours] atIndex:0];
			[strRecordingTime insertString:@"0" atIndex:0];
		}
		else if (intHours < 60)
		{
			[strRecordingTime insertString: [NSString stringWithFormat:@"%d", intHours] atIndex:0];			
		}
	}
	else
	{
		[strRecordingTime insertString:@"LIMIT" atIndex:0];
	}

	_recordingTimeLabel.text = strRecordingTime;
}

- (UIButton *)closeButton {
    if (!_closeButton) {
        _closeButton = [UIButton new];
        _closeButton.size = CGSizeMake(44, 44);
        //_closeButton.left = self.width - 10 - _closeButton.width;
		_closeButton.left = self.mainView.width - 10 - _closeButton.width;
        _closeButton.top = 20;
        [_closeButton setImage:[UIImage imageNamed:@"close_preview"] forState:UIControlStateNormal];
        _closeButton.exclusiveTouch = YES;
		//__weak typeof(self) _self = self;
        [_closeButton addBlockForControlEvents:UIControlEventTouchUpInside block:^(id sender) {
		
			//UIAlertView *alert = [[UIAlertView alloc] initWithTitle:self.alertStopSessionTitle message:self.alertStopSessionMessage delegate:self cancelButtonTitle:self.alertStopSessionNo otherButtonTitles:self.alertStopSessionYes, nil];
			//[alert show];			

			UIAlertController * alert = [UIAlertController alertControllerWithTitle:self.alertStopSessionTitle message:self.alertStopSessionMessage preferredStyle:UIAlertControllerStyleAlert];

			UIAlertAction* yesButton = [UIAlertAction actionWithTitle:self.alertStopSessionYes style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) 
			{
				//Handle your yes please button action here
				[self stopSession];
            }];

			UIAlertAction* noButton = [UIAlertAction actionWithTitle:self.alertStopSessionNo style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) 
			{
                //Handle no, thanks button                
            }];

			[alert addAction:yesButton];	
			[alert addAction:noButton];

			[self.viewController presentViewController:alert animated:YES completion:nil];

        }];
    }
    return _closeButton;
}

-(void)showVideoStartAlert
{
	UIAlertController * alert = [UIAlertController alertControllerWithTitle:self.alertStartSessionTitle message:self.alertStartSessionMessage preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction* okButton = [UIAlertAction actionWithTitle:self.alertStartSessionOK style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) 
	{
		//Handle your yes please button action here
	
    }];

	[alert addAction:okButton];	
	
	[self.viewController presentViewController:alert animated:YES completion:nil];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch(buttonIndex) {
        case 0: //"No" pressed
            //do something?
            break;
        case 1: //"Yes" pressed
            //here you pop the viewController
            [self stopSession];
			break;
    }
}

- (void)stopSession
{
	[self.session setVideoState:4]; //4 = SESSION IS ENDING, STOP BROADCASTING VIDEO

	_stateLabel.text = @"";
	[self blinkTimerStop];
	[self recordingTimerStop];
	_circleLabel.hidden = YES;
	_recordingTimeLabel.text = @"00:00:00";

	self.startLiveButton.selected = NO;

	[self.mainView removeFromSuperview];

	// WAIT 3 SECS AND THEN STOP BROADCAST
	[NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)(3.0)  target:self selector:@selector(stopBroadcast) userInfo:nil repeats:FALSE];	
    
}

- (void)stopBroadcast
{
	[self.session stopLive];
			
	_session = NULL;

	CDVPluginResult* pluginResult = nil;
	pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"CLOSE"];

	[self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
}

- (UIButton *)cameraButton {
    if (!_cameraButton) {
        _cameraButton = [UIButton new];
        _cameraButton.size = CGSizeMake(44, 44);
        _cameraButton.origin = CGPointMake(_closeButton.left - 10 - _cameraButton.width, 20);
        [_cameraButton setImage:[UIImage imageNamed:@"camra_preview"] forState:UIControlStateNormal];
        _cameraButton.exclusiveTouch = YES;
        __weak typeof(self) _self = self;
        [_cameraButton addBlockForControlEvents:UIControlEventTouchUpInside block:^(id sender) {
            AVCaptureDevicePosition devicePositon = _self.session.captureDevicePosition;
            _self.session.captureDevicePosition = (devicePositon == AVCaptureDevicePositionBack) ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
        }];
    }
    return _cameraButton;
}

- (UIButton *)beautyButton {
    if (!_beautyButton) {
        _beautyButton = [UIButton new];
        _beautyButton.size = CGSizeMake(44, 44);
        _beautyButton.origin = CGPointMake(_cameraButton.left - 10 - _beautyButton.width, 20);
        [_beautyButton setImage:[UIImage imageNamed:@"camra_beauty"] forState:UIControlStateNormal];
        [_beautyButton setImage:[UIImage imageNamed:@"camra_beauty_close"] forState:UIControlStateSelected];
        _beautyButton.exclusiveTouch = YES;
        __weak typeof(self) _self = self;
        [_beautyButton addBlockForControlEvents:UIControlEventTouchUpInside block:^(id sender) {
			
            _self.session.beautyFace = !_self.session.beautyFace;
            _self.beautyButton.selected = !_self.session.beautyFace; 
        }];
    }
    return _beautyButton;
}

- (UIButton *)micButton {
    if (!_micButton) 
	{	
        _micButton = [UIButton new];
        _micButton.size = CGSizeMake(44, 44);
        _micButton.origin = CGPointMake(_beautyButton.left - 10 - _micButton.width, 20);
        [_micButton setImage:[UIImage imageNamed:@"mic_on"] forState:UIControlStateNormal];
        [_micButton setImage:[UIImage imageNamed:@"mic_off"] forState:UIControlStateSelected];
        _micButton.exclusiveTouch = YES;
        __weak typeof(self) _self = self;
		[_self.session setMuted:NO];

        [_micButton addBlockForControlEvents:UIControlEventTouchUpInside block:^(id sender) {
			
			if (isMuted == YES)
			{
				isMuted = NO;

				if (isStreaming == TRUE)
				{				
					[_self.session setMuted:NO];
				}				
				_self.micButton.selected = NO; 
			}
			else
			{
				isMuted = YES;
				[_self.session setMuted:YES];
				_self.micButton.selected = YES; 
			}

			//isMuted = !isMuted;
            //_self.session.micFace = !_self.session.micFace;
			//[_self.session setMuted:isMuted];
            //_self.micButton.selected = isMuted; 

        }];
    }
    return _micButton;
}

- (UIButton *)startLiveButton {
    if (!_startLiveButton) {
        _startLiveButton = [UIButton new];

		 _startLiveButton.size = CGSizeMake(80, 80);
		 _startLiveButton.origin = CGPointMake(self.mainView.width / 2.0 - 40, self.mainView.height - 220);
		 [_startLiveButton setImage:[UIImage imageNamed:@"icon_record_start"] forState:UIControlStateNormal]; 
        [_startLiveButton setImage:[UIImage imageNamed:@"icon_record_stop"] forState:UIControlStateSelected];

        _startLiveButton.exclusiveTouch = YES;
        __weak typeof(self) _self = self;
        [_startLiveButton addBlockForControlEvents:UIControlEventTouchUpInside block:^(id sender) {
            _self.startLiveButton.selected = !_self.startLiveButton.selected;
            if (_self.startLiveButton.selected) {
				_stateLabel.text = self.labelLive;
				//blinkTimerStart;
				[self blinkTimerStart];
				//[self recordingTimerStart];
				_circleLabel.hidden = NO;
                //[_self.startLiveButton setTitle:self.buttonTextStart forState:UIControlStateNormal];
                
				if (isStreaming == FALSE)
				{
					isStreaming = TRUE;

					LFLiveStreamInfo *stream = [LFLiveStreamInfo new];
					//stream.url = @"rtmp://live.hkstv.hk.lxdns.com:1935/live/stream153";
					//stream.url = @"rtmp://testing-testvarsitymediaservices-usea.channel.media.azure.net:1935/live/85d7ede03c614a50b598a85dd057e0f81/1";
					stream.url = self.rtmpServerURL;
					[_self.session setMuted:NO];
					[_self.session setVideoState:2]; //2 = SESSION STARTED, BROADCAST VIDEO
					[_self.session startLive:stream];
				}
				else
				{
					//[_self.session setRunning:YES];
					//[_self.session setPaused:NO];
					[_self.session setVideoState:2]; //2 = SESSION STARTED, BROADCAST VIDEO
					[_self.session setMuted:NO];
					_self.micButton.selected = NO; 
				}				
            } else {
				//_stateLabel.text = @"READY";
				_stateLabel.text = @"";
				[self blinkTimerStop];
				//[self recordingTimerStop];
				_circleLabel.hidden = YES;
                //[_self.startLiveButton setTitle:@"STOPPED" forState:UIControlStateNormal];
				//[_self.startLiveButton setTitle:self.buttonTextStop forState:UIControlStateNormal];
				//[_self.session setRunning:NO];
                //[_self.session stopLive];

				if (isStreaming == TRUE)
				{
					//[_self.session setRunning:NO];
					//[_self.session setPaused:YES];
					[_self.session setVideoState:3]; //3 = SESSION HAS STARTED, PAUSE VIDEO BROADCAST
					[_self.session setMuted:YES];
				}
				
            }
        }];
    }
    return _startLiveButton;
}

- (void) forceQuit:(CDVInvokedUrlCommand *)command 
{
	NSLog(@"FORCE QUIT!!");

	NSDictionary *options = [command.arguments objectAtIndex: 0];
  
	NSString* strForceQuitTitle = [options objectForKey:@"alertForceQuitTitle"];	
	NSString* strForceQuitMessage = [options objectForKey:@"alertForceQuitMessage"];	

	UIAlertController * alert = [UIAlertController alertControllerWithTitle:strForceQuitTitle message:strForceQuitMessage preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction* okButton = [UIAlertAction actionWithTitle:self.alertStartSessionOK style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) 
	{
		//Handle your yes please button action here
		[self stopSession];
    }];

	[alert addAction:okButton];	
	
	[self.viewController presentViewController:alert animated:YES completion:nil];
}

@end
