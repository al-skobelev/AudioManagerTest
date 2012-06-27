/**************************************************************************** 
 * AudioManager.h                                                           * 
 * Created by Alexander Skobelev                                            * 
 *                                                                          * 
 ****************************************************************************/
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#define STATUS_KEY       @"status"
#define RATE_KEY         @"rate"
#define CURRENT_ITEM_KEY @"currentItem"

#define CURRENT_TIME_KEY  @"currentTime"
#define RELATIVE_TIME_KEY @"relativeTime"
#define DURATION_KEY      @"duration"

// NTF_AUDIO_MANAGER_PLAY_COMPLETED - notification is sent when playback has
//   reached the end of file or stream. Notification's object is AudioManager
//   instance.

// NTF_AUDIO_MANAGER_PLAY_TIMER - notification is being sending during
//   playback with period given by periodicTimerInterval, if it's value is
//   greater than 0.  Notification's object is AudioManager instance.  The
//   userInfo dictionary contains values for the CURRENT_TIME_KEY,
//   DURATION_KEY, RELATIVE_TIME_KEY, RATE_KEY keys.

#define NTF_AUDIO_MANAGER_PLAY_COMPLETED @"AUDIO_MANAGER_PLAY_COMPLETED"
#define NTF_AUDIO_MANAGER_PLAY_TIMER     @"AUDIO_MANAGER_PLAY_TIMER"
#define NTF_AUDIO_MANAGER_STATE_CHANGED  @"AUDIO_MANAGER_STATE_CHANGED"

//============================================================================
@interface AudioManager : NSObject

@property (readonly) BOOL playing;

// Set to non-zero value to activate NTF_AUDIO_MANAGER_TIMER
@property (assign, nonatomic) double periodicTimerInterval;


+ (AudioManager*) sharedManager;

- (void) reset; // is it neccessary?

- (BOOL) prepareFile: (NSString*) path;
- (BOOL) prepareURL: (NSURL*) url;

- (BOOL) asyncPrepareURL: (NSURL*) url
       completionHandler: (void (^)(NSError* error)) handler;

- (void) play;
- (void) pause;

// results in seconds
- (double) duration;
- (double) currentTime; 
- (void)   seekToTime: (double) seconds; 

@end
/* EOF */
