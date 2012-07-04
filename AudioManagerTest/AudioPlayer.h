/**************************************************************************** 
 * AudioManager.h                                                           * 
 * Created by Alexander Skobelev                                            * 
 *                                                                          * 
 ****************************************************************************/
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#define AUDIO_PLAYER_STATUS_KEY        @"status"
#define AUDIO_PLAYER_RATE_KEY          @"rate"
#define AUDIO_PLAYER_CURRENT_ITEM_KEY  @"currentItem"

#define AUDIO_PLAYER_CURRENT_TIME_KEY  @"currentTime"
#define AUDIO_PLAYER_RELATIVE_TIME_KEY @"relativeTime"
#define AUDIO_PLAYER_DURATION_KEY      @"duration"

// NTF_AUDIO_PLAYER_PLAY_COMPLETED - notification is sent when playback has
//   reached the end of file or stream. Notification's object is AudioPlayer
//   instance.

// NTF_AUDIO_PLAYER_PLAY_TIMER - notification is being sending during
//   playback with period given by periodicTimerInterval, if it's value is
//   greater than 0.  Notification's object is AudioPlayer instance.  The
//   userInfo dictionary contains values for the CURRENT_TIME_KEY,
//   DURATION_KEY, RELATIVE_TIME_KEY, RATE_KEY keys.

#define NTF_AUDIO_PLAYER_PLAY_COMPLETED @"AUDIO_PLAYER_PLAY_COMPLETED"
#define NTF_AUDIO_PLAYER_PLAY_TIMER     @"AUDIO_PLAYER_PLAY_TIMER"
#define NTF_AUDIO_PLAYER_STATE_CHANGED  @"AUDIO_PLAYER_STATE_CHANGED"

//============================================================================
@interface AudioPlayer : NSObject

@property (readonly) BOOL playing;

// Set to non-zero value to activate NTF_AUDIO_PLAYER_TIMER
@property (assign, nonatomic) double periodicTimerInterval;


+ (AudioPlayer*) sharedPlayer;

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
