//
//  IRNetwork.m
//  IRPhoneCamera
//
//  Created by Andy Rawson on 8/23/12.
//  Copyright (c) 2012 RH Workshop. 
//

#import "IRNetwork.h"


NSString *irHost1;
NSString *irHost2;
int irPort;
NSString *useHost;
NSString *command;

@class IRViewController;
@class GCDAsyncSocket;

@interface IRNetwork() {
}
  - (void)initialConfig:(NSString*)Host1 :(NSString*)Host2 :(int)Port;
  - (void)RequestIRData;
  - (void)connectToHost;

@end


@implementation IRNetwork


- (void)initialConfig:(NSString*)Host1 :(NSString*)Host2 :(int)Port {
    irHost1 = Host1;
    irHost2 = Host2;
    irPort = Port;
     socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()]; 
}

- (void)connectToHost {
    

    NSError *err = nil;
    useHost = irHost1;
    if (![socket connectToHost:useHost onPort:irPort error:&err])
    {
        useHost = irHost2;
        NSLog(@"Error Connecting: %@", err);
        NSLog(@"Trying second Host address: %@",useHost);
        [socket connectToHost:useHost onPort:irPort error:&err];
    }

}

- (void)RequestIRData {

    command = @"irdata";
    NSString *requestStrFrmt = @"HEAD / HTTP/1.0\r\nHost: %@/%@\r\n\r\n";
	
	NSString *requestStr = [NSString stringWithFormat:requestStrFrmt, useHost, command];
	NSData *requestData = [requestStr dataUsingEncoding:NSUTF8StringEncoding];
	
	[socket writeData:requestData withTimeout:-1.0 tag:0];
    NSLog(@"Request %@",requestStr);
    
}

- (void)socket:(GCDAsyncSocket *)sender didConnectToHost:(NSString *)host port:(UInt16)port
{
    NSLog(@"Connected to %@ at port %hu",host,port);

}

#define IR_DATA_READ_START 1
#define PTAT_DATA_READ_START 2
#define TGC_DATA_READ_START 3

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
	NSLog(@"socket:didReadData:withTag:");
	
	NSString *httpResponse = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	
#if READ_HEADER_LINE_BY_LINE
	
	NSLog(@"Line httpResponse: %@", httpResponse);
	
	// As per the http protocol, we know the header is terminated with two CRLF's.
	// In other words, an empty line.
	
	if ([data length] == 2) // 2 bytes = CRLF
	{
		DDLogInfo(@"<done>");
	}
	else
	{
		// Read the next line of the header
		[asyncSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1.0 tag:0];
	}
	
#else
	
	NSLog(@"Full HTTP Response:\n%@", httpResponse);
	
#endif
	
}


//- (void)socket:(GCDAsyncSocket *)sender didReadData:(NSData *)data withTag:(long)tag
//{
//    if (tag == IR_DATA_READ_START)
//    {
//
//        NSData *term = [@"END" dataUsingEncoding:NSUTF8StringEncoding];
//        [socket readDataToData:term withTimeout:-1 tag:IR_DATA_READ_START];
//        //int bodyLength = [self parseHttpHeader:data];
//        //[socket readDataToLength:bodyLength withTimeout:-1 tag:HTTP_BODY];
//    }
//    else if (tag == PTAT_DATA_READ_START)
//    {
//
//
//
//
//        // Process response
//        [self processHttpBody:data];
//
//        // Read header of next response
//        //NSData *term = [@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
//        //[socket readDataToData:term withTimeout:-1 tag:HTTP_HEADER];
//    }
//}



- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	// Since we requested HTTP/1.0, we expect the server to close the connection as soon as it has sent the response.
	
	NSLog(@"socketDidDisconnect:withError: \"%@\"", err);
}
@end
