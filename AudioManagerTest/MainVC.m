/**************************************************************************** 
 * MainVC.m                                                                 * 
 * Created by Alexander Skobelev                                            * 
 *                                                                          * 
 ****************************************************************************/

#import "MainVC.h"
#import "AudioPlayer.h"
#import "AudioSession.h"
#import <MediaPlayer/MediaPlayer.h>

#define ADD_OBSERVER_W_OBJ(NTFNAME$, OBSERV$, SEL$, OBJ$)               \
    {                                                                   \
        id nc$ = [NSNotificationCenter defaultCenter];                  \
        id observ$ = (OBSERV$);                                         \
        id ntfname$ = (NTFNAME$);                                       \
        id obj$ = (OBJ$);                                               \
        [nc$ removeObserver: observ$ name: ntfname$ object: obj$];      \
        [nc$ addObserver: observ$                                       \
                selector: @selector(SEL$)                               \
                    name: ntfname$                                      \
                  object: obj$];                                        \
    }

#define ADD_OBSERVER(NTFNAME$, OBSERV$, SEL$)           \
    ADD_OBSERVER_W_OBJ(NTFNAME$, OBSERV$, SEL$, nil)


#define REMOVE_OBSERVER_W_OBJ(NTFNAME$, OBSERV$, OBJ$)              \
    [[NSNotificationCenter defaultCenter]                           \
        removeObserver: OBSERV$ name: NTFNAME$ object: OBJ$];       \
    

#define REMOVE_OBSERVER(NTFNAME$, OBSERV$)          \
    REMOVE_OBSERVER_W_OBJ(NTFNAME$, OBSERV$, nil)               



//============================================================================
@interface MainVC ()

@property (strong, nonatomic) NSArray* files;

- (void) setupFiles;

- (void) setupSpeakerBtn;
- (void) setupTogglePlayBtn: (BOOL) enabled;
- (void) preparePlayerForSelectedRow;

- (void) onPlayTimer: (NSNotification*) ntf;
- (void) onPlayCompleted: (NSNotification*) ntf;
@end

//============================================================================
@implementation MainVC

@synthesize tableView;
@synthesize refreshBtn;
@synthesize speakerBtn;
@synthesize togglePlayBtn;
@synthesize playSlider;

@synthesize files = _files;
@synthesize weakView;

//----------------------------------------------------------------------------
- (void) viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    NSLog(@"%s -- view: %@", __PRETTY_FUNCTION__, self.weakView);
}

//----------------------------------------------------------------------------
- (void) viewDidUnload
{
    NSLog(@"%s -- view: %@", __PRETTY_FUNCTION__, self.weakView);
    [super viewDidUnload];
}

//----------------------------------------------------------------------------
- (void) syncSlider
{
    AudioPlayer* amgr = [AudioPlayer sharedPlayer];
    double dur = [amgr duration];

    double time = ((isfinite (dur) && (dur > 0))
                   ? [amgr currentTime] / dur
                   : 0);

    float minval = [self.playSlider minimumValue];
    float maxval = [self.playSlider maximumValue];
    
    [self.playSlider setValue: ((maxval - minval) * time + minval)];
}

//----------------------------------------------------------------------------
- (void) updateUI
{
    [self setupFiles];
    [self setupTogglePlayBtn: NO];
    [self syncSlider];
    [self setupSpeakerBtn];
    [self.tableView reloadData];
    [self preparePlayerForSelectedRow];
}

//----------------------------------------------------------------------------
- (void) viewWillAppear: (BOOL) animated
{
    [super viewWillAppear: animated];
    [self updateUI];
    [AudioPlayer sharedPlayer].periodicTimerInterval = 0.5;
    
    ADD_OBSERVER (NTF_AUDIO_PLAYER_PLAY_COMPLETED, self, onPlayCompleted:);
    ADD_OBSERVER (NTF_AUDIO_PLAYER_PLAY_TIMER,     self, onPlayTimer:);
    ADD_OBSERVER (NTF_AUDIO_PLAYER_STATE_CHANGED,  self, onPlayerStateChanged:);

    [AudioSession addListener: self
                  forProperty: kAudioSessionProperty_AudioRouteChange];
    [AudioSession addListener: self
                  forProperty: kAudioSessionProperty_CurrentHardwareOutputVolume];
}

