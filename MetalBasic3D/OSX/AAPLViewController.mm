/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 View Controller for Metal Sample Code. Maintains a CADisplayLink timer that runs on the main thread and triggers rendering in AAPLView. Provides update callbacks to its delegate on the timer, prior to triggering rendering.
 */
#import "AAPLViewController.h"
#import "AAPLView.h"
#import "AAPLRenderer.h"

#import <QuartzCore/CAMetalLayer.h>

@implementation AAPLViewController
{
@private
    // app control

    CVDisplayLinkRef _displayLink;
    dispatch_source_t _displaySource;

    // boolean to determine if the first draw has occured
    BOOL _firstDrawOccurred;
    
    CFTimeInterval _timeSinceLastDrawPreviousTime;
    
    // pause/resume
    BOOL _gameLoopPaused;
    
    // our renderer instance
    AAPLRenderer *_renderer;
}

- (void)dealloc
{
    if(_displayLink)
    {
        [self stopGameLoop];
    }
}

// This is the renderer output callback function
static CVReturn dispatchGameLoop(CVDisplayLinkRef displayLink,
                                 const CVTimeStamp* now,
                                 const CVTimeStamp* outputTime,
                                 CVOptionFlags flagsIn,
                                 CVOptionFlags* flagsOut,
                                 void* displayLinkContext)
{
    __weak dispatch_source_t source = (__bridge dispatch_source_t)displayLinkContext;
    dispatch_source_merge_data(source, 1);
    return kCVReturnSuccess;
}

- (void)initCommon
{
    _renderer = [AAPLRenderer new];
    self.delegate = _renderer;

    _displaySource = dispatch_source_create(DISPATCH_SOURCE_TYPE_DATA_ADD, 0, 0, dispatch_get_main_queue());
    __block AAPLViewController* weakSelf = self;
    dispatch_source_set_event_handler(_displaySource, ^(){
        [weakSelf gameloop];
    });
    dispatch_resume(_displaySource);

    CVReturn cvReturn;
    // Create a display link capable of being used with all active displays
    cvReturn = CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);

    assert(cvReturn == kCVReturnSuccess);

    cvReturn = CVDisplayLinkSetOutputCallback(_displayLink, &dispatchGameLoop, (__bridge void*)_displaySource);

    assert(cvReturn == kCVReturnSuccess);

    cvReturn = CVDisplayLinkSetCurrentCGDisplay(_displayLink, CGMainDisplayID () );

    assert(cvReturn == kCVReturnSuccess);

    _interval = 1;
}

- (void)_windowWillClose:(NSNotification*)notification
{
    // Stop the display link when the window is closing because we will
    // not be able to get a drawable, but the display link may continue
    // to fire

    if(notification.object == self.view.window)
    {
        CVDisplayLinkStop(_displayLink);
        dispatch_source_cancel(_displaySource);
    }
}

- (id)init
{
    self = [super init];
    
    if(self)
    {
        [self initCommon];
    }
    return self;
}

// Called when loaded from nib
- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
{
	self = [super initWithNibName:nibNameOrNil
                           bundle:nibBundleOrNil];
    
	if(self)
	{
		[self initCommon];
	}
    
	return self;
}

// called when loaded from storyboard
- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    
    if(self)
    {
        [self initCommon];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    AAPLView *renderView = (AAPLView *)self.view;
    renderView.delegate = _renderer;
    
    // load all renderer assets before starting game loop
    [_renderer configure:renderView];

    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    // Register to be notified when the window closes so we can stop the displaylink
    [notificationCenter addObserver:self
                           selector:@selector(_windowWillClose:)
                               name:NSWindowWillCloseNotification
                             object:self.view.window];


    CVDisplayLinkStart(_displayLink);
}


// The main game loop called by the timer above
- (void)gameloop
{
    
    // tell our delegate to update itself here.
    [_delegate update:self];
    
    if(!_firstDrawOccurred)
    {
        // set up timing data for display since this is the first time through this loop
        _timeSinceLastDraw             = 0.0;
        _timeSinceLastDrawPreviousTime = CACurrentMediaTime();
        _firstDrawOccurred              = YES;
    }
    else
    {
        // figure out the time since we last we drew
        CFTimeInterval currentTime = CACurrentMediaTime();
        
        _timeSinceLastDraw = currentTime - _timeSinceLastDrawPreviousTime;
        
        // keep track of the time interval between draws
        _timeSinceLastDrawPreviousTime = currentTime;
    }
    
    // display (render)
    
    assert([self.view isKindOfClass:[AAPLView class]]);
    
    // call the display method directly on the render view (setNeedsDisplay: has been disabled in the renderview by default)
    [(AAPLView *)self.view display];
}

- (void)stopGameLoop
{
    if(_displayLink)
    {
        // Stop the display link BEFORE releasing anything in the view
        // otherwise the display link thread may call into the view and crash
        // when it encounters something that has been release
        CVDisplayLinkStop(_displayLink);
        dispatch_source_cancel(_displaySource);

        CVDisplayLinkRelease(_displayLink);
        _displaySource = nil;
    }
}

- (void)setPaused:(BOOL)pause
{
    if(_gameLoopPaused == pause)
    {
        return;
    }
    
    if(_displayLink)
    {
        // inform the delegate we are about to pause
        [_delegate viewController:self
                        willPause:pause];

        if(pause)
        {
            CVDisplayLinkStop(_displayLink);
        }
        else
        {
            CVDisplayLinkStart(_displayLink);
        }
    }
}

- (BOOL)isPaused
{
    return _gameLoopPaused;
}

- (void)didEnterBackground:(NSNotification*)notification
{
    [self setPaused:YES];
}

- (void)willEnterForeground:(NSNotification*)notification
{
    [self setPaused:NO];
}

@end
