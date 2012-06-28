/****************************************************************************
 * AudioSession.h                                                           *
 * Created by Alexander Skobelev                                            *
 *                                                                          *
 ****************************************************************************/
#import <UIKit/UIKit.h>

#define NTF_AUDIO_SESSION_PROPERTY_CHANGED @"AUDIO_SESSION_PROPERTY_CHANGED"
#define NTF_AUDIO_SESSION_INTERRUPTION     @"AUDIO_SESSION_INTERRUPTION"


@protocol AudioSessionPropertyListener
@required
- (void) handleChangeOfPropery: (UInt32) prop_id
                      withInfo: (id) info;
@end

//============================================================================
@interface AudioSession : NSObject <AudioSessionPropertyListener>

+ (AudioSession*) sharedInstance;

- (OSStatus) setActive: (BOOL) active;

- (OSStatus) startListeningForProperty: (UInt32) prop_id;
- (OSStatus) stopListeningForProperty: (UInt32) prop_id;

- (NSString*) audioRoute;
- (OSStatus) setCategory: (UInt32) cat;
- (BOOL) loudspeakerEnabled;


@end

/* EOF */