//----------------------------------------------------------------------------
- (void) viewWillDisappear: (BOOL) animated
{
    [super viewWillDisappear: animated];

    [AudioSession removeListener: self
                     forProperty: kAudioSessionProperty_CurrentHardwareOutputVolume];

    [AudioSession removeListener: self
                     forProperty: kAudioSessionProperty_AudioRouteChange];

    REMOVE_OBSERVER (NTF_AUDIO_PLAYER_PLAY_COMPLETED, self);
    REMOVE_OBSERVER (NTF_AUDIO_PLAYER_PLAY_TIMER,     self);
    REMOVE_OBSERVER (NTF_AUDIO_PLAYER_STATE_CHANGED,  self);
}

//----------------------------------------------------------------------------
- (void) handleChangeOfPropery: (UInt32) prop_id
                      withInfo: (id) info
{
    NSLog(@"Property changed: %@ info: %@", fccode_to_string (prop_id), info);
    switch (prop_id)
    {
        case kAudioSessionProperty_AudioRouteChange:
            [self setupSpeakerBtn];
            break;

        case kAudioSessionProperty_CurrentHardwareOutputVolume:
            break;
    }
}

//----------------------------------------------------------------------------
- (IBAction) onRefresh: (id) sender 
{
    AudioPlayer* amgr = [AudioPlayer sharedPlayer];
    [amgr reset];
    [self updateUI];
}

//----------------------------------------------------------------------------
- (void) onPlayURLReady: (NSError*) err
{
    [self setupTogglePlayBtn: (err == nil)];
}

//----------------------------------------------------------------------------
- (IBAction) onSpeakerBtn: (id) sender 
{
    [AudioSession setLoudspeakerEnabled: ! [AudioSession loudspeakerEnabled]];
}

//----------------------------------------------------------------------------
- (IBAction) onTogglePlay: (id) sender 
{
    AudioPlayer* amgr = [AudioPlayer sharedPlayer];

    if (amgr.playing) [amgr pause];
    else              [amgr play];
    
    [self setupTogglePlayBtn: YES];
}

//----------------------------------------------------------------------------
- (IBAction) onBeginPlaySliding: (id) sender
{
    AudioPlayer* amgr = [AudioPlayer sharedPlayer];
    amgr.periodicTimerInterval = 0;
}


//----------------------------------------------------------------------------
- (IBAction) onEndPlaySliding: (id) sender
{
    AudioPlayer* amgr = [AudioPlayer sharedPlayer];

    double duration = [amgr duration];

    double  time = self.playSlider.value;
    float minval = self.playSlider.minimumValue;
    float maxval = self.playSlider.maximumValue;

    time = duration * (time - minval) / (maxval - minval);
    [amgr seekToTime: time];

    amgr.periodicTimerInterval = 0.5;
}


//----------------------------------------------------------------------------
- (IBAction) onPlaySliderChanged: (id) sender
{
    // AudioPlayer* amgr = [AudioPlayer sharedPlayer];
    // double duration = [amgr duration];

    // double  time = self.playSlider.value;
    // float minval = self.playSlider.minimumValue;
    // float maxval = self.playSlider.maximumValue;

    // time = duration * (time - minval) / (maxval - minval);
    // [amgr seekToTime: time];
}

//----------------------------------------------------------------------------
- (NSString*) documentsFolder
{
    static NSString* path = nil;
    if (! path) {
        path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)
                   lastObject];
    }

    return path;
}

//----------------------------------------------------------------------------
- (void) setupFiles
{
    id fm = [NSFileManager defaultManager];
    NSError* err = nil;
    NSArray* names = [fm contentsOfDirectoryAtPath: [self documentsFolder]
                                             error: &err];

    id arr = [NSMutableArray arrayWithObject: @"LIVE HTTP STREAM"];
    [arr addObjectsFromArray: names];

    self.files = arr;
}

//----------------------------------------------------------------------------
- (void) setupSpeakerBtn
{
    NSString* aroute = [AudioSession audioRoute];
    NSLog(@"audio route: %@", aroute);

    BOOL on = [aroute hasPrefix: @"Speaker"];
    self.speakerBtn.image = [UIImage imageNamed: (on ? @"speaker-on" : @"speaker-off")];
}

