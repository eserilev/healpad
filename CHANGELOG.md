# Changelog

## Unreleased

- Four looks for the aim menu, picked under Frames > Look; the preview changes as you pick.
  - Classic (the default): the game's own party frames, portrait, health and mana, in a plus
    with you in the middle. The aimed one glows gold and grows a little.
  - Medallions: round gold-rimmed portraits on a circle. The one you aim at grows
    inside a turning gold ring, a gold spoke points to them, and the others dim.
  - Sigil: a slowly turning blue rune circle; each person a gem with their health as a ring
    around it; a beam of light turns to whoever you aim at.
  - Compass: parchment cards with a class-color stripe and the missing health in big numbers; the
    needle of the compass rose in the middle swings to your aim.
- In every look: health is colored green to yellow to red, and pulses red under a quarter. Your
  own heal over time shows as a small icon, a debuff you can remove as a small colored gem (no
  longer the outline). Out of range is faded and grey; dead shows a skull, offline a cable.
- The menu slides open. Nothing flashes when a heal goes off.
- Tap to heal has a new choice, Target: a tap heals your target when it's a friend, else you.
- Sigil: cleaner rune circle, no blurry glows, names clear of the middle.
- The preview's heal-over-time icon no longer shows a question mark.
- Size, Spread and Position work for every look.

## 0.2.3

- Gamepad Mode: the d-pad picks who to heal while you aim, even where the game's own controller
  bindings take the d-pad.
- Aim with a stick turns on the game's stick buttons (GamePadStickAxisButtons); without it the
  sticks sent nothing.

## 0.2.2

- The game's Gamepad Mode: Buttons lists the controller bar (A, LT+A, RT+X, the d-pad...) with
  the spell each button casts on the page in front, and leaves out the action bars' keys, which
  the controller doesn't press there. Hold to Aim works on those buttons, in combat too: Healpad
  sits in the game's own controller bar buttons, so the triggers, pages and stances stay the game's.
- /hp test logs Gamepad Mode and the controller bar's buttons.

## 0.2.1

- Buttons lists heals bound straight to a key or pad button (for example a heal on LB from the
  game's controller settings), and heals in macros. Before, only action bar buttons showed.
- /hp test also logs what every controller button is bound to.

## 0.2.0

- Settings rebuilt: Buttons, Aim and Frames tabs, all usable with the pad.
- Buttons lists what you already bound; switch a heal to Hold to Aim. No more picking spells.
- Aim with the d-pad, the right stick or the left stick; choose the cancel button.
- Classic frames: portrait in a gold ring, level, health with numbers, mana, rage or energy.
- A form or bar page that puts another spell on a heal button gives that button back.
- The opposite direction brings the aim back to you.
- KeyBars: every layer's heals are listed (Normal, Shift, forms); Healpad works inside
  KeyBars' buttons, so KeyBars keeps its keys and a form's other spells cast as always.
- Pad buttons show as the game's icons for your controller.
- /hp test checks Healpad in the game and saves a log and screenshots.

## 0.1.0

- First version: hold-to-aim heals with the diamond, up to 8 heal keys, tap choices, raid groups, settings.
