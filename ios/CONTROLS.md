# Ultima VI on iOS — Touch Controls

The port drives the standard Nuvie/U6 interface with touch:

| Action | Touch gesture |
|---|---|
| **Move / walk** | Tap a tile on the map — the Avatar walks toward it (tap-and-hold to keep walking). |
| **Commands** (attack, look, talk, get, use, cast, drop, rest, …) | Tap the on-screen **command-bar icons**, or type the command letter on the keyboard. |
| **Text & conversations** (keywords, character name, quantities) | **Two-finger tap** anywhere to toggle the iOS on-screen keyboard, then type. Two-finger tap again to hide it. |
| **Menus / dialogs / advance cutscenes** | Single tap. |
| **Return / Escape / Backspace** | Use the keys on the iOS keyboard (Return and Backspace are on it; a single tap also acts as a click/confirm). |

### How it works
- SDL's default touch→mouse synthesis makes single taps act as mouse clicks, so **tap-to-walk** and the **clickable command bar** work with no extra code.
- The **two-finger keyboard toggle** (`Event.cpp`, guarded by `NUVIE_IOS`) calls `SDL_StartTextInput()`/`SDL_StopTextInput()`. SDL's iOS software keyboard emits real key-down events for every typed character, so the full U6 keyboard command set — and conversation typing — works through it.

### Not yet done
- A dedicated on-screen D-pad / button overlay (movement currently relies on tap-to-walk or the arrow keys on the keyboard).
- The full character-creation → world flow hasn't been auto-tested end to end in the Simulator (it needs the on-screen keyboard for the gypsy Q&A and name entry); the intro, rendering, data loading, tap input, and keyboard toggle are all verified.
