# cordova-plugin-rtmp-live-streamer

A cordova plugin that sends live video from your device to a server via RTMP

Based on https://github.com/LaiFengiOS/LFLiveKit

# Install

`$ cordova plugin add https://github.com/VarsitySoftware/cordova-plugin-rtmp-live-streamer`

# Usage Example

```html

var options = {
    videoWidth: "800",
    videoHeight: "480",
    videoBitRate: "819200", //(800 * 1024)
    videoMaxBitRate: "1024000", //(1000 * 1024)
    videoMinBitRate: "512000", //(500 * 1024)
    videoFrameRate: "24",
    videoMaxKeyframeInterval: "48",
    videoOrientation: "1", //1 = portrait, 2 = landscape
    rtmpServerURL: "rtmp://a.rtmp.youtube.com/live2/STREAMKEY",
    labelLive: "Live",
    labelViewers: "Viewers",
    labelNoQuestions: "No Questions",
    alertStopSessionTitle: "Alert",
    alertStopSessionYes: "Yes",
    alertStopSessionNo: "No",
    alertStopSessionMessage: "Are you sure you want to stop the session?",
    alertStartSessionTitle: "Alert",
    alertStartSessionOK: OK",
    alertStartSessionMessage: "Are you sure you want to start the session?",
    videoTitleStart: "Start",
    videoTitlePaused: "Paused",
    videoTitleEnd: "End"
};

var streamer = window.rtmpLiveStreamer;

streamer.start(
    (results) => {
        console.log('Results: ' + results);
    },
    (error) => {
        console.log('Error: ' + error);
    },
    options
);

streamer.stop(
    (results) => {
        console.log('Results: ' + results);
    },
    (error) => {
        console.log('Error: ' + error);
    },
    null
);
```

# Future Features

- [ ] Android support using Cordova RTMP/RTSP Streamer https://github.com/disono/cordova-rtmp-rtsp-stream
