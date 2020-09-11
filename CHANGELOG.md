# Changelog for DP3T-SDK iOS

## Version 1.2.2 ()
- 'Bearer' is not added as prefix to auth key if using HTTPAuthorizationBearer auth method. 

## Version 1.2.1 (31.08.2020)
- ensures that backgroundtask keeps running until outstandingPublishOperation is finished

## Version 1.2.0 (26.08.2020)
- resolves keychain issue with iOS 14
- adds iOS 14 info.plist entries for calibration app
- submitted keys are now always filled up to 30 instead of 14
- resolves detection issue for iOS 14 beta 5

## Version 1.1.1 (13.08.2020)
- DP3TNetworkingError.HTTPFailureResponse includes raw data

## Version 1.1.0 (17.07.2020)
- adds background refresh task to improve background time
- retrieves keys in background on iOS > 13.6
- expose data if HTTP Code is not expected
- handle case if EN Framework is not available (iOS 14 beta)
- defer schedule background task until EN is authorized
- retrys activation and enabling of ENManager if failed on willEnterForeground

## Version 1.0.2 (03.07.2020)
- defers sync until ENManager is fully initialized
- fixes in background task handling
- fix in storing of lastSync Date

## Version 1.0.1 (22.06.2020)
- Make timeshift detection independent from locale / region settings
- Update last sync timestamps of individual days that were successful even if some others failed

## Version 1.0.0 (19.06.2020)
- Introduce possibility to turn off logging
- Stop tracing when changing state to infected
- Fixes issues when getting last key 

## Version 0.7.0 (12.06.2020)
- Do not try to call getDiagnosisKeys() in background as iOS 13.5 does not allow delayed retrieval of last key in background
- Re-introduce time drift detection (of 10min)
- Do not sync when tracing is stopped 
- Do not abort sync when individual days fail
- Fixes key dates of fake keys 
- Fixes ENError code 2 (realpath) by not keeping references to already deleted files

## Version 0.6.0 (04.06.2020)
- Improved rate-limit handling

## Version 0.5.0 (29.05.2020)
- fixed several issues regarding the background tasks

## Version 0.4.0 (21.05.2020)

- switched to GAEN framework

## Version 0.1.12 (05.5.2020)
- Change 16bit UUID to DP3T registered FD68
- simplified handshake to contact conversion

## Version 0.1.11 (04.5.2020)
- Stop tracing and purge keys after a person was marked as exposed

## Version 0.1.10 (29.4.2020)
- Fixed bugs in contact matching
- Fixed bug in attenuation calculation
- disables timeInconsistency check for now

## Version 0.1.9 (28.4.2020)
- Fixed issue contact date calculation
- Adds fake request flag to exposed method
- Adds new contact matching logic

## Version 0.1.8 (27.4.2020)
- Add parameter to set bucket length (has to be supported by the backend)
- Sets reconnectionDelay to 1 minute
- Fixed issue in sync where sync never happend
- Added version number to the logs
- Streamlined networking errors
- Add Changelog file
