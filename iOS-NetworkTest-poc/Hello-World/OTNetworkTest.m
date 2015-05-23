//
//  OTNetworkTest.m
//  Hello-World
//
//  Created by Sridhar on 22/05/15.
//  Copyright (c) 2015 TokBox, Inc. All rights reserved.
//

#import "OTNetworkTest.h"
#import "OTNetworkStatsKit.h"

@interface OTNetworkTest ()
<OTSessionDelegate, OTSubscriberKitDelegate, OTPublisherDelegate,
OTSubscriberKitNetworkStatsDelegate >

@end

@implementation OTNetworkTest {
    OTSession* _session;
    OTPublisher* _publisher;
    OTSubscriber* _subscriber;
    NSTimer *_sampleTimer;
    NSString *_token;
    BOOL _runQualityStatsTest;
    int _qualityTestDuration;
    BOOL isConnected;
    BOOL isPublishing;
    BOOL isSubscribing;
    OTError *_error;
    double prevVideoTimestamp ;
    double prevVideoBytes ;
    long bw;
    

}

- (void)runConnectivityTestWithApiKey:(NSString*)apiKey
                           sessionId:(NSString*)sesssionId
                               token:(NSString*)token
                  executeQualityTest:(BOOL)needsQualityTest
                 qualityTestDuration:(int)qualityTestDuration
                            delegate:(id<OTNetworkTestDelegate>)delegate
{
    
    prevVideoTimestamp = prevVideoBytes = 0.0;
    
    _token = [token copy];
    _runQualityStatsTest = needsQualityTest;
    _qualityTestDuration = qualityTestDuration;
    self.networkTestDelegate = delegate;
    
    _session = [[OTSession alloc] initWithApiKey:apiKey
                                       sessionId:sesssionId
                                        delegate:self];
    [self doConnect];
}

-(void)dispatchResultsToDelegateWithConnectResult:(BOOL)canConnect
                                    publishResult:(BOOL)canPublish
                                  subscribeResult:(BOOL)canSubsribe
                                            error:(OTError*)error
{
    if(canConnect && _session)
    {
        // Will report result from sessionDidDisconnect callback
        // The callback will in term call the delegate
        isConnected = canConnect;
        isPublishing = canPublish;
        isSubscribing = canSubsribe;
        _error = [error copy];
        [_session disconnect:nil];
    } else
    {
        if ([self.networkTestDelegate
             respondsToSelector:@selector(networkTestDidCompleteWithConnectResult:
                                          publisherResult:subscriberResult:error:)])
        {
            [self.networkTestDelegate networkTestDidCompleteWithConnectResult:canConnect
                                                               publisherResult:canPublish
                                                              subscriberResult:canSubsribe
                                                                         error:error];
        }
        [self cleanupSession];
    }
}

#pragma mark - OpenTok methods

/**
 * Asynchronously begins the session connect process. Some time later, we will
 * expect a delegate method to call us back with the results of this action.
 */
- (void)doConnect
{
    OTError *error = nil;
    
    [_session connectWithToken:_token error:&error];
    if (error)
    {
        [self dispatchResultsToDelegateWithConnectResult:NO
                                           publishResult:NO
                                         subscribeResult:NO
                                                   error:error];
    }
}

- (void)cleanupSession {
    _session = nil;
    _publisher = nil;
    _subscriber = nil;
    _token = nil;
    _error = nil;
    isConnected = NO;
    isPublishing = NO;
    isSubscribing = NO;
    // this is a good place to notify the end-user that publishing has stopped.
}

/**
 * Sets up an instance of OTPublisher to use with this session. OTPubilsher
 * binds to the device camera and microphone, and will provide A/V streams
 * to the OpenTok session.
 */
- (void)doPublish
{
    _publisher =
    [[OTPublisher alloc] initWithDelegate:self
                                     name:[[UIDevice currentDevice] name]];
    OTError *error = nil;
    [_session publish:_publisher error:&error];
    if (error)
    {
        [self dispatchResultsToDelegateWithConnectResult:YES
                                           publishResult:NO
                                         subscribeResult:NO
                                                   error:error];
    }
}

/**
 * Cleans up the publisher and its view. At this point, the publisher should not
 * be attached to the session any more.
 */
- (void)cleanupPublisher {
    _publisher = nil;
    // this is a good place to notify the end-user that publishing has stopped.
}

/**
 * Instantiates a subscriber for the given stream and asynchronously begins the
 * process to begin receiving A/V content for this stream. Unlike doPublish,
 * this method does not add the subscriber to the view hierarchy. Instead, we
 * add the subscriber only after it has connected and begins receiving data.
 */
- (void)doSubscribe:(OTStream*)stream
{
    _subscriber = [[OTSubscriber alloc] initWithStream:stream delegate:self];
    _subscriber.networkStatsDelegate = self;
    
    OTError *error = nil;
    [_session subscribe:_subscriber error:&error];
    if (error)
    {
        [self dispatchResultsToDelegateWithConnectResult:YES
                                           publishResult:YES
                                         subscribeResult:NO
                                                   error:error];
    }   
}

/**
 * Cleans the subscriber from the view hierarchy, if any.
 * NB: You do *not* have to call unsubscribe in your controller in response to
 * a streamDestroyed event. Any subscribers (or the publisher) for a stream will
 * be automatically removed from the session during cleanup of the stream.
 */
- (void)cleanupSubscriber
{
    _subscriber = nil;
}

