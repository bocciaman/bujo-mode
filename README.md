# BuJo Mode

A macOS menu-bar utility for system-wide Bullet Journal rapid-logging. When BuJo
mode is **on**, pressing **Return** auto-continues the current line's bullet, and
dedicated hotkeys re-classify the current line's symbol. When it's **off**, the
keyboard behaves completely normally — nothing is intercepted.

## Symbol legend

| Symbol | Meaning          | Set with  |
|:------:|------------------|:---------:|
| `•`    | Action / task    | `Hyper-1` |
| `–`    | Note (en dash)   | `Hyper-2` |
| `=`    | Feelings / moody | `Hyper-3` |
| `○`    | Event            | `Hyper-4` |
| `>`    | Task migrated    | `Hyper-5` |
| `<`    | Task scheduled   | `Hyper-6` |
| `*`    | Priority         | `Hyper-7` |

Toggle BuJo mode with **`Hyper-B`**.

> These are the **defaults**. Every shortcut is now **recordable** — open
> **Shortcuts…** from the menu-bar menu, click a field, and press the keys you
> want (Hyper, Command combos, function keys, anything). The app captures the
> exact combo your keyboard emits, so a Hyperkey works no matter which modifier
> set it sends. Bindings are saved to `UserDefaults` and take effect immediately.
> **Reset to defaults** restores the Hyper set above.

Toggle BuJo mode with **`⌃⌥B`** (Control-Option-B).

## Behavior

- Turning mode **ON** immediately inserts `• ` to start an Action line.
- While ON:
  - **Return** on a bulleted line with text → new line + the same symbol + a space.
  - **Return** on an empty bullet (symbol + space only) → clears the symbol,
    leaving a plain line (breaks out of the list). Stays in mode.
  - **Return** on a plain line (no symbol) → a normal newline.
  - **`⌃1`–`⌃4`** set/replace the current line's leading symbol, keeping the text.
- While OFF: every key passes through untouched.

## Build & run

Requires macOS 13+ and the Swift toolchain (Xcode or Command Line Tools).

```bash
# Assemble a proper .app bundle (recommended — permission sticks to it):
./build_app.sh
open "build/BuJo Mode.app"
```

For a quick dev loop you can also run it straight from SwiftPM, though it won't
have the bundle's `LSUIElement`/stable identity:

```bash
swift run
```

Quit from the menu-bar menu (or `⌃⌥B` to just toggle off).

## Grant Accessibility permission

BuJo Mode needs Accessibility access to read the focused text field and to
intercept Return.

1. Launch the app. The first time you turn mode on (`⌃⌥B` or the menu), macOS
   prompts for Accessibility access — or the menu shows a **Request Accessibility
   Access…** button.
2. In **System Settings → Privacy & Security → Accessibility**, enable **BuJo Mode**.
   (The menu's **Open Accessibility Settings…** button jumps straight there.)
3. Toggle mode off and on once after granting, so the event tap starts with the
   new permission.

The toggle hotkey itself works *without* Accessibility (it's a Carbon global
hotkey), so you can always toggle on to trigger the permission prompt.

## How it works

- **Menu bar**: SwiftUI `MenuBarExtra`; the icon is filled when mode is on.
- **Shortcuts**: a single always-on `CGEventTap` (`.cgSessionEventTap`,
  `.defaultTap`) matches every keystroke against the recorded bindings
  (`Bindings.swift` / `BindingStore`). The toggle is matched whether mode is on
  or off; the swap keys and Return only while mode is on. It swallows *only* the
  bound combos — every other key passes through untouched, so the keyboard is
  normal when mode is off. The tap starts once Accessibility is granted (the app
  polls trust and brings it up automatically).
- **Recorder**: the Shortcuts window uses an `NSButton` (`RecorderButton`) that
  captures the next key + modifiers via `keyDown`/`performKeyEquivalent`. Modifier
  bits share the same layout in `NSEvent` and `CGEventFlags`, so a recorded combo
  matches a tapped event directly.
- **Editing**: the Accessibility API (`AXUIElement`) reads the focused element's
  value + selection range, a pure engine (`BuJoEngine`) computes the new text and
  caret, and the change is written back via `kAXSelectedText`. If a field refuses
  AX writes, it falls back to synthetic keystrokes.

## Where to change things

- **Symbols** — the `Symbols` struct in
  [`Config.swift`](Sources/BuJoMode/Config.swift). The Note character (`–`,
  U+2013) is called out as the easiest to swap.
- **Hotkeys** — recorded at runtime via the **Shortcuts…** window; defaults live
  in `Bindings.defaults` ([`Bindings.swift`](Sources/BuJoMode/Bindings.swift)).
  What counts as "Return" is `returnKeyCodes` in `Config.swift`.

## File layout

```
Package.swift
Resources/Info.plist            LSUIElement (agent) bundle metadata
build_app.sh                    swift build → .app bundle + ad-hoc codesign
Sources/BuJoMode/
  BuJoModeApp.swift             @main App + AppDelegate + Settings scene
  MenuContent.swift             Menu-bar menu UI (live bindings + status)
  SettingsView.swift            Shortcuts preferences window
  KeyRecorder.swift             NSButton that records a key + modifiers
  Bindings.swift                Hotkey model + persisted BindingStore
  AppState.swift                Observable UI state (mode, trust, tap active)
  AppController.swift           Wiring + tap matching + continue/swap logic
  Config.swift                  Symbols + Return key codes
  BuJoEngine.swift              Pure text transforms (no AppKit/AX)
  AX.swift                      Accessibility read/write of the focused field
  EventTap.swift                CGEventTap lifecycle + callback
  Synth.swift                   Synthetic-keystroke fallback
```

## macOS gotchas

- **Taps get disabled by the system.** If a tap callback is too slow, or during
  some secure-input moments, macOS sends `tapDisabledByTimeout` /
  `tapDisabledByUserInput` and stops the tap. `EventTap.swift` handles both by
  re-enabling. Keep the callback fast (the AX work here is lightweight).
- **Secure input fields.** Password fields (and apps that turn on Secure Event
  Input) block interception and AX reads entirely — expected and by design.
- **Web / Electron apps.** Chrome, VS Code, Slack, etc. often expose text through
  AX poorly or not at all. When `AX.focusedText()` returns nothing, Return just
  does its normal thing and swap keys no-op. Native AppKit text fields (Notes,
  TextEdit, Mail, most native apps) work well.
- **Deleting the app drops its permission.** macOS ties Accessibility to the app,
  and *removing* the bundle deletes the grant — so a "delete then copy" reinstall
  forces re-authorization every time. `build_app.sh … install` overwrites the
  installed bundle **in place** (via `ditto`) precisely to avoid that; combined
  with the stable Apple Development signing identity, the grant survives rebuilds.
  If it ever does get lost, reset and re-grant once:
  `tccutil reset Accessibility com.bujomode.app`, relaunch, toggle on.
- **`swift run` vs the bundle.** Run the `.app` for real use — it has
  `LSUIElement` (no Dock icon) and a bundle identity TCC can remember. `swift run`
  is fine for iterating on logic.
- **Don't use ⌥+number for swaps.** Option+number types typographic glyphs
  (`™ £ ¢ …`) on macOS — that's why the swap keys are `⌃`+number.

## Out of scope (for now)

- Nested / indented sub-bullets.
- Full BuJo state transitions (done `X`, migrate `>`, schedule `<`, priority `*`).
