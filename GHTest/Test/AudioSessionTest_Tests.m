/****************************************************************************
 * test_case.m                                                              *
 * Created by Alexander Skobelev                                            *
 *                                                                          *
 ****************************************************************************/

#import "AudioSessionTest.h"
#import <CoreAudio/CoreAudioTypes.h>
#import <AudioToolbox/AudioToolbox.h>
#import "../AudioManagerTest/AudioSession.h"

#define TEST_LOG(ARGS...)                        \
    ({                                           \
        GHTestLog (@"\nTEST: %s", #ARGS);        \
        ARGS;                                    \
    })


//============================================================================
@implementation AudioSessionTest (Tests)


//----------------------------------------------------------------------------
- (void) test_00_InitializeSession
{
    OSStatus status = TEST_LOG([AudioSession initializeSession]);
    GHAssertErr (status, 'init', @"-- status is '%@'", fccode_to_string (status));
    GHTestLog(@" -- OK");
}

//----------------------------------------------------------------------------
- (void) test_01_ActivateSession
{
    {
        BOOL active = TEST_LOG([AudioSession active]);
        GHAssertFalse (active, @"-- AudioSessin is active");
        GHTestLog(@" -- OK: session is inactive");
    }
    {
        OSStatus status = TEST_LOG([AudioSession setActive: YES]);
        GHAssertNoErr (status, @"-- status is '%@'", fccode_to_string (status));
        GHTestLog(@" -- OK");
    }

    {
        BOOL active = TEST_LOG([AudioSession active]);
        GHAssertTrue (active, @"-- AudioSessin is inactive");
        GHTestLog(@" -- OK: session is active");
    }
}

//----------------------------------------------------------------------------
- (void) test_02_Category
{
    {
        UInt32 category = TEST_LOG([AudioSession category]);

        GHAssertTrue (category == kAudioSessionCategory_SoloAmbientSound, 
                      @"-- category is '%@' (expected '%@')", 
                      fccode_to_string (category), fccode_to_string (kAudioSessionCategory_AmbientSound));

        GHTestLog(@" -- OK: category is '%@'", fccode_to_string (category));
    }

    {
        OSStatus status = TEST_LOG ([AudioSession setCategory: kAudioSessionCategory_MediaPlayback]);
        GHAssertNoErr (status, nil);
        GHTestLog(@" -- OK");
    }

    {
        UInt32 category = TEST_LOG([AudioSession category]);

        GHAssertTrue (category == kAudioSessionCategory_MediaPlayback, 
                      @"-- category is '%@' (expected '%@')", 
                      fccode_to_string (category), fccode_to_string (kAudioSessionCategory_AmbientSound));

        GHTestLog(@" -- OK: category is '%@'", fccode_to_string (category));
    }
}

//----------------------------------------------------------------------------
- (void) test_03_AudioRoute
{
    {
        GHTestLog(@"Test [AudioSession audioRoute]");
        NSString* route = [AudioSession audioRoute];

        GHAssertNotNil (route, nil);
        GHTestLog(@" -- OK: route is '%@'", route);
    }
}

//----------------------------------------------------------------------------
- (void) test_03_loudSpeaker
{
    UInt32 category = TEST_LOG([AudioSession category]);
    OSStatus status = TEST_LOG ([AudioSession setCategory: kAudioSessionCategory_PlayAndRecord]);

    {
        BOOL enabled = TEST_LOG ([AudioSession loudspeakerEnabled]);
        status = TEST_LOG ([AudioSession setLoudspeakerEnabled: ![AudioSession loudspeakerEnabled]]);

        GHAssertTrue (enabled == ![AudioSession loudspeakerEnabled], nil);
        GHTestLog(@" -- OK");

        status = TEST_LOG ([AudioSession setLoudspeakerEnabled: enabled]);

    }

    status = TEST_LOG ([AudioSession setCategory: category]);

    // {
    //     BOOL enabled = TEST_LOG ([AudioSession loudspeakerEnabled]);
    //     GHAssertTrue (enabled, nil);
    //     GHTestLog(@" -- OK: loudspeakerEnabled is enabled");
    // }

    // {
    //     OSStatus status = TEST_LOG ([AudioSession setLoudspeakerEnabled: NO]);
    //     GHAssertNoErr (status, nil);
    //     GHTestLog(@" -- OK:");
    // }

    // {
    //     BOOL enabled = TEST_LOG ([AudioSession loudspeakerEnabled]);
    //     GHAssertFalse (enabled, nil);
    //     GHTestLog(@" -- OK: loudspeakerEnabled is disabled");
    // }

    // {
    //     OSStatus status = TEST_LOG ([AudioSession setLoudspeakerEnabled: YES]);
    //     GHAssertNoErr (status, nil);
    //     GHTestLog(@" -- OK:");
    // }

    // {
    //     BOOL enabled = TEST_LOG ([AudioSession loudspeakerEnabled]);
    //     GHAssertTrue (enabled, nil);
    //     GHTestLog(@" -- OK: loudspeakerEnabled is enabled");
    // }
}

@end
