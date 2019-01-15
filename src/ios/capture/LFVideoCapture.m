//
//  LFVideoCapture.m
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <CoreText/CoreText.h>
#import "LFVideoCapture.h"
#import "LFGPUImageBeautyFilter.h"
#import "LFGPUImageEmptyFilter.h"

#if __has_include(<GPUImage/GPUImage.h>)
#import <GPUImage/GPUImage.h>
#elif __has_include("GPUImage/GPUImage.h")
#import "GPUImage/GPUImage.h"
#else
#import "GPUImage.h"
#endif

@interface LFVideoCapture ()

@property (nonatomic, strong) GPUImageVideoCamera *videoCamera;
@property (nonatomic, strong) LFGPUImageBeautyFilter *beautyFilter;
@property (nonatomic, strong) GPUImageOutput<GPUImageInput> *filter;
@property (nonatomic, strong) GPUImageCropFilter *cropfilter;
@property (nonatomic, strong) GPUImageOutput<GPUImageInput> *output;
@property (nonatomic, strong) GPUImageView *gpuImageView;
@property (nonatomic, strong) LFLiveVideoConfiguration *configuration;

@property (nonatomic, strong) GPUImageAlphaBlendFilter *blendFilter;
@property (nonatomic, strong) GPUImageUIElement *uiElementInput;
@property (nonatomic, strong) UIView *waterMarkContentView;

@property (nonatomic, strong) GPUImageMovieWriter *movieWriter;

@end

CVPixelBufferRef pixelBufferTitleStart;
CVPixelBufferRef pixelBufferTitlePaused;
CVPixelBufferRef pixelBufferTitleEnd;

@implementation LFVideoCapture
@synthesize torch = _torch;
@synthesize beautyLevel = _beautyLevel;
@synthesize brightLevel = _brightLevel;
@synthesize zoomScale = _zoomScale;

#pragma mark -- LifeCycle
- (instancetype)initWithVideoConfiguration:(LFLiveVideoConfiguration *)configuration {
    if (self = [super init]) {
        _configuration = configuration;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarChanged:) name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
        
        self.beautyFace = YES;
        self.beautyLevel = 0.5;
        self.brightLevel = 0.5;
        self.zoomScale = 1.0;
        self.mirror = YES;

		self.videoState = 1;

		pixelBufferTitleStart = [self drawPixelBufferTitle:_configuration.videoTitleStart];
		pixelBufferTitlePaused = [self drawPixelBufferTitle:_configuration.videoTitlePaused];
		pixelBufferTitleEnd = [self drawPixelBufferTitle:_configuration.videoTitleEnd];
    }
    return self;
}

- (void)dealloc {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_videoCamera stopCameraCapture];
    if(_gpuImageView){
        [_gpuImageView removeFromSuperview];
        _gpuImageView = nil;
    }
}

#pragma mark -- Setter Getter

- (GPUImageVideoCamera *)videoCamera{
    if(!_videoCamera){
        _videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:_configuration.avSessionPreset cameraPosition:AVCaptureDevicePositionFront];
        _videoCamera.outputImageOrientation = _configuration.outputImageOrientation;
        _videoCamera.horizontallyMirrorFrontFacingCamera = NO;
        _videoCamera.horizontallyMirrorRearFacingCamera = NO;
        _videoCamera.frameRate = (int32_t)_configuration.videoFrameRate;
    }
    return _videoCamera;
}

- (void)setRunning:(BOOL)running {
    if (_running == running) return;
    _running = running;
    
    if (!_running) {
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        [self.videoCamera stopCameraCapture];
        if(self.saveLocalVideo) [self.movieWriter finishRecording];
    } else {
        [UIApplication sharedApplication].idleTimerDisabled = YES;
        [self reloadFilter];
        [self.videoCamera startCameraCapture];
        if(self.saveLocalVideo) [self.movieWriter startRecording];
    }
}

