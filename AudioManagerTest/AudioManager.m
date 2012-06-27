/****************************************************************************
 * AudioManager.m                                                           *
 * Created by Alexander Skobelev                                            *
 *                                                                          *
 ****************************************************************************/
#import "AudioManager.h"

#define LOG(FMT$, ARGS$...) NSLog (@"%s -- " FMT$, __PRETTY_FUNCTION__, ##ARGS$)
#define ELOG(FMT$, ARGS$...) NSLog (@"%s -- ERROR -- " FMT$, __PRETTY_FUNCTION__, ##ARGS$)


#define TRACKS_KEY @"tracks"
#define PLAYABLE_KEY @"playable"



static void* _s_itemStatusContext  = &_s_itemStatusContext;
static void* _s_rateContext        = &_s_rateContext;
static void* _s_currentItemContext = &_s_currentItemContext;


//============================================================================
@interface AudioManager ()

@property (strong, nonatomic) AVPlayer* player;
@property (strong, nonatomic) AVPlayerItem* playerItem;

@property (strong, nonatomic) id <NSObject> timer;
@end

//============================================================================
@implementation AudioManager 

@synthesize player     = _player;
@synthesize playerItem = _playerItem;

@synthesize periodicTimerInterval = _periodicTimerInterval;
@synthesize timer = _timer;

//----------------------------------------------------------------------------
+ (AudioManager*) sharedManager
{
    static dispatch_once_t _s_once;
    static id _s_obj = nil;
    
    dispatch_once (&_s_once, ^{ _s_obj = [self new]; });
    return _s_obj;
}

//----------------------------------------------------------------------------
- (void) reset
{
    if (self.player) [self.player pause];
    
    [self setupPlayerItemToItem: nil];
    [self setupPlayer];
}

//----------------------------------------------------------------------------
- (NSError*) errorWithCode: (NSInteger) code
      localizedDescription: (NSString*) descr
{
    id info = [NSDictionary dictionaryWithObjectsAndKeys: 
                                descr, NSLocalizedDescriptionKey, nil];

    id domain = [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleIdentifier"];
    NSError* error = [NSError errorWithDomain: domain
                                         code: code
                                     userInfo: info];
    return error;
}

//----------------------------------------------------------------------------
- (BOOL) asyncPrepareURL: (NSURL*) url
       completionHandler: (void (^)(NSError* error)) handler
{
    if (! url) {
        ELOG (@"Empty URL");
        return NO;
    }

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL: url options: nil];

    if (! asset) {
        ELOG (@"Failed to create asset with URL \"%@\"", [url absoluteString]); 
        return NO;
    }
        
    id keys = [NSArray arrayWithObjects: TRACKS_KEY, PLAYABLE_KEY, nil];

    [asset loadValuesAsynchronouslyForKeys: keys
                         completionHandler: 

               ^{ dispatch_async (dispatch_get_main_queue(), 
                                  (^{ [self prepareToPlayAsset: asset 
                                                      withKeys: keys
                                             completionHandler: handler]; })); }];
    return YES;
}

//----------------------------------------------------------------------------
- (BOOL) prepareURL: (NSURL*) url
{
    BOOL     __block  url_ready = NO;
    NSError* __block  url_prep_err = nil;

    BOOL res = [self asyncPrepareURL: url
                   completionHandler: ^(NSError* err) {
            url_ready = YES;
            url_prep_err = err;
        }];

    if (! res) return NO;
    
    int i = 0;
    while (! url_ready)
    {
        NSLog(@"%d", i++);
        [[NSRunLoop currentRunLoop] runUntilDate: [NSDate distantPast]];
    }

    if (url_prep_err)
    {
        LOG(@"ERROR: %@", [url_prep_err localizedDescription]);
        return NO;
    }
    return YES;
}

//----------------------------------------------------------------------------
- (BOOL) prepareFile: (NSString*) path
{
    NSURL* url = [NSURL fileURLWithPath: path];
    return [self prepareURL: url];
}

