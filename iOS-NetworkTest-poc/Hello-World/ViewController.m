//
//  ViewController.m
//  Hello-World
//
//  Copyright (c) 2013 TokBox, Inc. All rights reserved.
//

#import "ViewController.h"
#import "OTNetworkTest.h"

// *** Fill the following variables using your own Project info  ***
// ***          https://dashboard.tokbox.com/projects            ***
// Replace with your OpenTok API key
static NSString* const kApiKey = @"";
// Replace with your generated session ID
static NSString* const kSessionId = @"";
// Replace with your generated token
static NSString* const kToken = @"";


#pragma mark - View lifecycle

@interface ViewController ()
<OTNetworkTestDelegate>

@end

@implementation ViewController {
    OTNetworkTest *_networkTest;
}

/**
 * canConnect - Whether I can connect or not
 * canPublish - This will be false when publisher fail to publish the stream
 *              as well as when bw < 150K
 * canSubscribe - This will be false when subscriber fail to subscribe the stream
 *                as well as when bw < 150K
 */
- (void)networkTestDidCompleteWithConnectResult:(BOOL)canConnect
                                publisherResult:(BOOL)canPublish
                               subscriberResult:(BOOL)canSubscribe
                                          error:(OTError*)error;
{
    NSLog(@"Test finished : canConnect %d, canPub %d, canSub %d, error %@",
          canConnect,canPublish,canSubscribe,error.localizedDescription);
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _networkTest = [[OTNetworkTest alloc] init];
    
    [_networkTest runConnectivityTestWithApiKey:kApiKey
                                      sessionId:kSessionId
                                          token:kToken
                             executeQualityTest:YES
                            qualityTestDuration:10
                                       delegate:self];
    
}

@end
