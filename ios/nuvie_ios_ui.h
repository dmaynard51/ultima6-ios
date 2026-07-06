/*
 *  nuvie_ios_ui.h
 *  On-screen touch controls for the iOS port (native UIKit button overlay).
 */
#ifndef __nuvie_ios_ui_h__
#define __nuvie_ios_ui_h__

#include "SDL.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Add the on-screen control buttons (D-pad + action keys) on top of the SDL
 * view for the given window. Safe to call more than once; only installs once. */
void nuvie_ios_setup_ui(SDL_Window *window);

/* Show/hide (or toggle) the iOS on-screen keyboard. When showing, the text
 * input rect is positioned near the bottom of the screen so SDL lifts the game
 * view above the keyboard, keeping the game's typed-text echo visible. */
void nuvie_ios_show_keyboard(int show);
void nuvie_ios_toggle_keyboard(void);

#ifdef __cplusplus
}
#endif

#endif /* __nuvie_ios_ui_h__ */
