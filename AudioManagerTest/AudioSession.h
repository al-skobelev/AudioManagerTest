/****************************************************************************
 * AudioSession.h                                                           *
 * Created by Alexander Skobelev                                            *
 *                                                                          *
 ****************************************************************************/
#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>

#define NTF_AUDIO_SESSION_INTERRUPTION @"AUDIO_SESSION_INTERRUPTION"
#define AUDIO_SESSION_STATE_KEY @"state"

NSString* fccode_to_string (UInt32 code);


//============================================================================
@protocol AudioSessionPropertyListener
@required
- (void) handleChangeOfPropery: (UInt32) prop_id
                      withInfo: (id) info;
@end


//============================================================================
@interface AudioSession : NSObject

+ (OSStatus) initializeSession;

+ (BOOL) active;
+ (OSStatus) setActive: (BOOL) active;

+ (OSStatus) addListener: (id <AudioSessionPropertyListener>) listener
             forProperty: (UInt32) prop_id;

+ (OSStatus) removeListener: (id <AudioSessionPropertyListener>) listener
                forProperty: (UInt32) prop_id;

+ (id) valueOfProperty: (UInt32) prop_id;
+ (OSStatus) setValue: (id) val
           ofProperty: (UInt32) prop_id;

+ (NSString*) audioRoute;

+ (UInt32) category;
+ (OSStatus) setCategory: (UInt32) cat;

// Relevant in PlayAndRecord mode only
+ (BOOL) loudspeakerEnabled;
+ (OSStatus) setLoudspeakerEnabled: (BOOL)  enable;

@end

/* EOF */
