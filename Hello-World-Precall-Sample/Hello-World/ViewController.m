//
//  ViewController.m
//  Hello-World
//
//  Copyright (c) 2013 TokBox, Inc. All rights reserved.
//

#import "ViewController.h"
#import <OpenTok/OpenTok.h>
#import "OTNetworkStatsKit.h"

@interface ViewController ()
<OTSessionDelegate, OTSubscriberKitDelegate, OTPublisherDelegate, OTSubscriberKitNetworkStatsDelegate>

@end

@implementation ViewController {
    OTSession* _session;
    OTPublisher* _publisher;
    OTSubscriber* _subscriber;
}
static double widgetHeight = 240;
static double widgetWidth = 320;

// *** Fill the following variables using your own Project info  ***
// ***          https://dashboard.tokbox.com/projects            ***
// Replace with your OpenTok API key
static NSString* const kApiKey = @"";
// Replace with your generated session ID
static NSString* const kSessionId = @"";
// Replace with your generated token
static NSString* const kToken = @"";

// Change to NO to subscribe to streams other than your own.
static bool subscribeToSelf = YES;

NSDate *startDate = nil;
bool canSubscribeVideo = true;
bool canPublishVideo = true;
bool isPublishingVideo = true;
bool isSubscribingVideo = true;

double prevVideoTimestamp = 0;
double prevVideoBytes = 0;
double prevAudioTimestamp = 0;
double prevAudioBytes = 0;
uint64_t prevVideoPacketsLost = 0;
uint64_t prevVideoPacketsRcvd = 0;
uint64_t prevAudioPacketsLost = 0;
uint64_t prevAudioPacketsRcvd = 0;

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Step 1: As the view comes into the foreground, initialize a new instance
    // of OTSession and begin the connection process.
    _session = [[OTSession alloc] initWithApiKey:kApiKey
                                       sessionId:kSessionId
                                        delegate:self];
    
    startDate = [NSDate date];
    OTError *error = nil;
    [_session testNetworkWithToken:kToken error:&error];
    if (error != nil)
    {
        NSLog(@"Test network failed with error %@",error.description);
    } else
    {
        NSLog(@"Started precall network test");
    }
}

- (void)session:(OTSession*)session
networkTestCompletedWithResult:(OTSessionNetworkStats*)result;
{
    NSTimeInterval timeTook = [[NSDate date] timeIntervalSinceDate:startDate];
    NSLog(@"precall uploadBitsPerSecond %f",result.uploadBitsPerSecond);
    NSLog(@"precall downloadBitsPerSecond %f",result.downloadBitsPerSecond);
    NSLog(@"precall roundTripTimeMilliseconds %f",result.roundTripTimeMilliseconds);
    NSLog(@"precall packetLossRatio %f",result.packetLossRatio);
    NSLog(@"Ended precall network test, took time %.2f seconds",timeTook);
    
    if (result.downloadBitsPerSecond < 30000) {
        // Not enough bw available
        [self showAlert:@"The quality of your network is not enough "
         "to start a call, please try it again later "
         "or connect to another network"];
    } else {
        canSubscribeVideo = (result.downloadBitsPerSecond < 150000) ?
        false : true;
        canPublishVideo = (result.uploadBitsPerSecond < 150000) ?
        false : true;
        [self doConnect];
    }
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
        long bw = 0;
        bw = (8 * (stats.videoBytesReceived - prevVideoBytes)) / ((stats.timestamp - prevVideoTimestamp) / 1000ull);
        
        NSLog(@"videoBytesReceived %llu, bps %ld",stats.videoBytesReceived, bw);
        prevVideoTimestamp = stats.timestamp;
        prevVideoBytes = stats.videoBytesReceived;
        [self checkQuality:stats];
    }
    
}

- (void)subscriber:(OTSubscriberKit*)subscriber
audioNetworkStatsUpdated:(OTSubscriberKitAudioNetworkStats*)stats
{
    if (prevAudioTimestamp == 0)
    {
        prevAudioTimestamp = stats.timestamp;
        prevAudioBytes = stats.audioBytesReceived;
    }
    
    int timeDelta = 1000; // 1 second
    if (stats.timestamp - prevAudioTimestamp >= timeDelta)
    {
        long bw = 0;
        bw = (8 * (stats.audioBytesReceived - prevAudioBytes)) / ((stats.timestamp - prevAudioTimestamp) / 1000ull);
        
        NSLog(@"audioBytesReceived %llu, bps %ld",stats.audioBytesReceived, bw);
        prevAudioTimestamp = stats.timestamp;
        prevAudioBytes = stats.audioBytesReceived;
        [self checkQuality:stats];
    }
    
}

