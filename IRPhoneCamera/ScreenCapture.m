//
//  ScreenCapture.m
//  AugCam
//
//  Created by John Carter on 1/26/2012.
//  Modified by Andy Rawson on 7/18/2012
//

#import "ScreenCapture.h"

#import <QuartzCore/CABase.h>
#import <QuartzCore/CATransform3D.h>
#import <QuartzCore/CALayer.h>
#import <QuartzCore/CAScrollLayer.h>


@implementation ScreenCapture

+ (UIImage *) UIViewToImage:(UIView *)view
{
    // Create a graphics context with the target size
    // On iOS 4 and later, use UIGraphicsBeginImageContextWithOptions to take the scale into consideration
    // On iOS prior to 4, fall back to use UIGraphicsBeginImageContext
    
    // camera image size extended to screen ratio so it captures the entire screen
    //

    CGSize imageSize = CGSizeMake( (CGFloat)640.0, (CGFloat)480.0 ); //Landscape
    if (NULL != UIGraphicsBeginImageContextWithOptions)
        UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0);
    else
        UIGraphicsBeginImageContext(imageSize);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Start with the view...
    //
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, [view center].x, [view center].y);
    CGContextConcatCTM(context, [view transform]);
    CGContextTranslateCTM(context,-[view bounds].size.width * [[view layer] anchorPoint].x,-[view bounds].size.height * [[view layer] anchorPoint].y);
    [[view layer] renderInContext:context];
    CGContextRestoreGState(context);
    
    // ...then repeat for every subview from back to front
    //
    for (UIView *subView in [view subviews])
    {
        if ( [subView respondsToSelector:@selector(screen)] )
            if ( [(UIWindow *)subView screen] == [UIScreen mainScreen] )
                continue;
        
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, [subView center].x, [subView center].y);
        CGContextConcatCTM(context, [subView transform]);
        CGContextTranslateCTM(context,-[subView bounds].size.width * [[subView layer] anchorPoint].x,-[subView bounds].size.height * [[subView layer] anchorPoint].y);
        [[subView layer] renderInContext:context];
        CGContextRestoreGState(context);
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();   // autoreleased image
    
    UIGraphicsEndImageContext();
    
    return image;
}


@end