// ADDED BY JOHN WEAVER ON 9/5/2018
- (void)setVideoState:(int)videoState {
    if (_videoState == videoState) return;
    _videoState = videoState;
}

- (void)setPreView:(UIView *)preView {
    if (self.gpuImageView.superview) [self.gpuImageView removeFromSuperview];
    [preView insertSubview:self.gpuImageView atIndex:0];
    self.gpuImageView.frame = CGRectMake(0, 0, preView.frame.size.width, preView.frame.size.height);
}

- (UIView *)preView {
    return self.gpuImageView.superview;
}

- (void)setCaptureDevicePosition:(AVCaptureDevicePosition)captureDevicePosition {
    if(captureDevicePosition == self.videoCamera.cameraPosition) return;
    [self.videoCamera rotateCamera];
    self.videoCamera.frameRate = (int32_t)_configuration.videoFrameRate;
    [self reloadMirror];
}

- (AVCaptureDevicePosition)captureDevicePosition {
    return [self.videoCamera cameraPosition];
}

- (void)setVideoFrameRate:(NSInteger)videoFrameRate {
    if (videoFrameRate <= 0) return;
    if (videoFrameRate == self.videoCamera.frameRate) return;
    self.videoCamera.frameRate = (uint32_t)videoFrameRate;
}

- (NSInteger)videoFrameRate {
    return self.videoCamera.frameRate;
}

- (void)setTorch:(BOOL)torch {
    BOOL ret;
    if (!self.videoCamera.captureSession) return;
    AVCaptureSession *session = (AVCaptureSession *)self.videoCamera.captureSession;
    [session beginConfiguration];
    if (self.videoCamera.inputCamera) {
        if (self.videoCamera.inputCamera.torchAvailable) {
            NSError *err = nil;
            if ([self.videoCamera.inputCamera lockForConfiguration:&err]) {
                [self.videoCamera.inputCamera setTorchMode:(torch ? AVCaptureTorchModeOn : AVCaptureTorchModeOff) ];
                [self.videoCamera.inputCamera unlockForConfiguration];
                ret = (self.videoCamera.inputCamera.torchMode == AVCaptureTorchModeOn);
            } else {
                NSLog(@"Error while locking device for torch: %@", err);
                ret = false;
            }
        } else {
            NSLog(@"Torch not available in current camera input");
        }
    }
    [session commitConfiguration];
    _torch = ret;
}

- (BOOL)torch {
    return self.videoCamera.inputCamera.torchMode;
}

- (void)setMirror:(BOOL)mirror {
    _mirror = mirror;
}

- (void)setBeautyFace:(BOOL)beautyFace{
    _beautyFace = beautyFace;
    [self reloadFilter];
}

- (void)setBeautyLevel:(CGFloat)beautyLevel {
    _beautyLevel = beautyLevel;
    if (self.beautyFilter) {
        [self.beautyFilter setBeautyLevel:_beautyLevel];
    }
}

- (CGFloat)beautyLevel {
    return _beautyLevel;
}

- (void)setBrightLevel:(CGFloat)brightLevel {
    _brightLevel = brightLevel;
    if (self.beautyFilter) {
        [self.beautyFilter setBrightLevel:brightLevel];
    }
}

- (CGFloat)brightLevel {
    return _brightLevel;
}

- (void)setZoomScale:(CGFloat)zoomScale {
    if (self.videoCamera && self.videoCamera.inputCamera) {
        AVCaptureDevice *device = (AVCaptureDevice *)self.videoCamera.inputCamera;
        if ([device lockForConfiguration:nil]) {
            device.videoZoomFactor = zoomScale;
            [device unlockForConfiguration];
            _zoomScale = zoomScale;
        }
    }
}

- (CGFloat)zoomScale {
    return _zoomScale;
}

