package com.opentok.qualitystats.sample;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.ProgressDialog;
import android.content.DialogInterface;
import android.os.Bundle;
import android.os.Handler;
import android.util.Log;

import com.opentok.android.OpentokError;
import com.opentok.android.Publisher;
import com.opentok.android.PublisherKit;
import com.opentok.android.Session;
import com.opentok.android.Stream;
import com.opentok.android.Subscriber;
import com.opentok.android.SubscriberKit;
import com.opentok.android.SubscriberKit.VideoStatsListener;

public class MainActivity extends Activity implements Session.SessionListener, PublisherKit.PublisherListener, SubscriberKit.SubscriberListener {

    private static final String LOGTAG = "quality-stats-demo";

    private static final String SESSION_ID = "2_MX4xMDB-fjE0MzM1MDEzMDE4OTN-bEt1Z1R4VDQ4TlhVc0V0UXpwVDlJbEhqfn4";
    private static final String TOKEN = "T1==cGFydG5lcl9pZD0xMDAmc2RrX3ZlcnNpb249dGJwaHAtdjAuOTEuMjAxMS0wNy0wNSZzaWc9N2VmZTZmMmRkMTcyOWIyOTMzNmFmZjFlNGM5M2ZlOWVhZWU3YTdlNzpzZXNzaW9uX2lkPTJfTVg0eE1EQi1makUwTXpNMU1ERXpNREU0T1ROLWJFdDFaMVI0VkRRNFRsaFZjMFYwVVhwd1ZEbEpiRWhxZm40JmNyZWF0ZV90aW1lPTE0MzM1MDA0MjAmcm9sZT1tb2RlcmF0b3Imbm9uY2U9MTQzMzUwMDQyMC43NzU3MTEwMDcxNTU1MSZleHBpcmVfdGltZT0xNDM2MDkyNDIw";
    private static final String APIKEY = "100";
    private static final boolean SUBSCRIBE_TO_SELF = true;

    private static final int TEST_DURATION = 20; //sec
    private static final int TIME_SEC = 1000; //1 sec

    private Session mSession;
    private Publisher mPublisher;
    private Subscriber mSubscriber;

    private boolean mConnected = false;

    private double mPrevAudioTimestamp = 0.0;
    private double mPrevAudioBytes = 0.0;
    private long mPacketsReceivedAudio = 0;
    private long mPacketsLostAudio = 0;
    private double mAudioPLRatio = 0.0;
    private long mVideoBw = 0;

    private double mPrevVideoTimestamp = 0.0;
    private double mPrevVideoBytes = 0.0;
    private long mPacketsReceivedVideo = 0;
    private long mPacketsLostVideo = 0;
    private double mVideoPLRatio = 0.0;
    private long mAudioBw = 0;

    private Handler mHandler = new Handler();

