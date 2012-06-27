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

#define NTF_AUDIO_MANAGER_PLAY_COMPLETED @"AUDIO_MANAGER_PLAY_COMPLETED"
#define NTF_AUDIO_MANAGER_STATE_CHANGED  @"AUDIO_MANAGER_STATE_CHAGED"
#define NTF_AUDIO_MANAGER_PLAY_TIMER     @"AUDIO_MANAGER_PLAY_TIMER"

//============================================================================
@interface AudioManager : NSObject

@property (readonly) BOOL playing;

@property (strong, nonatomic) AVPlayer* player;
@property (strong, nonatomic) AVPlayerItem* playerItem;

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

- (double) duration;
- (double) currentTime; 
- (void)   seekToTime: (double) seconds; 

@end
/* EOF */