- (void)checkQuality:(id)stats
{
    double ratio = -1;
    if ([stats isKindOfClass:[OTSubscriberKitVideoNetworkStats class]])
    {
        OTSubscriberKitVideoNetworkStats *videoStats =
        (OTSubscriberKitVideoNetworkStats *) stats;
        if (prevVideoPacketsRcvd != 0) {
            uint64_t pl = videoStats.videoPacketsLost - prevVideoPacketsLost;
            uint64_t pr = videoStats.videoPacketsReceived - prevVideoPacketsRcvd;
            uint64_t pt = pl + pr;
            if (pt > 0)
                ratio = (double) pl / (double) pt;
        }
        prevVideoPacketsLost = videoStats.videoPacketsLost;
        prevVideoPacketsRcvd = videoStats.videoPacketsReceived;
    }
    if ([stats isKindOfClass:[OTSubscriberKitAudioNetworkStats class]])
    {
        OTSubscriberKitAudioNetworkStats *audioStats =
        (OTSubscriberKitAudioNetworkStats *) stats;
        if (prevAudioPacketsRcvd != 0) {
            uint64_t pl = audioStats.audioPacketsLost - prevAudioPacketsLost;
            uint64_t pr = audioStats.audioPacketsReceived - prevAudioPacketsRcvd;
            uint64_t pt = pl + pr;
            if (pt > 0)
                ratio = (double) pl / (double) pt;
        }
        prevAudioPacketsLost = audioStats.audioPacketsLost;
        prevAudioPacketsRcvd = audioStats.audioPacketsReceived;
    }
    
    if (ratio >= 0)
    {
        if (ratio > 3.0f) {
            NSLog(@"Disabling video due to bad network conditions, pl :%.2f",ratio);
            if (isSubscribingVideo)
                _subscriber.subscribeToVideo = isSubscribingVideo = false;
            if (isPublishingVideo)
                _publisher.publishVideo = isPublishingVideo = false;
        } else
        {
            if (!isSubscribingVideo || !isPublishingVideo)
                NSLog(@"Network conditions improved, Enabling video, pl :%.2f",ratio);
            if (!isSubscribingVideo)
                _subscriber.subscribeToVideo = isSubscribingVideo = true;
            if (!isPublishingVideo)
                _publisher.publishVideo = isPublishingVideo = true;
        }
    }

}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:
(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    if (UIUserInterfaceIdiomPhone == [[UIDevice currentDevice]
                                      userInterfaceIdiom])
    {
        return NO;
    } else {
        return YES;
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
    
    [_session connectWithToken:kToken error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }
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

    _publisher.publishVideo = canPublishVideo;
    isPublishingVideo = _publisher.publishVideo;
    
    OTError *error = nil;
    [_session publish:_publisher error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }
    
    [self.view addSubview:_publisher.view];
    [_publisher.view setFrame:CGRectMake(0, 0, widgetWidth, widgetHeight)];
}

/**
 * Cleans up the publisher and its view. At this point, the publisher should not
 * be attached to the session any more.
 */
- (void)cleanupPublisher {
    [_publisher.view removeFromSuperview];
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
    
    _subscriber.subscribeToVideo = canSubscribeVideo;
    isSubscribingVideo = _subscriber.subscribeToVideo;
    
    OTError *error = nil;
    [_session subscribe:_subscriber error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
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
    [_subscriber.view removeFromSuperview];
    _subscriber = nil;
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
}


- (void)session:(OTSession*)mySession
  streamCreated:(OTStream *)stream
{
    NSLog(@"session streamCreated (%@)", stream.streamId);
    
    // Step 3a: (if NO == subscribeToSelf): Begin subscribing to a stream we
    // have seen on the OpenTok session.
    if (nil == _subscriber && !subscribeToSelf)
    {
        [self doSubscribe:stream];
    }
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
}

# pragma mark - OTSubscriber delegate callbacks

- (void)subscriberDidConnectToStream:(OTSubscriberKit*)subscriber
{
    NSLog(@"subscriberDidConnectToStream (%@)",
          subscriber.stream.connection.connectionId);
    assert(_subscriber == subscriber);
    [_subscriber.view setFrame:CGRectMake(0, widgetHeight, widgetWidth,
                                          widgetHeight)];
    [self.view addSubview:_subscriber.view];
}

- (void)subscriber:(OTSubscriberKit*)subscriber
  didFailWithError:(OTError*)error
{
    NSLog(@"subscriber %@ didFailWithError %@",
          subscriber.stream.streamId,
          error);
}

# pragma mark - OTPublisher delegate callbacks

- (void)publisher:(OTPublisherKit *)publisher
    streamCreated:(OTStream *)stream
{
    // Step 3b: (if YES == subscribeToSelf): Our own publisher is now visible to
    // all participants in the OpenTok session. We will attempt to subscribe to
    // our own stream. Expect to see a slight delay in the subscriber video and
    // an echo of the audio coming from the device microphone.
    if (nil == _subscriber && subscribeToSelf)
    {
        [self doSubscribe:stream];
    }
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
}

- (void)showAlert:(NSString *)string
{
    // show alertview on main UI
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"OTError"
                                                        message:string
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil] ;
        [alert show];
    });
}

@end