- (void)setWarterMarkView:(UIView *)warterMarkView{
    if(_warterMarkView && _warterMarkView.superview){
        [_warterMarkView removeFromSuperview];
        _warterMarkView = nil;
    }
    _warterMarkView = warterMarkView;
    self.blendFilter.mix = warterMarkView.alpha;
    [self.waterMarkContentView addSubview:_warterMarkView];
    [self reloadFilter];
}

- (GPUImageUIElement *)uiElementInput{
    if(!_uiElementInput){
        _uiElementInput = [[GPUImageUIElement alloc] initWithView:self.waterMarkContentView];
    }
    return _uiElementInput;
}

- (GPUImageAlphaBlendFilter *)blendFilter{
    if(!_blendFilter){
        _blendFilter = [[GPUImageAlphaBlendFilter alloc] init];
        _blendFilter.mix = 1.0;
        [_blendFilter disableSecondFrameCheck];
    }
    return _blendFilter;
}

- (UIView *)waterMarkContentView{
    if(!_waterMarkContentView){
        _waterMarkContentView = [UIView new];
        _waterMarkContentView.frame = CGRectMake(0, 0, self.configuration.videoSize.width, self.configuration.videoSize.height);
        _waterMarkContentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return _waterMarkContentView;
}

- (GPUImageView *)gpuImageView{
    if(!_gpuImageView){
        _gpuImageView = [[GPUImageView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [_gpuImageView setFillMode:kGPUImageFillModePreserveAspectRatioAndFill];
        [_gpuImageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    }
    return _gpuImageView;
}

-(UIImage *)currentImage{
    if(_filter){
        [_filter useNextFrameForImageCapture];
        return _filter.imageFromCurrentFramebuffer;
    }
    return nil;
}

- (GPUImageMovieWriter*)movieWriter{
    if(!_movieWriter){
        _movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:self.saveLocalVideoPath size:self.configuration.videoSize];
        _movieWriter.encodingLiveVideo = YES;
        _movieWriter.shouldPassthroughAudio = YES;
        self.videoCamera.audioEncodingTarget = self.movieWriter;
    }
    return _movieWriter;
}

#pragma mark -- Custom Method

#pragma mark -- Custom Method
- (void)processVideo:(GPUImageOutput *)output {
    __weak typeof(self) _self = self;
    @autoreleasepool {
        
		//////////////////////////
		// UPDATED BY JOHN WEAVER ON 9/5/2018
		// VIDEOSTATE
		// 1 = SESSION JUST STARTED, WAITING FOR VIDEO BROADCAST TO BEGIN
		// 2 = SESSION STARTED, BROADCAST VIDEO
		// 3 = SESSION HAS STARTED, PAUSE VIDEO BROADCAST
		// 4 = SESSION IS ENDING, STOP BROADCASTING VIDEO
		//////////////////////////

		CVPixelBufferRef pixelBuffer = NULL;

		if (_self.videoState == 1)
		{	
			pixelBuffer = pixelBufferTitleStart;
		}
		else if (_self.videoState == 3)
		{
			pixelBuffer = pixelBufferTitlePaused;
		}
		else if (_self.videoState == 4)
		{
			pixelBuffer = pixelBufferTitleEnd;
		}
		else
		{
			GPUImageFramebuffer *imageFramebuffer = output.framebufferForOutput;
			pixelBuffer = [imageFramebuffer pixelBuffer];
		}
				
        if (pixelBuffer && _self.delegate && [_self.delegate respondsToSelector:@selector(captureOutput:pixelBuffer:)]) {
            [_self.delegate captureOutput:_self pixelBuffer:pixelBuffer];
        }
    }
}

- (void)processVideo_OLD:(GPUImageOutput *)output {
    __weak typeof(self) _self = self;
    @autoreleasepool {
        GPUImageFramebuffer *imageFramebuffer = output.framebufferForOutput;
        CVPixelBufferRef pixelBuffer = [imageFramebuffer pixelBuffer];
        if (pixelBuffer && _self.delegate && [_self.delegate respondsToSelector:@selector(captureOutput:pixelBuffer:)]) {
            [_self.delegate captureOutput:_self pixelBuffer:pixelBuffer];
        }
    }
}

- (void)reloadFilter{
    [self.filter removeAllTargets];
    [self.blendFilter removeAllTargets];
    [self.uiElementInput removeAllTargets];
    [self.videoCamera removeAllTargets];
    [self.output removeAllTargets];
    [self.cropfilter removeAllTargets];
    
    if (self.beautyFace) {
        self.output = [[LFGPUImageEmptyFilter alloc] init];
        self.filter = [[LFGPUImageBeautyFilter alloc] init];
        self.beautyFilter = (LFGPUImageBeautyFilter*)self.filter;
    } else {
        self.output = [[LFGPUImageEmptyFilter alloc] init];
        self.filter = [[LFGPUImageEmptyFilter alloc] init];
        self.beautyFilter = nil;
    }
    
    ///< 调节镜像
    [self reloadMirror];
    
    //< 480*640 比例为4:3  强制转换为16:9
    if([self.configuration.avSessionPreset isEqualToString:AVCaptureSessionPreset640x480]){
        CGRect cropRect = self.configuration.landscape ? CGRectMake(0, 0.125, 1, 0.75) : CGRectMake(0.125, 0, 0.75, 1);
        self.cropfilter = [[GPUImageCropFilter alloc] initWithCropRegion:cropRect];
        [self.videoCamera addTarget:self.cropfilter];
        [self.cropfilter addTarget:self.filter];
    }else{
        [self.videoCamera addTarget:self.filter];
    }
    
    //< 添加水印
    if(self.warterMarkView){
        [self.filter addTarget:self.blendFilter];
        [self.uiElementInput addTarget:self.blendFilter];
        [self.blendFilter addTarget:self.gpuImageView];
        if(self.saveLocalVideo) [self.blendFilter addTarget:self.movieWriter];
        [self.filter addTarget:self.output];
        [self.uiElementInput update];
    }else{
        [self.filter addTarget:self.output];
        [self.output addTarget:self.gpuImageView];
        if(self.saveLocalVideo) [self.output addTarget:self.movieWriter];
    }
    
    [self.filter forceProcessingAtSize:self.configuration.videoSize];
    [self.output forceProcessingAtSize:self.configuration.videoSize];
    [self.blendFilter forceProcessingAtSize:self.configuration.videoSize];
    [self.uiElementInput forceProcessingAtSize:self.configuration.videoSize];
    
    
    //< 输出数据
    __weak typeof(self) _self = self;
    [self.output setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time) {
        [_self processVideo:output];
    }];
    
}

- (void)reloadMirror{
    if(self.mirror && self.captureDevicePosition == AVCaptureDevicePositionFront){
        self.videoCamera.horizontallyMirrorFrontFacingCamera = YES;
    }else{
        self.videoCamera.horizontallyMirrorFrontFacingCamera = NO;
    }
}

#pragma mark Notification

- (void)willEnterBackground:(NSNotification *)notification {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [self.videoCamera pauseCameraCapture];
    runSynchronouslyOnVideoProcessingQueue(^{
        glFinish();
    });
}

- (void)willEnterForeground:(NSNotification *)notification {
    [self.videoCamera resumeCameraCapture];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}

- (void)statusBarChanged:(NSNotification *)notification {
    NSLog(@"UIApplicationWillChangeStatusBarOrientationNotification. UserInfo: %@", notification.userInfo);
    UIInterfaceOrientation statusBar = [[UIApplication sharedApplication] statusBarOrientation];

    if(self.configuration.autorotate){
        if (self.configuration.landscape) {
            if (statusBar == UIInterfaceOrientationLandscapeLeft) {
                self.videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeRight;
            } else if (statusBar == UIInterfaceOrientationLandscapeRight) {
                self.videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeLeft;
            }
        } else {
            if (statusBar == UIInterfaceOrientationPortrait) {
                self.videoCamera.outputImageOrientation = UIInterfaceOrientationPortraitUpsideDown;
            } else if (statusBar == UIInterfaceOrientationPortraitUpsideDown) {
                self.videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
            }
        }
    }
}

- (CVPixelBufferRef) drawPixelBufferTitle:strTitle
{
	int intWidth = _configuration.videoSize.width;
	int intHeight = _configuration.videoSize.height;

    NSDictionary *options = @{(NSString*)kCVPixelBufferCGImageCompatibilityKey : @YES,(NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES,};

    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, intWidth, intHeight, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options, &pxbuffer);
    if (status!=kCVReturnSuccess) {
        NSLog(@"Operation failed");
    }
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);

    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);

    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, intWidth, intHeight, 8, 4*intWidth, rgbColorSpace, kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);

    //[self drawSMPTEBars:context ];
	[self drawLogo:context ];

	//NSString * strLabel = @"WAITING FOR LIVESTREAM TO BEGIN";
	//NSString * strLabel = _configuration.videoTitleStart;
	NSString * strLabel = strTitle;

	const char *cString = [strLabel cStringUsingEncoding:NSASCIIStringEncoding];

	int intPosX = 0;
	int intPosY = (int)intHeight * 0.4; // DRAWS FROM BOTTOM LEFT CORNER!
	int intLabelHeight = 100;
	int intLabelWidth = intWidth;
	int intFontSize = 30;
	
	CGRect labelRect = CGRectMake(intPosX, intPosY, intLabelWidth, intLabelHeight);
	UIFont * labelFont = [UIFont fontWithName:@"Helvetica" size: intFontSize];
	
	// https://stackoverflow.com/questions/30981213/cfstringref-change-color-in-objective-c
	[self drawText:strLabel withColor:[UIColor whiteColor] inFrame:labelRect currentContext:context withLabelFont:labelFont ];
	
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);

    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    return pxbuffer;
}


