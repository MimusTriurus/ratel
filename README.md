# Jackal — Godot 4 port

A 1:1 port of meatfighter.com's Java/Slick2D remake of Konami's *Jackal*
(NES) to Godot 4 / GDScript. The original source is kept alongside in
`../java_src` for reference.

Licence: LGPL v3, © meatfighter.com. Keep the licence and attribution with any
redistribution. The sprite and music assets are derived from Konami's original
game; that is a separate question from the code licence.

## Running

Open `godot/project.godot` in Godot 4.7 (or any 4.x with `static var`
support) and press Play. Default controls: arrow keys to drive, `X` to throw a
grenade, `Z` to fire. `F12` toggles fullscreen, `Escape` leaves it, `P` or
`Enter` pauses. Controls can be remapped from Options → Input, and are saved to
`user://buttons.cfg`.

## Layout

```
godot/
  assets/          images, maps, music, soundeffects — copied verbatim
  src/core/        engine layer: Main, atlases, data loading, audio, input
  src/game/        GameMode, Player and every game element
  src/modes/       title, map, cutscenes, menus
```

Every GDScript file names the `jackal.*` class it came from in its header
comment.

## How the port works

The original is a fixed-logic-rate game drawn with immediate-mode OpenGL, so it
is reproduced as such rather than being rebuilt out of Godot nodes.

**Timing.** Game logic runs in `Main._physics_process` with
`physics_ticks_per_second = 100`, matching the original's accumulator. Several
counters (the fade ramp, song chaining, the jeep rumble, the invincibility
flash, mine and star animation) advance from `render()` in the original, so the
frame rate is capped at 60 (`application/run/max_fps`) to keep them at the
cadence the original assumed.

**Entities.** `GameElement` / `HitElement` / `Enemy` are plain `RefCounted`
classes held in `GameMode.elements[8]`, exactly as in the Java version — no
nodes, no `Area2D`, no physics server. Collision is the original's hand-written
AABB tests, and update/draw order is preserved down to the reversed loops,
because enemy behaviour depends on it.

Note that GDScript does *not* call a parent `_init` implicitly, so every
element constructor starts with `super()`. That ordering matters: as in Java,
the base constructor runs `init()` and registers the element **before** the
subclass body assigns `x`/`y`.

**Rendering.** One `_draw` pass on `Main` replays `drawBackground()` and
`drawSprites()` in the original order. `Spr` stands in for Slick's `Image`
(including its per-image alpha, which the stage 2 water cross-fade depends on),
`Atlas` parses the `.xml` sprite sheets, and `_push`/`pop_graphics` emulate the
`glPushMatrix`/`glTranslatef`/`glRotatef` stack.

Slick's `Graphics.setWorldClip()` has no equivalent in Godot's immediate-mode
drawing, so a clipped sprite is emitted as a textured polygon: the quad is
transformed into device space, clipped against the rectangle with
Sutherland–Hodgman, and its UVs recovered through the inverse transform. This
is exact for rotated and scaled sprites, which the original needs for the floor
guns, the super tank treads and the rolling columns.

**Data.** The `.dat` files are read as-is with `FileAccess` in big-endian mode;
they are `java.io.DataInputStream` dumps. `maps/dirs-N.dat` is the precomputed
flow field: a 3-bit direction for every (from-cell, to-cell) pair on a 128px
grid, packed 21 to a `long`, which is how the tanks path in O(1).

**Audio.** `Song` chains an intro, an optional second intro and a looping
track through `AudioStreamPlayer.finished`; `Sfx` keeps a small voice pool per
effect and reproduces the original's 125 ms retrigger throttle.

## Known deviations

* The rotor disc in `SunsetMode._draw_helicopter` grows instead of fading in.
  The original passes its fade value into `drawRotated`'s `scale` parameter
  rather than its `alpha` one; that is reproduced rather than corrected.
* `Main.rotate` is `rotate_point` here, because `Node2D.rotate` already exists.
* `GameElement.remove()` is `do_remove()`, because GDScript cannot have a
  method and a property with the same name.

## Exporting

`export_presets.cfg` sets `include_filter="*.dat,*.xml"`. Godot does not import
those extensions as resources, so without that filter an exported build ships
without its maps or sprite indices and fails on the loading screen.
