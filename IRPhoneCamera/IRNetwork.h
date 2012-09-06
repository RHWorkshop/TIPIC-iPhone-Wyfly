//
//  IRNetwork.h
//  IRPhoneCamera
//
//  Created by Andy Rawson on 8/23/12.
//  Copyright (c) 2012 RH Workshop.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"

@interface IRNetwork : NSObject
{
    GCDAsyncSocket *socket;
}


- (void)initialConfig:(NSString*)Host1 :(NSString*)Host2 :(int)Port;
- (void)connectToHost;
- (void)RequestIRData;
@end
