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

static int    prop_data_type      (UInt32 prop_id);
static UInt32 prop_data_size      (UInt32 prop_id);
static UInt32 prop_data_type_size (int prop_data_type);

static id   prop_value_from_raw_data (UInt32 prop_id, void* data, UInt32 data_size);
static BOOL get_prop_value_raw_data  (UInt32 prop_id, id value, void* data, UInt32* data_size);

static void interruption_listener (void* data, UInt32 inInterruptionState);

static void property_listener (void* client_data, AudioSessionPropertyID  prop_id,
                               UInt32 data_size, const void* data);


enum prop_data_types {
    PROP_DATA_TYPE_UNKNOWN,
    PROP_DATA_TYPE_STRING,
    PROP_DATA_TYPE_DICT,
    PROP_DATA_TYPE_UINT32,
    PROP_DATA_TYPE_FLOAT32,
    PROP_DATA_TYPE_FLOAT64,
};

typedef union {
    CFStringRef     string;
    CFDictionaryRef dict;
    UInt32          uint32; 
    Float32         float32;
    Float64         float64;

} raw_data_t;

//============================================================================
@interface AudioSession ()

@property (assign, nonatomic) BOOL activated;
@end

//============================================================================
@implementation AudioSession

@synthesize activated = _activated;

//----------------------------------------------------------------------------
+ (AudioSession*) sharedInstance
{
    static dispatch_once_t _s_once;
    static id _s_obj = nil;
    
    dispatch_once (&_s_once, ^{ _s_obj = [self new]; });
    return _s_obj;
}

//----------------------------------------------------------------------------
- init
{
    if (! (self = [super init])) return nil;

    (void)[self initializeSession];
    return self;
}

//----------------------------------------------------------------------------
- (OSStatus) addListener: (id <AudioSessionPropertyListener>) listener
             forProperty: (UInt32) prop_id
{
    OSStatus status = AudioSessionAddPropertyListener (prop_id, property_listener, (__bridge void*)listener);
    if (status != 0)
    {
        ELOG(@"AudioSessionAddPropertyListener (%@) failed with error: '%@'\n", fccode_to_string (prop_id), fccode_to_string (status));
        return status;
    }
    return 0;
}

