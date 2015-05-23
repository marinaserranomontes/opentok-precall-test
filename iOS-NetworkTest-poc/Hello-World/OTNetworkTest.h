//
//  OTNetworkTest.h
//  Hello-World
//
//  Created by Sridhar on 22/05/15.
//  Copyright (c) 2015 TokBox, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenTok/OpenTok.h>

@protocol OTNetworkTestDelegate;

@interface OTNetworkTest : NSObject
{
    
}
- (void)runConnectivityTestWithApiKey:(NSString*)apiKey
                           sessionId:(NSString*)sesssionId
                               token:(NSString*)token
                  executeQualityTest:(BOOL)needsQualityTest
                 qualityTestDuration:(int)qualityTestDuration
                            delegate:(id<OTNetworkTestDelegate>)delegate;
@end

@protocol OTNetworkTestDelegate <NSObject>

@optional

- (void)networkTestDidCompleteWithConnectResult:(BOOL)canConnect
                                 publisherResult:(BOOL)canPublish
                                subscriberResult:(BOOL)canSubscribe
                                           error:(OTError*)error;

@end

@interface OTNetworkTest ()

@property (nonatomic, assign)
id<OTNetworkTestDelegate> networkTestDelegate;

@end

