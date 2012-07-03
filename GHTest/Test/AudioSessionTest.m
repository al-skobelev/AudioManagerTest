/****************************************************************************
 * OpenSSLTest.m                                                            *
 * Created by Alexander Skobelev                                            *
 *                                                                          *
 ****************************************************************************/

#import "AudioSessionTest.h"



//============================================================================
@implementation AudioSessionTest

//@synthesize stdinWriter;
@synthesize stdoutReader;

//----------------------------------------------------------------------------
- (void) onOutputAvailable: (NSNotification*) ntf
{
    if ([ntf object] == self.stdoutReader)
    {
        NSData* data = [self.stdoutReader availableData];
        if (data) {
            NSString* str =  [[NSString alloc] initWithData: data
                                                   encoding: NSUTF8StringEncoding];
            [str autorelease];

            str = [str stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (str.length) {
                [self log: str];
            }
        }
        [self.stdoutReader waitForDataInBackgroundAndNotify];
    }
}

//----------------------------------------------------------------------------
- (BOOL) rebindStreams
{
    if (!self.stdoutReader)
    {
        // int stdin_fds[2];
        int stdout_fds[2];

        [[NSNotificationCenter defaultCenter]
            addObserver: self
               selector: @selector(onOutputAvailable:)
                   name: NSFileHandleDataAvailableNotification
                 object: nil];
    

        // if (-1 == pipe (stdin_fds))
        // {
        //     NSLog (@"ERROR! Failed to create  a pipe for stdin. %s", strerror (errno));
        //     return NO;
        // }

        // if (-1 == dup2 (stdin_fds[0], STDIN_FILENO))
        // {
        //     NSLog (@"ERROR! Failed to dup2 the stdin. %s", strerror (errno));
        //     return NO;
        // }

        if (-1 == pipe (stdout_fds))
        {
            NSLog (@"ERROR! Failed to create  a pipe for stdout. %s", strerror (errno));
            return NO;
        }

        if (-1 == dup2 (stdout_fds[1], STDOUT_FILENO))
        {
            NSLog (@"ERROR! Failed to dup2 the stdin. %s", strerror (errno));
            return NO;
        }

        // if (-1 == dup2 (stdout_fds[1], STDERR_FILENO))
        // {
        //     NSLog (@"ERROR! Failed to dup2 the stdin. %s", strerror (errno));
        //     return NO;
        // }

        // id fhw = [[NSFileHandle alloc] initWithFileDescriptor: stdin_fds[1]];
        id fhr = [[NSFileHandle alloc] initWithFileDescriptor: stdout_fds[0]];

        // self.stdinWriter = fhw;
        self.stdoutReader = fhr;

        [self.stdoutReader waitForDataInBackgroundAndNotify];

        [fhr release];
        // [fhw release];

        setvbuf (stdout, NULL, _IONBF, 0);
    }

    return YES;
}

- (void)setUpClass {
    // [self performSelectorOnMainThread: @selector(rebindStreams)
    //                        withObject: nil
    //                     waitUntilDone: YES];
  // Run at start of all tests in the class
}

- (void)tearDownClass {
  // Run at end of all tests in the class
}

- (void)setUp {
  // Run before each test method
}

- (void)tearDown {
  // Run after each test method
}   

@end
