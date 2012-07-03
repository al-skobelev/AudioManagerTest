/****************************************************************************
 * AudioSession.m                                                           *
 * Created by Alexander Skobelev                                            *
 *                                                                          *
 ****************************************************************************/

#import "AudioSession.h"


#define LOG(FMT$, ARGS$...) NSLog (@"%s -- " FMT$, __PRETTY_FUNCTION__, ##ARGS$)
#define ELOG(FMT$, ARGS$...) NSLog (@"%s -- ERROR -- " FMT$, __PRETTY_FUNCTION__, ##ARGS$)

#if __BIG_ENDIAN__
#define SWAP_CODE(N$) (N$)
#else
#define SWAP_CODE(N$) ((((N$) >> 24) & 0x000000ff) |       \
                       (((N$) >>  8) & 0x0000ff00) |       \
                       (((N$) <<  8) & 0x00ff0000) |       \
                       (((N$) << 24) & 0xff000000))
#endif

static id prop_value_from_raw_data (UInt32 prop_id, void* data, UInt32 data_size);
static void interruption_listener (void* data, UInt32 inInterruptionState);

static void property_listener (void* client_data, AudioSessionPropertyID  prop_id,
                               UInt32 data_size, const void* data);


//============================================================================
@interface AudioSession ()

// @property (strong, nonatomic) NSCountedSet* listenedProperties;
@property (assign, nonatomic) BOOL activated;
@end

//============================================================================
@implementation AudioSession

// @synthesize listenedProperties = _listenedProperties;
@synthesize activated = _activated;

//----------------------------------------------------------------------------
// + initialize
// {
//     [[self sharedInstance] initializeSession];
// }

//----------------------------------------------------------------------------
- init
{
    if (! (self = [super init])) return nil;
    
    // self.listenedProperties = [NSCountedSet new];
    return self;
}

//----------------------------------------------------------------------------
+ (AudioSession*) sharedInstance
{
    static dispatch_once_t _s_once;
    static id _s_obj = nil;
    
    dispatch_once (&_s_once, ^{ _s_obj = [self new]; });
    return _s_obj;
}

// //----------------------------------------------------------------------------
// - (OSStatus) startListeningForProperty: (UInt32) prop_id
// {
//     id obj = [NSNumber numberWithUnsignedInt: prop_id];
//     [self.listenedProperties addObject: obj];
//     if (0 == [self.listenedProperties countForObject: obj])
//     {
//         OSStatus status = AudioSessionAddPropertyListener (prop_id, listener, NULL);
//         if (status != 0)
//         {
//             uint32_t ecode = SWAP_CODE(status);
//             uint32_t pcode = SWAP_CODE(prop_id);

//             ELOG(@"AudioSessionAddPropertyListener (%.4s) failed with error: '%.4s'\n", (const char*) &pcode, (const char*) &ecode);
//             return status;
//         }
//     }
//     [self.listenedProperties addObject: obj];
//     return 0;
// }
// //----------------------------------------------------------------------------
// - (OSStatus) stopListeningForProperty: (UInt32) prop_id
// {
//     id obj = [NSNumber numberWithUnsignedInt: prop_id];

//     [self.listenedProperties removeObject: obj];
//     if (0 == [self.listenedProperties countForObject: obj])
//     {
//         OSStatus status = AudioSessionRemovePropertyListener (prop_id);
//         if (status != 0)
//         {
//             uint32_t ecode = SWAP_CODE(status);
//             uint32_t pcode = SWAP_CODE(prop_id);

//             ELOG(@"AudioSessionAddPropertyListener (%.4s) failed with error: '%.4s'\n", (const char*) &pcode, (const char*) &ecode);
//             return status;
//         }
//     }

//     return 0;
// }

//----------------------------------------------------------------------------
- (OSStatus) addListener: (id <AudioSessionPropertyListener>) listener
             forProperty: (UInt32) prop_id
{
    OSStatus status = AudioSessionAddPropertyListener (prop_id, property_listener, (__bridge void*)listener);
    if (status != 0)
    {
        uint32_t ecode = SWAP_CODE(status);
        uint32_t pcode = SWAP_CODE(prop_id);
        
        ELOG(@"AudioSessionAddPropertyListener (%.4s) failed with error: '%.4s'\n", (const char*) &pcode, (const char*) &ecode);
        return status;
    }
    return 0;
}

