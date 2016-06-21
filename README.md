## IndoorAtlas SDK 2.1

### Quick Start with CocoaPods

```
cd ios-sdk-examples/example
pod install
open indooratlas-ios-sdk-example.xcworkspace
```

### Documentation

http://docs.indooratlas.com/ios/

### IndoorAtlas Framework download

http://docs.indooratlas.com/ios/getting-started.html

### What is new in SDK 2.x

http://docs.indooratlas.com/sdk-21-release-information.html

#### Known issues

* No accuracy information for IARegion / indoorLocationManager:didEnterRegion: event available yet.
* iOS automatic floor plan recognition is not always reliable. If recommended to set floor plan id directly when possible.
* Google maps overlay example and Image view example might be unable to fetch the floor plan image if only available image is marked as private.
* Floor level information is currently not set in IALocation.

## Changelog

http://docs.indooratlas.com/ios/CHANGELOG.html


