/**************************************************************************** 
 * AudioManager.h                                                           * 
 * Created by Alexander Skobelev                                            * 
 *                                                                          * 
 ****************************************************************************/
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

//============================================================================
@interface AudioManager : NSObject

@property (nonatomic) BOOL playing;

@property (strong, nonatomic) AVPlayer*     player;
@property (strong, nonatomic) AVPlayerItem* playerItem;

+ (AudioManager*) sharedManager;

- (BOOL) asyncPrepareURL: (NSURL*) url
       completionHandler: (void (^)(NSError* error)) handler;

- (void) play;
- (void) pause;

@end
/* EOF */
