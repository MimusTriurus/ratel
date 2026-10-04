# The 3D preview

Moved out of `CLAUDE.md`. `src/game3d/level3d_preview.tscn` is the project's main
scene. Every command-line option is in `preview3d-options.md`; its sound is in
`audio3d.md`.

## Title screen, settings and light

The 3D preview opens on a title screen, `Level3DTitle`
(`src/game3d/ui/level3d_title.gd`): the 2D game's title art and jeep cursor,
laid out as `IntroMode` lays them out, with 1 player, 2 players, the
difficulty, the settings and quit, in the HUD's font, over the stage with
the tree paused. Over the sun is the game's name, RATEL SQUAD
(`Level3DLogo`), in the settings' font: Black Ops One in the sun's colours, or Press Start 2P in bands. A game picked there starts the run from the Chinook with the
start jingle; the Escape menu's "Main menu" goes back to it. Hard is the
stage's hard trigger list, as `GameMode.set_stage` picks it
(`Level3DMap.hard`, `Level3DMap.triggers()`, saved as `Level3DSettings.hard`):
more soldiers, tanks and boats. A --shot and the level editor's Play skip it.
`docs/preview3d-options.md` lists every command-line option of the preview;
`--no-chinook` skips the Chinook's run and `--boss` starts each run a few
seconds' drive below the boss, the way there left unspawned.

The 3D preview's Escape menu opens its settings on a Game tab: 8-bit or
modern, each a preset of the sound mode, the driving, the firing, the reach,
the font, the look and the CRT (`Level3DSettings.PRESETS`). The mode is not
saved but read back off those settings, so changing one on its own tab shows
it as "Custom". The menu is in English, drawn in the HUD's font from the
.ttf files its sheets were baked from: Press Start 2P (scaled by 2/3 to fit
the panels) for both classic styles, Black Ops One for modern.

The stage's light is a preset, `Level3DLighting` (`src/game3d/look/level3d_lighting.gd`):
day, Blender's light and the default, or golden hour, dusk and sunrise, the
title splash's palette as far as a stage can be read in it (Graphics -> Light,
or `--light day|golden|dusk|sunrise`, which a --shot takes too). The time of
day does not change in a stage: the title's sun rises instead, once a game is
picked (`Level3DSplash3D`, `RISE_*`: the disc out of the horizon and yellower, its glow golden, the sky going from the dawn's red to a morning's gold, rose and pale blue (`MORNING_*`),
and the ground lit, to a burnt orange towards the stage's sand -- the ground by a glow of its own, since a sun light
raised with the disc turned the rolling ground's facets lit one by one, and
the sun taken off the ground as it rises), and the title fades on it into the
day. Over the Chinook the camera follows the jeeps in as they go
(`Level3DSplashLanding`, `CHASE_*`), so that the frame is not half empty ground,
over a few more low rocks and two palms (`SCATTER`, `SCATTER_PALMS`) -- not in
`ROCKS`, which the jeeps' way goes round. Its dust is one cloud a source --
each jeep, the Chinook's wash, each gust -- in the models' look
(`Level3DCelCloud`, `src/game3d/fx/level3d_cel_cloud.gd`, a port of the tank
bench's `CelCloud` in `BlenderMCP/godot`): puffs as spheres flowed into one
shape by a smooth union, one ink line round it, eaten from the rim, in the
camera's tangent plane since our camera is a perspective one; a cloud is one
only where its puffs overlap, so a jeep raises one every `CEL_WHEEL_STEP`;
the Chinook's wash raises its puffs at the edge of its hull, small, growing
as they roll out (`_hull_edge`, `WASH_*`), and the hull thins any that come
back into it (`_thin`, off
`Level3DChinook.HULL_BOXES`, as the bench's `CelSolids` thins its by the
tanks'), and the clouds are drawn at the frame's end, after the chase has
moved the camera.
`--splash-veil` stands it in a thin haze the wash raises (`VEIL_*`, soft
cards faded into the ground off the depth texture), off by default. `--splash-puffs` draws each puff as a card of
its own (`DUST_SHADER`), `--splash-motes` as soft motes (`MOTE_*`).
On the stage, under `--landing-dust` (off by default), the Chinook's rotors
raise the same kind of cloud round its hull as it comes down, stands and
climbs away (`Level3DWash`,
`src/game3d/fx/level3d_wash.gd`): one body rolling out from the hull, as a
helicopter's dust is, its puffs growing with the way they have gone
(`GROW`) so that the ring does not break up as it widens; lit by the
stage's two-tone light rather than painted in tones, so that it follows
the light preset, in the colour of the ground under it, its depth kept
out of the ground (`set_ground`), and orthographic in the top view.
So that the risen disc is not cut off, the splash is rendered the whole screen
big (`SCREEN`, the camera as wide as the focused frame's `FOCUS_ZOOM` needs):
the title shows the middle of it, exactly the old frame (`_region`), and the
frame opens out to the screen's edges as it comes to the middle (`focus`). Readability is the constraint, so a preset moves hue
and not brightness: a light's energy is held to the day's on a grey, the sun
stays top left and no lower than 30 degrees, the shade gets lighter as the sun
gets lower (and the sun weaker by what that adds to a lit face in
Compatibility, `AMBIENT_ON_LIT_COMPATIBILITY`, measured), and a fill from the
other side lights what stands up. The sand's orange is at the edge of the
gamut, so no light moves it: a grade over the stage and under the HUD
(`level3d_screen.gdshader`, mode 3) turns hue in OKLab -- cool shade, warm
light -- with its lightness, its black contour and its saturated colours'
chroma left as they were.

## Two players

The 3D preview has the same co-op, from the title's "2 players" (a new game
is picked only there, not in the Escape menu) or `--players 2`; it always starts with one. Everything one player's
is a `Crew` in `level3d_preview.gd` -- vehicle, gun, launcher, HUD line, and a
`Level3DFriends.Carrier` for the prisoners and the weapon; `btr`, `gun` and
`launcher` are still the first's, which the mouse, the --shot options and the
ground's craters (`Level3DLauncher.marks`) go by. The second is blue
(`Level3DBtr.tint`), reads `Main`'s second mapping from `user://buttons2.cfg`
through a `HumanInput` of its own, fires the classic way, and takes the arrows
from the camera. The modules get the nearest jeep from
`player_position.call(from)`, points go to `Level3DGuns.acting` (explosions
keep theirs as `by`), the frame follows the middle of the two and
`Level3DBtr.z_limits` keeps them in it, the Chinook carries both
(`Level3DChinook.Cargo`) and backs them out to either side of its ramp, and the rescue helicopter takes both at once. `--hold`
drives the second with `2:` spans, which is how it was checked:

```bash
godot --path . --windowed --resolution 1280x720 src/game3d/level3d_preview.tscn -- --shot out.png 0 1 top 8 --players 2 --immortal --hold w@0-8,2:l@0-8
```

