# Changelog

## Unreleased

A new settings window, smaller and simpler:

- Two tabs, Heals and Menu. LB and RB switch them.
- While the window is open, the menu itself shows beside it, where it will be, as big and in the look
  you picked. The window moves to the side of the screen the menu leaves free.
- Heals: every heal on your buttons in one list, each with a checkbox, its icon with the key in the
  corner, and its name and rank. Tick a heal to hold it for the menu; untick it and the button casts
  as it always did.
- Beside each ticked heal, who a quick tap heals: You, Target, Focus, Tank or Last healed. Left and
  Right change it.
- The menu shows the heal you're on with that person in gold, and fades out on a heal that isn't
  ticked.
- Menu: Style, Size, Spacing, Select person with and Cancel heal with, each changed with Left and
  Right; then Move and Reset for its position. Reset is greyed out when the menu is already in the
  middle.
- Spread is now Spacing, from 60% to 140%. Your old Spread carries over.
- Up and Down pick a row, A ticks or steps on, B closes. The gold edge shows only while you use the
  pad or the keys; the mouse lights the row it's on.
- Long names get a smaller font instead of being cut off.
- The gold box around the menu while you move it no longer pulses.

## 0.3.0

Four looks for the menu:

- Pick one under Frames > Look; the preview changes as you pick. All four take about the same
  room on screen at the same Size.
  - Classic (the default): the game's own party frames, with portrait, health and mana, in a
    plus with you in the middle. The aimed one glows gold and grows a little.
  - Medallions: round gold-rimmed portraits on a circle. The aimed one grows inside a gold ring,
    a gold spoke points to them, and the others dim.
  - Sigil: a blue rune circle with each person as a gem, their health a ring around it. A beam of
    light turns to whoever you aim at.
  - Compass: parchment cards with a class-color stripe and the missing health in big numbers. The
    needle of the compass rose in the middle swings to your aim.
- Every look shows the same things:
  - Health goes green, yellow, red.
  - Your heal over time is a small icon, and a debuff you can remove is a small colored gem.
  - Out of range is faded and grey. Dead shows a skull, and offline shows a cable.
- Nothing flashes or spins.

New settings window:

- Buttons: your heals in a list, with On beside the enabled ones. The heal you're on is shown
  beside the list with one Enable button and Tap to heal. When it's off, the button casts as it
  always did.
- Controls (was Aim): Select with D-pad, Left stick or Right stick; Cancel with A, B, X or Y.
- Frames: Size and Spread are sliders, with - and + beside them, then Look, Move and Reset.
- One way to move around: the d-pad goes to what's next to it on screen, A picks, B goes back a
  step (then closes), and LB and RB switch tabs.
- Chosen options are edged in gold, and red buttons are only for Move and Reset.
- The preview shows an example party with names, and you in the middle.

Tap to heal:

- New choice, Target: heals your target when it's a friend, else you.
- Focus heals your target when you have no friendly focus.

Screenshots:

- /hp shots takes screenshots while you play: one as the menu opens and one for each person you
  pick.
- /hp shots page stages the example party in every look, plus each settings tab.

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
