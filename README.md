## Release notes for IndoorAtlas SDK 2.0.0-beta

### Documentation

http://docs.indooratlas.com/ios/

### IndoorAtlas Framework download

https://indooratlas-ltd.bintray.com/iOS/

### What is new in SDK 2.x

New API modeled after iOS Core Location.

Significantly re-implemented core functionality for greater reliability.

New example code and tutorials including getting started guides.

New services

Automatic venue and floor detection implemented in the IndoorAtlas cloud positioning service. We will now automatically search for probable venue and floor based on environmental hints, without any application initialization data required. This enables developing applications which make use of accurate indoor location in any mapped venues without a requirement to prepare each app for positioning venue-by-venue.

Positioning sessions may now span multiple floors, building sections, or even venues, with automatic transitions signaled to apps as region change events.

## Known issues
* No accuracy information for IARegion / indoorLocationManager:didEnterRegion: event available yet.
* iOS automatic floor plan recognition is not always reliable. If recommended to set floor plan id directly when possible.
* Google maps overlay example and Image view example might be unable to fetch the floor plan image if only available image is marked as private.
* Floor level information is currently not set in IALocation.

### End of life notices

In April of this year at version 1.4 release, we announced end of support for SDK version 0.7 and will be shutting down 0.7 servers during October.

Versions 1.3 and 1.4 will continue to be supported until further notice, although we strongly encourage updating apps to use the new 2.0 SDK version due to improved performance. Our commitment to support previous major version extends for a minimum of six months from each end of life notice, and we will be contacting developers using versions 1.x separately to discuss upgrade timelines.

## Changelog

**v.2.0.0-beta:**

* Initial public release

