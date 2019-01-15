/*global cordova,window,console*/
/**
 * A RTMP Live Streamer plugin for Cordova
 * 
 * Developed by John Weaver for Varsity Software
 */

var RTMPLiveStreamer = function() {

};

RTMPLiveStreamer.prototype.start = function (success, fail, options)
{
	if (!options) {
		options = {};
    }

    console.log("RTMPLiveStreamer.prototype.start");

    return cordova.exec(success, fail, "RTMPLiveStreamer", "start", [options]);
};

RTMPLiveStreamer.prototype.stop = function (success, fail, options) {
    if (!options) {
        options = {};
    }

    return cordova.exec(success, fail, "RTMPLiveStreamer", "stop", [options]);
};

RTMPLiveStreamer.prototype.addQuestionsToList = function (success, fail, options) {
    if (!options) {
        options = {};
    }

    return cordova.exec(success, fail, "RTMPLiveStreamer", "addQuestionsToList", [options]);
};

RTMPLiveStreamer.prototype.updateViewerCount = function (success, fail, options) {
    if (!options) {
        options = {};
    }

    return cordova.exec(success, fail, "RTMPLiveStreamer", "updateViewerCount", [options]);
};

RTMPLiveStreamer.prototype.forceQuit = function (success, fail, options) {
    if (!options) {
        options = {};
    }

    return cordova.exec(success, fail, "RTMPLiveStreamer", "forceQuit", [options]);
};

window.rtmpLiveStreamer = new RTMPLiveStreamer();
