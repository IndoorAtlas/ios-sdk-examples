## Release notes for IndoorAtlas SDK 2.0.0-beta

### Documentation

http://docs.indooratlas.com/ios/

### IndoorAtlas Framework download

https://bintray.com/indooratlas-ltd/indooratlas-ios-sdk/indooratlas-ios-sdk/view

Unzip the SDK zip and drag and drop IndoorAtlas.framework to the project.
When "Choose options for adding these files:" dialog pops ups, tick "Copy items if needed" box.

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

## Changelog

**v.2.0.0-beta:**

* Initial public release