- (void)subscriber:(OTSubscriberKit*)subscriber
videoNetworkStatsUpdated:(OTSubscriberKitVideoNetworkStats*)stats
{
    if (prevVideoTimestamp == 0)
    {
        prevVideoTimestamp = stats.timestamp;
        prevVideoBytes = stats.videoBytesReceived;
    }
    
    int timeDelta = 1000; // 1 second
    if (stats.timestamp - prevVideoTimestamp >= timeDelta)
    {
        bw = (8 * (stats.videoBytesReceived - prevVideoBytes)) / ((stats.timestamp - prevVideoTimestamp) / 1000ull);
        
        NSLog(@"videoBytesReceived %llu, bps %ld",stats.videoBytesReceived, bw);
        prevVideoTimestamp = stats.timestamp;
        prevVideoBytes = stats.videoBytesReceived;
    }
}

# pragma mark - OTSession delegate callbacks

- (void)sessionDidConnect:(OTSession*)session
{
    NSLog(@"sessionDidConnect (%@)", session.sessionId);
    
    // Step 2: We have successfully connected, now instantiate a publisher and
    // begin pushing A/V streams into OpenTok.
    [self doPublish];
}

- (void)sessionDidDisconnect:(OTSession*)session
{
    NSString* alertMessage =
    [NSString stringWithFormat:@"Session disconnected: (%@)",
     session.sessionId];
    NSLog(@"sessionDidDisconnect (%@)", alertMessage);
    
    bool canPub = isPublishing;
    bool canSub = isSubscribing;
    OTError *error = [_error copy];

    [self cleanupSession];
    
    [self dispatchResultsToDelegateWithConnectResult:YES
                                       publishResult:canPub
                                     subscribeResult:canSub
                                               error:error];
}


- (void)session:(OTSession*)mySession
  streamCreated:(OTStream *)stream
{
    NSLog(@"session streamCreated (%@)", stream.streamId);
}

- (void)session:(OTSession*)session
streamDestroyed:(OTStream *)stream
{
    NSLog(@"session streamDestroyed (%@)", stream.streamId);
    
    if ([_subscriber.stream.streamId isEqualToString:stream.streamId])
    {
        [self cleanupSubscriber];
    }
}

- (void)  session:(OTSession *)session
connectionCreated:(OTConnection *)connection
{
    NSLog(@"session connectionCreated (%@)", connection.connectionId);
}

- (void)    session:(OTSession *)session
connectionDestroyed:(OTConnection *)connection
{
    NSLog(@"session connectionDestroyed (%@)", connection.connectionId);
    if ([_subscriber.stream.connection.connectionId
         isEqualToString:connection.connectionId])
    {
        [self cleanupSubscriber];
    }
}

- (void) session:(OTSession*)session
didFailWithError:(OTError*)error
{
    NSLog(@"didFailWithError: (%@)", error);
    [self dispatchResultsToDelegateWithConnectResult:NO
                                       publishResult:NO
                                     subscribeResult:NO
                                               error:error];
}

# pragma mark - OTSubscriber delegate callbacks

- (void)subscriberDidConnectToStream:(OTSubscriberKit*)subscriber
{
    NSLog(@"subscriberDidConnectToStream (%@)",
          subscriber.stream.connection.connectionId);
    assert(_subscriber == subscriber);

    if(!_runQualityStatsTest)
    {
        isConnected = YES;
        isPublishing = YES;
        isSubscribing = YES;
        [_session disconnect:nil];
    } else
    {
        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW,
                                              _qualityTestDuration * NSEC_PER_SEC);
        dispatch_after(delay,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
            isConnected = YES;
            isPublishing =  (bw < 150000) ? NO : YES;
            isSubscribing = (bw < 150000) ? NO : YES;
            if(!isPublishing)
            {
                NSDictionary* userInfo = [NSDictionary
                                          dictionaryWithObjectsAndKeys:@"The quality of your network is not enough "
                                          "to start a call, please try it again later "
                                          "or connect to another network",
                                          NSLocalizedDescriptionKey,
                                          nil];
                _error = [[OTError alloc] initWithDomain:@"OTSubscriber"
                                                            code:-1
                                                        userInfo:userInfo];
            }
            [_session disconnect:nil];
        });
    }
}

- (void)subscriber:(OTSubscriberKit*)subscriber
  didFailWithError:(OTError*)error
{
    NSLog(@"subscriber %@ didFailWithError %@",
          subscriber.stream.streamId,
          error);
    [self dispatchResultsToDelegateWithConnectResult:YES
                                       publishResult:YES
                                     subscribeResult:NO
                                               error:error];

}

# pragma mark - OTPublisher delegate callbacks

- (void)publisher:(OTPublisherKit *)publisher
    streamCreated:(OTStream *)stream
{
    [self doSubscribe:stream];
}

- (void)publisher:(OTPublisherKit*)publisher
  streamDestroyed:(OTStream *)stream
{
    if ([_subscriber.stream.streamId isEqualToString:stream.streamId])
    {
        [self cleanupSubscriber];
    }
    
    [self cleanupPublisher];
}

- (void)publisher:(OTPublisherKit*)publisher
 didFailWithError:(OTError*) error
{
    NSLog(@"publisher didFailWithError %@", error);
    [self cleanupPublisher];
    [self dispatchResultsToDelegateWithConnectResult:YES
                                       publishResult:NO
                                     subscribeResult:NO
                                               error:error];
}

@end
