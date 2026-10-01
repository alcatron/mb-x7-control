#import "X7Bridge.h"
#import <CoreFoundation/CoreFoundation.h>
#import <IOKit/hid/IOHIDManager.h>
#import <IOKit/hid/IOHIDKeys.h>
#import <IOKit/IOCFPlugIn.h>
#import <IOKit/usb/IOUSBLib.h>
#import <IOKit/usb/USBSpec.h>
#import <CoreAudio/CoreAudio.h>
#import <math.h>

#define CREATIVE_VID 0x041e
#define X7_PID 0x323a

static void setMatchingNumber(CFMutableDictionaryRef matching, CFStringRef key, SInt32 value) {
    CFNumberRef number = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &value);
    if (number) {
        CFDictionarySetValue(matching, key, number);
        CFRelease(number);
    }
}

static long numberProperty(IOHIDDeviceRef d, CFStringRef key) {
    CFTypeRef v = IOHIDDeviceGetProperty(d, key);
    long out = -1;
    if (v && CFGetTypeID(v) == CFNumberGetTypeID())
        CFNumberGetValue((CFNumberRef)v, kCFNumberLongType, &out);
    return out;
}

static IOHIDDeviceRef copyX7(IOHIDManagerRef *managerOut) {
    IOHIDManagerRef m = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!m) return NULL;
    // Match only the X7 before opening the manager. A wildcard manager also
    // attempts to open protected keyboard/input devices and may be denied to a
    // newly launched GUI app even though the X7 itself is accessible.
    CFMutableDictionaryRef matching = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                                 0,
                                                                 &kCFTypeDictionaryKeyCallBacks,
                                                                 &kCFTypeDictionaryValueCallBacks);
    if (!matching) { CFRelease(m); return NULL; }
    setMatchingNumber(matching, CFSTR(kIOHIDVendorIDKey), CREATIVE_VID);
    setMatchingNumber(matching, CFSTR(kIOHIDProductIDKey), X7_PID);
    IOHIDManagerSetDeviceMatching(m, matching);
    CFRelease(matching);
    if (IOHIDManagerOpen(m, kIOHIDOptionsTypeNone) != kIOReturnSuccess) { CFRelease(m); return NULL; }
    CFSetRef set = IOHIDManagerCopyDevices(m);
    if (!set) { IOHIDManagerClose(m, 0); CFRelease(m); return NULL; }
    CFIndex n = CFSetGetCount(set);
    if (n == 0) { CFRelease(set); IOHIDManagerClose(m, 0); CFRelease(m); return NULL; }
    IOHIDDeviceRef *devices = calloc((size_t)n, sizeof(*devices));
    if (!devices) { CFRelease(set); IOHIDManagerClose(m, 0); CFRelease(m); return NULL; }
    CFSetGetValues(set, (const void **)devices);
    IOHIDDeviceRef found = NULL;
    for (CFIndex i=0;i<n;i++) {
        if (numberProperty(devices[i], CFSTR(kIOHIDVendorIDKey)) == CREATIVE_VID &&
            numberProperty(devices[i], CFSTR(kIOHIDProductIDKey)) == X7_PID) {
            found = (IOHIDDeviceRef)CFRetain(devices[i]); break;
        }
    }
    free(devices); CFRelease(set);
    if (!found) { IOHIDManagerClose(m, 0); CFRelease(m); return NULL; }
    *managerOut = m; return found;
}

BOOL X7IsConnected(void) {
    IOHIDManagerRef m = NULL; IOHIDDeviceRef d = copyX7(&m);
    if (!d) return NO;
    CFRelease(d); IOHIDManagerClose(m, 0); CFRelease(m); return YES;
}

NSString *X7DeviceIdentifier(void) {
    IOHIDManagerRef manager = NULL;
    IOHIDDeviceRef device = copyX7(&manager);
    if (!device) return nil;

    NSString *identifier = @"041e-323a";
    CFTypeRef value = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDSerialNumberKey));
    if (value && CFGetTypeID(value) == CFStringGetTypeID() &&
        CFStringGetLength((CFStringRef)value) > 0) {
        identifier = [NSString stringWithFormat:@"041e-323a-%@", (NSString *)value];
    }

    CFRelease(device);
    IOHIDManagerClose(manager, 0);
    CFRelease(manager);
    return identifier;
}

