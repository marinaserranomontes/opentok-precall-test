package com.opentok.qualitystats.sample;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.ProgressDialog;
import android.content.DialogInterface;
import android.os.Bundle;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.Toast;

import com.opentok.android.OpentokError;
import com.opentok.android.Publisher;
import com.opentok.android.Session;
import com.opentok.android.Session.NetworkTestListener;
import com.opentok.android.Session.SessionStats;
import com.opentok.android.Stream;
import com.opentok.android.Subscriber;
import com.opentok.android.SubscriberKit;
import com.opentok.android.SubscriberKit.SubscriberVideoStats;
import com.opentok.android.SubscriberKit.VideoStatsListener;

public class MainActivity extends Activity implements Session.SessionListener {

    public static final String SESSION_ID = "";
    public static final String TOKEN = "";
    public static final String APIKEY = "";

    Session mSession;
    Publisher mPublisher;
    Subscriber mSubscriber;

    LinearLayout mVideoLayout;

    Button mBtnContactSupport;

    boolean mConnected = false;
    boolean mAudioOnly = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        mSession = new Session(this, APIKEY, SESSION_ID);
        mSession.setSessionListener(this);

        mVideoLayout = (LinearLayout) findViewById(R.id.linearlayout1);
        mBtnContactSupport = (Button) findViewById(R.id.button1);
    }

    @Override
    protected void onDestroy() {
        mSession.disconnect();
        super.onDestroy();
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_main, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        // Handle action bar item clicks here. The action bar will
        // automatically handle clicks on the Home/Up button, so long
        // as you specify a parent activity in AndroidManifest.xml.
        int id = item.getItemId();
        if (id == R.id.action_settings) {
            return true;
        }
        return super.onOptionsItemSelected(item);
    }

    ProgressDialog progressDialog;

    public void onClickContactSupport(View v) {
        mBtnContactSupport.setEnabled(false);

        progressDialog = ProgressDialog.show(this, "Testing network...", "Please wait");
        final long startTime = System.currentTimeMillis();
        mSession.testNetwork(TOKEN, new NetworkTestListener() {
            @Override
            public void onNetworkTestCompleted(Session session,
                                               SessionStats stats) {

                if (stats.downloadBitsPerSecond < 50000) {
                    // Not enough bw available
                    progressDialog.dismiss();
                    new AlertDialog.Builder(MainActivity.this)
                            .setTitle("Poor network")
                            .setMessage("The quality of your network is not enough " +
                                    "to start a call, please try it again later " +
                                    "or connect to another network")
                            .setPositiveButton(android.R.string.yes,
                                    new DialogInterface.OnClickListener() {
                                        public void onClick(DialogInterface dialog,
                                                            int which) {
                                        }
                                    }).setIcon(android.R.drawable.ic_dialog_alert)
                            .show();

                } else {
                    if (stats.downloadBitsPerSecond < 150000) {
                        // Audio only
                        mAudioOnly = true;
                    } else {
                        // full video
                        mAudioOnly = false;
                    }
                    progressDialog.setTitle("Connecting...");
                    progressDialog.setMessage("Please wait");
                    mSession.connect(TOKEN);
                }
            }
        });
    }


    @Override
    public void onConnected(Session arg0) {
        mConnected = true;

        mPublisher = new Publisher(this);
        mSession.publish(mPublisher);
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(352,
                288);
        mVideoLayout.addView(mPublisher.getView(), params);

        // Reset stats
        mPacketsReceivedAudio = 0;
        mPacketsLostAudio = 0;

        progressDialog.setTitle("On queue...");
        progressDialog.setMessage("Waiting for a support engineer");
    }

    @Override
    public void onDisconnected(Session arg0) {
        mConnected = false;

        mVideoLayout.removeAllViews();
        mPublisher = null;
        mSubscriber = null;

        mBtnContactSupport.setEnabled(true);

        if (progressDialog != null && progressDialog.isShowing()) {
            progressDialog.dismiss();
        }
    }

    @Override
    public void onError(Session arg0, OpentokError arg1) {
        if (progressDialog != null && progressDialog.isShowing()) {
            progressDialog.dismiss();
        }
        Toast.makeText(this, "Session error: " + arg1.getMessage(),
                Toast.LENGTH_LONG).show();
    }

    @Override
    public void onStreamDropped(Session arg0, Stream stream) {
        if (mSubscriber != null && mSubscriber.getStream() == stream) {
            mVideoLayout.removeView(mSubscriber.getView());
            mSession.unsubscribe(mSubscriber);
            mSubscriber = null;
        }
    }

    long mPacketsReceivedAudio = 0;
    long mPacketsLostAudio = 0;

    @Override
    public void onStreamReceived(Session arg0, Stream stream) {
        if (mSubscriber == null) {
            if (progressDialog != null && progressDialog.isShowing()) {
                progressDialog.dismiss();
            }

            mSubscriber = new Subscriber(this, stream);

            if (mAudioOnly) {
                mSubscriber.setSubscribeToVideo(false);
            }

            mSession.subscribe(mSubscriber);
            LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                    352, 288);
            mVideoLayout.addView(mSubscriber.getView(), params);

            mSubscriber.setVideoStatsListener(new VideoStatsListener() {

                @Override
                public void onVideoStats(SubscriberKit arg0,
                                         SubscriberVideoStats stats) {
                }

            });

            mSubscriber.setAudioStatsListener(new SubscriberKit.AudioStatsListener() {
                @Override
                public void onAudioStats(SubscriberKit subscriberKit, SubscriberKit.SubscriberAudioStats stats) {
                    if (mPacketsReceivedAudio != 0) {
                        long pl = stats.audioPacketsLost - mPacketsLostAudio;
                        long pr = stats.audioPacketsReceived - mPacketsReceivedAudio;
                        long pt = pl + pr;
                        if (pt > 0) {
                            double ratio = (double) pl / (double) pt;
                            Log.d("QualityStatsSampleApp", "Packet loss ratio = " + ratio);
                            if (ratio > 0.05 && !mAudioOnly) {
                                Toast.makeText(MainActivity.this, "Disabling video due to bad network conditions",
                                        Toast.LENGTH_LONG).show();
                                if (mSubscriber != null) {
                                    mSubscriber.setSubscribeToVideo(false);
                                }
                                if (mPublisher != null) {
                                    mPublisher.setPublishVideo(false);
                                }
                            }
                        }
                    }
                    mPacketsLostAudio = stats.audioPacketsLost;
                    mPacketsReceivedAudio = stats.audioPacketsReceived;
                }
            });
        }

    }

}
