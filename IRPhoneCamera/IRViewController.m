//
//  ViewController.m
//  AugCam
//
//  Image Capture sections Created by John Carter on 1/26/2012.
//  Modified by Andy Rawson on 7/18/2012
//
// Change the HOST1 and HOST2 entries to the ip of the device
// The device will output the ip on the serial port 


#import "IRViewController.h"
#import "ScreenCapture.h"


#define DEFAULT_HIGH_TEMP 100
#define DEFAULT_LOW_TEMP 70
#define DEFAULT_OPACITY 0.7
#define HOST2 @"192.168.1.83"
#define HOST1 @"192.168.20.119"
#define PORT 2000


@interface IRViewController() {
   NSTimer *updateTimer;
    int tempPointHeight;
    int tempPointWidth;
    int tempPositionXOffset;
    int tempPositionYOffset;
    int sensorFOV;
    NSString *tempData;
    NSMutableArray *eepromData;
    NSMutableArray *sensorData;
    NSMutableArray *irOffset;

    double highTemp;
    double lowTemp;
    double opacity;
    double Ta;
    double Vth;
    double Kt1;
    double Kt2;
    BOOL waiting;
    NSString *useHost;
    int readingCount;
    int readingType;
    int newData;

    MLX90620Math *math;
    
}

- (void) performImageCaptureFrom:(CMSampleBufferRef)sampleBuffer;
- (void) activateCameraFeed;
- (void) scanForCameraDevices;

- (void) swapCameras;
- (void) setViewSource:(int)newViewSource;
- (void) saveDisplayView;

// start the camera
- (void) goLive;
- (UIColor *) mapTempToColor:(int)tempValue;
- (float) map:(float)inMin:(float)inMax:(float)outMin:(float)outMax:(float)inValue;
// start the connection to the device
- (void)irConnectToHost;


@end


@implementation IRViewController


@synthesize cameraImage;
@synthesize overlayView;
@synthesize cameraImageOrientation;


- (id) init
{
    self = [super init];
    
    [[self view] setBackgroundColor:[UIColor blackColor]];
    
    return self;
}

// Map the temperature to color value
-(float) map:(float)inMin:(float)inMax:(float)outMin:(float)outMax:(float)inValue {
    float result = 0;
    result = outMin + (outMax - outMin) * (inValue - inMin) / (inMax - inMin);
    return result;
    
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    tempPointWidth = 39; // Individual sensor point width
    tempPointHeight = 43; // Individual sensor point height
    tempPositionXOffset = 200; // Where to start drawing
    tempPositionYOffset = 300; // Where to start drawing
    readingCount = 0;
    readingType = 1; // Read EEPROM data first
    newData = 0; // Is new IR data available
    
    [self goLive]; // Start the camera
    
    waiting = NO;
    //PTAT = 6848; // Default; Set from Sensor RAM
    sensorData = [[NSMutableArray alloc] init];
    eepromData = [[NSMutableArray alloc] init];


    // setup and connect to the irDevice
    [self irConfig];
    [self irConnectToHost];
    
    lowTemp = DEFAULT_LOW_TEMP;
    highTemp = DEFAULT_HIGH_TEMP;
    opacity = DEFAULT_OPACITY;
}

- (UIColor *)mapTempToColor:(int)tempValue {
    // Adjust the ratio to scale the colors that represent temp data
    CGFloat hue = [self map:lowTemp :highTemp :0.8 :0.0 :tempValue];  //  0.0 to 1.0
    if (hue >0.8) hue = 0.8;
    else if (hue < 0.0) hue = 0.0;
    CGFloat saturation = 0.9; 
    CGFloat brightness = 0.9; 
    
    return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:opacity];
}

