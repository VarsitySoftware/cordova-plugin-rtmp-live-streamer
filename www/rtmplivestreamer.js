/*global cordova,window,console*/
/**
 * A RTMP Live Streamer plugin for Cordova
 * 
 * Developed by John Weaver for Varsity Software
 */

var RTMPLiveStreamer = function() {

};

RTMPLiveStreamer.prototype.launch = function(success, fail, options) {
	if (!options) {
		options = {};
	}

	return cordova.exec(success, fail, "RTMPLiveStreamer", "launch", [options]);
};

window.rtmpLiveStreamer = new RTMPLiveStreamer();
