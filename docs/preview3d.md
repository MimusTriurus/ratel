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


## Game over

The end of a run as a scene of its own (`Level3DGameOver`,
`src/game3d/ui/level3d_game_over.gd`): the prisoners each player rescued, their
backs to the camera, saluting the players' graves -- a wooden cross for the
first, a headstone for the second with two players -- and up the slope behind
them a cross in a concrete block for every prisoner the run did not rescue.
Cannon Fodder's Boot Hill turned round. `--game-over 7,4:24` opens it at
once over the stage, and `tools/game_over_shot.gd` shoots it on its own in a
few seconds.

- **The run's end** (`Level3DGameOverScreen`,
  `src/game3d/ui/level3d_game_over_screen.gd`), the 2D game's `ContinueMode`
  in the cemetery. Every player out, the GAME OVER banner stands over the
  stage, which plays on with no one in it, for `GAME_OVER_HOLD` (2.5 s); then
  the stage goes to black with its song and pauses, and the cemetery comes up
  out of the black with `continue_song`. Once the guard has saluted, the
  summary's plate across the top of the frame, over the sky and the hill's
  crest rather than the guard: GAME OVER, each player's line -- his "1P" in
  his HUD colour, his score, the prisoners he brought in -- and PRESS ANY
  KEY, which any key, mouse button or pad button answers, as the summary's
  does. Then in its place CONTINUE and END, picked as the title's entries
  are, with its reticle and tints. CONTINUE is `ContinueMode`'s yes: the
  black lifts off the stage started again from the Chinook, fresh lives, no
  score, every player in -- what the last life lost did at once before, which
  is what R still does. END is its no: the title screen. The cemetery is
  made the first time it is wanted, under the black, not at the preview's
  start. `--lives 0 --die 1` with `--shot` runs into it.

- **Where it comes from.** `resources/3d/jackal_boot_hill.blend`, its `GameOver`
  scene, built by the text block `jackal_boot_hill.py` (`build_game_over()`),
  exports `resources/3d/jackal_game_over.glb` (`export_game_over()`): the
  ground, trees, bushes, rocks, the grass as one mesh, the camera, and under
  `Props` what the scene places itself, as many as the run wants -- the two
  graves, the mound under them, a prisoner's cross. The layout constants
  (`GRAVE_*`, `GUARD_*`, `FIELD_*`) are the script's, in its Blender metres:
  Blender's (x, y, z) is (x, z, -y) here. Everything stands on the ground under
  it, found off the hill's own triangles (`TriangleMesh.intersect_ray`).
- **The guard** is the prisoners' own `jackal_trooper_pow.glb` at 0.54, on
  `Pow_Attention` and then `Pow_Salute` (`docs/soldier-pipeline.md`, section 7),
  saluting from the aisle out. Each player's rescued stand in a block either
  side of the aisle the graves are seen down; one player's are split between
  the two. A block deeper than three ranks takes the camera back 1.8 m a rank.
- **Soft light, not two tones -- a deliberate departure from
  `docs/cel-shading.md`.** Picked over the stage's two tones and over three,
  after a reference picture: a slope's light runs over it smoothly and the
  hills and crowns have their volume. The 3 px contour stays (`Level3DHull`),
  on everything with one baked; not on the ground or the grass. The scene's
  viewport carries `Level3DGameOver.SOFT_LIGHT`, which `_toon` passes by, and
  its materials are copies with Lambert's diffuse -- the prisoners' are shared
  with the stage's, which `_toon` has already stepped.
- **Light**, the Blender scene's: a low warm sun from behind the camera's left
  and a warm ambient, the summer grass faded so that the green uniforms stand
  out. Compatibility lights it about 2.2 times as bright as the energies say
  (`LIGHT_GAIN_COMPATIBILITY`, measured against the Blender render) and reads
  the ground's vertex colours as sRGB, so they are turned to it on load.