- (void) update:(NSMutableArray*)sensorDataArray {
    //check if we are saving a snapshot
    if (!processingTouchEvent) {
    //check if a full sensorData frame is available
        //NSLog(@"ir data count %i",sensorData.count);
    if (sensorData.count == 66) {
        
    // Choose the Layer to place the tempdata
    CALayer *myLayer = cameraView.layer;
    
    NSString *sVcp = [sensorDataArray objectAtIndex:65];
    sVcp = [sVcp stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/r/n/r/n"]];
    int PTAT = [[sensorDataArray objectAtIndex:64] intValue];
    int Vcp = sVcp.intValue;
    Ta = [math GetTa:PTAT:Vcp];
    int rowCount = 0;
    int columnCount = 0;
    int row = tempPositionXOffset + (tempPointHeight * 2);
    int column = tempPositionYOffset - (tempPointWidth * 7.5);
    int irDataLoops = 64;
        //NSLog(@"Ta = %f", Ta);
        
    if (myLayer.sublayers.count < 5) {
        // Loop through the 64 temp readings and add layers to the View

        for (int i = 0; i < irDataLoops; i = i+1) {
            int temp = [[sensorDataArray objectAtIndex:i] intValue];
            temp = [math GetTo:temp:i];
            temp = (temp * 9 / 5) + 32; //convert C to F
            
            if (i == 34) {
                // add the single displayed numeric temp reading
                CATextLayer *sublayer = [CATextLayer layer];
                sublayer.fontSize = 20;
                sublayer.string = [NSString stringWithFormat:@"%d", temp]  ;
                sublayer.backgroundColor = [self mapTempToColor:temp].CGColor ;
                sublayer.opacity = 1;
                //sublayer.drawsAsynchronously = YES;
                [sublayer removeAllAnimations];
                sublayer.frame = CGRectMake(column, row, tempPointWidth, tempPointHeight);
                
                
                [myLayer addSublayer:sublayer];
            }
            else {
            //make new layers then add
            //CATextLayer *sublayer = [CATextLayer layer];
            CALayer *sublayer = [CALayer layer];
                sublayer.backgroundColor = [self mapTempToColor:temp].CGColor ;
                sublayer.opacity = 1;
                //sublayer.drawsAsynchronously = YES;
                [sublayer removeAllAnimations];
                sublayer.frame = CGRectMake(column, row, tempPointWidth, tempPointHeight);
                
                
                [myLayer addSublayer:sublayer];
            }// end checking for text point
            

            
            // Manage the row and column counts
            if (rowCount < 3) {
                rowCount++;
                row = row - tempPointHeight;
            }
            else {
                rowCount = 0;
                column = column + tempPointWidth;
                columnCount++;
                row = tempPositionXOffset + (tempPointHeight * 2);
            }
        } //end for loop
        

    } //end if checking for existing layers
    
        else {
                // Loop through the 64 temp readings and update the layers
            for (int i = 0; i < irDataLoops; i = i+1) {
                
                double temp = [[sensorDataArray objectAtIndex:i] intValue];
                temp = [math GetTo:temp:i];
                temp = (temp * 9 / 5) + 32; // convert C to F
                if (i == 34) {
                    // change the single displayed numeric temp reading
                    CATextLayer *sublayer = [myLayer.sublayers objectAtIndex:i];
                    sublayer.fontSize = 20;
                    sublayer.string = [NSString stringWithFormat:@"%f", temp]  ;
                    sublayer.backgroundColor = [self mapTempToColor:temp].CGColor;
                }
                else {
                    CALayer *sublayer = [myLayer.sublayers objectAtIndex:i];
                    sublayer.backgroundColor = [self mapTempToColor:temp].CGColor;
                }

                    
                // Manage the row and column counts
                if (rowCount < 3) {
                    rowCount++;
                    row = row - tempPointHeight;
                }
                else {
                    rowCount = 0;
                    column = column + tempPointWidth;
                    columnCount++;
                    row = tempPositionXOffset - (tempPointHeight * 1);
                }
            
            } //end for loop
        } //end else
        
    } // end if touch event check
    } // end if sensordata count

}

- (void) processEEPROMData {
    if (eepromData.count == 256) {

        math = [[MLX90620Math alloc] init];
        [math setup:eepromData]; //setup the math from the EEPROM
        
    }
    else {
        NSLog(@"No EEPROM data received");
    }
}

- (void) goLive
{
    // Disable Processing any Camera Feeds for now
    //
    ignoreImageStream = YES;
    
    
    // Device Info
    //
    currentDeviceOrientation = UIInterfaceOrientationLandscapeRight;
    currentViewSource = 0;          // or VIEWSOURCE_UIIMAGEVIEW or VIEWSOURCE_OPENGLVIEW
    
    
    // Scan for Cameras
    //
    cameraCount = 0;
    frontCameraDeviceIndex = -1;
    backCameraDeviceIndex = -1;
    
    [self scanForCameraDevices];
    
    
    // Turn on the Camera
    //
    [self activateCameraFeed];
    

    
    // Init the test layers
    //
    backingLayer = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"backinglayer.png"]];
    overlayLayer = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"overlaylayer.png"]];
    
    
    // Init the Plain Camera
    //
    cameraView = [[UIImageView alloc] initWithFrame:CGRectMake((CGFloat)0.0, (CGFloat)0.0, (CGFloat)640.0, (CGFloat)480.0)];    // size of the camera feed images
    
    
    // Init the displayView container and set the transform to scale the 480x640 so it will fit in 320x480 view (becomes 320x427)
    //
    displayView = [[UIImageView alloc] initWithFrame:CGRectMake((CGFloat)0.0, (CGFloat)0.0, (CGFloat)640.0, (CGFloat)480.0)];   // size of the camera feed images
    [displayView setTransform:CGAffineTransformIdentity];
    [displayView setTransform:CGAffineTransformScale([displayView transform], (CGFloat)0.667, (CGFloat)0.667)];
    [displayView setTransform:CGAffineTransformTranslate([displayView transform], (CGFloat)-160, (CGFloat)-160)];//(CGFloat)-120, (CGFloat)-173)];
    
    [self.view addSubview:displayView];
    
    
    // Set the default view source (also turns on the image stream)
    //
    [self setViewSource:VIEWSOURCE_UIIMAGEVIEW];    
}


