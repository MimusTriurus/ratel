# Промпты к снимкам стола брифинга

Вступление и финал — 3D-сцена: стол с картой, на который ложатся снимки
из досье (`docs/story/frames.md`). Генерируются только **снимки** и
**сет**; документы с текстом (вырезка, контракт, газета) делаются в
движке как текстуры с набранным текстом. Подписи маркером в картинку не
генерируются: их накладывает игра.

Каждый снимок сначала собирается в Blender как blockout (камера, массы,
свет, условные цвета), рендер даётся GPT image как референс вместе с
общим блоком стиля и описанием.

- Blend: `resources/3d/jackal_story_frames.blend`, по сцене на кадр
  старого комикса (`Intro_01` … `Intro_08`), текстовый блок
  `jackal_story_frames.py`: `build_frame(n)`, `render_frame(n, path)`.
  Нумерация сцен в blend — старая; соответствие — в таблице ниже.
- Рендеры: `docs/renders/story/intro_NN.png`, 2048×1152.
- Отрисованное: `docs/story/paint/` (кадр 1, снимки 2–4 — пока в цвете,
  комиксом; ч/б и растр — см. «Из цвета в ч/б»).

## Что из старого комикса куда

| Старый кадр | Теперь |
|---|---|
| 1 — карта | **сет**: карта на столе (уже в 3D, `jackal_intro_01_3d.blend`) |
| 2 — танки и знамя | снимок 2 вступления |
| 3 — Вассар на трибуне | снимок 3 вступления; он же снимок 2 финала |
| 4 — заложников ведут к грузовику | снимок 5 вступления |
| 5 — конференц-зал | снят: вместо него вырезка (в движке) |
| 6 — Everly в офисе | снят: вместо него контракт (в движке) |
| 7 — Badger в ангаре | **сет**: ангар, в котором стоит стол |
| 8 — Chinook на рассвете | последний план вступления: вид из ворот ангара (в движке) |

## Общий блок стиля

Добавляется к каждому снимку.

> Use the attached image as the layout reference: keep the camera angle,
> the composition, the position and size of every object and the direction
> of the light exactly; it is a rough 3D blockout, so replace its flat
> placeholder shapes with fully drawn, detailed ones. Style: a black and
> white press photograph from the late 1980s as printed in a newspaper,
> rendered as ink drawing: clean black ink lines, flat grey tones with one
> hard shadow tone, coarse halftone dot screen in the greys, slight film
> grain. Not photorealistic. 16:9. No text, no lettering, no logos, no
> signatures anywhere in the image.

Для цветных эпилогов финала вместо «black and white press photograph»:
«a colour snapshot from the late 1980s, slightly faded, as a printed
photo», остальное то же.

## Из цвета в ч/б

Снимки 2–4 уже отрисованы в цвете, в стиле комикса. Их не перегенерируем:
в движке они переводятся в ч/б (обесцвечивание) и получают полутоновый
растр шейдером. Если результат спорит с новыми снимками —
перегенерировать с блоком стиля выше.

## Сет

### Карта на столе

Бывший кадр 1. Уже собрана в 3D (`jackal_intro_01_3d.blend`). На столе
телефон: чёрный дисковый, за картой слева вверху, под лампой, в стороне от
флажка столицы (`SF1P_Phone`, `_phone()` в `jackal_story_frames.py` этого
blend'а).

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
> around the map falls off into darkness.

### Ангар

Бывший кадр 7. Промпт ниже — старый, для кадра с Badger'ом; для сета из
него убираются Badger, телефон на стене и экипажи: в сцене со столом людей
нет. Эмблема на стене остаётся.

> Night inside a corrugated-steel aircraft hangar, almost dark. On the
> back wall hangs the team's emblem exactly as in the second attached
> image (a snarling honey badger over a sunset disc, "R.A.T.E.L." on a
> banner below), lit by a spotlight from the roof beams. Under a single
> hanging industrial lamp stands Roy "Badger" Callahan, a weathered
> veteran in his fifties with a grey crew cut, olive T-shirt and combat
> trousers, the receiver of a black wall telephone at his ear, its cord
> running to the phone on the wall beside him; the lamp throws a hard cone
> of warm light over him and onto the floor. Either side, in the dark,
> two armoured pickup trucks (one olive, one blue) and the crews waiting
> by them, sitting on crates or standing, only their outlines caught by
> cold blue light from an open hangar door on the right.

Ко второму референсу приложить саму эмблему (`ratel_emblem.blend` или
логотип), чтобы GPT не перерисовал её по-своему.

## Вступление

### Снимок 2 — *Coup. One night.*

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
> everywhere else.

### Снимок 3 — *Gen. Tarek Vassar — "the Mamba"*

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
> Menacing, faceless.

### Снимок 4 — *41* ⬜

Новый. Пачка фото на документы под скрепкой; генерируется лист из
нескольких портретов, в движке он режется на отдельные карточки.

> A sheet of eight small passport-style identity photographs in two rows,
> each a head-and-shoulders portrait against a plain pale backdrop, flat
> frontal light: doctors and nurses of an aid mission, two press
> reporters, a helicopter pilot in a flight suit; men and women of
> different ages and origins, tired, plain everyday clothes. Each photo
> has a thin white border. Late-1980s ID photos.

### Снимок 5 — *Ashra checkpoint. 3 days ago.*

Бывший кадр 4. Снят телеобъективом: зерно сильнее, глубина резкости
меньше.

> Harsh midday sun on a dusty road at the edge of a desert town of
> flat-roofed sand-coloured houses behind a low wall. A file of civilian
> detainees, men and women in plain everyday clothes, bareheaded and
> unarmed, is marched from left to right towards an army truck with a
> canvas back and its tailgate down at the right. An armed escort of junta
> soldiers in helmets walks with the file, rifles ready, on both sides of
> it; in the left foreground one soldier has halted and aims his rifle at
> the file; another stands at the truck. Far off over the rooftops a
> column of black smoke rises from the hills. Short, hard shadows. Only
> the escort wears helmets and gear; the detainees wear none.

### Снимок 8 — *They don't do peace talks.* ⬜

Новый. Групповое фото отряда.

> A team photo of four mercenaries posing in front of two armoured
> military pickup trucks with roof-mounted weapons on a desert airstrip.
> From the left: Roy "Badger" Callahan, a weathered veteran in his fifties
> with a grey crew cut, arms folded; Niko "Wire" Revaz, young, grinning,
> leaning on the bonnet; Hannah "Fuse" Weil, sleeves rolled up, a
> demolition bag over her shoulder; Themba "Echo" Nkosi, a field radio
> handset clipped to his vest. Olive T-shirts and combat trousers, the
> same honey badger patch on every shoulder. Bright midday sun, short
> shadows.

## Финал ⬜

Промпты ещё не написаны. Снимки: горящий штаб с остовом супертанка (1);
падает знамя с мамбой, поднимается флаг Сахруна (4); четыре цветных
эпилога (7–10). Снимок 2 — снимок 3 вступления; на 3 — карточки снимка 4
вступления.

## Intel ⬜

Промпты ещё не написаны: по 2–3 разведфото на этап, одно — намёк на босса
(`docs/story/frames.md`, «Тот же стол в остальном сюжете»).
