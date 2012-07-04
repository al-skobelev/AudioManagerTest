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


enum prop_data_types {
    PROP_DATA_TYPE_UNKNOWN,
    PROP_DATA_TYPE_STRING,
    PROP_DATA_TYPE_DICT,
    PROP_DATA_TYPE_UINT32,
    PROP_DATA_TYPE_FLOAT32,
    PROP_DATA_TYPE_FLOAT64,
};

typedef union {
    CFTypeRef ref;
    UInt32  uint32; 
    Float32 float32;
    Float64 float64;

} raw_data_t;

static int    prop_data_type      (UInt32 prop_id);
static UInt32 prop_data_type_size (int prop_data_type);

static id    prop_value_from_data     (int prop_data_type, const void* data, UInt32 data_size);
static id    prop_value_from_raw_data (int prop_data_type, const raw_data_t* data, UInt32 data_size);
static BOOL  get_prop_value_raw_data  (int prop_data_type, id value, raw_data_t* data, UInt32* data_size);
static void* raw_data_ptr             (int prop_data_type, raw_data_t* data);

static void interruption_listener (void* data, UInt32 inInterruptionState);

static void property_listener (void* client_data, AudioSessionPropertyID  prop_id,
                               UInt32 data_size, const void* data);


//============================================================================
@interface AudioSessionHelper : NSObject <AudioSessionPropertyListener>

@property (assign, nonatomic) BOOL sessionActive;

+ (AudioSessionHelper*) sharedInstance;
@end

//============================================================================
@implementation AudioSessionHelper 

@synthesize sessionActive = _sessionActive;

//----------------------------------------------------------------------------
+ (AudioSessionHelper*) sharedInstance
{
    static dispatch_once_t _s_once;
    static id _s_obj = nil;

    dispatch_once (&_s_once, ^{ _s_obj = [self new]; });
    return _s_obj;
}


//----------------------------------------------------------------------------
- (void) handleChangeOfPropery: (UInt32) prop_id
                      withInfo: (id) info
{
    if (prop_id == kAudioSessionProperty_ServerDied)
    {
        dispatch_after (dispatch_time (DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), 
                        dispatch_get_main_queue(), 
                        ^{
                            [AudioSession initializeSession];
                            
                            if (self.sessionActive) {
                                [AudioSession setActive: NO];
                                [AudioSession setActive: YES];
                            }
                        });
    }
}

@end

//============================================================================
@implementation AudioSession

//----------------------------------------------------------------------------
+ (void) initialize
{
    (void) [self initializeSession];
}

//----------------------------------------------------------------------------
+ (BOOL) active
{
    return [AudioSessionHelper sharedInstance].sessionActive; 
}

//----------------------------------------------------------------------------
+ (OSStatus) setActive: (BOOL) active
{
    OSStatus status = AudioSessionSetActive (active);

    if (active && (status == kAudioSessionNotInitialized))
    {
        if (! (status = [self initializeSession]))
        {
            status = AudioSessionSetActive (active);
        }
    }

    AudioSessionHelper* helper = [AudioSessionHelper sharedInstance];

    if (status != 0) {
        ELOG(@"Failed to set Audio Session %sactive. Error: '%@'\n", active ? "" : "in", fccode_to_string (status));
    }
    else if (active) {
        helper.sessionActive = YES;
        [self addListener: helper
              forProperty: kAudioSessionProperty_ServerDied];
    }
    else {
        helper.sessionActive = NO;
        [self removeListener: helper
                 forProperty: kAudioSessionProperty_ServerDied];
    }

    return status;
}

//----------------------------------------------------------------------------
+ (OSStatus) initializeSession
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
+ (OSStatus) addListener: (id <AudioSessionPropertyListener>) listener
             forProperty: (UInt32) prop_id
{
    OSStatus status = AudioSessionAddPropertyListener (prop_id, property_listener, (__bridge void*) listener);
    if (status != 0)
    {
        ELOG(@"AudioSessionAddPropertyListener (%@) failed with error: '%@'\n", fccode_to_string (prop_id), fccode_to_string (status));
        return status;
    }
    return 0;
}

