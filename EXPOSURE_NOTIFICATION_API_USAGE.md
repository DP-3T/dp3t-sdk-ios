# ExposureNotification API usage
This document outlines the interaction of the SDK with the [Exposure Notification](https://developer.apple.com/documentation/exposurenotification) Framework by Apple.

## Enabling Exposure Notifications

To enable Exposure Notifications for our app we need to call [ENManager.setExposureNotificationEnabled(true:completionHandler:)](https://developer.apple.com/documentation/exposurenotification/enmanager/3583729-setexposurenotificationenabled). This will trigger a system popup asking the user to either enable Exposure Notifications on this device or (if another app is active) to switch to our app as active Exposure Notifications app. After the user gave or denied consent the completionHandler will be called.

## Disabling Exposure Notifications

To disable Exposure Notifications for our app we need to call [ENManager.setExposureNotificationEnabled(false:completionHandler:)](https://developer.apple.com/documentation/exposurenotification/enmanager/3583729-setexposurenotificationenabled).

## Exporting Temporary Exposure Keys

To retrieve the Temporary Exposure Keys (TEKs) we need to call [ENManager.getDiagnosisKeys(completionHandler:)](https://developer.apple.com/documentation/exposurenotification/enmanager/3583725-getdiagnosiskeys). This will trigger a system popup asking the user whether he wants to share the TEKs of the last 14 days with the app. If the user agrees to share the keys with the app the completion handler will get called with a maximum of 14 TEKs.

The TEK of the current day is currently not returned by [getDiagnosisKeys(completionHandler:)](https://developer.apple.com/documentation/exposurenotification/enmanager/3583725-getdiagnosiskeys), but only the keys of the previous 13 days. After the user agreed to share the keys we call [getDiagnosisKeys(completionHandler:)](https://developer.apple.com/documentation/exposurenotification/enmanager/3583725-getdiagnosiskeys) again on the following day and will then receive the TEK of last day. For this to work, the user has to open the app, after which we will temporarily enable EN, then call [getDiagnosisKeys(completionHandler:)](https://developer.apple.com/documentation/exposurenotification/enmanager/3583725-getdiagnosiskeys) (which triggers a system popup once once) and disable EN again.

## Detecting Exposure

For a contact to be counted as a possible exposure it must be longer than a certain number of minutes on a certain day. The current implementation of the EN-framework does not expose this information. Our way to overcome this limitation is to pass the published keys to the framework grouped by day.

To check for exposure on a given day (we check the past 10 days) we need to call [ENManager.detectExposures(configuration:diagnosisKeyURLs:completionHandler:)](https://developer.apple.com/documentation/exposurenotification/enmanager/3586331-detectexposures). This method has three parameters:

#### Exposure Configuration

The [ENExposureConfiguration](https://developer.apple.com/documentation/exposurenotification/enexposureconfiguration) defines the configuration for the Apple scoring of exposures. In our case we ignore most of the scoring methods and only provide [attenuationDurationThresholds](https://developer.apple.com/documentation/exposurenotification/enexposureconfiguration/3601128-attenuationdurationthresholds), the thresholds for the duration at attenuation buckets. The thresholds for the attenuation buckets are loaded from our [config server](https://github.com/DP-3T/dp3t-config-backend-ch/blob/master/dpppt-config-backend/src/main/java/org/dpppt/switzerland/backend/sdk/config/ws/model/GAENSDKConfig.java). This allows us to group the duration of a contact with another device into three buckets regarding the measured attenuation values that we then use to detect if the contact was long and close enough.
To detect an exposure the following formula is used to compute the exposure duration:
```
durationAttenuationLow * factorLow + durationAtttenuationMedium * factorMedium
```
If this duration is at least as much as defined in the triggerThreshold a notification is triggered for that day.

#### Diagnosis key URLs

We need to unzip the file which we got from our backend, store the key file (.bin) and signature file (.sig) locally and pass the local urls to the EN API. Unlike Android, on iOS we can't just pass the difference from last detection but we have to pass the every key of a day everytime we do a detection.

#### Completion Handler

The completionHandler is called with a [ENExposureDetectionSummary](https://developer.apple.com/documentation/exposurenotification/enexposuredetectionsummary). That allows us to check if the exposure limit for a notification was reached by checking the minutes of exposure per attenuation bucket. The duration per bucket has a maximum of 30min, longer exposures are also returned as 30min of exposure.

#### Rate limit

We are only allowed to call [detectExposures()](https://developer.apple.com/documentation/exposurenotification/enmanager/3586331-detectexposures) 20 times within 24h. Because we check for every of the past 10 days individually, this allows us to check for exposure twice per day. These checks happen after 6am and 6pm (swiss time) when the BackgroundTask is scheduled the next time or the app is opened. All 10 days are checked individually and if one fails it is retried on the next run. No checks are made between midnight UTC and 6am (swiss time) to prevent exceeding the rate limit per 24h.