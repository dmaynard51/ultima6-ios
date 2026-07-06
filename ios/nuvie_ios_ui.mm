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

// Shared state (declared up-front so the button target class can use it).
static bool g_ui_installed = false;
static SDL_Window *g_window = NULL;
static UIView *g_root_view = nil;   // the SDL view (fills the window)
static CGRect g_full_frame;         // its normal, full-screen frame

@interface NuvieButtonTarget : NSObject
- (void)onTap:(UIButton *)sender;
- (void)keyboardWillShow:(NSNotification *)note;
- (void)keyboardWillHide:(NSNotification *)note;
@end

@implementation NuvieButtonTarget
- (void)onTap:(UIButton *)sender
{
	if(sender.tag == NUVIE_TAG_KEYBOARD) {
		nuvie_ios_toggle_keyboard();
		return;
	}
	nuvie_push_key((SDL_Keycode)sender.tag);
}

// When the keyboard appears, scale the whole game down into the space above it
// so nothing is cropped; restore full size when it hides.
//
// SDL rewrites its view's .frame in its own keyboard-notification handler.
// Assigning a .frame while a transform is active corrupts the view's bounds,
// so we (a) defer our change with dispatch_async so it runs *after* SDL's
// handler, and (b) always reset transform + bounds to a known-good state first,
// undoing any corruption, before applying the new scale.
- (void)applyKeyboardScale:(CGFloat)scale
{
	if(g_root_view == nil)
		return;
	// Restore to the exact full-screen frame with no transform first (this
	// undoes any position/size corruption from SDL assigning .frame while a
	// transform was active), then apply the new scale around the centre.
	g_root_view.transform = CGAffineTransformIdentity;
	g_root_view.frame = g_full_frame;
	if(scale < 1.0) {
		CGFloat H = g_full_frame.size.height;
		g_root_view.transform = CGAffineTransformConcat(
		    CGAffineTransformMakeScale(scale, scale),
		    CGAffineTransformMakeTranslation(0, -H * (1.0 - scale) / 2.0));
	}
}

- (void)keyboardWillShow:(NSNotification *)note
{
	if(g_root_view == nil)
		return;
	CGRect kb = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
	CGRect kbLocal = [g_root_view convertRect:kb fromView:nil];
	CGFloat H = g_full_frame.size.height;
	CGFloat visibleH = kbLocal.origin.y;   // keyboard top, in view coords
	if(H < 1.0 || visibleH < 120.0)
		return;
	CGFloat s = visibleH / H;
	dispatch_async(dispatch_get_main_queue(), ^{ [self applyKeyboardScale:s]; });
}

- (void)keyboardWillHide:(NSNotification *)note
{
	dispatch_async(dispatch_get_main_queue(), ^{ [self applyKeyboardScale:1.0]; });
}
@end

// Retain the target for the lifetime of the app so the button actions fire.
static NuvieButtonTarget *g_btn_target = nil;

void nuvie_ios_show_keyboard(int show)
{
	if(show) {
		if(!SDL_IsTextInputActive())
			SDL_StartTextInput();
	} else {
		if(SDL_IsTextInputActive())
			SDL_StopTextInput();
	}
}

void nuvie_ios_toggle_keyboard(void)
{
	nuvie_ios_show_keyboard(SDL_IsTextInputActive() ? 0 : 1);
}

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
	g_window = window;
	g_root_view = root;
	g_full_frame = root.frame;
	g_btn_target = [[NuvieButtonTarget alloc] init];
	NuvieButtonTarget *t = g_btn_target;

	// Resize the game to fit above the keyboard when it shows / hides.
	[[NSNotificationCenter defaultCenter] addObserver:t
	    selector:@selector(keyboardWillShow:)
	    name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:t
	    selector:@selector(keyboardWillHide:)
	    name:UIKeyboardWillHideNotification object:nil];

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
