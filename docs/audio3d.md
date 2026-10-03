# Sound and music of the 3D preview

Moved out of `CLAUDE.md`. The 2D game reads `assets/soundeffects/` and
`assets/music/` and nothing here.

## Effects and music

The 3D preview has its own sound, `Level3DAudio` (`src/tools/level3d_audio.gd`):
one table, `SOUNDS`, of every effect it plays, with its bus (sub-buses of
`Sfx`; the enemies' guns on `EnemyFire` under `Weapons`), gain, variants and
whether it is positional; engines and rotors are loops on the unit, heard
through a listener over the frame's centre. The Escape menu's Sound tab picks
original, classic (8-bit) or modern, and sets the master, music, effects and enemy-fire volumes,
the last with a switch of its own since the original's enemies fired in
silence; under them, a 0–200 % slider for each of the modern mode's sounds
(`Level3DMenu.SOUND_GROUPS`, which must list every sound in `SOUNDS` but
`enemy_hit`, which only plays under a blast -- the verify script checks).
The music is chained as `Song` chains it: the title's song under the title
screen, over and over -- in modern a heavy cover of «От героев былых
времён», in classic its notes on the chips (`build/music3d_officers/`), in
original the 2D game's `title_song` -- `intro_song` at the start,
`stage_song0` after a restart, `boss_song` from the boss's trigger, stopped
when it is beaten or the last life goes. A song's parts are not chained
through `finished` as `Song` chains them, which left about 20 ms of silence
between two (measured on WASAPI): `_next_part` puts every part still to come
into one `AudioStreamInteractive`, each auto-advancing into the next and the
last looped. That runs on with no gap, though Godot switches some 12 ms
before a clip's end, so the last of each part is not heard -- which is why
modern `start.ogg` holds its chord to the bar line rather than ringing out.
A chain's position is the clock's, since the stream's is always 0
(`_music_position`). It is split by mode as the effects
are: `assets/music3d/original/` holds copies of the parts of `MUSIC` from
`assets/music/`, under their own names, and `assets/music3d/modern/` started
as a copy of it, a new song going in by replacing its file. A change of mode
swaps the part playing for the other folder's from the same position (an
intro that runs out goes on to its loop, a loop wraps round).

## Classic (8-bit) music

`assets/music3d/classic/` is modern's songs as a Famicom game with Konami's
VRC6 (the Japanese Castlevania III's) could have played them, and
`tools/music_chiptune.py --install` makes it -- not out of modern's audio but
out of its notes, the MIDI in `build/music3d_pogonya/` and
`build/music3d_boss/`. Its `ARRANGEMENT` puts the tracks on eight voices:
the lead on pulse 1, a second voice (the stage's lead echoed an eighth late,
the boss's harmony or arpeggio) on pulse 2, the rhythm guitar's power chord
over the VRC6's two pulses, the strings on its sawtooth (a chord as a
one-frame arpeggio), the bass on the triangle, the drums on the noise and
the kick, timpani and taiko as DPCM samples. Everything moves on the frame,
as an NES driver does; at 180 and 150 BPM a sixteenth is 5 and 6 frames and
a bar 80 and 96, which are modern's 58800- and 70560-sample bars, so each
part is cut on modern's bars, a loop out of the middle of three. A song is at
modern's loop's loudness, through a limiter at -1 dBFS on the whole render
before the cuts. The boss's is the linear one (below).

## Adaptive boss music

The modern boss is the exception: its music follows the fight
(`Level3DAudio.ADAPTIVE`). It is one `AudioStreamInteractive` of three clips:
the intro over the pan, running on into the loop by itself; the loop, an
`AudioStreamSynchronized` of the lead part (drums, bass, the theme) and a
layer for each of the four tanks -- guitars, double kick, strings,
arpeggio, by the order the tanks come in (`Level3DBoss.alive_layers`) -- all
16 bars and summed sample for sample; and the victory, which anything goes
to on the next beat (`music_end`). `Level3DPreview._update_music` says which
tanks are on the field every tick (`music_layers`): a layer comes in on the
next bar and goes as soon as its tank does, over a beat either way, by its
volume in the synchronized stream, which takes a change while it plays; and
the lead is up to 4 dB louder as layers go, so that the music thins and does
not die away. Every part is at 150 BPM and starts on a bar, so the bars run on
unbroken from the intro's first: that is what a layer comes in on, and what
`music_accent` -- a tank breached -- counts the beat its `boss_breach.ogg`
lands on from (the file starts a beat in, and is played from as far into the
beat as the song has got). The count is the system clock, which agrees with a
real audio driver and not with `--headless`'s Dummy one, which runs slow;
`get_playback_position()` of an interactive stream is always 0. The parts are
mixed linearly, EQ and gain and no compressor, because they are summed in the
game. `modern/` holds the nine files in place of `boss_repeat.ogg`
(`mode_music_files`); the mix has every file of both modes, so each layer has
its own gain in the Mixer, which shows each mode's own. The original mode
plays the intro and loop as before and stops at the end, as the game stops
its song; the classic mode plays it as modern does linearly, whatever the
setting, its folder holding the intro, `boss_full.ogg`, the victory and the
accent (`linear_files`).
The Sound tab's "Boss music" (`Level3DSettings.boss_music`,
`Level3DAudio.set_adaptive`) plays it linearly, and does by default: the same stream with
`boss_full.ogg` -- the lead and every layer mixed into one file -- for its
loop, so the fight changes only the accent and the end. A switch while it
plays starts the other loop from its first bar, since there is no position
to carry over. The score and how the files are made are in
`build/music3d_boss/`.

