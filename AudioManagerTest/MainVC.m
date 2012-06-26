/**************************************************************************** 
 * MainVC.m                                                                 * 
 * Created by Alexander Skobelev                                            * 
 *                                                                          * 
 ****************************************************************************/

#import "MainVC.h"
#import "AudioManager.h"

//============================================================================
@interface MainVC ()

@property (strong, nonatomic) NSArray* files;
@property (assign, nonatomic) BOOL     playing;

- (void) setupFiles;
- (void) setupTogglePlayBtn: (BOOL) enabled;
- (void) preparePlayerForSelectedRow;
@end

//============================================================================
@implementation MainVC

@synthesize tableView;
@synthesize refreshBtn;
@synthesize togglePlayBtn;
@synthesize playSlider;

@synthesize files = _files;
@synthesize weakView;
@synthesize playing = _playing;

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
- (void) updateUI
{
    [self setupFiles];
    [self setupTogglePlayBtn: NO];

    [self.tableView reloadData];
    [self preparePlayerForSelectedRow];
}

//----------------------------------------------------------------------------
- (void) viewWillAppear: (BOOL) animated
{
    [super viewWillAppear: animated];
    [self updateUI];
}

//----------------------------------------------------------------------------
- (IBAction) onRefresh: (id) sender 
{
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
    if (self.playing)
    {
        [[AudioManager sharedManager] pause];
        self.playing = NO;
    }
    else
    {       
        [[AudioManager sharedManager] play];
        self.playing = YES;
    }
    [self setupTogglePlayBtn: YES];
}

//----------------------------------------------------------------------------
- (IBAction) onPlaySliderChanged: (id) sender
{
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
    self.files = names;
}

//----------------------------------------------------------------------------
- (void) setupTogglePlayBtn: (BOOL) enabled
{
    self.togglePlayBtn.enabled = enabled;
    self.togglePlayBtn.image = [UIImage imageNamed:  (self. playing ? @"stop" : @"play")];
}

//----------------------------------------------------------------------------
- (void) preparePlayerForSelectedRow
{
    NSIndexPath* ipath = [self.tableView indexPathForSelectedRow];
    if (ipath)
    {
        NSString* fname = [self.files objectAtIndex: ipath.row];
        
        fname = [[self documentsFolder] stringByAppendingPathComponent: fname];
        NSURL* url = [NSURL fileURLWithPath: fname];
        
        [[AudioManager sharedManager] 
            asyncPrepareURL: url
          completionHandler: ^(NSError* err){ [self onPlayURLReady: err]; }];
    }
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
- (UITableViewCell*) tableView: (UITableView*) tableView
         cellForRowAtIndexPath: (NSIndexPath*) indexPath
{
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier: @"Cell"];
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
