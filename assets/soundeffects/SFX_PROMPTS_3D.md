# Звуки 3D-превью: описания для генерации

Все 36 звуков из таблицы `SOUNDS` в `src/tools/level3d_audio.gd`. Здесь они
разбиты на те же группы, что и ползунки на вкладке «Звук» меню Escape
(`Level3DMenu.SOUND_GROUPS`). Эффекты 2D-игры описаны в
[SFX_PROMPTS.md](SFX_PROMPTS.md), и **общий стиль у обоих файлов один**: ставьте
его строку в начало каждого prompt'а отсюда тоже.

> Stylized arcade military game sound effect, top-down action game, punchy and
> readable, slightly exaggerated like a modern cartoon-shaded game, tight and
> dry with almost no reverb, clean transient, no music, no voice, no background
> ambience, mono, 48 kHz.

## Чем 3D-звуки отличаются от 2D

- **Звук позиционный.** Всё, что не помечено *flat*, движок сам ослабляет с
  расстоянием и разводит по панораме. Поэтому генерируйте звук «вблизи», без
  дистанции в самом звуке: без гула, без эха, без дальнего затухания.
- **Куда класть.** Новый звук заменяет файл с тем же именем в
  `assets/sfx3d/modern/`. `assets/sfx3d/classic/` не трогайте: это оригинал.
- **Варианты.** Движок берёт `name_0.ogg`, `name_1.ogg` и так далее подряд и на
  каждое воспроизведение выбирает случайный. Для частых разовых звуков
  (попадания, выстрелы, взрывы) сделайте 3–6 вариантов одного prompt'а: так
  повтор не звучит как пулемёт одной и той же записи. Петлям (*loop*) нужен
  один вариант, `_0`.
- **Громкость в файле не важна.** Её подстраивают значением `db` в
  `"modern"` записи в `SOUNDS` по измеренной громкости. После замены измерьте
  новый файл и старый из `classic/`: `tools/measure_loudness.gd -- <пути>`.
- **Звуки со «(=2D)»** в оригинале уже есть, и до замены в `modern/` лежит
  копия файла из `assets/soundeffects/`. Новый звук должен читаться как та же
  вещь, чтобы режимы «классика» и «современный» не расходились по смыслу.
  Остальные до замены — тишина.

---

## Оружие игрока

### `gun` — пулемёт BTR *(flat, =2D `machine_gun`)*
Одиночный выстрел пулемёта игрока. До 6 одновременно, до ~33 в секунду при
удержании. Короткий и лёгкий, иначе очередь утомляет. ~0.25 с, 4–6 вариантов.

> Single shot of a heavy vehicle-mounted machine gun on an armored personnel
> carrier, sharp punchy crack with a short mechanical clack, dense but short,
> designed to be repeated rapidly in long bursts without fatigue, 0.25 seconds.

### `grenade_launch` — выстрел гранатомёта *(flat, =2D `throw`)*
Граната уходит по дуге. Не взрыв. ~0.6 с.

> Grenade launcher firing, hollow metallic thunk followed by a short airy
> whoosh moving away, no explosion, 0.6 seconds.

### `rocket_launch` — пуск ракеты *(flat, =2D `missile`)*
Ракета игрока после апгрейда: только старт, полёт — это `rocket_flight`. В
современном режиме доигрывает, пока ракета летит, и гаснет за 60 мс, если
она взорвалась раньше, поэтому основное в первые 0.3 с. ~0.5–1 с.

> Rocket fired from a vehicle launcher, sharp ignition pop and a bright hissing
> rocket whoosh moving away, punchy, 0.5 seconds.

### `rocket_flight` — полёт ракеты *(loop)*
Двигатель летящей ракеты, висит на ней от пуска до взрыва и летит с ней по
панораме. Тон движок поднимает со скоростью (0.85 → 1.2), поэтому в файле
ровный звук без нарастания и без удаления. Ракета летит 0.3–1 с. Ровная
бесшовная петля ~1 с.

> Steady rocket motor burn in flight, continuous roaring hiss of a small
> solid-fuel rocket, constant level and pitch, no ignition, no fade, seamless
> loop, 1 second.

---

## Попадания

Пуля попала, но ничего не разрушила: и пули игрока, и пули врагов. В оригинале
этих звуков не было. Все три — тихая мелочь под боем, очень короткие, до 4
одновременно. По 4–6 вариантов.

### `hit_ground` — по земле

> Bullet impact into soft dirt ground, short dull thud with a small spray of
> soil and grit, quiet and subtle, 0.2 seconds.

### `hit_water` — по воде

> Bullet impact into water, short sharp plip with a small splash, quiet and
> subtle, 0.2 seconds.