- (void) setViewSource:(int)newViewSource
{
    if ( newViewSource==currentViewSource )
    {
        return;
    }
    
    ignoreImageStream=YES;
    
    
    // Pop all the views off the container view
    //
    if ( overlayLayer != nil )
        [overlayLayer removeFromSuperview];
    
    switch( currentViewSource )
    {
            
        case VIEWSOURCE_UIIMAGEVIEW:
            [cameraView removeFromSuperview];
            break;
    }
    
    if ( backingLayer != nil )
        [backingLayer removeFromSuperview];
    
    
    currentViewSource = newViewSource;
    
    
    // Put all the views back in the container view
    //
    if ( backingLayer != nil )
        [displayView addSubview:backingLayer];
    
    switch( newViewSource )
    {
            
        case VIEWSOURCE_UIIMAGEVIEW:
            [displayView addSubview:cameraView];
            break;
    }
    
    if ( overlayLayer != nil )
        //[displayView addSubview:overlayLayer];
        //[displayView addSubview:overlayView];
    ignoreImageStream=NO;
}


//
// This will only automatically change the size of self.view
// it will not change the sizes and locations of subviews
//
- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return( interfaceOrientation==UIInterfaceOrientationLandscapeRight );
}


//
// This method releases the 'newimage' because it may change it
// so the references passed can no longer be released by the
// caller of this method
//
- (void) newCameraImageNotification:(CGImageRef)newImage
{
    if ( newImage == nil )
        return;
    
    if ( currentViewSource == VIEWSOURCE_UIIMAGEVIEW )
    {
        cameraImage0 = [[UIImage alloc] initWithCGImage:newImage scale:(CGFloat)1.0 orientation:cameraImageOrientation];
        cameraImage = cameraImage0;
        
        [cameraView setImage:cameraImage];
        
        if ( cameraImage1 != nil )
            //            [cameraImage1 release];
            cameraImage1 = cameraImage0;
    }
    else

        
        CGImageRelease(newImage);
    
    // Check for new data and update the array
    if (newData) {
        [self update:sensorData];
        newData = 0;
        NSData *responseTerminatorData = [@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding]; 
        [irSocket readDataToData:responseTerminatorData withTimeout:-1.0 tag:0];
    }
}


- (void) savedSnapShot:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    if ( error != nil )
    {
        //        NSLog(@"Error saving snapshot: %@", <div class="error"><div class="message_box_content"></div><div class="clearboth"></div></div> );
    }
}