//----------------------------------------------------------------------------
+ (OSStatus) removeListener: (id <AudioSessionPropertyListener>) listener
                forProperty: (UInt32) prop_id
{
    OSStatus status = AudioSessionRemovePropertyListenerWithUserData (prop_id, property_listener, (__bridge void*) listener);
    if (status != 0) {
        ELOG(@"AudioSessionRemovePropertyListenerWithUserData (%@) failed with error: '%@'\n", fccode_to_string (prop_id), fccode_to_string (status));
        return status;
    }
    return 0;
}

//----------------------------------------------------------------------------
+ (OSStatus) getRawValue: (void*) prop
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
+ (OSStatus) setRawValue: (void*) prop
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
+ (id) valueOfProperty: (UInt32) prop_id
{
    int dtype = prop_data_type (prop_id);
    UInt32 data_size = prop_data_type_size (dtype);

    raw_data_t raw_data = {0};
    
    OSStatus status = [self getRawValue: &raw_data
                                 ofSize: data_size
                            forProperty: prop_id];
    
    id val = (0 == status) ? prop_value_from_raw_data (dtype, &raw_data, data_size) : nil;
    return val;
}


//----------------------------------------------------------------------------
+ (OSStatus) setValue: (id) val
           ofProperty: (UInt32) prop_id
{
    OSStatus status = -1;

    int dtype = prop_data_type (prop_id);
    raw_data_t raw_data;
    UInt32 data_size;

    if (get_prop_value_raw_data (dtype, val, &raw_data, &data_size))
    {
        status = [self  setRawValue: raw_data_ptr (dtype, &raw_data)
                             ofSize: data_size
                        forProperty: prop_id];
    }
    return status;
}



//----------------------------------------------------------------------------
+ (NSString*) audioRoute
{
    return [self valueOfProperty: kAudioSessionProperty_AudioRoute];

    // NSString*  route = nil; 
    // CFStringRef prop = nil; 
    // UInt32 prop_size = sizeof (prop);
    
    // if (0 == [self getRawValue: &prop
    //                     ofSize: prop_size
    //                forProperty: kAudioSessionProperty_AudioRoute])
    // {
    //     route = (NSString*) CFBridgingRelease (prop);
    // }
    
    // return route;
}

//----------------------------------------------------------------------------
+ (UInt32) category
{
    return [[self valueOfProperty: kAudioSessionProperty_AudioCategory] 
               unsignedIntValue];

    // UInt32 cat = 0;
    // [self getRawValue: &cat
    //            ofSize: sizeof(cat)
    //       forProperty: kAudioSessionProperty_AudioCategory];
    
    // return cat;
}

//----------------------------------------------------------------------------
+ (OSStatus) setCategory: (UInt32) cat
{
    OSStatus status = 0;

    if ([self category] != cat)
    {
        status = [self setValue: [NSNumber numberWithUnsignedInt: cat]
                     ofProperty: kAudioSessionProperty_AudioCategory];
        // status = [self setRawValue: &cat 
        //                     ofSize: sizeof(cat)
        //                forProperty: kAudioSessionProperty_AudioCategory];
    }
    return status;
}



//----------------------------------------------------------------------------
+ (BOOL) loudspeakerEnabled
{
    NSString* route = [self audioRoute];
    return (route && [route hasPrefix: @"Speaker"]);
}


//----------------------------------------------------------------------------
+ (OSStatus) setLoudspeakerEnabled: (BOOL)  enable
{
    UInt32 prop = (enable 
                   ? kAudioSessionOverrideAudioRoute_Speaker 
                   : kAudioSessionOverrideAudioRoute_None);

    return [self setValue: [NSNumber numberWithUnsignedInt: prop]
               ofProperty: kAudioSessionProperty_OverrideAudioRoute];

    // UInt32 prop_size = sizeof (prop);

    // return [self setRawValue: &prop
    //                   ofSize: prop_size
    //              forProperty: kAudioSessionProperty_OverrideAudioRoute];
}

