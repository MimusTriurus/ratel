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

The 3D preview's Escape menu opens its settings on a Game tab whose Style is
8-bit or modern, each a preset of the sound mode, the driving, the firing,
the reach, the font, the look and the CRT (`Level3DSettings.PRESETS`; how
round the CRT's glass is, Graphics -> Screen curvature, is not in them). It is
the one place the style is picked: every screen reads the settings it sets,
the shop's bay under the pixels and the CRT as the stage is. The style is not
saved but read back off those settings, so changing one on its own tab shows
it as "Custom". A new config starts as modern; one saved before the font was
takes the font of its look. `--style 8bit|modern` picks one at launch, as
the menu would, and saves it (not under a --shot). The menu is in English, drawn in the HUD's font from the
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
(`Level3DBtr.tint`), and on the armoured pickup drives another make of it,
`jackal_armored_b.glb` (`Level3DBtr.player`, `for_player`, VEHICLES'
`second`) -- on the level, in the shop, the splash, the mission's end and
the HUD's lives icon alike; it reads `Main`'s second mapping from `user://buttons2.cfg`
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


## Rounds and the run

The stage does not end with its boss: once the mission's summary is closed
(`Level3DSummary.closed`), or `ROUND_HOLD` (4 s) after the boss with the summary
off, the same stage starts again from the Chinook as its next round, STAGE 1-2,
1-3 and so on (`_round_won`, `_start_round`). From the second round on it plays
the level file's hard list of enemies (`Level3DMap.hard`), as the first already
does at the title's hard. `--round <n>` starts every run on that round. The
plan behind it is `docs/shop-plan.md`; its steps and their state are in
`docs/shop-implementation.md`.

**The shop** (`Level3DShop`, `src/game3d/shop/level3d_shop.gd`) stands between
the rounds: the summary closed, the stage goes to black and pauses, and the
shop comes up out of it. The players' jeeps stand on turntables at the frame's
edges with what they have bought on them; between them the goods, a matrix out
of `Level3DShopCatalog` (`level3d_shop_catalog.gd`) -- weapons, protection,
devices, three of each, and a life across the bottom. Both players shop at
once, each with a frame of his own colour for a cursor, the first's outside
the second's on one tile. A tile says on each player's side what it is to him:
its price, red when he is short of it, OWNED, IN SLOT, MAX.

- Fire buys (the gun, Enter or Space, a left click, a pad's A); fire on a
  device already owned puts it in the slot. The rocket (P, a right click,
  right Ctrl, a pad's B) takes back the last of that tile bought in this
  visit. Fire on READY under the matrix is a player's word that he is done;
  the next round starts, from the Chinook, when every player has given it.
- The jeep turns on its table to show the part its player's tile is about,
  the part on trial standing on it see-through and pulsing.
- Escape opens the Escape menu over it, as on the stage; closing it leaves
  the stage paused under the shop (`Level3DMenu` puts the pause back as it
  found it), and its "Main menu" gives the run up there too.
- The bay is on the cemetery's layer (`scene_layer`, `CEMETERY_LAYER`), under
  the pixels and the CRT, its words over the pixels as the HUD's are; the
  HUD is hidden while it stands.
- Everything is on sale at once; price is the balance. Lives cost 15000, each
  one 5000 more, up to 9; the launcher's steps 10000, 15000, 20000.
- `--shop` opens it at once over the stage, as if a round were won;
  `src/game3d/shop/level3d_shop.tscn` runs it on its own (F6) with made-up
  players, to lay it out.

**The upgrades on the jeep.** `jackal_jeep.py`'s `upgrades()` builds a part for
each that shows -- the twin gun, the armour, the spares' box, the nitro, the
radar, the mines, the rifles' rests -- in a collection of its own, exported
with the jeep and hidden; `Level3DBtr.set_upgrades` shows the bought ones, in
the shop and on the stage. `--upgrades twin,radar,...` starts every player
with them.

**What they do in a round.** The spares (`zip`): a death takes the launcher
down one step rather than to the grenade. The armour: every prisoner aboard
jumps out alive -- the game's death loses one and lets four out at most
(`Level3DFriends.player_died`). The twin gun: twice the gun's rate, each
round from the next barrel (`Level3DBtr.cycle_muzzle`), the in-flight cap
growing with it as the rate cheat's does. The loopholes: every prisoner
aboard fires at the nearest enemy within a soldier's reach, at a soldier's
pace -- a round every 1.5 s over the prisoners aboard -- that hits as the
gun's does, a soldier dead, the rest chipped, the points the player's. The
radar (`Level3DRadar`): a small arrow at the frame's edge for each gun and
tank off it within 26 m, in the buyer's colour.

**The device** in the slot goes off on its key -- the settings' Device, K to
start with, rebound in the menu's keys; right Shift for the second player,
whose other keys are the 2D game's mapping, which has no such button -- and
the HUD's line names it after the prisoners, dimmed while it cannot go off.
Nitro dashes the jeep ahead for 0.6 s at twice its speed, the way it faces
with no key held (`Level3DBtr.dash`; classic, the game's move twice a tick,
each through its sensors), then reloads for 5 s. Mines: one down behind the
jeep every 3 s, three of a player's at most, the oldest taken up; one goes
off under an enemy tank or a boss tank, the player's blast round it. The
airstrike blows up every enemy in the frame but the boss's tanks for 2000,
4000 the next call in the round, 8000 the next, the dead worth nothing,
prisoners and buildings left alone, and is dimmed while the boss holds the
camera or the score cannot pay for it.

What a round leaves a player for the next is the run's (`Level3DRun`): his
score, his lives, his launcher's step and what the shop sold him. What lives in
a round -- the prisoners aboard, the stage's enemies -- starts again. The
preview keeps the run as it was at the round's start (`_saved`), which is what
the game over's CONTINUE goes back to.

**Lives are bought, not earned.** The score is the shop's money, so points no
longer give a life at 20000 and every 50000 as the game's `PlayerState` does
(`_add_points`): a deliberate departure. A run starts with the game's four.

## The mission's end

Made, not yet in the game: the boss beaten, the mission is to end on a scene
of its own (`Level3DVictory`, `src/game3d/ui/level3d_victory.gd`) rather
than on the summary's plate over the stage, which the preview still shows.
The arena at the top of stage 1 seen from behind and over the players'
jeeps, turned in towards its middle so that a flank shows, and up the
clearing the four boss tanks burnt black where they stopped, smoking and
burning, the jungle round it all. The picture the user chose out of Blender
renders: the evening's light, the camera high over the shoulder, the jeeps
turned in (`docs/renders/victory_1p.png`, `victory_2p.png`; in Godot,
`victory_godot_1p.png`, `victory_godot_2p.png`). Nothing in the preview
opens it yet; `tools/victory_shot.gd` shoots it on its own
(`docs/preview3d-options.md`).

- **The scene** is built from `resources/3d/jackal_victory.glb`, which
  `resources/3d/jackal_victory.blend` exports (`export_victory()` in its text
  block `jackal_victory.py`; `build_victory()` makes the Blender scene, with
  the game's glbs imported in it, to render). In the glb: the ground, the
  tanks' tracks, the soot and the craters in its vertices' colours; the four
  wrecks, each the boss's tank posed in Blender -- Breach's end, Breached,
  Death's end, then its turret thrown further than Death throws it, onto
  the deck, off onto the sand, or left on its ring with the gun down -- and
  baked, burnt (`CHAR` 0.32 of the sRGB colour); the rocks, the
  debris, a camera for one player and one for two. And markers for what the
  preview makes: each player's jeep (`Car_Solo`, `Car_1P`, `Car_2P`), the
  smoke's and the fires' (`Smoke_<k>`, its scale the column's height;
  `Fire_<k>`), and the jungle's oaks (`Oak_<n>`, the scale its height).
- **The jeeps** are the preview's own vehicle (`Level3DBtr`), as the shop's
  are: each in his paint, with what the shop has sold him and his launcher's
  step -- the jeep he finished the stage in -- idling, its exhaust puffing.
  The camera eases in 0.7 m over 9 s and comes to rest on the frame chosen.
- **The wrecks' fire and smoke** (`Level3DBurn`, `src/game3d/fx/
  level3d_burn.gd`) are BlenderMCP's `CelBurn` and `CelCloud`
  (`BlenderMCP/godot/scripts/`), carried over to the preview's metres,
  perspective and two-tone light. The flames are one quad over the open
  turret ring, facing the camera and upright, and on it one field of
  teardrop tongues -- a body that breathes and three that come and go every
  0.9 s -- their smooth union cut into bands once, yellow core to dark red
  rim (`level3d_flame.gdshader`); each pixel at its port's depth, so the
  deck hides the fire's foot. The smoke is one cloud (`Level3DCloud`,
  `level3d_cloud.gdshader`): 34 puffs off the top of the fire as discs on
  one quad, flowed into one shape with one black line round it and lit as
  one column, swelling and blown right and away as they climb, eaten from
  the rim -- not `Level3DPuffs`' balls, each with a line of its own, which
  stood in a column as a heap of them. Closed form: a puff is arithmetic on
  its index and the clock, so the column is up from the first frame and a
  shot repeats. A flickering light over each fire. Not carried over yet: the
  fire coming up and dying down, the scorch round it, the turret's stencil.
  The jeeps' exhaust is still `Level3DPuffs`'.
- **The oaks** are the cemetery's (`Level3DOaks`, `src/game3d/world/
  level3d_oaks.gd`, moved there out of `Level3DGameOver` for both): soft,
  in the wind, outlined through the mask -- but 1.5 px (`OAK_INK_PIXELS`)
  rather than the cemetery's 3: a crown here is a few dozen pixels across,
  and at 3 every gap in it was inked. The jungle is oaks alone; the palms
  the stage has along its edges were taken out. Unlike everything round them,
  which is lit as the stage is, in two tones (the stage's Golden hour, the
  sun low from the right): their crowns read better soft. There are 463 of
  them; the levels of detail the oaks' import made are kept when their
  meshes are rebuilt, taken 4 px sooner than the default (`LOD_THRESHOLD`),
  and only those within 22 m cast a shadow -- 22 million triangles a frame
  where it was 40.
- **The screen** (`Level3DVictoryScreen`,
  `src/game3d/ui/level3d_victory_screen.gd`), as it is meant to go in: the
  fourth tank gone, the stage stands over its blast for a hold (2.5 s), then
  goes to black and pauses, and the scene comes up out of it, the HUD
  hidden. From 1.6 s the summary (`Level3DSummary`, with `plate` off and
  `top` set): MISSION
  ACCOMPLISHED! typed, a prisoner for every one the level held in the colour
  of who brought him in, the count and the time, PRESS ANY KEY -- at the top
  of the frame, over the sky and the jungle, with no plate. A key, a button
  or a pad's brings it all at once, and the next closes it: the scene and
  the music to black, and the shop out of it (its `done`, the preview's
  `_round_won`). The music is the boss's own end, which plays on. Its scene is on the cemetery's layer
  (`CEMETERY_LAYER`), as 8-bit's pixels want; the two are never up together.
  The mission's banner off (Options), there is to be no mission's end, as
  there is no summary. The wiring into the preview was written and taken
  out again until it is wanted.

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
  out of the black with its song. Over it nothing but KILLED IN ACTION at
  the top, over the sky, fading in once the guard has saluted (2.4 s), and a
  little after (4.4 s), by itself, CONTINUE and END small at the foot of the
  frame, picked as the title's entries are, with its reticle and tints; a
  key, mouse button or pad button before that brings them at once. KIA, not
  MIA: the players are in those graves. The summary's plate it had at first
  -- GAME OVER, each player's score and rescued, PRESS ANY KEY -- covered
  half the frame and broke the burial; the guard says who brought in how
  many. At either pick the words go (`WORDS_OUT`, 0.5 s) and the scene
  plays on without them. CONTINUE is `ContinueMode`'s yes, played as help coming
  (`Level3DGameOver.reinforce`, `HELP_*`): the guard's hands down, a
  Chinook heard coming in from behind the camera and over -- above the
  frame, the wind in the grass and the oaks up to four times as it passes --
  then seen going away nose first across the hill's slope, 20 degrees to the
  right of straight ahead, a dark shape against the light (no haze on it),
  smaller, and sinking behind the ground's crest on its line; the colour
  coming back into the print as it goes. The sky over the hill in the frame
  is a narrow band, which a Chinook fills only well off: nearer, it is out of
  the top of the frame; further right, behind the oak. It is at the stage's
  size for it beside the soldiers (`HELP_SIZE`, the BTR's 0.31 against the
  soldiers' 0.55), some nine soldiers long, not a real Chinook's sixteen. 9 s, long on purpose, a key
  cutting it short; then the
  black lifts off the round started again from the Chinook, every player in,
  with the run as it was when the round started (`_saved`) -- on the first
  round fresh lives and no score, as the game's; R starts the run from
  nothing. END is its no: the title screen, slowly -- the guard's hands
  down, and the guard leaving file by file (`disperse`), till one man stands
  alone at the first grave and goes last; the cemetery to black over 2 s as
  he walks, eased, with its song and rain, a key cutting it to 0.6 s,
  a beat of black, and the title out of it over 1.6 s, its song coming up
  with it (`Level3DTitle.open_from_black`, `Level3DAudio.fade_in_music`). The cemetery is
  made the first time it is wanted, under the black, not at the preview's
  start. `--lives 0 --die 1` with `--shot` runs into it.

- **Where it comes from.** `resources/3d/jackal_boot_hill.blend`, its `GameOver`
  scene, built by the text block `jackal_boot_hill.py` (`build_game_over()`),
  exports `resources/3d/jackal_game_over.glb` (`export_game_over()`): the
  ground, trees and bushes (in Godot an oak each and nothing), rocks, the grass
  as one mesh, the camera, and under
  `Props` what the scene places itself, as many as the run wants -- the two
  graves, the mound under them, a prisoner's cross. The layout constants
  (`GRAVE_*`, `GUARD_*`, `FIELD_*`) are the script's, in its Blender metres:
  Blender's (x, y, z) is (x, z, -y) here. Everything stands on the ground under
  it, found off the hill's own triangles (`TriangleMesh.intersect_ray`).
- **The guard** is a soldier for every prisoner rescued: Kolos Studios' low
  poly soldier (`low_poly_soldier.glb`, CC BY 4.0, attribution in
  `resources/3d/low_poly_soldier.txt`) at 0.54, his rifle hidden
  (`GUARD_UNARMED`), at attention (`Attention`) and then saluting with the hand
  (`Salute`) from the aisle out; at CONTINUE or END it lowers its hands in
  the same order, `Salute` played back (`lower_salute`). **Two more on post**
  either side of the graves, facing in across them, with their rifles: order
  arms (`Order`), presenting arms (`Present`) with the guard's first salute
  and holding it from then on, the guard's hands down or not; at END they
  stay. In the gap between
  the guard's blocks there is room for two: four hid each other and stood
  behind the guard's inner files. One model for all of them -- the
  prisoners' own stood in the guard at first, and beside the armed soldiers
  looked out of place. The clips and the glb are made by the scripts in
  `resources/3d/low_poly_soldier.blend` (`soldier_guard.py`,
  `soldier_walk.py`, `soldier_rifle.py`, `soldier_export.py`). At END the
  guard then leaves (`disperse`): each man turns outward, the left block to
  the left and the right to the right, and walks out of the frame on
  `Walk_Unarmed`, his arms swinging, his feet on the ground -- the
  outermost file first, the rearmost rank first, as from a pew; the front
  rank's man at the first player's grave (the second's, if the first brought
  none home) stays 2 s after the last of the others has turned, and goes last. Each player's rescued stand in a block either
  side of the aisle the graves are seen down; one player's are split between
  the two. A block deeper than three ranks takes the camera back 1.8 m a rank.
- **Soft light, not two tones -- a deliberate departure from
  `docs/cel-shading.md`.** Picked over the stage's two tones and over three,
  after a reference picture: a slope's light runs over it smoothly and the
  hills and crowns have their volume. The 3 px contour stays (`Level3DHull`),
  on everything with one baked; not on the ground or the grass (the oaks' is
  drawn over the frame, below). The scene's
  viewport carries `Level3DGameOver.SOFT_LIGHT`, which `_toon` passes by, and
  its materials are copies with Lambert's diffuse -- the prisoners' are shared
  with the stage's, which `_toon` has already stepped.
- **The oaks are BlenderMCP's** (`resources/3d/oaks/`, three of the six its
  `pipeline/tree_gen.py` made, each with its `tree.json`), in place of the
  stage's faceted trees, which the glb still carries only to say where a tree
  stands and how tall (`_plant_oaks`); the faceted bushes are dropped, out of
  place beside them. The oak's twigs (shown once it has burnt) and its root
  plate are not drawn. Each is sunk to the lowest ground round its trunk's
  foot, less 5 cm, so that on a slope no side of the foot stands in the air
  -- checked per twelfth of the way round: every side's lowest bark is at or
  under the ground. The crown (`level3d_leaf_wind.gdshader`) is lit as
  BlenderMCP's board lights it: the file's normals, the crown's own volume, on
  both sides of a leaf, and no sun shadow on it, which speckled it. Its
  palette was picked for BlenderMCP's board light and came out olive-brown
  here, the grass's colour (41,38,5 on average); `OAK_TINT` turns it green,
  27,66,28. **Their outline is drawn over the frame** (`_outline_oaks`), as
  BlenderMCP does it, not grown round the mesh: a leaf is an open plane, which
  `Level3DHull`'s shell cannot ring. A second viewport renders the same world
  from the same camera with each oak replaced by a flat double in its own
  colour (`level3d_oak_mask.gdshader`, on `MASK_LAYER`, which the scene's
  camera leaves out, as the mask's leaves out the oaks' `OAK_LAYER`), swaying
  as the oak does; the scene's frame is then drawn through
  `level3d_oak_ink.gdshader`, which inks an oak's pixel within 3 px of
  anything in the mask that is not that oak -- the silhouette's edge, every
  gap the sky shows through, the line between two oaks, and where something
  stands in front of one, since that is in the mask as it is. The ink is
  hazed as the scene is: drawn over the finished frame it was black at any
  distance, where the rocks' and the crosses' shells are fogged with
  everything else, and an oak's line stood out against a rock's beside it.
  The double writes how much haze is in front of it (Godot's
  `1 - exp(-distance * density)`) into the mask's green, and the ink is mixed
  toward the fog's colour by it -- in linear light, as Godot fogs: mixed as
  sRGB, the same haze left the oaks' line half as light, 36,38,41 against a
  cross's 73,77,83 at the same distance. Now the left oak's trunk measures
  74,78,84. The cost is
  the scene rendered twice, without its smoothing the second time.
- **Wind.** The oaks sway on the stage's wind (`level3d_wind.gdshaderinc`, its
  gusts from the same quarter), the trunk in `level3d_wind_soft.gdshader`, the
  crown in the leaf shader; an oak is in real metres, 7 m tall, and the bend
  goes by the square of the height, so `OAK_GIVE` is 0.3 of a palm's, its top
  some 0.3 m. The grass and the flowers, one mesh, bend from their feet
  (`level3d_grass_wind.gdshader`): each vertex's height over the ground goes
  into UV2 on load, off the hill's triangles, and its normal is a dome's over
  its tuft rather than its blade's own (`dome`, as BlenderMCP's cel tufts):
  under 0.2 s for all of it. On the scene's own clock -- `Level3DWind`'s is
  the preview's, which stops with the stage paused under it; stepped with the
  stage's (G), still under `--no-wind`.
- **Rain** (`Level3DRain`, `src/game3d/world/level3d_rain.gd`), for a gloomier
  end: the sunset the scene was made under turned overcast -- a grey sky
  (`RAIN_SKY`), the sun at 0.4 of its energy and cold, its shadows at 0.45, a
  cold ambient brighter than the sunset's, a haze (`RAIN_FOG`) -- and 7000
  drops falling through the frame, slanting with the wind's way, with
  splashes at the guard's feet: a crown of thin jets a few centimetres
  high, gone in a sixth of a second, and a faint ring spreading round it --
  round drops thrown up and falling back, as they were at first, read as
  hail. CPU particles, the project being on
  Compatibility; each drop a quad stretched along its fall
  (`level3d_rain.gdshader`). They start over the hill's crest and stop 3 m
  short of the camera, where one crossed the lens as a thick white bar. It
  is heard too: `ambient_rain` (War Thunder's rain on a tank's armour, made a
  seamless loop in `build/sfx3d_rain/`) fading in under the song as the
  cemetery comes up and out with it, on the Ambient bus, its slider under
  Ambience; modern and classic alike, none in original. The
  rain is on a render layer of its own that the oaks' mask leaves out, or a
  drop over a crown would ink a streak across it. Under the rain the light
  is turned round: the sun low behind the graves, into the camera, a bright
  band at the horizon, the guard's shadows long towards us and the ambient
  low, so that the guard reads as figures against the light and its models'
  faces and hands are in their own shadow. `--no-rain` gives the sunset back.
- **Layers**: the cemetery is drawn on a canvas layer of its own
  (`CEMETERY_LAYER`, 49) between the stage's grade and the pixels, so that
  8-bit's look takes it as it takes the stage -- in pixels, under the CRT's
  glass -- while the plate over it, on the HUD's layer, stays sharp; the HUD
  itself is hidden while the cemetery stands. On the HUD's layer with the
  plate, as it was at first, the pixels passed it by.
- **Film**, over the finished frame (`level3d_game_over_film.gdshader`): an old
  print -- black and white, a grain, the corners dark and soft (by the place
  on the screen: Compatibility has no depth of field). The title hides the
  models' low detail with its light; here the print does. Nothing keeps its
  colour: the graves have neither wreaths nor helmets, a cross for the first
  player and a headstone for the second telling them apart. Under the rain, drops on the lens
  too: small ones, a few pixels across, land here and there, stand a few
  seconds and dry, and larger ones run down the glass by fits and starts, as on a window -- round below,
  narrowing above into a trail near as wide, a way cleared of the standing
  drops with a bead left on it here and there, drying slowly; the frame through each turned over (`--no-drops`).
  `--no-film` takes it off.
- **Light**, the Blender scene's: a low warm sun from behind the camera's left
  and a warm ambient, the summer grass faded so that the green uniforms stand
  out. Compatibility lights it about 2.2 times as bright as the energies say
  (`LIGHT_GAIN_COMPATIBILITY`, measured against the Blender render) and reads
  the ground's vertex colours as sRGB, so they are turned to it on load.