int X7SendReport(const uint8_t *bytes, size_t length) {
    IOHIDManagerRef m = NULL; IOHIDDeviceRef d = copyX7(&m);
    if (!d) return -1;
    IOReturn r = IOHIDDeviceOpen(d, kIOHIDOptionsTypeNone);
    if (r == kIOReturnSuccess)
        r = IOHIDDeviceSetReport(d, kIOHIDReportTypeOutput, 0, bytes, (CFIndex)length);
    IOHIDDeviceClose(d, 0); CFRelease(d); IOHIDManagerClose(m, 0); CFRelease(m);
    return (int)r;
}

static AudioDeviceID findX7AudioDevice(void) {
    AudioObjectPropertyAddress a = { kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain };
    UInt32 size = 0;
    if (AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &a, 0, NULL, &size) != noErr) return kAudioObjectUnknown;
    UInt32 count = size / sizeof(AudioDeviceID);
    if (count == 0) return kAudioObjectUnknown;
    AudioDeviceID *ids = calloc(count, sizeof(AudioDeviceID));
    if (!ids) return kAudioObjectUnknown;
    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &a, 0, NULL, &size, ids) != noErr) { free(ids); return kAudioObjectUnknown; }
    AudioDeviceID found = kAudioObjectUnknown;
    for (UInt32 i=0;i<count;i++) {
        CFStringRef name = NULL; UInt32 ns = sizeof(name);
        AudioObjectPropertyAddress na = { kAudioObjectPropertyName, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain };
        if (AudioObjectGetPropertyData(ids[i], &na, 0, NULL, &ns, &name) == noErr && name) {
            if (CFStringFind(name, CFSTR("Sound Blaster X7"), kCFCompareCaseInsensitive).location != kCFNotFound) found = ids[i];
            CFRelease(name);
        }
        if (found != kAudioObjectUnknown) break;
    }
    free(ids); return found;
}

static BOOL setFloatProperty(AudioDeviceID d, AudioObjectPropertySelector sel, Float32 value) {
    AudioObjectPropertyAddress a = { sel, kAudioDevicePropertyScopeOutput, kAudioObjectPropertyElementMain };
    UInt32 size = sizeof(value);
    Boolean settable = false;
    if (AudioObjectHasProperty(d, &a) &&
        AudioObjectIsPropertySettable(d, &a, &settable) == noErr && settable) {
        if (AudioObjectSetPropertyData(d, &a, 0, NULL, size, &value) == noErr) return YES;
    }
    // Fallback: stereo channels, matching the legacy panel's observed behavior.
    BOOL ok = NO;
    for (UInt32 ch=1; ch<=2; ch++) {
        a.mElement = ch;
        settable = false;
        if (AudioObjectHasProperty(d, &a) &&
            AudioObjectIsPropertySettable(d, &a, &settable) == noErr && settable &&
            AudioObjectSetPropertyData(d, &a, 0, NULL, size, &value) == noErr) ok = YES;
    }
    return ok;
}

static BOOL setUIntProperty(AudioDeviceID d, AudioObjectPropertySelector sel, UInt32 value) {
    AudioObjectPropertyAddress a = { sel, kAudioDevicePropertyScopeOutput, kAudioObjectPropertyElementMain };
    UInt32 size = sizeof(value);
    Boolean settable = false;
    if (AudioObjectHasProperty(d, &a) &&
        AudioObjectIsPropertySettable(d, &a, &settable) == noErr && settable &&
        AudioObjectSetPropertyData(d, &a, 0, NULL, size, &value) == noErr) return YES;
    BOOL ok = NO;
    for (UInt32 ch=1; ch<=2; ch++) {
        a.mElement=ch; settable=false;
        if (AudioObjectHasProperty(d,&a) &&
            AudioObjectIsPropertySettable(d,&a,&settable)==noErr && settable &&
            AudioObjectSetPropertyData(d,&a,0,NULL,size,&value)==noErr) ok=YES;
    }
    return ok;
}