//----------------------------------------------------------------------------
- (OSStatus) removeListener: (id <AudioSessionPropertyListener>) listener
                forProperty: (UInt32) prop_id
{
    OSStatus status = AudioSessionRemovePropertyListenerWithUserData (prop_id, property_listener, (__bridge void*)listener);
    if (status != 0)
    {
        uint32_t ecode = SWAP_CODE(status);
        uint32_t pcode = SWAP_CODE(prop_id);
        
        ELOG(@"AudioSessionRemovePropertyListenerWithUserData (%.4s) failed with error: '%.4s'\n", (const char*) &pcode, (const char*) &ecode);
        return status;
    }
    return 0;
}

//----------------------------------------------------------------------------
-(OSStatus) getRawValue: (void*) prop
                 ofSize: (UInt32) prop_size
            forProperty: (UInt32) prop_id
{
    assert (prop);

    OSStatus status = AudioSessionGetProperty (prop_id, &prop_size, prop);

    if (status != 0)
    {
        uint32_t ecode = SWAP_CODE(status);
        uint32_t pcode = SWAP_CODE(prop_id);
        ELOG(@"AudioSessionGetProperty ('%.4s') failed with error: '%.4s'\n", (const char*) &pcode, (const char*) &ecode);
    }

    return status;
}

//----------------------------------------------------------------------------
- (OSStatus) setRawValue: (void*) prop
                  ofSize: (UInt32) prop_size
             forProperty: (UInt32) prop_id
{
    assert (prop);
    OSStatus status = AudioSessionSetProperty (prop_id, prop_size, prop);
    if (status != 0)
    {
        uint32_t ecode = SWAP_CODE(status);
        uint32_t pcode = SWAP_CODE(prop_id);
        ELOG(@"AudioSessionGetProperty (%.4s) failed with error: '%.4s'\n", (const char*) &pcode, (const char*) &ecode);
    }
    return status;
}


//----------------------------------------------------------------------------
- (BOOL) enableLoudspeaker: (BOOL)  enable
{
    UInt32 prop = (enable 
                   ? kAudioSessionOverrideAudioRoute_Speaker 
                   : kAudioSessionOverrideAudioRoute_None);

    UInt32 prop_size = sizeof (prop);

    return (0 == [self setRawValue: &prop
                            ofSize: prop_size
                       forProperty: kAudioSessionProperty_OverrideAudioRoute]);
}

//----------------------------------------------------------------------------
- (NSString*) audioRoute
{
    NSString*  route = nil; 
    CFStringRef prop = nil; 
    UInt32 prop_size = sizeof (prop);
    
    if (0 == [self getRawValue: &prop
                        ofSize: prop_size
                   forProperty: kAudioSessionProperty_AudioRoute])
    {
        route = (NSString*) CFBridgingRelease (prop);
    }
    
    return route;
}

//----------------------------------------------------------------------------
- (OSStatus) setCategory: (UInt32) cat
{
    UInt32 old_cat = 0;
    OSStatus status = [self getRawValue: &old_cat
                                 ofSize: sizeof(old_cat)
                            forProperty: kAudioSessionProperty_AudioCategory];

    if (status && (old_cat != cat)) {
        status = [self setRawValue: &cat 
                            ofSize: sizeof(cat)
                       forProperty: kAudioSessionProperty_AudioCategory];
    }
        
    return status;
}


//----------------------------------------------------------------------------
- (BOOL) loudspeakerEnabled
{
    NSString* route = [self audioRoute];
    return (route && ! [route hasPrefix: @"Headset"]);
}

//----------------------------------------------------------------------------
- (OSStatus) setActive: (BOOL) active
{
    OSStatus status = AudioSessionSetActive (active);

    if (active && (status == kAudioSessionNotInitialized))
    {
        if (! (status = [self initializeSession]))
        {
            status = AudioSessionSetActive (active);
        }
    }

    if (status != 0) {
        uint32_t code = SWAP_CODE(status);
        ELOG(@"Failed to set Audio Session %sactive. Error: '%.4s'\n", active ? "" : "in", (const char*) &code);
    }
    else {
        self.activated = active;

        if (active) [self addListener: self
                          forProperty: kAudioSessionProperty_ServerDied];

        else        [self removeListener: self
                             forProperty: kAudioSessionProperty_ServerDied];
    }

    return status;
}

