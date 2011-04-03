//
//  DemoTextViewController.m
//  CoreTextExtensions
//
//  Created by Oliver Drobnik on 1/9/11.
//  Copyright 2011 Drobnik.com. All rights reserved.
//

#import "DemoTextViewController.h"
#import "DTAttributedTextView.h"
#import "DTAttributedTextContentView.h"
#import "NSAttributedString+HTML.h"
#import "DTTextAttachment.h"

#import "DTLinkButton.h"
#import <QuartzCore/QuartzCore.h>

#import <MediaPlayer/MediaPlayer.h>

@interface DemoTextViewController ()
- (void)_segmentedControlChanged:(id)sender;

- (void)linkPushed:(DTLinkButton *)button;
- (void)linkLongPressed:(UILongPressGestureRecognizer *)gesture;
- (void)debugButton:(UIBarButtonItem *)sender;

@property (nonatomic, retain) NSMutableSet *mediaPlayers;

@end


@implementation DemoTextViewController

#pragma mark NSObject

- (id)init {
	self = [super init];
	if (self) {
		_segmentedControl = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"View", @"Ranges", @"Chars", @"Data", nil]];
		_segmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
		_segmentedControl.selectedSegmentIndex = 0;
		[_segmentedControl addTarget:self action:@selector(_segmentedControlChanged:) forControlEvents:UIControlEventValueChanged];
		self.navigationItem.titleView = _segmentedControl;	
		
		// toolbar
		UIBarButtonItem *spacer = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease];
		UIBarButtonItem *debug = [[[UIBarButtonItem alloc] initWithTitle:@"Debug Frames" style:UIBarButtonItemStyleBordered target:self action:@selector(debugButton:)] autorelease];
		[self setToolbarItems:[NSArray arrayWithObjects:spacer, debug, nil]];
	}
	return self;
}


- (void)dealloc 
{
	[_fileName release];
	[lastActionLink release];
	[baseURL release];
	
	[_segmentedControl release];
	[_textView release];
	[_rangeView release];
	[_charsView release];
	[_dataView release];
	
	[mediaPlayers release];
    
	[super dealloc];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}


#pragma mark UIViewController

//- (void)loadView {
////	[super loadView];
////	From the docs:
////	"If you override this method in order to create your views manually, you should do so and
////	assign the root view of your hierarchy to the view property.
////	(The views you create should be unique instances and should not be shared
////	with any other view controller object.) Your custom implementation of this method
////	should not call super.
//}

- (void)viewDidLoad {
    [super viewDidLoad];
	
	CGRect frame = CGRectMake(0.0, 0.0, self.view.frame.size.width, self.view.frame.size.height);
	
	// Create data view
	_dataView = [[UITextView alloc] initWithFrame:frame];
	_dataView.editable = NO;
	_dataView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:_dataView];
	
	// Create chars view
	_charsView = [[UITextView alloc] initWithFrame:frame];
	_charsView.editable = NO;
	_charsView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:_charsView];
	
	// Create range view
	_rangeView = [[UITextView alloc] initWithFrame:frame];
	_rangeView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_rangeView.editable = NO;
	[self.view addSubview:_rangeView];
	
	// Create text view
    [DTAttributedTextContentView setLayerClass:[CATiledLayer class]];
	_textView = [[DTAttributedTextView alloc] initWithFrame:frame];
	_textView.textDelegate = self;
	_textView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.view addSubview:_textView];

	// Load HTML data
	NSString *readmePath = [[NSBundle mainBundle] pathForResource:_fileName ofType:nil];
	NSString *html = [NSString stringWithContentsOfFile:readmePath encoding:NSUTF8StringEncoding error:NULL];
	NSData *data = [html dataUsingEncoding:NSUTF8StringEncoding];
	
	// Create attributed string from HTML
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:1.3], NSTextSizeMultiplierDocumentOption, 
                            @"Verdana", DTDefaultFontFamily,  @"purple", DTDefaultLinkColor, nil]; // @"green",DTDefaultTextColor,
    
	NSAttributedString *string = [[NSAttributedString alloc] initWithHTML:data options:options documentAttributes:NULL];
	
	// Display string
    _textView.contentView.edgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
	_textView.attributedString = string;
   
	// Data view
	_dataView.text = [data description];
     
    [string release];
}

- (void)viewDidUnload {
	[super viewDidUnload];
	
	[_dataView release], _dataView = nil;
	[_charsView release], _charsView = nil;
	[_rangeView release], _rangeView = nil;
	[_textView release], _textView = nil;
}