- (CVPixelBufferRef) drawPixelBufferPaused_OLD
{
	//UIImage * img = [UIImage imageNamed:@"icon_record_stop"];
	//CGImageRef image = [img CGImage];

	//int intWidth = self.gpuImageView.frame.size.width;
	//int intHeight = self.gpuImageView.frame.size.height;

	//int intWidth = 720;
	//int intHeight = 1280;

	int intWidth = _configuration.videoSize.width;
	int intHeight = _configuration.videoSize.height;

	int intWidthBar = (int)intWidth / 7.0;

	//NSLog(@"%d,%d,%d", intWidth, intHeight, intWidthBar);

	int intPosX_1 = 0;
	int intPosX_2 = intWidthBar;
	int intPosX_3 = intWidthBar * 2;
	int intPosX_4 = intWidthBar * 3;
	int intPosX_5 = intWidthBar * 4;
	int intPosX_6 = intWidthBar * 5;
	int intPosX_7 = intWidthBar * 6;

	int intPosY = (int)intHeight * 0.40; // DRAWS FROM BOTTOM LEFT CORNER!
	int intHeightBar = (int)intHeight * 0.40;
	int intHeightBarShort = (int)intHeight * 0.05;

	int intPosYShort = (int)(intPosY - intHeightBarShort);

    NSDictionary *options = @{(NSString*)kCVPixelBufferCGImageCompatibilityKey : @YES,(NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES,};

    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, intWidth, intHeight, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options, &pxbuffer);
    if (status!=kCVReturnSuccess) {
        NSLog(@"Operation failed");
    }
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);

    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);

    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, intWidth, intHeight, 8, 4*intWidth, rgbColorSpace, kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);

    //CGContextConcatCTM(context, CGAffineTransformMakeRotation(0));
    //CGAffineTransform flipVertical = CGAffineTransformMake( 1, 0, 0, -1, 0, intWidth );
    //CGContextConcatCTM(context, flipVertical);
    //CGAffineTransform flipHorizontal = CGAffineTransformMake( -1.0, 0.0, 0.0, 1.0, intHeight, 0.0 );
    //CGContextConcatCTM(context, flipHorizontal);

	//CGContextSetRGBFillColor(context, 1.0, 1.0, 0.0, 1.0); // YELLOW
	//CGContextSetRGBFillColor(context, 0.0, 0.0, 0.0, 1.0); // BLACK
	//CGContextFillRect(context, CGRectMake(0, 0, intWidth, intHeight));

	CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0); // WHITE
    CGContextFillRect(context, CGRectMake(intPosX_1, intPosY, intWidthBar, intHeightBar));

	CGContextSetRGBFillColor(context, 1.0, 1.0, 0.0, 1.0); // YELLOW
    CGContextFillRect(context, CGRectMake(intPosX_2, intPosY, intWidthBar, intHeightBar));

	CGContextSetRGBFillColor(context, 0.0, 1.0, 1.0, 1.0); // CYAN
    CGContextFillRect(context, CGRectMake(intPosX_3, intPosY, intWidthBar, intHeightBar));

	CGContextSetRGBFillColor(context, 0.0, 1.0, 0.0, 1.0); // GREEN
    CGContextFillRect(context, CGRectMake(intPosX_4, intPosY, intWidthBar, intHeightBar));

	CGContextSetRGBFillColor(context, 1.0, 0.0, 1.0, 1.0); // MAGENTA
    CGContextFillRect(context, CGRectMake(intPosX_5, intPosY, intWidthBar, intHeightBar));

	CGContextSetRGBFillColor(context, 1.0, 0.0, 0.0, 1.0); // RED
    CGContextFillRect(context, CGRectMake(intPosX_6, intPosY, intWidthBar, intHeightBar));

	CGContextSetRGBFillColor(context, 0.0, 0.0, 1.0, 1.0); // BLUE
    CGContextFillRect(context, CGRectMake(intPosX_7, intPosY, intWidthBar, intHeightBar));
	
	CGContextSetRGBFillColor(context, 0.0, 0.0, 1.0, 1.0); // BLUE - SHORT
    CGContextFillRect(context, CGRectMake(intPosX_1, intPosYShort, intWidthBar, intHeightBarShort));

	CGContextSetRGBFillColor(context, 1.0, 0.0, 1.0, 1.0); // MAGENTA - SHORT
    CGContextFillRect(context, CGRectMake(intPosX_3, intPosYShort, intWidthBar, intHeightBarShort));

	CGContextSetRGBFillColor(context, 0.0, 1.0, 1.0, 1.0); // CYAN - SHORT
    CGContextFillRect(context, CGRectMake(intPosX_5, intPosYShort, intWidthBar, intHeightBarShort));

	CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0); // WHITE - SHORT
    CGContextFillRect(context, CGRectMake(intPosX_7, intPosYShort, intWidthBar, intHeightBarShort));

	NSString * strLabel = @"WAITING FOR LIVESTREAM TO BEGIN";
	const char *cString = [strLabel cStringUsingEncoding:NSASCIIStringEncoding];

	//int intLabelWidth = [strLabel sizeWithAttributes:@{NSFontAttributeName:[UIFont fontWithName:@"Helvetica" size:14]}].width;
	//NSLog(@"%d", intLabelWidth);

	CGRect labelRect = CGRectMake(0, (int)intHeight * 0.8, intWidth, 100);
	UIFont * labelFont = [UIFont fontWithName:@"Helvetica" size: 30];
	
	// https://stackoverflow.com/questions/30981213/cfstringref-change-color-in-objective-c
	[self drawText:strLabel withColor:[UIColor whiteColor] inFrame:labelRect currentContext:context withLabelFont:labelFont ];
	
	//[self drawSMPTEBars ];

	
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);

    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    return pxbuffer;
}

