# JS Precall Sample

This sample application is an example of using the `testNetwork` API. It includes a simple algorithm for choosing whether to allow the user to publish with video or just audio. It also uses the `getStats` API to continually monitor the quality and potentially drop to audio only if it gets too bad.

## Usage

* Replace the config variables in [index.html](index.html) with your sessionId, apiKey and token.
* Serve this directory on a webserver, eg. using Apache, [SimpleHTTPServer](https://docs.python.org/2/library/simplehttpserver.html) or [http-server](https://github.com/indexzero/http-server).
* load index.html in a browser (Chrome or Firefox) and allow access to your camera and microphone.
