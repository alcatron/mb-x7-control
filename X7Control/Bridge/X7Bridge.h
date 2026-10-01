#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT BOOL X7IsConnected(void);
FOUNDATION_EXPORT NSString * _Nullable X7DeviceIdentifier(void);
FOUNDATION_EXPORT int X7SendReport(const uint8_t *bytes, size_t length);
FOUNDATION_EXPORT BOOL X7SetMasterVolume(float scalar);
FOUNDATION_EXPORT BOOL X7SetMasterMute(BOOL muted);
FOUNDATION_EXPORT BOOL X7ReadMasterVolume(float *scalar);
FOUNDATION_EXPORT BOOL X7ReadMasterMute(BOOL *muted);
FOUNDATION_EXPORT NSArray<NSDictionary<NSString *, id> *> *X7AudioDevices(BOOL input);
FOUNDATION_EXPORT BOOL X7SetDefaultAudioDevice(uint32_t deviceID, BOOL input);
FOUNDATION_EXPORT BOOL X7ReadHeadphoneJackInserted(BOOL *inserted);

// Playback-source monitoring controls exposed by the X7's USB Audio feature
// units. Channel 0 means both stereo channels; 1 and 2 mean left and right.
FOUNDATION_EXPORT int X7SetPlaybackSourceMute(uint8_t unitID, BOOL muted);
FOUNDATION_EXPORT int X7SetPlaybackSourceVolume(uint8_t unitID, int16_t decibels, uint8_t channel);
FOUNDATION_EXPORT int X7ReadPlaybackSourceMute(uint8_t unitID, BOOL *muted);
FOUNDATION_EXPORT int X7ReadPlaybackSourceVolume(uint8_t unitID, int16_t *decibels, uint8_t channel);
FOUNDATION_EXPORT int X7ReadPlaybackSourceVolumeLimits(uint8_t unitID, int16_t *minimum, int16_t *maximum);

NS_ASSUME_NONNULL_END
