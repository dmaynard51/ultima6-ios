/*
 *  nuvie_ios_ui.mm
 *  On-screen touch controls for the iOS port. Adds a native UIKit overlay of
 *  buttons (a movement D-pad plus a few action keys) in the letterbox bars on
 *  either side of the 320x200 game view. Each button synthesises the SDL key
 *  event that the corresponding Nuvie keybinding expects.
 */
#import <UIKit/UIKit.h>

#include "nuvie_ios_ui.h"
#include "SDL.h"
#include "SDL_syswm.h"

// Special tag value meaning "toggle the on-screen keyboard" rather than a key.
#define NUVIE_TAG_KEYBOARD 0x7FFFFFFF

static void nuvie_push_key(SDL_Keycode sym)
{
	SDL_Event e;
	SDL_zero(e);
	e.type = SDL_KEYDOWN;
	e.key.state = SDL_PRESSED;
	e.key.keysym.sym = sym;
	e.key.keysym.scancode = SDL_GetScancodeFromKey(sym);
	SDL_PushEvent(&e);

	e.type = SDL_KEYUP;
	e.key.state = SDL_RELEASED;
	SDL_PushEvent(&e);
}

@interface NuvieButtonTarget : NSObject
- (void)onTap:(UIButton *)sender;
@end

@implementation NuvieButtonTarget
- (void)onTap:(UIButton *)sender
{
	if(sender.tag == NUVIE_TAG_KEYBOARD) {
		if(SDL_IsTextInputActive())
			SDL_StopTextInput();
		else
			SDL_StartTextInput();
		return;
	}
	nuvie_push_key((SDL_Keycode)sender.tag);
}
@end

// Retain the target for the lifetime of the app so the button actions fire.
static NuvieButtonTarget *g_btn_target = nil;
static bool g_ui_installed = false;

static UIButton *nuvie_make_button(NSString *title, long tag, CGRect frame,
                                   NuvieButtonTarget *target)
{
	UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
	b.frame = frame;
	[b setTitle:title forState:UIControlStateNormal];
	b.titleLabel.font = [UIFont boldSystemFontOfSize:(title.length > 2 ? 15 : 22)];
	b.titleLabel.adjustsFontSizeToFitWidth = YES;
	[b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	b.backgroundColor = [UIColor colorWithWhite:0.20 alpha:0.55];
	[b setBackgroundImage:nil forState:UIControlStateNormal];
	b.layer.cornerRadius = 8.0;
	b.layer.borderWidth = 1.0;
	b.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.35].CGColor;
	b.tag = tag;
	b.showsTouchWhenHighlighted = YES;
	[b addTarget:target action:@selector(onTap:)
	    forControlEvents:UIControlEventTouchDown];
	return b;
}

void nuvie_ios_setup_ui(SDL_Window *window)
{
	if(g_ui_installed || window == NULL)
		return;

	SDL_SysWMinfo info;
	SDL_VERSION(&info.version);
	if(!SDL_GetWindowWMInfo(window, &info))
		return;

	UIWindow *uiwin = info.info.uikit.window;
	UIViewController *vc = uiwin.rootViewController;
	UIView *root = vc.view;
	if(root == nil)
		return;

	g_ui_installed = true;
	g_btn_target = [[NuvieButtonTarget alloc] init];
	NuvieButtonTarget *t = g_btn_target;

	// Work in the root view's coordinate space, respecting the safe area so
	// nothing hides under the notch / home indicator.
	CGRect b = root.bounds;
	UIEdgeInsets safe = root.safeAreaInsets;
	CGFloat left = b.origin.x + safe.left;
	CGFloat right = b.origin.x + b.size.width - safe.right;
	CGFloat bottom = b.origin.y + b.size.height - safe.bottom;

	const CGFloat DS = 40.0;  // d-pad button size (kept compact to fit the bar)
	const CGFloat S = 48.0;   // action button size
	const CGFloat G = 4.0;    // gap

	// ---- Left side: movement D-pad, anchored bottom-left ----
	CGFloat dpx = left + 6.0;
	CGFloat dpy = bottom - (DS * 3 + G * 2) - 10.0;
	// up / left / right / down in a cross
	[root addSubview:nuvie_make_button(@"▲", SDLK_UP,
	         CGRectMake(dpx + DS + G, dpy, DS, DS), t)];
	[root addSubview:nuvie_make_button(@"◀", SDLK_LEFT,
	         CGRectMake(dpx, dpy + DS + G, DS, DS), t)];
	[root addSubview:nuvie_make_button(@"▶", SDLK_RIGHT,
	         CGRectMake(dpx + (DS + G) * 2, dpy + DS + G, DS, DS), t)];
	[root addSubview:nuvie_make_button(@"▼", SDLK_DOWN,
	         CGRectMake(dpx + DS + G, dpy + (DS + G) * 2, DS, DS), t)];

	// ---- Right side: action buttons, stacked bottom-right ----
	NSArray *labels = @[ @"⌨", @"Esc", @"↵", @"Spc", @"Save" ];
	long tags[] = { NUVIE_TAG_KEYBOARD, SDLK_ESCAPE, SDLK_RETURN,
	                SDLK_SPACE, SDLK_s };
	CGFloat bx = right - S - 8.0;
	CGFloat by = bottom - (S * 5 + G * 4) - 10.0;
	for(int i = 0; i < 5; i++) {
		[root addSubview:nuvie_make_button(labels[i], tags[i],
		         CGRectMake(bx, by + (S + G) * i, S, S), t)];
	}
}
