# Changelog for DP3T-SDK iOS

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