- (void) snapShot
{
    if ( ignoreImageStream )
        return;
    
    ignoreImageStream = YES;
    
    if ( currentViewSource==VIEWSOURCE_UIIMAGEVIEW )
        [self saveDisplayView];
    
    ignoreImageStream = NO;
}


- (void) saveDisplayView
{
    UIImage *photo = [ScreenCapture UIViewToImage:displayView];         // returns an autoreleased image
    
    if ( photo == nil )
        return;
    
    //    [photo retain];
    
    UIImageWriteToSavedPhotosAlbum(photo, self, @selector(savedSnapShot:didFinishSavingWithError:contextInfo:), nil);
    
    //    [photo release];
}


- (void) scanForCameraDevices
{
    cameraCount = 0;
    frontCameraDeviceIndex = -1;
    backCameraDeviceIndex = -1;
    
    AVCaptureDevice *backCameraDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSArray *deviceList = [AVCaptureDevice devices];
    NSRange cameraSearch;
    NSUInteger i;
    
    for ( i=0; i<[deviceList count]; i++ )
    {
        AVCaptureDevice *currentDevice = (AVCaptureDevice *)[deviceList objectAtIndex:i];
        
        //
        // This is the best info so skip string the string searches
        // that follow if we have a match on this
        //
        if ( currentDevice==backCameraDevice )
        {
            backCameraDeviceIndex = i;
            cameraCount++;
            continue;
        }
        
        cameraSearch = [[currentDevice description] rangeOfString:@"front camera" options:NSCaseInsensitiveSearch];
        if ( frontCameraDeviceIndex<0 && cameraSearch.location != NSNotFound )
        {
            frontCameraDeviceIndex = i;
            cameraCount++;
            continue;
        }
        
        cameraSearch = [[currentDevice description] rangeOfString:@"back camera" options:NSCaseInsensitiveSearch];
        if ( backCameraDevice<0 && cameraSearch.location != NSNotFound )
        {
            backCameraDeviceIndex = i;
            cameraCount++;
            continue;
        }
        
        cameraSearch = [[currentDevice description] rangeOfString:@"camera" options:NSCaseInsensitiveSearch];
        if ( backCameraDevice<0 && cameraSearch.location != NSNotFound )
        {
            backCameraDeviceIndex = i;
            cameraCount++;
            continue;
        }
    }
}