//----------------------------------------------------------------------------
- (void) setupPlayerItemToItem: (AVPlayerItem*) item
{
    id nc = [NSNotificationCenter defaultCenter];

    if (self.playerItem)
    {
        [self.playerItem removeObserver: self
                             forKeyPath: STATUS_KEY];            
		
        [nc removeObserver: self
                      name: AVPlayerItemDidPlayToEndTimeNotification
                    object: self.playerItem];

        self.playerItem = nil;
    }

    if (item)
    {
        self.playerItem = item;
    
        [self.playerItem addObserver: self 
                          forKeyPath: STATUS_KEY 
                             options: (NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew)
                             context: _s_itemStatusContext];
        

        [nc addObserver: self
               selector: @selector (playerItemDidReachEnd:)
                   name: AVPlayerItemDidPlayToEndTimeNotification
                 object: self.playerItem];
    }
}

//----------------------------------------------------------------------------
- (void) setupPlayer
{
    if (self.player)
    {
        [self stopPeriodicTimer];

        [self.player removeObserver: self 
                         forKeyPath: CURRENT_ITEM_KEY];

        [self.player removeObserver: self 
                         forKeyPath: RATE_KEY];
        self.player = nil;
    }

    if (self.playerItem) 
    {
        self.player = [AVPlayer playerWithPlayerItem: self.playerItem];	
	
        [self.player addObserver: self 
                      forKeyPath: CURRENT_ITEM_KEY 
                         options: (NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew)
                         context: _s_currentItemContext];
    
        [self.player addObserver: self 
                      forKeyPath: RATE_KEY 
                         options: (NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew)
                         context: _s_rateContext];
    }
}    

//----------------------------------------------------------------------------
- (void) prepareToPlayAsset: (AVURLAsset*) asset
                   withKeys: (NSArray*) keys
          completionHandler: (void (^)(NSError* error)) handler
{
    AVPlayerItem* item = nil;

	for (NSString* key in keys)
	{
		NSError* error = nil;
		AVKeyValueStatus status = [asset statusOfValueForKey: key
                                                       error: &error];
        switch (status)
        {
            case AVKeyValueStatusFailed:
                item = [AVPlayerItem playerItemWithURL: asset.URL];
                if (! item) {
                    if (handler) handler (error);
                    return;
                }
                break;

            case AVKeyValueStatusCancelled:
                return;
		}
	}

    if (! item) item = [AVPlayerItem playerItemWithAsset: asset];
    if (item) 
    {
        [self setupPlayerItemToItem: item];
        [self setupPlayer];
    }
    if (handler) handler (nil);
}

//----------------------------------------------------------------------------
- (void) notifyAboutChangeOfObject: (id) obj
                           withKey: (NSString*) key
{
    id info = [NSDictionary dictionaryWithObject: obj forKey: key];

    id ntf = [NSNotification
                 notificationWithName: NTF_AUDIO_MANAGER_STATE_CHANGED
                               object: self
                             userInfo: info];
    
    LOG(@"WILL POST NOTIFICATION: key: \"%@\" object: %@", key, obj);
    
    [[NSNotificationCenter defaultCenter]
        performSelectorOnMainThread: @selector(postNotification:)
                         withObject: ntf
                      waitUntilDone: NO];
}

//----------------------------------------------------------------------------
- (void) observeValueForKeyPath: (NSString*) keyPath
                       ofObject: (id) object
                         change: (NSDictionary*) change
                        context: (void*) context 
{
    if (context == _s_rateContext) 
    {
        LOG(@"context: RATE");
        [self notifyAboutChangeOfObject: [NSNumber numberWithFloat: self.player.rate]
                                withKey: RATE_KEY];
    }
    else if (context == _s_currentItemContext) 
    {
        LOG(@"context: CURRENT_ITEM");
        [self notifyAboutChangeOfObject: self.player.currentItem
                                withKey: CURRENT_ITEM_KEY];
    }
    else if (context == _s_itemStatusContext) 
    {
        LOG(@"context: ITEM STATUS");
        [self notifyAboutChangeOfObject: [NSNumber numberWithInt: self.player.status]
                                withKey: STATUS_KEY];
    }
    else {
        [super observeValueForKeyPath: keyPath
                             ofObject: object
                               change: change
                              context: context];
    }
    return;
}

