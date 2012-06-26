/**************************************************************************** 
 * AppDelegate.h                                                            * 
 * Created by Alexander Skobelev                                            * 
 *                                                                          * 
 ****************************************************************************/

#import <UIKit/UIKit.h>

#define APP  ((UIApplication*)[UIApplication sharedApplication])
#define APPD ((AppDelegate*)[UIApplication sharedApplication].delegate)

//============================================================================
@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@end
/* EOF */
