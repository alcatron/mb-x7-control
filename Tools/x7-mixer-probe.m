#import <Foundation/Foundation.h>
#import "../X7Control/Bridge/X7Bridge.h"

static int readSource(uint8_t unit, const char *name, BOOL printValues,
                      BOOL *mute, int16_t *left, int16_t *right) {
    int16_t minimum = 0, maximum = 0;
    int limitsStatus = X7ReadPlaybackSourceVolumeLimits(unit, &minimum, &maximum);
    int leftStatus = X7ReadPlaybackSourceVolume(unit, left, 1);
    int rightStatus = X7ReadPlaybackSourceVolume(unit, right, 2);
    int muteStatus = X7ReadPlaybackSourceMute(unit, mute);
    if (printValues) {
        printf("%-22s unit=0x%02x range=%d..%d dB left=%d right=%d mute=%d status=%08x/%08x/%08x/%08x\n",
               name, unit, minimum, maximum, *left, *right, *mute,
               limitsStatus, leftStatus, rightStatus, muteStatus);
    }
    return limitsStatus || leftStatus || rightStatus || muteStatus;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        const uint8_t units[] = {0x0f, 0x10, 0x11, 0x12, 0x13};
        const char *names[] = {"Mic-In/Mic Array", "Line In", "Bluetooth", "SPDIF-In", "USB Host"};
        BOOL writeTest = argc == 2 && strcmp(argv[1], "--mute-roundtrip") == 0;
        int failed = 0;
        for (size_t i = 0; i < sizeof(units); i++) {
            BOOL mute = NO;
            int16_t left = 0, right = 0;
            failed |= readSource(units[i], names[i], YES, &mute, &left, &right);
        }
        if (!writeTest) {
            puts("Dry run only. Pass --mute-roundtrip to toggle and restore Mic-In mute.");
            return failed ? 1 : 0;
        }

        BOOL originalMute = NO;
        int16_t originalLeft = 0, originalRight = 0;
        if (readSource(0x0f, "Mic-In/Mic Array", NO, &originalMute, &originalLeft, &originalRight)) return 2;
        int status = X7SetPlaybackSourceMute(0x0f, !originalMute);
        BOOL changedMute = originalMute;
        int16_t ignoredLeft = 0, ignoredRight = 0;
        int readChanged = readSource(0x0f, "Mic-In/Mic Array", NO, &changedMute, &ignoredLeft, &ignoredRight);
        int restore = X7SetPlaybackSourceMute(0x0f, originalMute);
        BOOL restoredMute = !originalMute;
        int readRestored = readSource(0x0f, "Mic-In/Mic Array", NO, &restoredMute, &ignoredLeft, &ignoredRight);
        int leftWrite = X7SetPlaybackSourceVolume(0x0f, originalLeft, 1);
        int rightWrite = X7SetPlaybackSourceVolume(0x0f, originalRight, 2);
        printf("Mic-In round-trip: set=%08x observed=%d restore=%08x restored=%d volume-same=%08x/%08x\n",
               status, changedMute, restore, restoredMute, leftWrite, rightWrite);
        return status || readChanged || changedMute == originalMute || restore || readRestored ||
               restoredMute != originalMute || leftWrite || rightWrite ? 3 : 0;
    }
}