//----------------------------------------------------------------------------
- (void) playerItemDidReachEnd: (NSNotification*) ntf
{
    self.player.rate = 0;

    ntf = [NSNotification
              notificationWithName: NTF_AUDIO_MANAGER_PLAY_COMPLETED
                            object: self];
    
    [[NSNotificationCenter defaultCenter]
        performSelectorOnMainThread: @selector(postNotification:)
                         withObject: ntf
                      waitUntilDone: NO];
}

//----------------------------------------------------------------------------
- (BOOL) playing
{
    return (self.player.rate > 0);
}

//----------------------------------------------------------------------------
- (void) play
{
    [self startPeriodicTimer];
    [self.player play];
}

//----------------------------------------------------------------------------
- (void) pause
{
    [self.player pause];
    [self stopPeriodicTimer];
}

//----------------------------------------------------------------------------
- (double) duration
{
    AVPlayerItem* item = self.player.currentItem;
    CMTime cmtime = item ? item.duration : kCMTimeInvalid;

    return (CMTIME_IS_INVALID (cmtime) ? 0 : CMTimeGetSeconds (cmtime));
}

//----------------------------------------------------------------------------
- (double) currentTime
{
    CMTime cmtime = self.player.currentTime;
    return (CMTIME_IS_VALID (cmtime) ? CMTimeGetSeconds (cmtime) : 0);
}

//----------------------------------------------------------------------------
- (void) seekToTime: (double) seconds
{
    CMTime cmtime = kCMTimeZero;
        
    if (isfinite(seconds)) 
    {
        if (seconds < 0) seconds = [self duration] + seconds;
        if (seconds < 0) seconds = 0;

        cmtime  = CMTimeMakeWithSeconds (seconds, NSEC_PER_SEC);
    }
    else {
        AVPlayerItem* item = self.player.currentItem;
        cmtime = item ? item.duration : kCMTimeInvalid;
    }
    [self.player seekToTime: cmtime];
}

//----------------------------------------------------------------------------
- (void) startPeriodicTimer
{
    if (_periodicTimerInterval > 0) 
    {
        CMTime cmtime = CMTimeMakeWithSeconds (_periodicTimerInterval, NSEC_PER_SEC);

        AudioManager* __weak self_weak = self;
        
        self.timer = [self.player 
                         addPeriodicTimeObserverForInterval: cmtime
                                                      queue: NULL // use the main queue
                                                 usingBlock: ^(CMTime time) 
                             {
                                 if (self_weak.periodicTimerInterval > 0)
                                 {
                                     double secs  = CMTimeGetSeconds(time);
                                     double dur   = [self_weak duration];
                                     double rate  = self_weak.player.rate;
                                     double rtime = 0;

                                     if (isfinite (dur) && dur > 0) rtime = secs / dur;
 
                                     id info = [NSDictionary dictionaryWithObjectsAndKeys: 
                                                                 [NSNumber numberWithDouble: secs],  CURRENT_TIME_KEY,
                                                                 [NSNumber numberWithDouble: rtime], RELATIVE_TIME_KEY,
                                                                 [NSNumber numberWithDouble: dur],   DURATION_KEY,
                                                                 [NSNumber numberWithDouble: rate],  RATE_KEY,
                                                                 nil];

                                     [[NSNotificationCenter defaultCenter]
                                         postNotificationName: NTF_AUDIO_MANAGER_PLAY_TIMER
                                                       object: self_weak
                                                     userInfo: info];
                                 }
                             }];
    }
}

//----------------------------------------------------------------------------
- (void) stopPeriodicTimer
{
    if (self.timer) {
        [self.player removeTimeObserver: self.timer];
        self.timer = nil;
    }
}

@end

/* EOF */
