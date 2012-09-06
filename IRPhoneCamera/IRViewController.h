//
//  ViewController.h
//  AugCam
//
//  Created by John Carter on 1/26/2012.
//  Modified by Andy Rawson on 7/18/2012
//


enum    {
    VIEWSOURCE_UIIMAGEVIEW = 1,
    //    VIEWSOURCE_OPENGLVIEW,
};


enum    {
    CameraDeviceSetting640x480 = 0,
    CameraDeviceSettingHigh = 1,
    CameraDeviceSettingMedium = 2,
    CameraDeviceSettingLow = 3,
};


#import <UIKit/UIKit.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <MobileCoreServices/UTType.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreFoundation/CoreFoundation.h>
#import "IRViewOverlay.h"
#import "GCDAsyncSocket.h"
#import "MLX90620Math.h"
//#import "IRNetwork.h"



@interface IRViewController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate>
{
    BOOL ignoreImageStream;
    
        long tag;
    //GCDAsyncSocket *tcpSocket;
    // Device Information
    //
    
    int cameraCount;
    int currentCameraDeviceIndex;
    int frontCameraDeviceIndex;
    int backCameraDeviceIndex;
    int cameraImageOrientation;
    GCDAsyncSocket *irSocket;
    UIInterfaceOrientation currentDeviceOrientation;
    
    
    // test layers for augmented screen capture
    //
    UIImageView *backingLayer;
    UIImageView *overlayLayer;
    
    
    // The primary View for image capture
    // and it's cooresponding view for display
    //
    int currentViewSource;      // 1=cameraView
    UIView *displayView;
    
    
    AVCaptureDeviceInput *captureInput;
    AVCaptureVideoDataOutput *captureOutput;
    AVCaptureSession *captureSession;
    AVCaptureVideoPreviewLayer *cameraPreviewLayer;
    NSDictionary* videoSettings;
    NSNumber *pixelFormatCode;
    NSString *pixelFormatKey;
    int cameraDeviceSetting;
    

    UIImageView *cameraView;
    UIImage *cameraImage;
    UIImage *cameraImage0;
    UIImage *cameraImage1;
    
}

- (IBAction)Save:(UIButton *)sender;
- (IBAction)ShiftUp:(UIButton *)sender;
- (IBAction)ShiftDown:(UIButton *)sender;
- (IBAction)CenterUp:(UIButton *)sender;
- (IBAction)CenterDown:(UIButton *)sender;
- (IBAction)OpacityUp:(UIButton *)sender;
- (IBAction)OpacityDown:(UIButton *)sender;

- (void)irConnectToHost;

@property (readonly) UIImage *cameraImage;
@property (readonly) int cameraImageOrientation;
@property (weak, nonatomic) IBOutlet IRViewOverlay *overlayView;


@end