-(void)drawLogo:(CGContextRef)currentContext
{
	UIImage * img = [UIImage imageNamed:@"logo"];
	CGImageRef image = [img CGImage];

	int intWidth = _configuration.videoSize.width;
	int intHeight = _configuration.videoSize.height;

	//int intImageWidth = (int)intWidth * 0.80;
	int intImageWidth = (int)intWidth;
	int intImageHeight = (int)img.size.height * (intImageWidth / img.size.width);

	//int intPosX = (int)intHeight * 0.10;
	int intPosX = 0;
	int intPosY = (int)intHeight * 0.6; // DRAWS FROM BOTTOM LEFT CORNER!
	
	//UIGraphicsBeginImageContext(img.size);
	////CGContextRef _context = UIGraphicsGetCurrentContext(); // here you don't need this reference for the context but if you want to use in the future for drawing anything else on the context you could get it for it
	//[img drawInRect:CGRectMake(intPosX, intPosY, intImageWidth, intImageHeight)];

	//UIImage *_newImage = UIGraphicsGetImageFromCurrentImageContext();    
	//UIGraphicsEndImageContext();

	//CGContextTranslateCTM(context, 0, image.size.height);
	//CGContextScaleCTM(context, 1.0, -1.0);
	CGRect imageRect = CGRectMake(intPosX, intPosY, intImageWidth, intImageHeight);       

	CGContextDrawImage(currentContext, imageRect, image);

}

