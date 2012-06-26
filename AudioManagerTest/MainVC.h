/**************************************************************************** 
 * MainVC.h                                                                 * 
 * Created by Alexander Skobelev                                            * 
 *                                                                          * 
 ****************************************************************************/

#import <UIKit/UIKit.h>

//============================================================================
@interface MainVC : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView*     tableView;
@property (weak, nonatomic) IBOutlet UIButton*        refreshBtn;
@property (weak, nonatomic) IBOutlet UIBarButtonItem* togglePlayBtn;
@property (weak, nonatomic) IBOutlet UISlider*        playSlider;

@property (weak, nonatomic) IBOutlet UIView* weakView;

- (IBAction) onRefresh: (id) sender;
- (IBAction) onTogglePlay: (id) sender;
- (IBAction) onPlaySliderChanged: (id) sender;

@end
/* EOF */