## Effects by mode

Each mode is a folder holding its files under the same names, `<name>_0.ogg`
and optionally `_1`, `_2`... as variants picked at random:
`assets/sfx3d/original/`, `classic/` and `modern/`, all imported, committed
and shipped. A sound with no file is silent, in any mode.

- **Original** is the base and does not change: every file is a copy of the
  sound's `"original"` in `assets/soundeffects/`, and a sound the original
  had no sound for (engines, the enemies' guns, rounds landing, the ambience)
  has none, played flat, unpitched, unlooped and throttled as
  `Main.play_sound` plays it. `tools/sfx3d_classic.gd` wrote it and filled in
  modern as a copy; run again, it rewrites original and only adds to modern
  what is missing and the original has, never over a file already there.
- **Modern** is positional, pitched and looped where `SOUNDS` says, and a new
  sound goes in by replacing its file there, or by putting one where there is
  none.
- **Classic** is modern's sounds as the NES could have made them, and holds
  exactly modern's files: `tools/sfx_chiptune.py --install` reads each modern
  file a frame (1/60 s) at a time into the APU's registers and plays them on
  a model of the 2A03 with a Famicom's output filters -- the original's
  recordings keep the low end the NES's 440 Hz high-pass takes out -- at the
  loudness of the original's file of that name, so the original's gains in
  the mix hold for it, and copies the original's own where modern's is still a
  copy of it. Played by modern's rules -- positional, pitched, looped, the
  edge fades and fade-outs, the rescue helicopter idling on its pad, the
  Sound tab's sliders; only the original is played as the game plays it
  (`Level3DAudio.as_original`) -- and its music is modern's on the same
  chips (above), the boss's linear. A loop is rendered three
  times and the middle cut out, crossfaded at the seam. What modern is
  silent for, classic is too. A new modern sound wants a run of the tool.

`SOUNDS`' `"classic"` / `"modern"` sub-dicts hold what differs for one mode --
a new blast that already has the hit in it `"with": ""` -- `"classic"` the
original mode's and `"modern"` the classic mode's too (`SPEC_KEYS`),
`"original"` being a field of its own. `Level3DAudio.Mode`'s values are the settings' and so a saved config's:
`ORIGINAL` came last, so a config that said classic before it now says
classic, the 8-bit mode.

## The mix

The gains are not in `SOUNDS`: `assets/sfx3d/mix.json` holds every sound's
and every music part's, in dB, for each mode, one to a line. The Escape
menu's Mixer tab (always there, as the other tabs are) is where they are set
by ear -- a slider and a ▶ for each, the mode picked on the tab, the
changes heard at once -- and Save writes the file through
`Level3DAudio.save_mix`, which only works where `res://` is the project
folder, not in an exported build. A replaced file starts from its measured
loudness against the original one (`tools/measure_loudness.gd -- <paths>`).
The generator leaves an echo and a rumble after the hit however dry it is
asked for, so the long-tailed ones go through `tools/sfx_tails.py`, which
reads each as generated out of git (its `TAILS` table names the sounds,
where their hits end and where they now stop) and writes the shortened file
in its place; a newly generated file is committed as it came first. The
player's own 0–200 % sliders on the Sound tab act over the mix. The
2D game reads `assets/soundeffects/` and `assets/music/` and nothing here;
`tools/sfx3d_classic.gd` writes `music3d/` the same way. Check all five
folders and the mix (every sound and part in every mode, laid out as a save
writes it):

```bash
godot --path . --headless --script tools/verify_level3d_audio.gd
```

## When it is silent

When the preview is silent, `-- --audio-debug` prints every bus's mute, gain and
peak once a second, which says whether Godot is producing anything, and
`tools/audio_check.ps1` says what Windows does with it: the output device, its
volume, and every app's mute in the volume mixer. Windows remembers a mute per
executable, so muting the editor once mutes every game it runs.

```bash
godot --path . --windowed --resolution 1280x720 src/tools/level3d_preview.tscn -- --audio-debug
```

```bash
powershell -ExecutionPolicy Bypass -File tools/audio_check.ps1
```