BOOL X7SetMasterVolume(float scalar) {
    AudioDeviceID d = findX7AudioDevice(); if (d == kAudioObjectUnknown) return NO;
    scalar = fmaxf(0.f, fminf(1.f, scalar));
    return setFloatProperty(d, kAudioDevicePropertyVolumeScalar, scalar);
}
BOOL X7SetMasterMute(BOOL muted) {
    AudioDeviceID d = findX7AudioDevice(); if (d == kAudioObjectUnknown) return NO;
    return setUIntProperty(d, kAudioDevicePropertyMute, muted ? 1 : 0);
}
BOOL X7ReadMasterVolume(float *scalar) {
    if (!scalar) return NO;
    AudioDeviceID d=findX7AudioDevice(); if(d==kAudioObjectUnknown) return NO;
    Float32 v=0; UInt32 s=sizeof(v); AudioObjectPropertyAddress a={kAudioDevicePropertyVolumeScalar,kAudioDevicePropertyScopeOutput,kAudioObjectPropertyElementMain};
    if(AudioObjectGetPropertyData(d,&a,0,NULL,&s,&v)==noErr) { *scalar=v; return YES; }
    a.mElement=1; if(AudioObjectGetPropertyData(d,&a,0,NULL,&s,&v)==noErr) { *scalar=v; return YES; }
    return NO;
}
BOOL X7ReadMasterMute(BOOL *muted) {
    if (!muted) return NO;
    AudioDeviceID d=findX7AudioDevice(); if(d==kAudioObjectUnknown) return NO;
    UInt32 v=0,s=sizeof(v); AudioObjectPropertyAddress a={kAudioDevicePropertyMute,kAudioDevicePropertyScopeOutput,kAudioObjectPropertyElementMain};
    if(AudioObjectGetPropertyData(d,&a,0,NULL,&s,&v)==noErr) { *muted=v!=0; return YES; }
    a.mElement=1; if(AudioObjectGetPropertyData(d,&a,0,NULL,&s,&v)==noErr) { *muted=v!=0; return YES; }
    return NO;
}

NSArray<NSDictionary<NSString *, id> *> *X7AudioDevices(BOOL input) {
    AudioObjectPropertyAddress devicesAddress = { kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain };
    UInt32 size = 0;
    if (AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &devicesAddress, 0, NULL, &size) != noErr) return @[];
    UInt32 count = size / sizeof(AudioDeviceID);
    AudioDeviceID *deviceIDs = calloc(count, sizeof(AudioDeviceID));
    if (!deviceIDs) return @[];
    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &devicesAddress, 0, NULL, &size, deviceIDs) != noErr) {
        free(deviceIDs); return @[];
    }

    AudioObjectPropertySelector defaultSelector = input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice;
    AudioObjectPropertyAddress defaultAddress = { defaultSelector, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain };
    AudioDeviceID defaultDevice = kAudioObjectUnknown;
    UInt32 defaultSize = sizeof(defaultDevice);
    AudioObjectGetPropertyData(kAudioObjectSystemObject, &defaultAddress, 0, NULL, &defaultSize, &defaultDevice);

    NSMutableArray<NSDictionary<NSString *, id> *> *result = [NSMutableArray array];
    AudioObjectPropertyScope scope = input ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput;
    for (UInt32 index = 0; index < count; index++) {
        AudioObjectPropertyAddress streamsAddress = { kAudioDevicePropertyStreams, scope, kAudioObjectPropertyElementMain };
        UInt32 streamsSize = 0;
        if (!AudioObjectHasProperty(deviceIDs[index], &streamsAddress) ||
            AudioObjectGetPropertyDataSize(deviceIDs[index], &streamsAddress, 0, NULL, &streamsSize) != noErr || streamsSize == 0) continue;
        CFStringRef name = NULL;
        UInt32 nameSize = sizeof(name);
        AudioObjectPropertyAddress nameAddress = { kAudioObjectPropertyName, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain };
        if (AudioObjectGetPropertyData(deviceIDs[index], &nameAddress, 0, NULL, &nameSize, &name) != noErr || !name) continue;
        CFStringRef uid = NULL;
        UInt32 uidSize = sizeof(uid);
        AudioObjectPropertyAddress uidAddress = { kAudioDevicePropertyDeviceUID, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain };
        BOOL hasUID = AudioObjectGetPropertyData(deviceIDs[index], &uidAddress, 0, NULL, &uidSize, &uid) == noErr && uid;
        NSString *stableUID = hasUID ? (NSString *)uid : [NSString stringWithFormat:@"device-%u", deviceIDs[index]];
        [result addObject:@{ @"id": @(deviceIDs[index]), @"uid": stableUID, @"name": (NSString *)name, @"default": @(deviceIDs[index] == defaultDevice) }];
        if (uid) CFRelease(uid);
        CFRelease(name);
    }
    free(deviceIDs);
    return result;
}

BOOL X7SetDefaultAudioDevice(uint32_t deviceID, BOOL input) {
    AudioDeviceID value = (AudioDeviceID)deviceID;
    AudioObjectPropertySelector selector = input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice;
    AudioObjectPropertyAddress address = { selector, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain };
    UInt32 size = sizeof(value);
    if (AudioObjectSetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, size, &value) != noErr) return NO;
    if (!input) {
        AudioObjectPropertyAddress systemAddress = { kAudioHardwarePropertyDefaultSystemOutputDevice, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain };
        AudioObjectSetPropertyData(kAudioObjectSystemObject, &systemAddress, 0, NULL, size, &value);
    }
    return YES;
}

