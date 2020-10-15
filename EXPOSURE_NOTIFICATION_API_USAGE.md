# ExposureNotification API usage
This document outlines the interaction of the SDK with the [Exposure Notification](https://developer.apple.com/documentation/exposurenotification) Framework by Apple.

## Enabling Exposure Notifications

To enable Exposure Notifications for our app we need to call [ENManager.setExposureNotificationEnabled(true:completionHandler:)](https://developer.apple.com/documentation/exposurenotification/enmanager/3583729-setexposurenotificationenabled). This will trigger a system popup asking the user to either enable Exposure Notifications on this device or (if another app is active) to switch to our app as active Exposure Notifications app. After the user gave or denied consent the completionHandler will be called.

## Disabling Exposure Notifications

To disable Exposure Notifications for our app we need to call [ENManager.setExposureNotificationEnabled(false:completionHandler:)](https://developer.apple.com/documentation/exposurenotification/enmanager/3583729-setexposurenotificationenabled).

## Exporting Temporary Exposure Keys

To retrieve the Temporary Exposure Keys (TEKs) we need to call [ENManager.getDiagnosisKeys(completionHandler:)](https://developer.apple.com/documentation/exposurenotification/enmanager/3583725-getdiagnosiskeys). This will trigger a system popup asking the user whether he wants to share the TEKs of the last 14 days with the app. If the user agrees to share the keys with the app the completion handler will get called with a maximum of 14 TEKs.

## Detecting Exposure

To check for exposure on a given day we need to call [ENManager.detectExposures(configuration:diagnosisKeyURLs:completionHandler:)](https://developer.apple.com/documentation/exposurenotification/enmanager/3586331-detectexposures). This method has three parameters:

#### Exposure Configuration

The [ENExposureConfiguration](https://developer.apple.com/documentation/exposurenotification/enexposureconfiguration) defines the configuration for the Apple scoring of exposures. In our case we ignore most of the scoring methods and only provide:

- [reportTypeNoneMap](https://developer.apple.com/documentation/exposurenotification/enexposureconfiguration/3644397-reporttypenonemap): this defines what report type a key should bet set if no value is provided by the backend. This is set to `.confirmedTest`.
- [infectiousnessForDaysSinceOnsetOfSymptoms](https://developer.apple.com/documentation/exposurenotification/enexposureconfiguration/3644389-infectiousnessfordayssinceonseto): This value is obligatory and has to map between the days since onset of symptoms to the degree of infectiousness. Since we score each day equally we set all values to `ENInfectiousness.high`

#### Diagnosis key URLs

We need to unzip the file which we got from our backend, store the key file (.bin) and signature file (.sig) locally and pass the local urls to the EN API. Unlike Android, on iOS we can't just pass the difference from last detection but we have to pass every key of a day every time we do a detection.

#### Completion Handler

The completion handler is called with a [ENExposureDetectionSummary](https://developer.apple.com/documentation/exposurenotification/enexposuredetectionsummary). 

Given a [ENExposureDetectionSummary](https://developer.apple.com/documentation/exposurenotification/enexposuredetectionsummary) we get ENExposureWindows by calling [ENManager.getExposureWindows(summary:completionHandler:)](https://developer.apple.com/documentation/exposurenotification/enmanager/3644438-getexposurewindows). This method has two parameters:

#### Summary

Here we pass the previously obtained [ENExposureDetectionSummary](https://developer.apple.com/documentation/exposurenotification/enexposuredetectionsummary).

#### Completion Handler

The completion handler is called with [[ENExposureWindow]](https://developer.apple.com/documentation/exposurenotification/enexposurewindow). 

A [ENExposureWindow](https://developer.apple.com/documentation/exposurenotification/enexposurewindow) is a set of Bluetooth scan events from observed beacons within a timespan. A window contains multiple [ENScanInstance](https://developer.apple.com/documentation/exposurenotification/enscaninstance) which are aggregations of attenuation of beacons during a scan.

By grouping the ENExposureWindows by day and then adding up all seconds which lie between our defines attenuation thresholds we can compose the buckets.

The thresholds for the attenuation buckets are loaded from our [config server](https://github.com/DP-3T/dp3t-config-backend-ch/blob/master/dpppt-config-backend/src/main/java/org/dpppt/switzerland/backend/sdk/config/ws/model/GAENSDKConfig.java).

To detect an exposure the following formula is used to compute the exposure duration:

```
durationAttenuationLow * factorLow + durationAtttenuationMedium * factorMedium
```

If this duration is at least as much as defined in the triggerThreshold a notification is triggered for that day.

#### Rate limit

We are only allowed to call [detectExposures()](https://developer.apple.com/documentation/exposurenotification/enmanager/3586331-detectexposures) 6 times within 24h. 