//----------------------------------------------------------------------------
- (OSStatus) initializeSession
{
    OSStatus status = AudioSessionInitialize (NULL, NULL,                    
                                              interruption_listener,
                                              NULL);  
    if (status && (status != kAudioSessionAlreadyInitialized)) 
    {
        uint32_t code = SWAP_CODE(status);
        ELOG(@"Failed to initialize Audio Session. error: '%.4s'\n", (const char*) &code);
    }

    return status;
}

//----------------------------------------------------------------------------
- (void) handleInterruption: (UInt32) state
{
    id info = [NSDictionary dictionaryWithObject: [NSNumber numberWithUnsignedInt: state]
                                          forKey: STATE_KEY];

    [[NSNotificationCenter defaultCenter]
        postNotificationName: NTF_AUDIO_SESSION_INTERRUPTION
                      object: self
                    userInfo: info];
}

//----------------------------------------------------------------------------
- (id) valueOfProperty: (UInt32) prop_id
        fromRawDataPtr: (void*) data
              dataSize: (UInt32) data_size
{
    switch (prop_id)
    {
        case kAudioSessionProperty_AudioRoute:                              // CFStringRef      (get only)

            assert (data_size == sizeof (id));
            return CFBridgingRelease (*(void**)data);

        case kAudioSessionProperty_AudioRouteChange:                        // CFDictionaryRef  (property listener)

            assert (data_size == sizeof (id));
            return CFBridgingRelease (*(void**)data);

        case kAudioSessionProperty_CurrentHardwareSampleRate:               // Float64          (get only)
        case kAudioSessionProperty_PreferredHardwareSampleRate:             // Float64          (get/set)

            assert (data_size == sizeof (Float64));
            return [NSNumber numberWithDouble: *(Float64*)data];

        case kAudioSessionProperty_AudioCategory:                           // UInt32           (get/set)
        case kAudioSessionProperty_AudioInputAvailable:                     // UInt32           (get only/property listener)
        case kAudioSessionProperty_CurrentHardwareInputNumberChannels:      // UInt32           (get only)
        case kAudioSessionProperty_CurrentHardwareOutputNumberChannels:     // UInt32           (get only)
        case kAudioSessionProperty_OtherAudioIsPlaying:                     // UInt32           (get only)
        case kAudioSessionProperty_OtherMixableAudioShouldDuck:             // UInt32           (get/set)
        case kAudioSessionProperty_OverrideAudioRoute:                      // UInt32           (set only)
        case kAudioSessionProperty_OverrideCategoryDefaultToSpeaker:        // UInt32           (get, some set)
        case kAudioSessionProperty_OverrideCategoryEnableBluetoothInput:    // UInt32           (get, some set)
        case kAudioSessionProperty_OverrideCategoryMixWithOthers:           // UInt32           (get, some set)
        case kAudioSessionProperty_ServerDied:                              // UInt32           (property listener)

            assert (data_size == sizeof (UInt32));
            return [NSNumber numberWithUnsignedInt: *(UInt32*)data];

        case kAudioSessionProperty_CurrentHardwareIOBufferDuration:         // Float32          (get only)
        case kAudioSessionProperty_CurrentHardwareInputLatency:             // Float32          (get only)
        case kAudioSessionProperty_CurrentHardwareOutputLatency:            // Float32          (get only)
        case kAudioSessionProperty_CurrentHardwareOutputVolume:             // Float32          (get only/property listener)
        case kAudioSessionProperty_PreferredHardwareIOBufferDuration:       // Float32          (get/set)

            assert (data_size == sizeof (Float32));
            return [NSNumber numberWithFloat: *(Float32*)data];
    }

    return nil;
}

//----------------------------------------------------------------------------
// - (void) handleChangeOfPropery: (UInt32) prop_id
//                   propertyData: (void*)  data
//                       dataSize: (UInt32) data_size
// {
//     id val = [self valueOfProperty: prop_id
//                     fromRawDataPtr: data
//                           dataSize: data_size];

//     id info = [NSDictionary dictionaryWithObjectsAndKeys: 
//                                 [NSNumber numberWithUnsignedInt: prop_id], PROP_ID_KEY,
//                                 val, VALUE_KEY,
//                                 nil];