    private ProgressDialog mProgressDialog;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        sessionConnect();
    }

    @Override
    public void onBackPressed() {
        super.onBackPressed();

        if (mSession != null && mConnected) {
            mSession.disconnect();
        }
    }

    public void sessionConnect() {
        Log.i(LOGTAG, "Connecting session");

        if( mSession == null) {
            mSession = new Session(this, APIKEY, SESSION_ID);
            mSession.setSessionListener(this);

            mProgressDialog = ProgressDialog.show(this, "Checking your available bandwidth", "Please wait");
            final long startTime = System.currentTimeMillis();
            mSession.connect(TOKEN);
        }
    }

    private void subscribeToStream(Stream stream) {
        mSubscriber = new Subscriber(MainActivity.this, stream);

        mSubscriber.setSubscriberListener(this);
        mSession.subscribe(mSubscriber);
        mSubscriber.setVideoStatsListener(new VideoStatsListener() {

            @Override
            public void onVideoStats(SubscriberKit subscriber,
                                     SubscriberKit.SubscriberVideoStats stats) {

                checkVideoQuality(stats);
            }

        });

        mSubscriber.setAudioStatsListener(new SubscriberKit.AudioStatsListener() {
            @Override
            public void onAudioStats(SubscriberKit subscriber, SubscriberKit.SubscriberAudioStats stats) {

                checkAudioQuality(stats);
            }
        });
    }

    private void unsubscribeFromStream(Stream stream) {
        if (mSubscriber.getStream().equals(stream)) {
            mSubscriber = null;
        }
    }

    private void checkVideoQuality(SubscriberKit.SubscriberVideoStats stats) {

        if (mPacketsReceivedVideo != 0) {
            long pl = stats.videoPacketsLost - mPacketsLostVideo;
            long pr = stats.videoBytesReceived - mPacketsReceivedVideo;
            long pt = pl + pr;
            if (pt > 0) {
                mVideoPLRatio = (double) pl / (double) pt;
             }
        }

        mPacketsLostVideo = stats.videoPacketsLost;
        mPacketsReceivedVideo = stats.videoPacketsReceived;


        if (stats.timeStamp - mPrevVideoTimestamp >= TIME_SEC)
        {
            mVideoBw = (long) ((8 * (stats.videoBytesReceived - mPrevVideoBytes)) / ((stats.timeStamp - mPrevVideoTimestamp) / 1000));

            mPrevVideoTimestamp = stats.timeStamp;
            mPrevVideoBytes = stats.videoBytesReceived;

            Log.i(LOGTAG, "Video bandwidth: "+ mVideoBw + " Video Bytes received: "+stats.videoBytesReceived + " Video packet loss ratio: "+mVideoPLRatio);

        }

    }
    private void checkAudioQuality(SubscriberKit.SubscriberAudioStats stats) {

        if (mPacketsReceivedAudio != 0) {
            long pl = stats.audioPacketsLost - mPacketsLostAudio;
            long pr = stats.audioPacketsReceived - mPacketsReceivedAudio;
            long pt = pl + pr;
            if (pt > 0) {
                mAudioPLRatio = (double) pl / (double) pt;
            }
        }

        mPacketsLostAudio = stats.audioPacketsLost;
        mPacketsReceivedAudio = stats.audioPacketsReceived;


        if (stats.timeStamp - mPrevAudioTimestamp >= TIME_SEC)
        {
            mAudioBw = (long) ((8 * (stats.audioBytesReceived - mPrevAudioBytes)) / ((stats.timeStamp - mPrevAudioTimestamp) / 1000));

            mPrevAudioTimestamp = stats.timeStamp;
            mPrevAudioBytes = stats.audioBytesReceived;

            Log.i(LOGTAG, "Audio bandwidth: "+ mAudioBw + " Audio Bytes received: "+stats.audioBytesReceived + " Audio packet loss ratio: "+mAudioPLRatio);
        }
    }

    private void checkQuality(){
        if ( mSession != null ){
            //result qualitystats
            mProgressDialog.dismiss();
            Log.i(LOGTAG, "Check quality");

            if ( mVideoBw > 150000 || mVideoPLRatio < 3 || mAudioPLRatio < 3 ) {
                showAlert("All good", "You're all set!", android.R.drawable.ic_dialog_alert);
            }
            else {
                if ( mVideoBw > 30000 ) {
                    showAlert("Voice-only", "Your bandwidth is too low for video", android.R.drawable.ic_dialog_alert);
                }

                else {
                    if ( mVideoBw < 30000 || mVideoPLRatio > 3 || mAudioPLRatio > 3 ) {
                        showAlert("No good", "You can't successfully connect", android.R.drawable.ic_dialog_alert);
                    }
                }
            }
        }
    }

    private void showAlert(String title, String Message, int iconID){
        new AlertDialog.Builder(MainActivity.this)
                .setTitle(title)
                .setMessage(Message)
                .setPositiveButton(android.R.string.yes,
                        new DialogInterface.OnClickListener() {
                            public void onClick(DialogInterface dialog,
                                                int which) {
                                try {
                                    finish();
                                } catch (Throwable throwable) {
                                    throwable.printStackTrace();
                                }
                            }
                        }).setIcon(iconID)
                .show();
    }

    @Override
    public void onConnected(Session session) {
        Log.i(LOGTAG, "Session is connected");
        mConnected = true;

        mPublisher = new Publisher(this);
        mPublisher.setPublisherListener(this);
        mPublisher.setAudioFallbackEnabled(false);
        mSession.publish(mPublisher);

        // Reset stats
        mPacketsReceivedAudio = 0;
        mPacketsLostAudio = 0;
        mPacketsReceivedVideo = 0;
        mPacketsLostVideo = 0;
    }

    @Override
    public void onDisconnected(Session session) {
        Log.i(LOGTAG, "Session is disconnected");
        mConnected = false;

        mPublisher = null;
        mSubscriber = null;
        mSession = null;

        if (mProgressDialog != null && mProgressDialog.isShowing()) {
            mProgressDialog.dismiss();
        }
    }

    @Override
    public void onError(Session session, OpentokError opentokError) {
        Log.i(LOGTAG, "Session error: " + opentokError.getMessage());
        if (mProgressDialog != null && mProgressDialog.isShowing()) {
            mProgressDialog.dismiss();
        }
        showAlert("No good", "You can't successfully connect. Session error: " + opentokError.getMessage(), android.R.drawable.ic_dialog_alert);
    }

    @Override
    public void onStreamDropped(Session session, Stream stream) {
        Log.i(LOGTAG, "Session onStreamDropped");
        if (mSubscriber == null && !SUBSCRIBE_TO_SELF) {
            unsubscribeFromStream(stream);
        }
    }

    @Override
    public void onStreamReceived(Session session, Stream stream) {
        Log.i(LOGTAG, "Session onStreamReceived");
        if (mSubscriber == null && !SUBSCRIBE_TO_SELF) {
            subscribeToStream(stream);
        }
    }

    @Override
    public void onStreamCreated(PublisherKit publisherKit, Stream stream) {
        Log.i(LOGTAG, "Publisher onStreamCreated");
        if (mSubscriber == null && SUBSCRIBE_TO_SELF) {
            subscribeToStream(stream);
        }
    }
    @Override
    public void onStreamDestroyed(PublisherKit publisherKit, Stream stream) {
        Log.i(LOGTAG, "Publisher onStreamDestroyed");
        if (mSubscriber == null && SUBSCRIBE_TO_SELF) {
            unsubscribeFromStream(stream);
        }
    }

    @Override
    public void onError(PublisherKit publisherKit, OpentokError opentokError) {
        Log.i(LOGTAG, "Publisher error: " + opentokError.getMessage());
        if (mProgressDialog != null && mProgressDialog.isShowing()) {
            mProgressDialog.dismiss();
        }
        showAlert("No good", "You can't successfully connect. Publisher error: " + opentokError.getMessage(), android.R.drawable.ic_dialog_alert);
    }

    @Override
    public void onConnected(SubscriberKit subscriberKit) {
        Log.i(LOGTAG, "Subscriber onConnected");
        mHandler.postDelayed(statsRunnable, TEST_DURATION * 1000);
    }

    @Override
    public void onDisconnected(SubscriberKit subscriberKit) {
        Log.i(LOGTAG, "Subscriber onDisconnected");
    }

    @Override
    public void onError(SubscriberKit subscriberKit, OpentokError opentokError) {
        Log.i(LOGTAG, "Subscriber error: " + opentokError.getMessage());
        if (mProgressDialog != null && mProgressDialog.isShowing()) {
            mProgressDialog.dismiss();
        }
        showAlert("No good", "You can't successfully connect. Subscriber error: " + opentokError.getMessage(), android.R.drawable.ic_dialog_alert);
    }


    private Runnable statsRunnable = new Runnable(){

        @Override
        public void run() {
            checkQuality();
            mSession.disconnect();
        }
    };
}
