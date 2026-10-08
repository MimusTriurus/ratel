# Промпты к кадрам-комиксам

Кадры из `docs/story/frames.md` сделаны в Blender как blockout (раскладка:
камера, массы, свет, условные цвета). Каждый рендер даётся GPT image как
референс вместе с общим блоком стиля и описанием кадра. Подписи в картинку
не генерируются: их накладывает игра.

- Blend: `resources/3d/jackal_story_frames.blend`, по сцене на кадр
  (`Intro_01`, `Intro_03`, `Intro_08`), текстовый блок
  `jackal_story_frames.py`:
  `build_frame(n)`, `render_frame(n, path)`.
- Рендеры: `docs/renders/story/intro_NN.png`, 2048×1152.

## Общий блок стиля

Добавляется к каждому кадру.

> Use the attached image as the layout reference: keep the camera angle,
> the composition, the position and size of every object and the direction
> of the light exactly; it is a rough 3D blockout, so replace its flat
> placeholder shapes with fully drawn, detailed ones. Style: a panel from
> a late-1980s action comic, clean black ink lines, cel-shaded flat colour
> with one hard shadow tone, slight halftone texture in the shadows, muted
> warm palette. 16:9. No text, no lettering, no speech balloons, no
> captions, no logos, no signatures anywhere in the image. Leave the area
> marked below calm and uncluttered for a caption box added later.

## Вступление

### 1 — *Sahrun. 1987.*

> A large paper military map of a fictional desert country, unrolled on a
> dark wooden desk at night, under a single warm desk lamp out of frame on
> the left. The map: ochre desert, the sea down the left (west) edge with
> a ragged coastline, brown hills in the top right corner. One blue river
> runs from those hills diagonally down across the desert into the sea at
> the bottom left, with a thin green band along it. A railway line (black,
> with sleeper ticks) runs from a port on the coast inland through a small
> green swamp and between two ridges to the hills. A planned route is
> pencilled on the map in dashed red: from an X at the bottom, across the
> river, up to the port, then along the railway; each stop ringed in red
> pencil. The last stop, the capital in the hills where the river begins,
> is a black square ringed twice in red, with a red map pin in it. No
> place names, no lettering on the map. The paper is worn, its corners
> curling a little, with faint fold lines and a pale margin. On the desk:
> a coffee cup at the top left, a brass magnifying glass on the desert at
> the right, a pencil at the bottom right. The desk around the map falls
> off into darkness. Caption space: the dark desk along the top edge.

### 3 — *The people called them the Mamba.*

> Low-angle close-up from just below a parade stand: a military dictator
> in an olive dress uniform stands behind its stone rail, seen from below
> against a bright, pale midday sky. His face is entirely hidden in the
> shadow of a high peaked officer's cap with a red band and a gold badge.
> Gold shoulder boards, rows of medal ribbons. Both hands in spotless
> white gloves grip the front edge of the rail, the left one big in the
> foreground: the gloves and the cap's crown are the only things that
> catch the light, everything else is in cool shadow. Two microphones on
> goosenecks to his left. The rail is hung with black cloth bearing a red
> coiled snake emblem. Behind him, far off, two flagpoles with black flags
> on the left and a huge black banner with a red coiled snake on the right.
> Menacing, faceless. Caption space: the dark rail across the bottom.

### 8 — *Rapid Assault Team for Extraction & Liberation. They don't do peace talks.*

> A dark olive twin-rotor CH-47 Chinook transport helicopter flying low
> over endless sand dunes at sunrise, seen from directly behind, slightly
> above the level of its cargo floor. Its rear loading ramp is lowered
> level, like a platform, and the cargo hold is lit warmly from inside:
> standing in it, nose first, two armoured military pickup trucks with
> roof-mounted weapons, the nearer one olive green, the second one blue
> just visible beyond it, both mostly dark silhouettes against the warm
> light in the hold. The low sun on the right, just above a hazy horizon;
> the sky from warm orange at the horizon to dusky violet at the top; the
> helicopter in contre-jour, its rim catching the light. Long soft ridges
> of dunes fading into haze. Caption space: the sky at the top left.