#pragma mark - Playback mixer USB Audio feature units

typedef struct {
    IOCFPlugInInterface **plugin;
    IOUSBInterfaceInterface **interface;
} X7USBControlInterface;

static IOReturn copyX7USBControlInterface(X7USBControlInterface *result) {
    if (!result) return kIOReturnBadArgument;
    result->plugin = NULL;
    result->interface = NULL;

    // This is the same public USB control interface selected by the legacy
    // panel: the X7 vendor/product, configuration 1, interface 0.
    CFMutableDictionaryRef matching = IOServiceMatching(kIOUSBInterfaceClassName);
    if (!matching) return kIOReturnNoMemory;
    setMatchingNumber(matching, CFSTR(kUSBVendorID), CREATIVE_VID);
    setMatchingNumber(matching, CFSTR(kUSBProductID), X7_PID);
    setMatchingNumber(matching, CFSTR(kUSBConfigurationValue), 1);
    setMatchingNumber(matching, CFSTR(kUSBInterfaceNumber), 0);

    io_iterator_t iterator = IO_OBJECT_NULL;
    IOReturn status = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator);
    if (status != kIOReturnSuccess) return status;

    io_service_t service = IO_OBJECT_NULL;
    while ((service = IOIteratorNext(iterator)) != IO_OBJECT_NULL) {
        SInt32 score = 0;
        IOCFPlugInInterface **plugin = NULL;
        status = IOCreatePlugInInterfaceForService(service,
                                                    kIOUSBInterfaceUserClientTypeID,
                                                    kIOCFPlugInInterfaceID,
                                                    &plugin,
                                                    &score);
        IOObjectRelease(service);
        if (status != kIOReturnSuccess || !plugin) continue;

        IOUSBInterfaceInterface **interface = NULL;
        HRESULT query = (*plugin)->QueryInterface(plugin,
                                                   CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID100),
                                                   (LPVOID *)&interface);
        if (query == S_OK && interface) {
            result->plugin = plugin;
            result->interface = interface;
            status = kIOReturnSuccess;
            break;
        }
        IODestroyPlugInInterface(plugin);
        status = kIOReturnNotFound;
    }
    IOObjectRelease(iterator);
    return result->interface ? kIOReturnSuccess : (status == kIOReturnSuccess ? kIOReturnNotFound : status);
}

static void releaseX7USBControlInterface(X7USBControlInterface *control) {
    if (!control) return;
    if (control->interface) {
        (*control->interface)->Release(control->interface);
        control->interface = NULL;
    }
    if (control->plugin) {
        IODestroyPlugInInterface(control->plugin);
        control->plugin = NULL;
    }
}

typedef struct {
    BOOL received;
    BOOL inserted;
} X7JackQueryContext;

static void x7JackInputReport(void *context,
                              IOReturn result,
                              void *sender,
                              IOHIDReportType type,
                              uint32_t reportID,
                              uint8_t *report,
                              CFIndex length) {
    (void)sender; (void)type; (void)reportID;
    X7JackQueryContext *query = context;
    // The X7 reply is 00 23 12 ss jj..., where bit 2 of jj is the front
    // headphone jack. Ignore unrelated asynchronous HID notifications.
    if (result == kIOReturnSuccess && length >= 5 &&
        report[1] == 0x23 && report[2] == 0x12) {
        query->inserted = (report[4] & 0x04) != 0;
        query->received = YES;
    }
}

BOOL X7ReadHeadphoneJackInserted(BOOL *inserted) {
    if (!inserted) return NO;
    IOHIDManagerRef manager = NULL;
    IOHIDDeviceRef device = copyX7(&manager);
    if (!device) return NO;

    uint8_t inputBuffer[128] = {0};
    X7JackQueryContext query = {0};
    IOHIDDeviceRegisterInputReportCallback(device,
                                           inputBuffer,
                                           sizeof(inputBuffer),
                                           x7JackInputReport,
                                           &query);
    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    IOReturn status = IOHIDDeviceOpen(device, kIOHIDOptionsTypeNone);
    if (status == kIOReturnSuccess) {
        const uint8_t command[] = {0x23, 0x12};
        status = IOHIDDeviceSetReport(device,
                                      kIOHIDReportTypeOutput,
                                      0,
                                      command,
                                      sizeof(command));
    }

    CFAbsoluteTime deadline = CFAbsoluteTimeGetCurrent() + 0.25;
    while (status == kIOReturnSuccess && !query.received &&
           CFAbsoluteTimeGetCurrent() < deadline) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.02, true);
    }

    IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    IOHIDDeviceClose(device, kIOHIDOptionsTypeNone);
    CFRelease(device);
    IOHIDManagerClose(manager, kIOHIDOptionsTypeNone);
    CFRelease(manager);

    if (status != kIOReturnSuccess || !query.received) return NO;
    *inserted = query.inserted;
    return YES;
}