-(void)drawSMPTEBars:(CGContextRef)currentContext
{
	int intWidth = _configuration.videoSize.width;
	int intHeight = _configuration.videoSize.height;

	int intWidthBar = (int)intWidth / 7.0;

	//NSLog(@"%d,%d,%d", intWidth, intHeight, intWidthBar);

	int intPosX_1 = 0;
	int intPosX_2 = intWidthBar;
	int intPosX_3 = intWidthBar * 2;
	int intPosX_4 = intWidthBar * 3;
	int intPosX_5 = intWidthBar * 4;
	int intPosX_6 = intWidthBar * 5;
	int intPosX_7 = intWidthBar * 6;

	int intPosY = (int)intHeight * 0.40; // DRAWS FROM BOTTOM LEFT CORNER!
	int intHeightBar = (int)intHeight * 0.40;
	int intHeightBarShort = (int)intHeight * 0.05;

	int intPosYShort = (int)(intPosY - intHeightBarShort);

	CGContextSetRGBFillColor(currentContext, 1.0, 1.0, 1.0, 1.0); // WHITE
    CGContextFillRect(currentContext, CGRectMake(intPosX_1, intPosY, intWidthBar, intHeightBar));

	CGContextSetRGBFillColor(currentContext, 1.0, 1.0, 0.0, 1.0); // YELLOW
    CGContextFillRect(currentContext, CGRectMake(intPosX_2, intPosY, intWidthBar, intHeightBar));

	CGContextSetRGBFillColor(currentContext, 0.0, 1.0, 1.0, 1.0); // CYAN
    CGContextFillRect(currentContext, CGRectMake(intPosX_3, intPosY, intWidthBar, intHeightBar));

	CGContextSetRGBFillColor(currentContext, 0.0, 1.0, 0.0, 1.0); // GREEN
    CGContextFillRect(currentContext, CGRectMake(intPosX_4, intPosY, intWidthBar, intHeightBar));

	CGContextSetRGBFillColor(currentContext, 1.0, 0.0, 1.0, 1.0); // MAGENTA
    CGContextFillRect(currentContext, CGRectMake(intPosX_5, intPosY, intWidthBar, intHeightBar));

	CGContextSetRGBFillColor(currentContext, 1.0, 0.0, 0.0, 1.0); // RED
    CGContextFillRect(currentContext, CGRectMake(intPosX_6, intPosY, intWidthBar, intHeightBar));

	CGContextSetRGBFillColor(currentContext, 0.0, 0.0, 1.0, 1.0); // BLUE
    CGContextFillRect(currentContext, CGRectMake(intPosX_7, intPosY, intWidthBar, intHeightBar));
	
	CGContextSetRGBFillColor(currentContext, 0.0, 0.0, 1.0, 1.0); // BLUE - SHORT
    CGContextFillRect(currentContext, CGRectMake(intPosX_1, intPosYShort, intWidthBar, intHeightBarShort));

	CGContextSetRGBFillColor(currentContext, 1.0, 0.0, 1.0, 1.0); // MAGENTA - SHORT
    CGContextFillRect(currentContext, CGRectMake(intPosX_3, intPosYShort, intWidthBar, intHeightBarShort));

	CGContextSetRGBFillColor(currentContext, 0.0, 1.0, 1.0, 1.0); // CYAN - SHORT
    CGContextFillRect(currentContext, CGRectMake(intPosX_5, intPosYShort, intWidthBar, intHeightBarShort));

	CGContextSetRGBFillColor(currentContext, 1.0, 1.0, 1.0, 1.0); // WHITE - SHORT
    CGContextFillRect(currentContext, CGRectMake(intPosX_7, intPosYShort, intWidthBar, intHeightBarShort));
}

