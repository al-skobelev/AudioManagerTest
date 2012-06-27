/**************************************************************************** 
 * AppDelegate.h                                                            * 
 * Created by Alexander Skobelev                                            * 
 *                                                                          * 
 ****************************************************************************/

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#define APP  ((UIApplication*)[UIApplication sharedApplication])
#define APPD ((AppDelegate*)[UIApplication sharedApplication].delegate)

//============================================================================
@interface AppDelegate : UIResponder <UIApplicationDelegate, AVAudioSessionDelegate>

@property (strong, nonatomic) UIWindow *window;

@end
/* EOF */