### `hit_hard` — по бетону и стенам

> Bullet impact on concrete or stone wall, short hard crack with a tiny chip of
> debris and a faint whizz of a ricochet, quiet and subtle, 0.2 seconds.

### `hit_armor` — по броне, пулемёт *(=2D `bullet_hit`)*
Бронированная цель приняла пулю и не разрушилась. Заметнее трёх остальных:
игрок должен понимать, что стреляет не туда.

> Bullet ricocheting off thick tank armor, sharp metallic clank with a short
> ringing ping, 0.35 seconds.

### `hit_armor_blast` — по броне, ракета или мина
Ракета или мина ударила в технику: танк, лодку, бункер, танк босса. Играет
**поверх** взрыва самого оружия, убило попадание или нет, так что здесь только
металл: удар и скрежет, без взрыва. Только в современном режиме: в оригинале
граната и ракета взрывались по броне так же, как по песку.

> Heavy impact of a warhead against thick steel armor, a deep resonant metal
> slam with a short grinding crunch and scattering metal debris, no explosion,
> no fire, 0.6 seconds.

---

## Выстрелы врагов

В оригинале враги стреляли беззвучно. Оба звука заметно тише и «беднее»
оружия игрока: их много, и они не должны его перекрывать. У них своя шина
(`EnemyFire`), которую можно выключить отдельно. По 4–6 вариантов.

### `enemy_mg` — пулемёты солдат

> Enemy infantry rifle or light machine gun shot, thinner and lighter than the
> player's gun, dry crack with a small pop, 0.2 seconds.

### `enemy_cannon` — пушки бункеров, танков и лодок

> Small enemy cannon shot from a bunker or light tank, short compact boom with
> a metallic punch, lighter than a big artillery gun, 0.4 seconds.

---

## Взрывы

Одно семейство: все шесть — варианты одного взрыва разного размера и среды.
По 3–4 варианта у каждого.

### `blast_small` — граната, миномёт *(=2D `explode2`)*

> Small grenade explosion on the ground, tight dry pop-boom with a dirt and
> gravel spray, 1 second.

### `blast_missile` — ракета *(=2D `explode3`)*

> Rocket warhead explosion, sharp high-energy blast with a fiery whoosh and a
> short crackling tail, snappier and bigger than a grenade, 1.2 seconds.

### `blast_water` — всплеск от взрыва в воде
Граната или ракета упала в воду. Играет **поверх** взрыва самого оружия
(`blast_small` или `blast_missile`), так что здесь только вода: столб воды,
брызги, шлепок и дождь капель, без самого взрыва. Один всплеск на все
оружия. Только в современном режиме: оригинал воду не различал.

> Water splash from an explosion, a heavy slap of water thrown up into a tall
> column, spray and droplets falling back down, no explosion, no boom, no fire,
> 1.3 seconds.

### `blast` — уничтожение врага *(=2D `explode` + `enemy_hit`)*
Уничтожен танк, грузовик, лодка, бункер. В классике это `explode` с `enemy_hit`
поверх. Здесь это один звук, поэтому удар в начале должен быть внутри файла.

> Medium vehicle explosion, sharp crunchy impact at the start into a punchy
> boom with a metal burst and a short rumbling tail with falling debris,
> 1.5 seconds.

### `building` — разрушение здания *(=2D `hut`)*

> Building destroyed by an explosion, heavy boom followed by cracking timber,
> crumbling masonry and a dusty collapse, 1.5 seconds.

### Пробитие танка босса *(=2D `bullet_hit`)*
Танк-босс получил первое повреждение: в броне появилась пробоина, но танк ещё
цел. Больше попадания, меньше взрыва. Два звука по тому, чем пробили; в
оригинале оба `bullet_hit`.

#### `breach_gun` — пулемётом (пятое попадание)
> Heavy armor plate giving way under sustained machine gun fire, a last sharp
> bullet strike and a deep metallic crunch with a short burst of sparks and
> hissing, damaged but not destroyed, 0.6 seconds.

#### `breach_blast` — ракетой или миной
Поверх взрыва оружия и `hit_armor_blast`, так что без взрыва.
> Heavy armor plate torn open, deep tearing metallic crunch, a groan of bent
> steel and a short burst of sparks and hissing, no explosion, damaged but not
> destroyed, 0.8 seconds.

### `player_explodes` — гибель BTR *(flat, =2D `player_explodes`)*

> Player armored vehicle destroyed, heavy explosion with a crunching metal
> wreck and a dramatic descending low rumble, clearly a defeat moment,
> 2 seconds.

### Гибель солдата *(=2D `soldier_killed`)*
Три звука по тому, что убило: в оригинале один `soldier_killed` на всё, и
классический режим играет его для каждого. Без крика и крови, как в
оригинале. До 3 одновременно каждого.