-(void)drawText:(NSString*)textToDraw withColor: (UIColor*) color inFrame:(CGRect)frameRect currentContext:(CGContextRef)currentContext withLabelFont:(UIFont*)labelFont
{
    CFStringRef stringRef = (__bridge CFStringRef)textToDraw;
    // Prepare the text using a Core Text Framesetter

    CGMutablePathRef framePath = CGPathCreateMutable();
    CGPathAddRect(framePath, NULL, frameRect);

	NSMutableParagraphStyle *paragraphStyle = NSMutableParagraphStyle.new;
	paragraphStyle.alignment = NSTextAlignmentCenter;

    /// ATTRIBUTES FOR COLOURED STRING
    NSDictionary *attrs = @{ 
		NSForegroundColorAttributeName : color, 
		//NSFontAttributeName : [UIFont fontWithName:@"Helvetica" size: 30],
		NSFontAttributeName : labelFont,
		NSParagraphStyleAttributeName : paragraphStyle
	};

    NSAttributedString *attString = [[NSAttributedString alloc] initWithString:textToDraw attributes:attrs];

	CFRange currentRange = CFRangeMake(0, [attString length]);
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)attString); //3
    //CTFrameRef frameRef = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, [attString length]), framePath, NULL);
	CTFrameRef frameRef = CTFramesetterCreateFrame(framesetter, currentRange, framePath, NULL);

    // Get the graphics context.
    //CGContextRef    currentContext = UIGraphicsGetCurrentContext();

    // Put the text matrix into a known state. This ensures
    // that no old scaling factors are left in place.
    CGContextSetTextMatrix(currentContext, CGAffineTransformIdentity);

    // Core Text draws from the bottom-left corner up, so flip
    // the current transform prior to drawing.
    //CGContextTranslateCTM(currentContext, 0, frameRect.origin.y*2);
    //CGContextScaleCTM(currentContext, 1.0, -1.0);

	 //CGContextConcatCTM(context, CGAffineTransformMakeRotation(0));
    //CGAffineTransform flipVertical = CGAffineTransformMake( 1, 0, 0, -1, 0, intWidth );
    //CGContextConcatCTM(context, flipVertical);
    //CGAffineTransform flipHorizontal = CGAffineTransformMake( -1.0, 0.0, 0.0, 1.0, intHeight, 0.0 );
    //CGContextConcatCTM(context, flipHorizontal);


    // Draw the frame.
    CTFrameDraw(frameRef, currentContext);

    //CGContextScaleCTM(currentContext, 1.0, -1.0);
    //CGContextTranslateCTM(currentContext, 0, (-1)*frameRect.origin.y*2);
	
    CFRelease(frameRef);
    CFRelease(stringRef);
    CFRelease(framesetter);
}


@end
