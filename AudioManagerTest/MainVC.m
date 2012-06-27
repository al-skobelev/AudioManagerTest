/**************************************************************************** 
 * MainVC.m                                                                 * 
 * Created by Alexander Skobelev                                            * 
 *                                                                          * 
 ****************************************************************************/

#import "MainVC.h"
#import "AudioManager.h"
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
- (void) setupTogglePlayBtn: (BOOL) enabled;
- (void) preparePlayerForSelectedRow;

- (void) onPlayTimer: (NSNotification*) ntf;
- (void) onPlayCompleted: (NSNotification*) ntf;
@end

//============================================================================
@implementation MainVC

@synthesize tableView;
@synthesize refreshBtn;
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
    AudioManager* amgr = [AudioManager sharedManager];
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

    [self.tableView reloadData];
    [self preparePlayerForSelectedRow];
}

//----------------------------------------------------------------------------
- (void) viewWillAppear: (BOOL) animated
{
    [super viewWillAppear: animated];
    [self updateUI];
    [AudioManager sharedManager].periodicTimerInterval = 0.5;
    
    ADD_OBSERVER (NTF_AUDIO_MANAGER_PLAY_COMPLETED, self, onPlayCompleted:);
    ADD_OBSERVER (NTF_AUDIO_MANAGER_PLAY_TIMER,     self, onPlayTimer:);
}

//----------------------------------------------------------------------------
- (void) viewWillDisappear: (BOOL) animated
{
    [super viewWillDisappear: animated];
    REMOVE_OBSERVER (NTF_AUDIO_MANAGER_PLAY_COMPLETED, self);
    REMOVE_OBSERVER (NTF_AUDIO_MANAGER_PLAY_TIMER,     self);
}

//----------------------------------------------------------------------------
- (IBAction) onRefresh: (id) sender 
{
    AudioManager* amgr = [AudioManager sharedManager];
    [amgr reset];
    [self updateUI];
}

//----------------------------------------------------------------------------
- (void) onPlayURLReady: (NSError*) err
{
    [self setupTogglePlayBtn: (err == nil)];
}

//----------------------------------------------------------------------------
- (IBAction) onTogglePlay: (id) sender 
{
    AudioManager* amgr = [AudioManager sharedManager];

    if (amgr.playing) [amgr pause];
    else              [amgr play];
    
    [self setupTogglePlayBtn: YES];
}

//----------------------------------------------------------------------------
- (IBAction) onBeginPlaySliding: (id) sender
{
    AudioManager* amgr = [AudioManager sharedManager];
    amgr.periodicTimerInterval = 0;
}


//----------------------------------------------------------------------------
- (IBAction) onEndPlaySliding: (id) sender
{
    AudioManager* amgr = [AudioManager sharedManager];
    amgr.periodicTimerInterval = 0.5;
}


//----------------------------------------------------------------------------
- (IBAction) onPlaySliderChanged: (id) sender
{
    AudioManager* amgr = [AudioManager sharedManager];
    double duration = [amgr duration];

    double  time = self.playSlider.value;
    float minval = self.playSlider.minimumValue;
    float maxval = self.playSlider.maximumValue;

    time = duration * (time - minval) / (maxval - minval);
    [amgr seekToTime: time];
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
- (void) setupTogglePlayBtn: (BOOL) enabled
{
    AudioManager* amgr = [AudioManager sharedManager];

    self.togglePlayBtn.enabled = enabled;
    self.togglePlayBtn.image = [UIImage imageNamed: (amgr.playing ? @"stop" : @"play")];
}

//----------------------------------------------------------------------------
- (void) preparePlayerForSelectedRow
{
    AudioManager* amgr = [AudioManager sharedManager];

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
    double  time = [[[ntf userInfo] objectForKey: RELATIVE_TIME_KEY] doubleValue];

    [self.playSlider setValue: ((maxval - minval) * time + minval)];
    
    
    NSIndexPath* ipath = [self.tableView indexPathForSelectedRow];
    if (ipath)
    {
        id info = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithInt: MPMediaTypeAnyAudio],   MPMediaItemPropertyMediaType,
                                    [self.files objectAtIndex: ipath.row],           MPMediaItemPropertyTitle,
                                    [[ntf userInfo] objectForKey: CURRENT_TIME_KEY], MPNowPlayingInfoPropertyPlaybackRate,
                                    [[ntf userInfo] objectForKey: DURATION_KEY],     MPMediaItemPropertyPlaybackDuration,
                                    [[ntf userInfo] objectForKey: RATE_KEY],         MPNowPlayingInfoPropertyPlaybackRate,
                                    nil];

        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;
    }
}

//----------------------------------------------------------------------------
- (void) onPlayCompleted: (NSNotification*) ntf
{
    AudioManager* amgr = [AudioManager sharedManager];

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