static IOReturn playbackSourceRequest(UInt8 requestType,
                                      UInt8 requestCode,
                                      UInt8 unitID,
                                      UInt8 selector,
                                      UInt8 channel,
                                      void *data,
                                      UInt16 length) {
    X7USBControlInterface control = {0};
    IOReturn status = copyX7USBControlInterface(&control);
    if (status != kIOReturnSuccess) return status;

    IOUSBDevRequest request = {
        .bmRequestType = requestType,
        .bRequest = requestCode,
        .wValue = (UInt16)(((UInt16)selector << 8) | channel),
        .wIndex = (UInt16)((UInt16)unitID << 8),
        .wLength = length,
        .pData = data,
        .wLenDone = 0
    };
    status = (*control.interface)->ControlRequest(control.interface, 0, &request);
    releaseX7USBControlInterface(&control);
    return status;
}

static IOReturn setPlaybackSourceVolumeChannel(UInt8 unitID, SInt16 decibels, UInt8 channel) {
    // USB Audio volume values are signed 8.8 dB. The captured panel accepts
    // integral dB in its six-byte payload, then performs this same conversion.
    SInt16 fixedDB = (SInt16)((SInt32)decibels * 256);
    return playbackSourceRequest(0x21, 0x01, unitID, 0x02, channel, &fixedDB, sizeof(fixedDB));
}

int X7SetPlaybackSourceMute(uint8_t unitID, BOOL muted) {
    UInt8 value = muted ? 1 : 0;
    return (int)playbackSourceRequest(0x21, 0x01, unitID, 0x01, 0, &value, sizeof(value));
}

int X7SetPlaybackSourceVolume(uint8_t unitID, int16_t decibels, uint8_t channel) {
    if (channel == 1 || channel == 2)
        return (int)setPlaybackSourceVolumeChannel(unitID, decibels, channel);
    if (channel != 0) return (int)kIOReturnBadArgument;

    // The X7 has no writable master channel for these feature units. The
    // original panel implements channel 0 as the same request to left/right.
    IOReturn left = setPlaybackSourceVolumeChannel(unitID, decibels, 1);
    if (left != kIOReturnSuccess) return (int)left;
    return (int)setPlaybackSourceVolumeChannel(unitID, decibels, 2);
}

int X7ReadPlaybackSourceMute(uint8_t unitID, BOOL *muted) {
    if (!muted) return (int)kIOReturnBadArgument;
    UInt8 value = 0;
    IOReturn status = playbackSourceRequest(0xA1, 0x81, unitID, 0x01, 0, &value, sizeof(value));
    if (status == kIOReturnSuccess) *muted = value != 0;
    return (int)status;
}

static SInt16 integralDBFromFixed(SInt16 fixedDB) {
    return (SInt16)(fixedDB / 256);
}

int X7ReadPlaybackSourceVolume(uint8_t unitID, int16_t *decibels, uint8_t channel) {
    if (!decibels || (channel != 1 && channel != 2)) return (int)kIOReturnBadArgument;
    SInt16 fixedDB = 0;
    IOReturn status = playbackSourceRequest(0xA1, 0x81, unitID, 0x02, channel, &fixedDB, sizeof(fixedDB));
    if (status == kIOReturnSuccess) *decibels = integralDBFromFixed(fixedDB);
    return (int)status;
}

int X7ReadPlaybackSourceVolumeLimits(uint8_t unitID, int16_t *minimum, int16_t *maximum) {
    if (!minimum || !maximum) return (int)kIOReturnBadArgument;
    // UAC2 RANGE response: number of sub-ranges, minimum, maximum, resolution.
    // The X7 exposes one 16-bit volume sub-range and stalls legacy GET_MIN/MAX.
    struct __attribute__((packed)) {
        UInt16 count;
        SInt16 minimum;
        SInt16 maximum;
        UInt16 resolution;
    } range = {0};
    IOReturn status = playbackSourceRequest(0xA1, 0x02, unitID, 0x02, 1, &range, sizeof(range));
    if (status == kIOReturnSuccess && range.count > 0) {
        *minimum = integralDBFromFixed(range.minimum);
        *maximum = integralDBFromFixed(range.maximum);
    } else if (status == kIOReturnSuccess) {
        status = kIOReturnUnderrun;
    }
    return (int)status;
}
