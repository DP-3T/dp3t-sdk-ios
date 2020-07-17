# DP3T-SDK for iOS
[![Swift Package Manager compatible](https://img.shields.io/badge/SPM-%E2%9C%93-brightgreen.svg?style=flat)](https://github.com/apple/swift-package-manager) ![CocoaPods compatible](https://img.shields.io/cocoapods/v/DP3TSDK)
[![License: MPL 2.0](https://img.shields.io/badge/License-MPL%202.0-brightgreen.svg)](https://github.com/DP-3T/dp3t-sdk-ios/blob/master/LICENSE)
![build](https://github.com/DP-3T/dp3t-sdk-ios/workflows/build/badge.svg)

## DP3T
The Decentralised Privacy-Preserving Proximity Tracing (DP-3T) project is an open protocol for COVID-19 proximity tracing using Bluetooth Low Energy functionality on mobile devices that ensures personal data and computation stays entirely on an individual's phone. It was produced by a core team of over 25 scientists and academic researchers from across Europe. It has also been scrutinized and improved by the wider community.

DP-3T is a free-standing effort started at EPFL and ETHZ that produced this protocol and that is implementing it in an open-sourced app and server.


## Introduction
This is the implementation of the DP-3T protocol using the [Exposure Notification](https://developer.apple.com/documentation/exposurenotification) Framework of Apple/Google. Only approved government public health authorities can access the APIs. Therefore, using this SDK will result in an API error unless you were granted the `com.apple.developer.exposure-notification` entitlement by Apple. The ExposureNotification.framework is available starting with iOS 13.5.

Our prestandard solution that is not using the Apple/Google framework can be found under the [tag prestandard](https://github.com/DP-3T/dp3t-sdk-ios/tree/prestandard).

## Repositories
* Android SDK & Calibration app: [dp3t-sdk-android](https://github.com/DP-3T/dp3t-sdk-android)
* iOS SDK & Calibration app: [dp3t-sdk-ios](https://github.com/DP-3T/dp3t-sdk-ios)
* Android Demo App: [dp3t-app-android](https://github.com/DP-3T/dp3t-app-android)
* iOS Demo App: [dp3t-app-ios](https://github.com/DP-3T/dp3t-app-ios)
* Backend SDK: [dp3t-sdk-backend](https://github.com/DP-3T/dp3t-sdk-backend)

## Further Documentation
The full set of documents for DP3T is at https://github.com/DP-3T/documents. Please refer to the technical documents and whitepapers for a description of the implementation.

## Calibration App
Included in this repository is a Calibration App that can run, debug and test the SDK directly without implementing it in a new app first. Various parameters of the SDK are exposed and can be changed at runtime. Additionally it provides an overview of how to use the SDK.

<p align="center">
  <img src="SampleApp/screenshots/1.png" width="256">
  <img src="SampleApp/screenshots/2.png" width="256">
  <img src="SampleApp/screenshots/3.png" width="256">
</p>


## Function overview

### Initialization
Name | Description | Function Name
---- | ----------- | -------------
init | Initializes the SDK and configures it | `initialize(applicationDescriptor:urlSession:backgroundHandler)` 

### Methods 
Name | Description | Function Name
---- | ----------- | -------------
startTracing | Starts EN tracing | `func startTracing(completionHandler: )throws` 
stopTracing | Stops EN tracing | `func stopTracing(completionHandler:)` 
sync | Pro-actively triggers sync with backend to refresh exposed list | `func sync(callback:)` 
status | Returns a TracingState-Object describing the current state. This contains:<br/>- `numberOfHandshakes` : `Int` <br /> - `trackingState` : `TrackingState` <br /> - `lastSync` : `Date` <br /> - `infectionStatus`:`InfectionStatus`<br /> - `backgroundRefreshState`:`UIBackgroundRefreshStatus ` | `func status(callback:)` 
iWasExposed | This method must be called upon positive test. | `func iWasExposed(onset:authentication:isFakeRequest:callback:)` 
reset | Removes all SDK related data | `func reset() throws`


## Installation
### Swift Package Manager

DP3T-SDK is available through [Swift Package Manager](https://swift.org/package-manager)

1. Add the following to your `Package.swift` file:

  ```swift

  dependencies: [
      .package(url: "https://github.com/DP-3T/dp3t-sdk-ios.git", .branch("develop"))
  ]

  ```
### Cocoapods

DP3T-SDK is available through [Cocoapods](https://cocoapods.org/)

1. Add the following to your `Podfile`:

  ```ruby

  pod 'DP3TSDK', => '1.1.0'

  ```

This version points to the HEAD of the `develop` branch and will always fetch the latest development status. Future releases will be made available using semantic versioning to ensure stability for depending projects.

## Using the SDK

### Initialization

In your AppDelegate in the `didFinishLaunchingWithOptions` function you have to initialize the SDK.

```swift
let url = URL(string: "https://example.com/your/api/")!
try! DP3TTracing.initialize(with: .init(appId: "com.example.your.app", 
                                        bucketBaseUrl: url, 
                                        reportBaseUrl: url))
```

##### 

#### Certificate pinning

The SDK accepts a `URLSession` as an optional argument to the initializer. This can be used to enable certificate pinning. If no session is provided `URLSession.shared` will be used.

### Start / Stop tracing
To start and stop tracing use
```swift
try DP3TTracing.startTracing()
DP3TTracing.stopTracing()
```

### Checking the current tracing status
```swift
DP3TTracing.status(callback: (Result<TracingState, DP3TTracingErrors>) -> Void)
```
The `TracingState` object contains all information regarding the current tracing status.

To receive callbacks and notifications when the state changes, you should assign a delegate object conforming to `DP3TTracingDelegate`:
```swift
DP3TTracing.delegate = yourDelegateObject // weak retained by the SDK

// Delegate method
func DP3TTracingStateChanged(_ state: TracingState) {

}
```
The SDK will call your delegate on every state change, this includes: Handshake detection, start/stop of tracing, change in exposure, errors...

### Report user exposed
```swift
DP3TTracing.iWasExposed(onset: Date(), authentication: .none) { result in
	// Handle result here
}
```

### Sync with backend for exposed user
The SDK automatically syncs with the backend for new exposed users by scheduling a background task.
```swift
DP3TTracing.sync() { result in
	// Handle result here
}
```

#### Background Tasks

The SDK supports iOS 13 background tasks. It uses the provided `exposure-notification` background processing task as well as the `BGAppRefreshTask`. To enable them the app has to support the `Background process` and `Background fetch` capabilities and include  `org.dpppt.exposure-notification` and `org.dpppt.refresh` in the `BGTaskSchedulerPermittedIdentifiers`  `Info.plist` property.

`Info.plist` sample:

```swift
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
  <string>org.dpppt.exposure-notification</string>
  <string>org.dpppt.refresh</string>
</array>
<key>UIBackgroundModes</key>
<array>
  <string>processing</string>
  <string>fetch</string>
</array>
```

If a `DP3TBackgroundHandler` was passed to the SDK on initialisation it will be called on each background task execution by the SDK.

## License

This project is licensed under the terms of the MPL 2 license. See the [LICENSE](LICENSE) file.