//----------------------------------------------------------------------------
+ (void) handleInterruption: (NSNumber*) state
{
    if (! [NSThread isMainThread])
    {
        [self performSelectorOnMainThread: _cmd
                               withObject: state
                            waitUntilDone: YES];
        return;
    }

    id info = [NSDictionary 
                  dictionaryWithObject: state
                                forKey: AUDIO_SESSION_STATE_KEY];

    [[NSNotificationCenter defaultCenter]
        postNotificationName: NTF_AUDIO_SESSION_INTERRUPTION
                      object: nil
                    userInfo: info];
}

@end

//----------------------------------------------------------------------------
void interruption_listener (void* data, UInt32 interruptionState)
{
    [AudioSession handleInterruption: [NSNumber numberWithUnsignedInt: interruptionState]];
}

//----------------------------------------------------------------------------
void property_listener (void* client_data, AudioSessionPropertyID  prop_id,
                        UInt32 data_size, const void* data)
{
    int dtype = prop_data_type (prop_id);
    id info = prop_value_from_data (dtype, (void*) data, data_size);
    id <AudioSessionPropertyListener> obj = (__bridge id) client_data;
            
    dispatch_after 
        (dispatch_time (DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC), 
         dispatch_get_main_queue(), 
         ^{
            [obj handleChangeOfPropery: prop_id
                              withInfo: info]; 
         });
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
id prop_value_from_data (int prop_data_type, const void* data, UInt32 data_size)
{
    switch (prop_data_type)
    {
        case PROP_DATA_TYPE_STRING:
        case PROP_DATA_TYPE_DICT:
            return prop_value_from_raw_data (prop_data_type, (const raw_data_t*)&data, data_size);
            
        default:
            return prop_value_from_raw_data (prop_data_type, (const raw_data_t*)data, data_size);
    }
}

//----------------------------------------------------------------------------
id prop_value_from_raw_data (int prop_data_type, const raw_data_t* data, UInt32 data_size)
{
    switch (prop_data_type)
    {
        case PROP_DATA_TYPE_STRING:

            assert (data_size == sizeof (CFTypeRef));
            return CFBridgingRelease (data->ref);

        case PROP_DATA_TYPE_DICT:

            assert (data_size == sizeof (CFTypeRef));
            return (__bridge id)data->ref;

        case PROP_DATA_TYPE_UINT32:

            assert (data_size == sizeof (UInt32));
            return [NSNumber numberWithUnsignedInt: data->uint32];

        case PROP_DATA_TYPE_FLOAT32:

            assert (data_size == sizeof (Float32));
            return [NSNumber numberWithFloat: data->float32];

        case PROP_DATA_TYPE_FLOAT64:

            assert (data_size == sizeof (Float64));
            return [NSNumber numberWithDouble: data->float64];
    }

    return nil;
}

//----------------------------------------------------------------------------
void* raw_data_ptr (int prop_data_type, raw_data_t* data)
{
    switch (prop_data_type)
    {
        case PROP_DATA_TYPE_STRING:
        case PROP_DATA_TYPE_DICT:
            return (void*)data->ref;
        default:
            return data;
    }
}

//----------------------------------------------------------------------------
BOOL get_prop_value_raw_data (int prop_data_type, id value, raw_data_t* data, UInt32* data_size)
{
    assert (data && data_size);

    switch (prop_data_type)
    {
        case PROP_DATA_TYPE_STRING:
        case PROP_DATA_TYPE_DICT:

            data->ref = (__bridge CFTypeRef) value;
            *data_size = sizeof (CFTypeRef);
            return YES;
            
        case PROP_DATA_TYPE_UINT32:
            
            data->uint32 = [value unsignedIntValue];
            *data_size = sizeof(UInt32);
            return YES;

        case PROP_DATA_TYPE_FLOAT32:

            data->float32 = [value floatValue];
            *data_size = sizeof(Float32);
            return YES;

        case PROP_DATA_TYPE_FLOAT64:
            
            data->float64 = [value doubleValue];
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
NSString* fccode_to_string (UInt32 code)
{
    code = SWAP_CODE(code);
    return [NSString stringWithFormat: @"%.4s", (const char*) &code];
}

/* EOF */
