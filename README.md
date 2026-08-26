# Jackal — Godot 4 port

A 1:1 port of meatfighter.com's Java/Slick2D remake of Konami's *Jackal*
(NES) to Godot 4 / GDScript. The original source is kept alongside in
`../java_src` for reference.

Licence: LGPL v3, © meatfighter.com. Keep the licence and attribution with any
redistribution. The sprite and music assets are derived from Konami's original
game; that is a separate question from the code licence.

## Running

Open `project.godot` in Godot 4.7 (or any 4.x with `static var` support) and
press Play.

Default controls: `WASD` to drive, the mouse to aim, left mouse button to fire
the machine gun, right mouse button to throw a grenade or missile. The arrow
keys always work as a second set of direction keys, and `X` / `Z` still throw
and fire from the keyboard. `F12` toggles fullscreen, `Escape` leaves it, `P` or
`Enter` pauses. Keys and pad buttons can be remapped from Options → Input, and
are saved to `user://buttons.cfg`; mouse aiming can be turned off there by
setting `[mouse] aim=false` in the same file, which restores the original
scheme.

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

## Controls, and where they deviate

The original is a NES game: eight-direction movement, grenades thrown in
whatever direction the jeep faces, and a machine gun that only ever fires
north. Mouse aiming replaces the last two, so `Player` now resolves a
continuous weapon angle once per tick from the cursor's world position
(`HumanInput.aim_position()` plus the camera offset) and passes it to
`Grenade`, `PlayerMissile` and `PlayerBullet`.

Three things this had to respect:

* `create_unit_vector(int)` is an exact table over multiples of 45, and it
  returns a *stale* vector for anything else. `create_unit_vector_deg(float)`
  dispatches back to that table whenever the angle is a multiple of 45, so
  keyboard and pad aiming stay bit-identical to the Java version, and only
  mouse angles go through `cos`/`sin`.
* Mouse buttons are kept out of `is_fire()` / `is_shoot()`, which also feed the
  menus, the title screen and the Konami code — a click must not navigate a
  menu. `Player` reads `is_grenade()` / `is_gun()` instead.
* `W` is in the original's fallback gun-key set (`Z / Y / W / K`) and is now
  also the default "up", so a fallback key claimed by a direction is skipped.

The jeep body still turns to face its movement direction, not the cursor. That
is not a shortcut: the original's machine gun never pointed where the sprite
did either, so decoupling aim from the body costs no fidelity and needs no new
art.

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