#### `soldier_death_gun` — от пулемёта
> Enemy foot soldier hit by machine gun fire and falling, a couple of sharp
> muffled bullet impacts on the body, then a short dull body thud on the
> ground with a quick cloth rustle, no voice, no gore, 0.5 seconds.

#### `soldier_death_blast` — от ракеты или мины
Играет поверх взрыва самого оружия, так что здесь только солдат: без взрыва.
> Enemy foot soldier thrown by a blast, a quick whoosh of a body flung
> through the air and a heavy thud landing on the ground with scattering dirt,
> no explosion, no voice, no gore, 0.6 seconds.

#### `soldier_death_run_over` — под колёсами BTR
> Enemy foot soldier knocked down by a heavy armored vehicle, a hard dull body
> impact against steel and a heavy thud on the ground, no engine, no voice,
> no gore, 0.5 seconds.

---

## Двигатели *(loop)*

Висят на машине и слышны, пока она едет. Все без атаки и без затухания,
цикл без щелчка на стыке, 2–4 с. Движок меняет только громкость, не высоту
тона, поэтому ровные обороты должен держать сам файл.

### `btr_idle` — BTR на холостых
Когда BTR стоит. Громкость уходит вниз, когда он трогается.

> Armored personnel carrier diesel engine idling, low steady rumbling chug
> with a light mechanical rattle, seamless loop, 3 seconds.

### `btr_drive` — BTR в движении
Накладывается поверх `btr_idle` с ростом скорости. Тот же двигатель, те же
тембры, но под нагрузкой.

> Armored personnel carrier driving, the same diesel engine under load at
> higher revs, growling roar with tire and suspension rumble, steady cruising
> speed, seamless loop, 3 seconds.

### `tank_engine` — танки

> Tank driving, heavy diesel engine rumble with squeaking and clanking steel
> tracks, steady, seamless loop, 3 seconds.

### `boat_engine` — лодки

> Small military patrol boat cruising, buzzing outboard motor with water
> splashing and churning against the hull, steady, seamless loop, 3 seconds.

### `chinook` — Chinook *(flat, =2D `helicopter`)*
Высаживает BTR в начале уровня.

> Heavy twin-rotor transport helicopter hovering, deep rhythmic thumping blade
> chop with a turbine whine underneath, steady, seamless loop, 2 seconds.

### `rescue_rotor` — спасательный вертолёт *(flat, =2D `helicopter2`)*
Лёгкий вертолёт Little Bird, забирает пленных.

> Small light scout helicopter hovering, fast higher-pitched rotor chop and a
> light turbine whine, lighter than a transport helicopter, steady, seamless
> loop, 2 seconds.

---

## Интерфейс *(flat)*

Одна тембровая палитра на всех, общая с интерфейсом 2D-игры.

### `pickup` — пленный подобран *(=2D `pickup`)*

> Short friendly pickup chime, two quick rising bright notes, cheerful and
> clean, arcade style, 0.3 seconds.

### `rescue_pickup` — пленный в вертолёте *(=2D `helicopter_pickup`)*

> Tiny soft confirmation blip, single bright tone, same timbre family as a
> pickup chime but smaller, 0.2 seconds.

### `upgrade` — улучшение оружия *(=2D `weapon_upgrade`)*

> Weapon power-up, rising three-note arpeggio with a metallic reload clack at
> the end, triumphant and energetic, 0.6 seconds.

### `warning` — предупреждение о боссе
Появляется баннер «Warning» перед боем с боссом. В оригинале звука не было.
Самый громкий и тревожный сигнал интерфейса.

> Boss warning alarm, urgent pulsing two-tone military klaxon, repeated three
> times, tense and loud but clean, 1.5 seconds.

### `pause` — пауза *(=2D `pause`)*
Открытие и закрытие меню Escape.

> Game pause jingle, short neutral two-tone chime with a soft decay, calm and
> clean, 0.9 seconds.

---

## Окружение *(loop, flat)*

Звучит под всем остальным всё время, пока идёт превью, поэтому здесь
отступление от общего стиля: без атаки, мягко и ровно. Строку общего стиля
для этих двух звуков замените на эту:

> Ambient background loop for a top-down action game, soft, even and
> unobtrusive, no distinct events that would draw attention, seamless loop,
> mono, 48 kHz.

### `ambient_sea` — море

> Gentle ocean shoreline, soft rolling waves washing on a sandy beach, calm
> wind, 20 seconds.

### `ambient_jungle` — джунгли

> Tropical jungle at daytime, dense insect buzz and distant bird calls,
> leaves rustling in a light breeze, no animals close up, 20 seconds.