- (void) activateCameraFeed
{
    videoSettings = nil;
    
    pixelFormatCode = [[NSNumber alloc] initWithUnsignedInt:(unsigned int)kCVPixelFormatType_32BGRA];
    pixelFormatKey = [[NSString alloc] initWithString:(NSString *)kCVPixelBufferPixelFormatTypeKey];
    videoSettings = [[NSDictionary alloc] initWithObjectsAndKeys:pixelFormatCode, pixelFormatKey, nil];
    
    dispatch_queue_t queue = dispatch_queue_create("com.jellyfilledstudios.ImageCaptureQueue", NULL);
    
    captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    [captureOutput setAlwaysDiscardsLateVideoFrames:YES];
    [captureOutput setSampleBufferDelegate:self queue:queue];
    [captureOutput setVideoSettings:videoSettings];
    
    dispatch_release(queue);
    
    AVCaptureDevice *selectedCamera;
    
    currentCameraDeviceIndex = -1;
    
    // default to rear facing camera
    //
    if ( YES )
    {
        currentCameraDeviceIndex = backCameraDeviceIndex;
        cameraImageOrientation = UIImageOrientationUp;
    }
    else
    {
        currentCameraDeviceIndex = frontCameraDeviceIndex;
        cameraImageOrientation = UIImageOrientationLeftMirrored;
    }
    

    
    if ( currentCameraDeviceIndex < 0 )
        selectedCamera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    else
        selectedCamera = [[AVCaptureDevice devices] objectAtIndex:(NSUInteger)currentCameraDeviceIndex];
    
    captureInput = [AVCaptureDeviceInput deviceInputWithDevice:selectedCamera error:nil];
    
    if ( [selectedCamera lockForConfiguration:nil] )
    {
        if ( [selectedCamera isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure] )
        {
            [selectedCamera setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
        }
        
        if ( [selectedCamera isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance] )
        {
            [selectedCamera setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
        }
        
        if ( [selectedCamera isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus] )
        {
            [selectedCamera setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
        }
        
        if ( [selectedCamera isTorchModeSupported:AVCaptureTorchModeAuto] )
        {
            [selectedCamera setTorchMode:AVCaptureTorchModeOff];    // AVCaptureTorchModeOn turns the "torch" light ON
        }
        
        if ( [selectedCamera isFlashModeSupported:AVCaptureFlashModeAuto] )
        {
            [selectedCamera setFlashMode:AVCaptureFlashModeAuto];   // AVCaptureFlashModeAuto
        }
        
        [selectedCamera unlockForConfiguration];
    }
    
    captureSession = [[AVCaptureSession alloc] init];
    [captureSession beginConfiguration];
    
    if ( [selectedCamera supportsAVCaptureSessionPreset:AVCaptureSessionPreset640x480])
    {
        cameraDeviceSetting = CameraDeviceSetting640x480;
        [captureSession setSessionPreset:AVCaptureSessionPreset640x480];    // AVCaptureSessionPresetHigh or AVCaptureSessionPreset640x480
    }
    else
        if ( [selectedCamera supportsAVCaptureSessionPreset:AVCaptureSessionPresetHigh] )
        {
            cameraDeviceSetting = CameraDeviceSettingHigh;
            [captureSession setSessionPreset:AVCaptureSessionPresetHigh];   // AVCaptureSessionPresetHigh or AVCaptureSessionPreset640x480
        }
        else
            if ( [selectedCamera supportsAVCaptureSessionPreset:AVCaptureSessionPresetMedium] )
            {
                cameraDeviceSetting = CameraDeviceSettingMedium;
                [captureSession setSessionPreset:AVCaptureSessionPresetMedium]; // AVCaptureSessionPresetHigh or AVCaptureSessionPreset640x480
            }
            else
                if ( [selectedCamera supportsAVCaptureSessionPreset:AVCaptureSessionPresetLow] )
                {
                    cameraDeviceSetting = CameraDeviceSettingLow;
                    [captureSession setSessionPreset:AVCaptureSessionPresetLow];    // AVCaptureSessionPresetHigh or AVCaptureSessionPreset640x480
                }

    [captureSession addInput:captureInput];
    [captureSession addOutput:captureOutput];
    [captureSession commitConfiguration];
    
    [captureSession startRunning];
}

- (void)cameraSwapAnimation:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
}

    - (void) swapCameras
    {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.75];
        [UIView setAnimationCurve:UIViewAnimationCurveLinear];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(cameraSwapAnimation:finished:context:)];
        [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:[self view] cache:YES];
        [UIView commitAnimations];
        
        [captureSession stopRunning];
        [captureSession beginConfiguration];
        [captureSession removeInput:captureInput];
        
        if ( currentCameraDeviceIndex==frontCameraDeviceIndex )
        {
            currentCameraDeviceIndex = backCameraDeviceIndex;
            cameraImageOrientation = UIImageOrientationRight;
        }
        else
        {
            currentCameraDeviceIndex = frontCameraDeviceIndex;
            cameraImageOrientation = UIImageOrientationLeftMirrored;
        }

    // Start the Camera
    //
    AVCaptureDevice *selectedCamera = [[AVCaptureDevice devices] objectAtIndex:(NSUInteger)currentCameraDeviceIndex];
    
    captureInput = [AVCaptureDeviceInput deviceInputWithDevice:selectedCamera error:nil];
    
    if ( [selectedCamera lockForConfiguration:nil] )
    {
        if ( [selectedCamera isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure] )
        {
            [selectedCamera setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
        }
        
        if ( [selectedCamera isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance] )
        {
            [selectedCamera setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
        }
        
        if ( [selectedCamera isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus] )
        {
            [selectedCamera setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
        }
        
        if ( [selectedCamera isTorchModeSupported:AVCaptureTorchModeAuto] )
        {
            [selectedCamera setTorchMode:AVCaptureTorchModeOff];    // AVCaptureTorchModeOn turns the "torch" light ON
        }
        
        if ( [selectedCamera isFlashModeSupported:AVCaptureFlashModeAuto] )
        {
            [selectedCamera setFlashMode:AVCaptureFlashModeAuto];   // AVCaptureFlashModeAuto
        }
        
        [selectedCamera unlockForConfiguration];
    }
    
    if ( [selectedCamera supportsAVCaptureSessionPreset:AVCaptureSessionPreset640x480])
    {
        cameraDeviceSetting = CameraDeviceSetting640x480;
        [captureSession setSessionPreset:AVCaptureSessionPreset640x480];    // AVCaptureSessionPresetHigh or AVCaptureSessionPreset640x480
    }
    else
        if ( [selectedCamera supportsAVCaptureSessionPreset:AVCaptureSessionPresetHigh] )
        {
            cameraDeviceSetting = CameraDeviceSettingHigh;
            [captureSession setSessionPreset:AVCaptureSessionPresetHigh];   // AVCaptureSessionPresetHigh or AVCaptureSessionPreset640x480
        }
        else
            if ( [selectedCamera supportsAVCaptureSessionPreset:AVCaptureSessionPresetMedium] )
            {
                cameraDeviceSetting = CameraDeviceSettingMedium;
                [captureSession setSessionPreset:AVCaptureSessionPresetMedium]; // AVCaptureSessionPresetHigh or AVCaptureSessionPreset640x480
            }
            else
                if ( [selectedCamera supportsAVCaptureSessionPreset:AVCaptureSessionPresetLow] )
                {
                    cameraDeviceSetting = CameraDeviceSettingLow;
                    [captureSession setSessionPreset:AVCaptureSessionPresetLow];    // AVCaptureSessionPresetHigh or AVCaptureSessionPreset640x480
                }
    
    [captureSession addInput:captureInput];
    [captureSession commitConfiguration];
    
    [captureSession startRunning];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if ( ignoreImageStream )
        return;

    [self performImageCaptureFrom:sampleBuffer];
    
}

- (void) performImageCaptureFrom:(CMSampleBufferRef)sampleBuffer
{
    CVImageBufferRef imageBuffer;
    
    if ( CMSampleBufferGetNumSamples(sampleBuffer) != 1 )
        return;
    if ( !CMSampleBufferIsValid(sampleBuffer) )
        return;
    if ( !CMSampleBufferDataIsReady(sampleBuffer) )
        return;
    
    imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    if ( CVPixelBufferGetPixelFormatType(imageBuffer) != kCVPixelFormatType_32BGRA )
        return;
    
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    CGImageRef newImage = nil;
    
    if ( cameraDeviceSetting == CameraDeviceSetting640x480 )
    {
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        newImage = CGBitmapContextCreateImage(newContext);
        CGColorSpaceRelease( colorSpace );
        CGContextRelease(newContext);
    }
    else
    {
        //uint8_t *tempAddress = malloc( 640 * 4 * 480 ); //Portrait
        uint8_t *tempAddress = malloc( 480 * 4 * 640); //Landscape
        memcpy( tempAddress, baseAddress, bytesPerRow * height );
        baseAddress = tempAddress;
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace,  kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst);
        newImage = CGBitmapContextCreateImage(newContext);
        CGContextRelease(newContext);
        //newContext = CGBitmapContextCreate(baseAddress, 640, 480, 8, 640*4, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst); //Portrait
        newContext = CGBitmapContextCreate(baseAddress, 480, 640, 8, 640*4, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst); //Landscape
        //CGContextScaleCTM( newContext, (CGFloat)640/(CGFloat)width, (CGFloat)480/(CGFloat)height ); //Portrait
        CGContextScaleCTM( newContext, (CGFloat)480/(CGFloat)width, (CGFloat)640/(CGFloat)height ); //Landscape
        //CGContextDrawImage(newContext, CGRectMake(0,0,640,480), newImage); //Portrait
        CGContextDrawImage(newContext, CGRectMake(0,0,480,640), newImage); //Landscape
        CGImageRelease(newImage);
        newImage = CGBitmapContextCreateImage(newContext);
        CGColorSpaceRelease( colorSpace );
        CGContextRelease(newContext);

    }
    
    if ( newImage != nil )
    {
           [self performSelectorOnMainThread:@selector(newCameraImageNotification:) withObject:(id)CFBridgingRelease(newImage) waitUntilDone:YES]; 
    }

    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
}



static BOOL processingTouchEvent = NO;

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{

}


- (IBAction)Save:(UIButton *)sender {
    {
        if ( processingTouchEvent )
            return;
        processingTouchEvent = YES;
        
        [self snapShot];
        
        processingTouchEvent = NO;
    }
}

- (IBAction)ShiftUp:(UIButton *)sender {
    // expand the temp range to scale around the center temp
    highTemp++;
    lowTemp--;
}

- (IBAction)ShiftDown:(UIButton *)sender {
    // shrink the temp range to scale around the center temp
    highTemp--;
    lowTemp++;
}

- (IBAction)CenterUp:(UIButton *)sender {
    // Raise the center temp to scale around
    highTemp++;
    lowTemp++;
}

- (IBAction)CenterDown:(UIButton *)sender {
    // Lower the center temp to scale around
    highTemp--;
    lowTemp--;
}

- (IBAction)OpacityUp:(UIButton *)sender {
    // Raise the Opacity of the layers
    opacity = opacity + 0.1;
}

- (IBAction)OpacityDown:(UIButton *)sender {
    //Lower the Opacity of the layers
    opacity = opacity - 0.1;
}

- (void)viewDidUnload {
    
    [self setOverlayView:nil];
    [super viewDidUnload];
}

- (void)irConfig {

    irSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
}


- (void)irConnectToHost {
    
    NSError * err = nil;
    
    useHost = HOST1;
    [irSocket connectToHost:useHost onPort:PORT error:&err];
    
}
- (void)irRequestData:(NSString*)command {
    
    NSString *requestStrFrmt = @"HEAD / HTTP/1.0\r\nHost: %@/%@\r\n\r\n";
	
	NSString *requestStr = [NSString stringWithFormat:requestStrFrmt, useHost, command];
	NSData *requestData = [requestStr dataUsingEncoding:NSUTF8StringEncoding];
    [irSocket writeData:requestData withTimeout:-1.0 tag:0];
    NSLog(@"Request %@",requestStr);
    
    NSData *responseTerminatorData = [@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];
	
	[irSocket readDataToData:responseTerminatorData withTimeout:-1.0 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    NSLog(@"Connected to %@ at port %hu",host,port);

        [self irRequestData:@"getdata"];
}


- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
	//NSLog(@"socket:didReadData:withTag:");
    NSString *httpResponse = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSData *responseTerminatorData = [@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];
    //NSLog(@"Full HTTP Response:\n%@", httpResponse);

    if (readingType) {
        if (readingCount < 8) {
            
          // Parse the EEPROM data and run initial calculations        
          [eepromData addObjectsFromArray:[httpResponse componentsSeparatedByString:@","]];
          readingCount++;
        
          // read more data
          NSLog(@"EEPROM Read %i", eepromData.count);
          [irSocket readDataToData:responseTerminatorData withTimeout:-1.0 tag:0];

        }
        else {
          //NSLog(@"Got all the eeprom data");
          [self processEEPROMData];
          readingType = 0; //set to irdata reading now
          [irSocket readDataToData:responseTerminatorData withTimeout:-1.0 tag:0];
        }
    }
    else {

    // Parse the sensor data and then update the display
    [sensorData removeAllObjects];
    [sensorData addObjectsFromArray:[httpResponse componentsSeparatedByString:@","]];
    //readingCount++;
    //NSLog(@"%i",readingCount);
    //[self update:sensorData];
        newData = 1;
        
    // read more data

    //[irSocket readDataToData:responseTerminatorData withTimeout:-1.0 tag:0];
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	// Since we requested HTTP/1.0, we expect the server to close the connection as soon as it has sent the response.
	
	NSLog(@"socketDidDisconnect:withError: \"%@\"", err);
    
    
}


@end