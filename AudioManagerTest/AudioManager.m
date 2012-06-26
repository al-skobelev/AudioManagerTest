/****************************************************************************
 * AudioManager.m                                                           *
 * Created by Alexander Skobelev                                            *
 *                                                                          *
 ****************************************************************************/
#import "AudioManager.h"

#define LOG(FMT$, ARGS$...) NSLog (@"%s -- " FMT$, __PRETTY_FUNCTION__, ##ARGS$)
#define ELOG(FMT$, ARGS$...) NSLog (@"%s -- ERROR -- " FMT$, __PRETTY_FUNCTION__, ##ARGS$)

#define STATUS_KEY       @"status"
#define RATE_KEY         @"rate"
#define CURRENT_ITEM_KEY @"currentItem"

#define TRACKS_KEY @"tracks"
#define PLAYABLE_KEY @"playable"



static void* _s_itemStatusContext  = &_s_itemStatusContext;
static void* _s_rateContext        = &_s_rateContext;
static void* _s_currentItemContext = &_s_currentItemContext;


//============================================================================
@interface AudioManager ()

@end

//============================================================================
@implementation AudioManager 

@synthesize playing    = _playing;
@synthesize player     = _player;
@synthesize playerItem = _playerItem;
@synthesize playerView = _playerView;

//----------------------------------------------------------------------------
+ (AudioManager*) sharedManager
{
    static dispatch_once_t _s_once;
    static id _s_obj = nil;
    
    dispatch_once (&_s_once, ^{ _s_obj = [self new]; });
    return _s_obj;
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
    if (! self.player)
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

    if (self.player.currentItem != self.playerItem)
    {
        [self.player replaceCurrentItemWithPlayerItem: self.playerItem];
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
                    if (handler) handler(error);
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
- (void) observeValueForKeyPath: (NSString*) keyPath
                       ofObject: (id) object
                         change: (NSDictionary*) change
                        context: (void*) context 
{
    if (context == _s_rateContext) 
    {
        LOG(@"context: RATE");
    }
    else if (context == _s_currentItemContext) 
    {
        LOG(@"context: CURRENT_ITEM");
    }
    else if (context == _s_itemStatusContext) 
    {
        LOG(@"context: ITEM STATUS");
        dispatch_async (dispatch_get_main_queue(),
                        ^{
                            LOG(@"PLAYER STATUS KEY CHANGED");
                            //if (self.statusCallback) self.statusCallback(self);
                        });
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
    [self.player seekToTime: kCMTimeZero];
}

//----------------------------------------------------------------------------
- (void) play
{
    [self.player play];
}

//----------------------------------------------------------------------------
- (void) pause
{
    [self.player pause];
}

@end

/* EOF */