//----------------------------------------------------------------------------
- (void) setupTogglePlayBtn: (BOOL) enabled
{
    AudioPlayer* amgr = [AudioPlayer sharedPlayer];

    self.togglePlayBtn.enabled = enabled;
    self.togglePlayBtn.image = [UIImage imageNamed: (amgr.playing ? @"stop" : @"play")];
}

//----------------------------------------------------------------------------
- (void) preparePlayerForSelectedRow
{
    AudioPlayer* amgr = [AudioPlayer sharedPlayer];

    [amgr pause]; 
    [amgr seekToTime: 0];
    [self syncSlider];

    NSIndexPath* ipath = [self.tableView indexPathForSelectedRow];
    if (ipath)
    {
        NSURL* url;
        if (ipath.row > 0) 
        {
            NSString* fname = [self.files objectAtIndex: ipath.row];
            fname = [[self documentsFolder] stringByAppendingPathComponent: fname];

            url = [NSURL fileURLWithPath: fname];
        }
        else {
            url = [NSURL URLWithString: @"http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8"];
        }
        
        if ([amgr prepareURL: url])
        {
            [self onPlayURLReady: nil];
        }

        // [amgr 
        //     asyncPrepareURL: url
        //   completionHandler: ^(NSError* err){ [self onPlayURLReady: err]; }];
    }
}


//----------------------------------------------------------------------------
- (void) onPlayTimer: (NSNotification*) ntf
{
    // [self syncSlider];

    float minval = [self.playSlider minimumValue];
    float maxval = [self.playSlider maximumValue];
    double  time = [[[ntf userInfo] objectForKey: AUDIO_PLAYER_RELATIVE_TIME_KEY] doubleValue];

    [self.playSlider setValue: ((maxval - minval) * time + minval)];
    
    
    NSIndexPath* ipath = [self.tableView indexPathForSelectedRow];
    if (ipath)
    {
        id info = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithInt: MPMediaTypeAnyAudio],   MPMediaItemPropertyMediaType,
                                    [self.files objectAtIndex: ipath.row],           MPMediaItemPropertyTitle,
                                    [[ntf userInfo] objectForKey: AUDIO_PLAYER_CURRENT_TIME_KEY], MPNowPlayingInfoPropertyPlaybackRate,
                                    [[ntf userInfo] objectForKey: AUDIO_PLAYER_DURATION_KEY],     MPMediaItemPropertyPlaybackDuration,
                                    [[ntf userInfo] objectForKey: AUDIO_PLAYER_RATE_KEY],         MPNowPlayingInfoPropertyPlaybackRate,
                                    nil];

        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;
    }
}

//----------------------------------------------------------------------------
- (void) onPlayerStateChanged: (NSNotification*) ntf
{
    id rate = [[ntf userInfo] objectForKey: AUDIO_PLAYER_RATE_KEY];
    if (rate)
    {
        [self setupTogglePlayBtn: YES];
    }
}

//----------------------------------------------------------------------------
- (void) onPlayCompleted: (NSNotification*) ntf
{
    AudioPlayer* amgr = [AudioPlayer sharedPlayer];

    [amgr seekToTime: 0];
    self.playSlider.value = 0;

    [self setupTogglePlayBtn: YES];
}

//////////////////////////////////////////////////////////////////////////////
- (BOOL) shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation) orient
{
    return (orient != UIInterfaceOrientationPortraitUpsideDown);
}

//----------------------------------------------------------------------------
- (NSInteger) tableView: (UITableView*) tableView
  numberOfRowsInSection: (NSInteger) section
{
    return self.files.count;
}


//----------------------------------------------------------------------------
- (UITableViewCell*) tableView: (UITableView*) tv
         cellForRowAtIndexPath: (NSIndexPath*) indexPath
{
    UITableViewCell* cell = [tv dequeueReusableCellWithIdentifier: @"Cell"];
    if (! cell)
    {
        cell = [[UITableViewCell alloc] 
                   initWithStyle: UITableViewCellStyleDefault
                 reuseIdentifier: @"Cell"];
    }
    cell.textLabel.text = [self.files objectAtIndex: indexPath.row];
    return cell;
}

//----------------------------------------------------------------------------
- (void) tableView: (UITableView*) tableView
didSelectRowAtIndexPath: (NSIndexPath*) ipath
{
    [self preparePlayerForSelectedRow];
}

@end
/* EOF */
