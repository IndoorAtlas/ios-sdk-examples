# IndoorAtlas SDK Examples for iOS (Objective-C)

[IndoorAtlas](https://www.indooratlas.com/) provides a unique Platform-as-a-Service (PaaS) solution that runs a disruptive geomagnetic positioning in its full-stack hybrid technology for accurately pinpointing a location inside a building. The IndoorAtlas SDK enables app developers to use high-accuracy indoor positioning in venues that have been fingerprinted.

This example app showcases the IndoorAtlas SDK features and acts as a reference implementation in Objective-C for many of the basic SDK features. Getting started requires you to set up a free developer account and fingerprint your indoor venue using the IndoorAtlas MapCreator tool.

There are also similar examples for [Swift](https://github.com/IndoorAtlas/ios-sdk-swift-examples) and [Android](https://github.com/IndoorAtlas/android-sdk-examples).

* [Getting Started](#getting-started)
    * [Set up your account](#set-up-your-account)
    * [Get started by using CocoaPods](#get-started-by-using-cocoapods)
    * [Manual IndoorAtlas framework download](#manual-indooratlas-framework-download)
* [Features](#features)
* [Documentation](#documentation)
* [SDK Changelog](#sdk-changelog)
* [License](#license)


## Getting Started

### Set up your account

* Set up your [free developer account](https://app.indooratlas.com) in the IndoorAtlas developer portal. Help with getting started is available in the [IndoorAtlas support pages](https://indooratlas.freshdesk.com/support/home).
* To enable IndoorAtlas indoor positioning in a venue, the venue needs to be fingerprinted with the [IndoorAtlas MapCreator 2](https://play.google.com/store/apps/details?id=com.indooratlas.android.apps.jaywalker) tool.
* To start developing your own app, create an [API key](https://app.indooratlas.com/apps).

### Get started by using CocoaPods

Clone or download this git repository and install the project dependencies using CocoaPods (recommended):

```
cd ios-sdk-examples/example
pod install
open indooratlas-ios-sdk-example.xcworkspace
```

Set your API keys in `ApiKeys.h`. API keys can be generated at https://app.indooratlas.com/apps

### Manual IndoorAtlas framework download

If you are not using CocoaPods, the IndoorAtlas SDK framework can be downloaded and installed manually by following the steps in the [manual installation of iOS SDK](https://indooratlas.freshdesk.com/support/solutions/articles/36000092592-manual-installation-of-ios-sdk).

## Features

These examples are included in the app:

* Map View: Example of using IndoorAtlas positioning with AppleMaps overlay. Demonstrates the use of region change, indoor-outdoor and wayfinding features of the IndoorAtlas SDK. 
* Image View: Floor plan bitmap image view with the blue dot location.
* Background: Demonstrates running the SDK in the background, by periodically initiating positioning.
* Geofence: Allows the user to set geofences and triggers callbacks once the user enters/exits the geofence.
* Orientation: Demonstrates the 3D orientation API.

## Documentation

The IndoorAtlas SDK API documentation is available in the documentation portal: https://docs.indooratlas.com/ios/latest/

## SDK Changelog

https://docs.indooratlas.com/technical/changelogs/ios/

## License

Copyright 2015-2018 IndoorAtlas Ltd. The IndoorAtlas SDK Examples are released under the Apache License. See the [LICENSE.md](https://github.com/IndoorAtlas/ios-sdk-examples/blob/master/LICENSE.md) file for details.
