/****************************************************************************
 * OpenSSLTest.h                                                            *
 * Created by Alexander Skobelev                                            *
 *                                                                          *
 ****************************************************************************/
#import <UIKit/UIKit.h>
#import <gh-unit/Classes/GHUnit.h> 

//============================================================================
@interface AudioSessionTest : GHTestCase

//@property (nonatomic, retain) NSFileHandle* stdinWriter;
@property (nonatomic, retain) NSFileHandle* stdoutReader;
@end

/* EOF */
