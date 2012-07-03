/**************************************************************************** 
 * AppDelegate.m                                                            * 
 * Created by Alexander Skobelev                                            * 
 *                                                                          * 
 ****************************************************************************/

#import "AppDelegate.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "CommonUtils.h"

#import "AudioPlayer.h"

//============================================================================
@interface AppDelegate ()
@property (assign) BOOL resumePlayback;
@property (assign) BOOL inBackground;
@end

//============================================================================
@implementation AppDelegate

@synthesize resumePlayback = _resumePlayback;
@synthesize window = _window;
@synthesize inBackground = _inBackground;

// //----------------------------------------------------------------------------
// - (void) setupAudioSession
// {
//     //AudioSessionInitialize (NULL, NULL, NULL, NULL);
//     NSError* err = nil;
//     AVAudioSession* as = [AVAudioSession sharedInstance];

//     as.delegate = self;

//     if (! [as setCategory: AVAudioSessionCategoryPlayback
//                     error: &err])
//     {
//         NSLog(@"ERROR: Failed to set playback audio category. %@", [err localizedDescription]);
//     }

//     //NSLog(@"#3 Category: %@", [[AVAudioSession sharedInstance] category]);
//     if (! [as setActive: YES
//                   error: &err])
//     {
//         NSLog(@"ERROR: Failed to set audio session active. %@", [err localizedDescription]);
//     }

// }

//----------------------------------------------------------------------------
- (void) setupAudioSession
{
    [[NSNotificationCenter defaultCenter]
        addObserver: self
           selector: @selector(onAudioInterruption:)
               name: NTF_AUDIO_SESSION_INTERRUPTION
             object: nil];

    OSStatus status = [AudioSession setCategory: kAudioSessionCategory_MediaPlayback];
    if (status != 0)
    {
        NSLog(@"ERROR: Failed to set playback audio category.");
    }

    //NSLog(@"#3 Category: %@", [[AVAudioSession sharedInstance] category]);
    if (0 != [AudioSession setActive: YES])
    {
        NSLog(@"ERROR: Failed to set audio session active.");
    }
}

//----------------------------------------------------------------------------
- (void) beginInterruption
{
    if ([AudioPlayer sharedPlayer].playing)
    {
        [[AudioPlayer sharedPlayer] pause];
        self.resumePlayback = YES;
    }
}

//----------------------------------------------------------------------------
- (void) endInterruption
{
    if (! self.inBackground)
    {
        [self setupAudioSession];
        if (self.resumePlayback)
        {
            [[AudioPlayer sharedPlayer] play];
            self.resumePlayback = NO;
        }
    }
}

//----------------------------------------------------------------------------
- (void) onAudioInterruption: (NSNotification*) ntf
{
    int state = [[[ntf userInfo] objectForKey: AUDIO_SESSION_STATE_KEY] intValue];
    
    if (state == kAudioSessionBeginInterruption)
    {
        [self beginInterruption];
    }
    else {
        [self endInterruption];
    }
}

//----------------------------------------------------------------------------
- (void) handleChangeOfPropery: (UInt32) prop_id
                      withInfo: (id) info
{
    NSLog (@"Property '%@' changed with info: %@", fccode_to_string (prop_id), info);
}

//----------------------------------------------------------------------------
- (BOOL) application: (UIApplication*) application
  didFinishLaunchingWithOptions: (NSDictionary*) launchOptions
{
    [self setupAudioSession];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];

    NSString* docpath = user_documents_path();
    NSArray* files = [[NSBundle mainBundle] 
                         pathsForResourcesOfType: @"wav"
                                     inDirectory: @"audio"];

    for (NSString* fpath in files)
    {
        [[NSFileManager defaultManager]
            copyItemAtPath: fpath 
                    toPath: STR_ADDPATH (docpath, [fpath lastPathComponent]) 
                     error: NULL];
    }

    return YES;
}
							
//----------------------------------------------------------------------------
- (void) applicationWillResignActive: (UIApplication*) application
{
    // Sent when the application is about to move from active to inactive
    // state. This can occur for certain types of temporary interruptions
    // (such as an incoming phone call or SMS message) or when the user quits
    // the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle
    // down OpenGL ES frame rates. Games should use this method to pause the
    // game.
}

//----------------------------------------------------------------------------
- (void) applicationDidEnterBackground: (UIApplication*) application
{
    self.inBackground = YES;
}

//----------------------------------------------------------------------------
- (void) applicationWillEnterForeground: (UIApplication*) application
{
    self.inBackground = NO;

    if (self.resumePlayback) {
        dispatch_after (0.1, dispatch_get_main_queue(), ^{
                [self endInterruption];
            });
    }
}

//----------------------------------------------------------------------------
- (void) applicationDidBecomeActive: (UIApplication*) application
{
    // Restart any tasks that were paused (or not yet started) while the
    // application was inactive. If the application was previously in the
    // background, optionally refresh the user interface.
}

//----------------------------------------------------------------------------
- (void) applicationWillTerminate: (UIApplication*) application
{
    // Called when the application is about to terminate. Save data if
    // appropriate. See also applicationDidEnterBackground:.
}


@end
/* EOF */