//     [[NSNotificationCenter defaultCenter]
//         postNotificationName: NTF_AUDIO_SESSION_PROPERTY_CHANGED
//                       object: self
//                     userInfo: info];
// }

//----------------------------------------------------------------------------
- (void) handleChangeOfPropery: (UInt32) prop_id
                      withInfo: (id) info
{
    if (prop_id == kAudioSessionProperty_ServerDied)
    {
        if (self.activated) {
            [self setActive: NO];
            [self setActive: YES];
        }
    }
}

@end

//----------------------------------------------------------------------------
void interruption_listener (void* data, UInt32 interruptionState)
{
    dispatch_async (dispatch_get_main_queue(), ^{
            [[AudioSession sharedInstance] handleInterruption: interruptionState]; });
}

//----------------------------------------------------------------------------
void property_listener (void* client_data, AudioSessionPropertyID  prop_id,
                        UInt32 data_size, const void* data)
{
    dispatch_sync (dispatch_get_main_queue(), ^{
            
            id info = prop_value_from_raw_data (prop_id, (void*)data, data_size);
            id <AudioSessionPropertyListener> __unsafe_unretained obj = (__bridge id) client_data;

            [obj handleChangeOfPropery: prop_id
                              withInfo: info]; });

            // [[AudioSession sharedInstance] handleChangeOfPropery: prop_id
            //                                         propertyData: data
            //                                             dataSise: data_size]; });
}

//----------------------------------------------------------------------------
id prop_value_from_raw_data (UInt32 prop_id, void* data, UInt32 data_size)
{
    switch (prop_id)
    {
        case kAudioSessionProperty_AudioRoute:                              // CFStringRef      (get only)

            assert (data_size == sizeof (id));
            return CFBridgingRelease (*(void**)data);

        case kAudioSessionProperty_AudioRouteChange:                        // CFDictionaryRef  (property listener)

            assert (data_size == sizeof (id));
            return CFBridgingRelease (*(void**)data);

        case kAudioSessionProperty_CurrentHardwareSampleRate:               // Float64          (get only)
        case kAudioSessionProperty_PreferredHardwareSampleRate:             // Float64          (get/set)

            assert (data_size == sizeof (Float64));
            return [NSNumber numberWithDouble: *(Float64*)data];

        case kAudioSessionProperty_AudioCategory:                           // UInt32           (get/set)
        case kAudioSessionProperty_AudioInputAvailable:                     // UInt32           (get only/property listener)
        case kAudioSessionProperty_CurrentHardwareInputNumberChannels:      // UInt32           (get only)
        case kAudioSessionProperty_CurrentHardwareOutputNumberChannels:     // UInt32           (get only)
        case kAudioSessionProperty_OtherAudioIsPlaying:                     // UInt32           (get only)
        case kAudioSessionProperty_OtherMixableAudioShouldDuck:             // UInt32           (get/set)
        case kAudioSessionProperty_OverrideAudioRoute:                      // UInt32           (set only)
        case kAudioSessionProperty_OverrideCategoryDefaultToSpeaker:        // UInt32           (get, some set)
        case kAudioSessionProperty_OverrideCategoryEnableBluetoothInput:    // UInt32           (get, some set)
        case kAudioSessionProperty_OverrideCategoryMixWithOthers:           // UInt32           (get, some set)
        case kAudioSessionProperty_ServerDied:                              // UInt32           (property listener)

            assert (data_size == sizeof (UInt32));
            return [NSNumber numberWithUnsignedInt: *(UInt32*)data];

        case kAudioSessionProperty_CurrentHardwareIOBufferDuration:         // Float32          (get only)
        case kAudioSessionProperty_CurrentHardwareInputLatency:             // Float32          (get only)
        case kAudioSessionProperty_CurrentHardwareOutputLatency:            // Float32          (get only)
        case kAudioSessionProperty_CurrentHardwareOutputVolume:             // Float32          (get only/property listener)
        case kAudioSessionProperty_PreferredHardwareIOBufferDuration:       // Float32          (get/set)

            assert (data_size == sizeof (Float32));
            return [NSNumber numberWithFloat: *(Float32*)data];
    }

    return nil;
}

/* EOF */
