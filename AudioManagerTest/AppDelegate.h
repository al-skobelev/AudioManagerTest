/**************************************************************************** 
 * AppDelegate.h                                                            * 
 * Created by Alexander Skobelev                                            * 
 *                                                                          * 
 ****************************************************************************/

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "AudioSession.h"

#define APP  ((UIApplication*)[UIApplication sharedApplication])
#define APPD ((AppDelegate*)[UIApplication sharedApplication].delegate)

//============================================================================
@interface AppDelegate : UIResponder <UIApplicationDelegate, AudioSessionPropertyListener>

@property (strong, nonatomic) UIWindow *window;

@end
/* EOF */
