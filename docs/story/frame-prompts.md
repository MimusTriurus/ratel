# Промпты к кадрам-комиксам

Кадры из `docs/story/frames.md` сделаны в Blender как blockout (раскладка:
камера, массы, свет, условные цвета). Каждый рендер даётся GPT image как
референс вместе с общим блоком стиля и описанием кадра. Подписи в картинку
не генерируются: их накладывает игра.

- Blend: `resources/3d/jackal_story_frames.blend`, по сцене на кадр
  (`Intro_01` … `Intro_06`, `Intro_08`), текстовый блок
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
> pencil, with a small red flag on a map pin stuck in it. The last stop,
> the capital in the hills where the river begins, is a black square
> ringed twice in red, under a black pin flag with a red coiled-snake
> emblem. On the X stands a small die-cast model of an olive armoured
> pickup truck, a staff map's game piece, facing up the route. No place
> names, no numbers, no lettering on the map or on the flags. The paper
> is worn, with faint fold lines and a pale margin; a white coffee cup
> stands on its left edge, holding it down, and its top right corner
> curls up off the desk. On the desk and the map: a brass magnifying
> glass on the desert at the right, a pencil at the bottom right. The desk
> around the map falls off into darkness. Caption space: the dark desk
> along the top edge.

### 2 — *In one night, the army took the capital. They called themselves the National Order Council.*

> Night, a military coup. A wide low-angle view across a paved government
> square towards a neoclassical palace: a long pale stone front with two
> rows of dark windows, a portico of eight tall columns under a triangular
> pediment, a green-grey dome behind, wide steps down to the square. Two
> drab desert-coloured main battle tanks stand on the square, the near one
> large on the left, side-on, its gun over the square, the other further
> in on the right. Soldiers in helmets with rifles at the order on the
> steps and by the tanks, small. Down the front of the portico, over the
> columns, two soldiers on the portico's ledge are letting down a huge
> black banner on ropes, still half rolled at its foot, with a red coiled
> snake emblem on it. Floodlights at the foot of the steps throw a hard
> white light up the columns and the banner. Two searchlight beams cross
> in the dark blue sky behind the palace, a full moon at the upper left,
> street lamps making warm pools on the paving. Cold blue night shadows
> everywhere else. Caption space: the night sky at the upper left.

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

### 4 — *Aid workers. Reporters. A downed helicopter crew. Forty-one names.*

> Harsh midday sun on a dusty road at the edge of a desert town of
> flat-roofed sand-coloured houses behind a low wall. A file of civilian
> detainees, men and women in plain everyday clothes, bareheaded and
> unarmed, is marched from left to right towards an army truck with a
> canvas back and its tailgate down at the right. An armed escort of junta
> soldiers in helmets walks with the file, rifles ready, on both sides of
> it; in the left foreground one soldier has halted and aims his rifle at
> the file; another stands at the truck. Far off over the rooftops a
> column of black smoke rises from the hills. Short, hard shadows. Only
> the escort wears helmets and gear; the detainees wear none. Caption
> space: the sky at the upper left.

### 5 — *Governments expressed concern. No one came.*

> A formal international conference hall in cold grey daylight, seen
> straight down the length of a very long table covered in green baize,
> one-point perspective. Sixteen chairs along it, nearly all empty, some
> pulled out and left askew. At every place a blank white name card, a
> microphone on a gooseneck with its little light off, a glass of water.
> Only at the far end sit three diplomats in dark suits, small, papers in
> front of them, not speaking. On the right, tall windows between stone
> piers throw cold stripes of light across the table and the carpet; the
> left wall pale, with wood panelling below; on the end wall, dark wood
> panelling and a large plain round emblem (no real country's or
> organisation's symbol). Quiet, empty, indifferent. No flags of real
> countries, no lettering anywhere. Caption space: the ceiling across the
> top.

### 6 — *Someone had insured those forty-one lives. And someone had to pay.*

> A high corner office of a 1980s insurance syndicate at sunset, film
> noir mood. In the foreground a dark wooden desk with a green leather
> blotter: on it a manila folder with a white label bearing only the
> number "41" in black, a red pencil beside it, a green banker's lamp lit
> on the left, a black rotary telephone on the right whose coiled cord
> runs up to the receiver. Behind the desk, at a wide window with venetian
> blinds lowered past her shoulders, stands Ms. Everly, an elegant cold
> woman in her forties in a grey skirt suit and white blouse, auburn hair
> pinned up, seen three-quarters from behind, the telephone receiver at
> her ear, looking out over the city. Through the blinds the orange
> sunset sky and dark office towers with a few lit windows; the low sun
> lays thin stripes of light and shadow across her and the desk. No text
> anywhere except the number 41 on the folder's label. Caption space: the
> blinds across the top.

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