//----------------------------------------------------------------------------
- (OSStatus) removeListener: (id <AudioSessionPropertyListener>) listener
                forProperty: (UInt32) prop_id
{
    OSStatus status = AudioSessionRemovePropertyListenerWithUserData (prop_id, property_listener, (__bridge void*)listener);
    if (status != 0) {
        ELOG(@"AudioSessionRemovePropertyListenerWithUserData (%@) failed with error: '%@'\n", fccode_to_string (prop_id), fccode_to_string (status));
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
    if (status != 0) {
        ELOG(@"AudioSessionGetProperty (%@) failed with error: '%@'\n", fccode_to_string (prop_id), fccode_to_string (status));
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
    if (status != 0) {
        ELOG(@"AudioSessionSetProperty (%@) failed with error: '%@'\n", fccode_to_string (prop_id), fccode_to_string (status));
    }
    return status;
}

//----------------------------------------------------------------------------
- (id) valueForProperty: (UInt32) prop_id
{
    raw_data_t data;
    
    UInt32 data_size = prop_data_size (prop_id);
    
    OSStatus status = [self getRawValue: &data
                                 ofSize: data_size
                            forProperty: prop_id];
    
    id val = (0 == status) ? prop_value_from_raw_data (prop_id, &data, data_size) : nil;
    return val;
}


//----------------------------------------------------------------------------
- (OSStatus) setValue: (id) val
          forProperty: (UInt32) prop_id
{
    OSStatus status = -1;
    raw_data_t data;
    UInt32 data_size;

    if (get_prop_value_raw_data (prop_id, val, &data, &data_size))
    {
        status = [self  setRawValue: &data
                             ofSize: data_size
                        forProperty: prop_id];
    }
    return status;
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
- (UInt32) category
{
    UInt32 cat = 0;
    [self getRawValue: &cat
               ofSize: sizeof(cat)
          forProperty: kAudioSessionProperty_AudioCategory];
    
    return cat;
}

//----------------------------------------------------------------------------
- (OSStatus) setCategory: (UInt32) cat
{
    OSStatus status = -1;

    if ([self category] != cat)
    {
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
- (BOOL) setLoudspeakerEnabled: (BOOL)  enable
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
        ELOG(@"Failed to set Audio Session %sactive. Error: '%@'\n", active ? "" : "in", fccode_to_string (status));
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
        ELOG(@"Failed to initialize Audio Session. error: '%@'\n", fccode_to_string (status));
    }

    return status;
}

//----------------------------------------------------------------------------
- (void) handleInterruption: (UInt32) state
{
    id info = [NSDictionary dictionaryWithObject: [NSNumber numberWithUnsignedInt: state]
                                          forKey: AUDIO_SESSION_STATE_KEY];

    [[NSNotificationCenter defaultCenter]
        postNotificationName: NTF_AUDIO_SESSION_INTERRUPTION
                      object: self
                    userInfo: info];
}

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
    dispatch_after (dispatch_time (DISPATCH_TIME_NOW,  0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
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
}

//----------------------------------------------------------------------------
int prop_data_type (UInt32 prop_id)
{
    switch (prop_id)
    {
        case kAudioSessionProperty_AudioRoute:                              // CFStringRef      (get only)

            return PROP_DATA_TYPE_STRING;

        case kAudioSessionProperty_AudioRouteChange:                        // CFDictionaryRef  (property listener)

            return PROP_DATA_TYPE_DICT;

        case kAudioSessionProperty_CurrentHardwareSampleRate:               // Float64          (get only)
        case kAudioSessionProperty_PreferredHardwareSampleRate:             // Float64          (get/set)

            return PROP_DATA_TYPE_FLOAT64;

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

            return PROP_DATA_TYPE_UINT32;

        case kAudioSessionProperty_CurrentHardwareIOBufferDuration:         // Float32          (get only)
        case kAudioSessionProperty_CurrentHardwareInputLatency:             // Float32          (get only)
        case kAudioSessionProperty_CurrentHardwareOutputLatency:            // Float32          (get only)
        case kAudioSessionProperty_CurrentHardwareOutputVolume:             // Float32          (get only/property listener)
        case kAudioSessionProperty_PreferredHardwareIOBufferDuration:       // Float32          (get/set)

            return PROP_DATA_TYPE_FLOAT32;
    }

    return PROP_DATA_TYPE_UNKNOWN;
}

//----------------------------------------------------------------------------
id prop_value_from_raw_data (UInt32 prop_id, void* data, UInt32 data_size)
{
    int dtype = prop_data_type (prop_id);

    switch (dtype)
    {
        case PROP_DATA_TYPE_STRING:
        case PROP_DATA_TYPE_DICT:

            assert (data_size == sizeof (id));
            return CFBridgingRelease (*(void**)data);

        case PROP_DATA_TYPE_UINT32:

            assert (data_size == sizeof (UInt32));
            return [NSNumber numberWithUnsignedInt: *(UInt32*)data];

        case PROP_DATA_TYPE_FLOAT32:

            assert (data_size == sizeof (Float32));
            return [NSNumber numberWithFloat: *(Float32*)data];

        case PROP_DATA_TYPE_FLOAT64:

            assert (data_size == sizeof (Float64));
            return [NSNumber numberWithDouble: *(Float64*)data];
    }

    return nil;
}

//----------------------------------------------------------------------------
BOOL get_prop_value_raw_data (UInt32 prop_id, id value, void* data, UInt32* data_size)
{
    assert (data && data_size);

    int dtype = prop_data_type (prop_id);

    switch (dtype)
    {
        case PROP_DATA_TYPE_STRING:
            *(CFStringRef*)data = (__bridge void*) value;
            *data_size = sizeof (CFStringRef);
            return YES;

        case PROP_DATA_TYPE_DICT:

            *(CFDictionaryRef*)data = (__bridge void*) value;
            *data_size = sizeof (CFDictionaryRef);
            return YES;
            
        case PROP_DATA_TYPE_UINT32:

            *(UInt32*)data = [value unsignedIntValue];
            *data_size = sizeof(UInt32);
            return YES;

        case PROP_DATA_TYPE_FLOAT32:

            *(Float32*)data = [value floatValue];
            *data_size = sizeof(Float32);
            return YES;

        case PROP_DATA_TYPE_FLOAT64:

            *(Float64*)data = [value doubleValue];
            *data_size = sizeof(Float64);
            return YES;
            
        default:
            return NO;
    }
}

//----------------------------------------------------------------------------
UInt32 prop_data_type_size (int dtype)
{
    return ((dtype == PROP_DATA_TYPE_STRING)  ? sizeof (CFStringRef) :
            (dtype == PROP_DATA_TYPE_DICT)    ? sizeof (CFDictionaryRef) :
            (dtype == PROP_DATA_TYPE_UINT32)  ? sizeof (UInt32) :
            (dtype == PROP_DATA_TYPE_FLOAT32) ? sizeof (Float32) :
            (dtype == PROP_DATA_TYPE_FLOAT64) ? sizeof (Float64) :
            0);
}
//----------------------------------------------------------------------------
UInt32 prop_data_size (UInt32 prop_id)
{
    return prop_data_type_size (prop_data_type (prop_id));
}

//----------------------------------------------------------------------------
NSString* fccode_to_string (UInt32 code)
{
    code = SWAP_CODE(code);
    return [NSString stringWithFormat: @"%.4s", (const char*) &code];
}

/* EOF */