- (void)viewWillAppear:(BOOL)animated 
{
	[super viewWillAppear:animated];
	
	CGRect bounds = self.view.bounds;
	_textView.frame = bounds;
	
	[self _segmentedControlChanged:nil];
	[_textView setContentInset:UIEdgeInsetsMake(0, 0, 44, 0)];
	[_textView setScrollIndicatorInsets:UIEdgeInsetsMake(0, 0, 44, 0)];
	[self.navigationController setToolbarHidden:NO animated:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
    
	// now the bar is up so we can autoresize again
	_textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    // fill other tabs
    // Create range view
	NSMutableString *dumpOutput = [[NSMutableString alloc] init];
	NSDictionary *attributes = nil;
	NSRange effectiveRange = NSMakeRange(0, 0);
    
    if ([_textView.attributedString length])
    {
        
        while ((attributes = [_textView.attributedString attributesAtIndex:effectiveRange.location effectiveRange:&effectiveRange]))
        {
            [dumpOutput appendFormat:@"Range: (%d, %d), %@\n\n", effectiveRange.location, effectiveRange.length, attributes];
            effectiveRange.location += effectiveRange.length;
            
            if (effectiveRange.location >= [_textView.attributedString length])
            {
                break;
            }
        }
    }
	_rangeView.text = dumpOutput;
	
    
	// Create characters view
	[dumpOutput setString:@""];
	NSData *dump = [[_textView.attributedString string] dataUsingEncoding:NSUTF8StringEncoding];
	for (NSInteger i = 0; i < [dump length]; i++)
	{
		char *bytes = (char *)[dump bytes];
		char b = bytes[i];
		
		[dumpOutput appendFormat:@"%x %c\n", b, b];
	}
	_charsView.text = dumpOutput;
	[dumpOutput release];
}

- (void)viewWillDisappear:(BOOL)animated;
{
	[self.navigationController setToolbarHidden:YES animated:YES];
	
	[super viewWillDisappear:animated];
}


#pragma mark Private Methods

- (void)_segmentedControlChanged:(id)sender {
	UIScrollView *selectedView = _textView;
	
	switch (_segmentedControl.selectedSegmentIndex) {
		case 1:
			selectedView = _rangeView;
			break;
		case 2:
			selectedView = _charsView;
			break;
		case 3:
			selectedView = _dataView;
			break;
	}
	
	[self.view bringSubviewToFront:selectedView];
	[selectedView flashScrollIndicators];
}


#pragma mark Custom Views on Text
- (UIView *)attributedTextContentView:(DTAttributedTextContentView *)attributedTextView viewForAttributedString:(NSAttributedString *)string frame:(CGRect)frame
{
	NSDictionary *attributes = [string attributesAtIndex:0 effectiveRange:NULL];
	
	NSURL *link = [attributes objectForKey:@"DTLink"];
	
	if (link)
	{
		DTLinkButton *button = [[[DTLinkButton alloc] initWithFrame:frame] autorelease];
		button.url = link;
		button.alpha = 0.4;
        button.guid = [attributes objectForKey:@"DTGUID"];
        
		// use normal push action for opening URL
		[button addTarget:self action:@selector(linkPushed:) forControlEvents:UIControlEventTouchUpInside];
        
		// demonstrate combination with long press
		UILongPressGestureRecognizer *longPress = [[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(linkLongPressed:)] autorelease];
		[button addGestureRecognizer:longPress];
		return button;
	}
	
	
	DTTextAttachment *attachment = [attributes objectForKey:@"DTTextAttachment"];
	
	if (attachment)
	{
		if ([attachment.contents isKindOfClass:[NSDictionary class]])
		{
			if ([[attachment.contents objectForKey:@"_tag"] isEqualToString:@"video"])
			{
				NSDictionary *attributes = [attachment.contents objectForKey:@"Attributes"];
				
				NSURL *url = [NSURL URLWithString:[attributes objectForKey:@"src"]];
				
				// we could customize the view that shows before playback starts
				UIView *grayView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
				grayView.backgroundColor = [UIColor blackColor];
				
				MPMoviePlayerController *player =[[[MPMoviePlayerController alloc] initWithContentURL:url] autorelease];
				player.controlStyle = MPMovieControlStyleEmbedded;
				
				[player prepareToPlay];
				[player setShouldAutoplay:NO];
				[self.mediaPlayers addObject:player];
				
				player.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
				[grayView addSubview:player.view];
                
				// will get resized and added to view by caller
				return grayView;
			}
		}
	}
	
	return nil;
}

- (void)linkPushed:(DTLinkButton *)button
{
	[[UIApplication sharedApplication] openURL:[button.url absoluteURL]];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex != actionSheet.cancelButtonIndex)
	{
		[[UIApplication sharedApplication] openURL:[self.lastActionLink absoluteURL]];
	}
}

- (void)linkLongPressed:(UILongPressGestureRecognizer *)gesture
{
	if (gesture.state == UIGestureRecognizerStateBegan)
	{
		DTLinkButton *button = (id)[gesture view];
		button.highlighted = NO;
		self.lastActionLink = button.url;
		
		if ([[UIApplication sharedApplication] canOpenURL:[button.url absoluteURL]])
		{
			UIActionSheet *action = [[[UIActionSheet alloc] initWithTitle:[[button.url absoluteURL] description] delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Open in Safari", nil] autorelease];
			[action showFromRect:button.frame inView:button.superview animated:YES];
		}
	}
}

- (void)debugButton:(UIBarButtonItem *)sender
{
	_textView.contentView.drawDebugFrames = !_textView.contentView.drawDebugFrames;
    [DTCoreTextLayoutFrame setShouldDrawDebugFrames:_textView.contentView.drawDebugFrames];
    [self.view setNeedsDisplay];
}

#pragma mark Properties

- (NSMutableSet *)mediaPlayers
{
	if (!mediaPlayers) {
		mediaPlayers = [[NSMutableSet alloc] init];
	}
	
	return mediaPlayers;
}

@synthesize fileName = _fileName;
@synthesize lastActionLink;
@synthesize mediaPlayers;
@synthesize baseURL;


@end
