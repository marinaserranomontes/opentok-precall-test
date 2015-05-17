(function() {
  var MIN_BW = 30000, // Minimum bandwidth required to use OpenTok in audio-only mode
    MIN_BW_FOR_VIDEO = 150000999999999999, // Minimum bandwidth required to use video and audio chat
    STATS_FREQUENCY = 5000, // How often to check the Subscriber stats
    MAX_PACKETLOSS_RATIO = 0,
    message = document.querySelector('#message');

  var showMessage = function(msg) {
    message.innerHTML += msg + '<br/>';
  };
  var showError = function(err) {
    showMessage('<strong>Error:</strong>' + err.message);
  };
  // Monitor the Subscriber and if the audio packet loss ratio
  // goes over MAX_PACKET_LOSS_RATIO then disable the video
  var monitorSubscriber = function(subscriber) {
    showMessage('Monitoring new Subscriber');
    var prevStats;
    var checkStats = function () {
      subscriber.getStats(function (err, stats) {
        if (err) {
          showError(err);
        } else {
          if (prevStats && prevStats.audio) {
            var packetsLost = stats.audio.packetsLost - prevStats.audio.packetsLost,
              totalPackets = stats.audio.packetsReceived - prevStats.audio.packetsReceived,
              packetLossRatio = packetsLost / totalPackets;
            if(packetLossRatio > MAX_PACKETLOSS_RATIO) {
              showMessage('Packet loss ratio (' + packetLossRatio + ') is too high, dropping video');
              subscriber.subscribeToVideo(false);
            } else {
              subscriber.subscribeToVideo(true);
            }
          }
          prevStats = stats;
          
          setTimeout(checkStats, STATS_FREQUENCY);
        }
      });
    };
    checkStats();
  };

  var connectToSession = function () {
    session.connect(config.token, function (err) {
      if (err) {
        showError(err);
      } else {
        showMessage('Connected to session');
        session.publish(publisher);
      }
    });
  };

  var session = OT.initSession(config.apiKey, config.sessionId),
    subscribeToVideo = true,
    publisher = OT.initPublisher('publisher', {
      insertMode: 'append',
      width: '100%',
      height: '100%'
    }, function(err) {
      if (err) {
        showError(err);
      } else {
        showMessage('Testing network...');
        session.testNetwork(config.token, publisher, function(err, stats) {
          if (err) {
            showError(err);
          } else {
            // Display the stats
            var statsMsg = 'Test complete:<br/>';
            for(var key in stats) {
              if (stats.hasOwnProperty(key)) {
                statsMsg += '<strong>' + key + ':</strong> ' + stats[key] + '<br/>';
              }
            }
            showMessage(statsMsg);
            if (stats.downloadBitsPerSecond < MIN_BW) {
              showMessage('The download bitrate is not good enough for video chat.');
            } else {
              showMessage('Your bitrate is good enough to use OpenTok');
              if (stats.downloadBitsPerSecond < MIN_BW_FOR_VIDEO) {
                showMessage('Your download bitrate is not good enough for video, using audio only.');
                subscribeToVideo = false;
              }
              if (stats.uploadBitsPerSecond < MIN_BW_FOR_VIDEO) {
                showMessage('Your upload bitrate is not good enough for video, using audio only.');
                publisher.publishVideo(false);
              }
            }
            // Connect to the session
            connectToSession();
          }
        });
      }
    });
  showMessage('Please allow access to your camera and microphone');

  session.on('streamCreated', function(event) {
    var subscriber = session.subscribe(event.stream, 'subscribers', {
      subscribeToVideo: subscribeToVideo,
      insertMode: 'append'
    }, function(err) {
      if (err) {
        showError(err);
      } else if (subscribeToVideo) {
        monitorSubscriber(subscriber);
      }
    });
  });

})();
