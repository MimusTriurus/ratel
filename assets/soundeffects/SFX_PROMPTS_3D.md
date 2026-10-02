# Звуки 3D-превью: описания для генерации

Все 38 звуков из таблицы `SOUNDS` в `src/tools/level3d_audio.gd`. Здесь они
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
- **Громкость в файле не важна.** Её задаёт `assets/sfx3d/mix.json`, отдельно
  для каждого режима. Первое значение для нового файла: измерьте его и
  старый из `classic/` (`tools/measure_loudness.gd -- <пути>`) и запишите
  разницу. Окончательное — на слух, на вкладке «Микшер» меню Escape, кнопкой
  «Сохранить».
- **Звуки со «(=2D)»** в оригинале уже есть. Новый звук должен читаться как та
  же вещь, чтобы режимы «классика» и «современный» не расходились по смыслу.
- **Без файла звук молчит.** Замены-тишины больше нет: если в `modern/` нет
  `name_0.ogg`, в новом режиме звука нет, и `tools/verify_level3d_audio.gd`
  сообщает об этом. В классике молчит всё, чего не было в оригинале.

## Что готово

Статус стоит под заголовком каждого звука:

- ✅ **Готов** — в `modern/` свой файл. Указано, сколько вариантов.
- ♻️ **Копия оригинала** — в `modern/` лежит файл из 2D-игры, своего пока нет.
- 🔧 **Заглушка** — в `modern/` синтезированный звук, чтобы было что слышать; его
  нужно заменить сгенерированным.
- ⬜ **Нет файла** — в новом режиме звук молчит.

Состояние на 2026-10-02: готово 20, копий оригинала 4, заглушек 1, без файла 13.

| Осталось | Звуки |
|---|---|
| ⬜ Сгенерировать | `hit_ground`, `hit_water`, `hit_hard`, `hit_armor_blast`, `enemy_mg`, `enemy_cannon`, `btr_idle`, `btr_drive`, `tank_engine`, `boat_engine`, `warning`, `ambient_sea`, `ambient_jungle` |
| ♻️ Заменить копию | `pickup`, `upgrade`, `extra_life`, `pause` |
| 🔧 Заменить заглушку | `hit_dull` |
| ✅ Добавить вариантов | Один файл, а нужно 3–6: `gun`, `grenade_launch`, `blast_small`, `blast_missile`, `blast_water`, `blast`, `breach_blast`, `soldier_death_blast` |

Статусы поставлены по содержимому папок на эту дату и сами не обновляются:
после новой партии звуков их нужно поправить.

---

## Оружие игрока

### `gun` — пулемёт BTR *(flat, =2D `machine_gun`)*
✅ **Готов** — свой файл, вариантов: 1.

Одиночный выстрел пулемёта игрока. До 6 одновременно, до ~33 в секунду при
удержании. Короткий и лёгкий, иначе очередь утомляет. ~0.25 с, 4–6 вариантов.

> Single shot of a heavy vehicle-mounted machine gun on an armored personnel
> carrier, sharp punchy crack with a short mechanical clack, dense but short,
> designed to be repeated rapidly in long bursts without fatigue, 0.25 seconds.

### `grenade_launch` — выстрел гранатомёта *(flat, =2D `throw`)*
✅ **Готов** — свой файл, вариантов: 1.

Граната уходит по дуге. Не взрыв. ~0.6 с.

> Grenade launcher firing, hollow metallic thunk followed by a short airy
> whoosh moving away, no explosion, 0.6 seconds.

### `rocket_launch` — пуск ракеты *(flat, =2D `missile`)*
✅ **Готов** — свой файл, вариантов: 1.

Ракета игрока после апгрейда: только старт, полёт — это `rocket_flight`. В
современном режиме доигрывает, пока ракета летит, и гаснет за 60 мс, если
она взорвалась раньше, поэтому основное в первые 0.3 с. ~0.5–1 с.

> Rocket fired from a vehicle launcher, sharp ignition pop and a bright hissing
> rocket whoosh moving away, punchy, 0.5 seconds.

### `rocket_flight` — полёт ракеты *(loop)*
✅ **Готов** — свой файл, вариантов: 1.

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
этих звуков не было. Первые четыре — тихая мелочь под боем, очень короткие, до 4
одновременно. По 4–6 вариантов.

### `hit_ground` — по земле
⬜ **Нет файла** — в новом режиме молчит, нужно сгенерировать.

> Bullet impact into soft dirt ground, short dull thud with a small spray of
> soil and grit, quiet and subtle, 0.2 seconds.

### `hit_water` — по воде
⬜ **Нет файла** — в новом режиме молчит, нужно сгенерировать.

> Bullet impact into water, short sharp plip with a small splash, quiet and
> subtle, 0.2 seconds.

### `hit_hard` — по бетону и стенам
⬜ **Нет файла** — в новом режиме молчит, нужно сгенерировать.

> Bullet impact on concrete or stone wall, short hard crack with a tiny chip of
> debris and a faint whizz of a ricochet, quiet and subtle, 0.2 seconds.

### `hit_dull` — по хижинам и воротам
🔧 **Заглушка** — синтезирована ffmpeg'ом, вариантов: 4.

Пуля попала в то, что открывает только ракета или мина: хижину или ангар с
пленными, ворота. Глухой, тупой, без треска `hit_hard` и без звона `hit_armor`:
игрок должен слышать, что пулемёт здесь не помогает, и не путать это с бронёй.

> Bullet thudding into a thick wooden plank wall or heavy timber door, short
> dull muffled knock, low and woody, no crack, no ricochet, no metal, quiet
> and subtle, 0.2 seconds.

Заглушка сделана так (вместо `F` — 85, 100, 72, 92, вместо `N` — 0–3):

```bash
ffmpeg -f lavfi -i "aevalsrc='0.9*sin(2*PI*(F+60*exp(-t*45))*t)*exp(-t*32)+0.55*(random(N)*2-1)*exp(-t*70)':s=48000:d=0.22:c=mono" -af "lowpass=f=1100,lowpass=f=1100,afade=t=out:st=0.14:d=0.08,loudnorm=I=-16:TP=-1.5" -ar 48000 -c:a libvorbis -q:a 6 assets/sfx3d/modern/hit_dull_N.ogg
```

### `hit_armor` — по броне, пулемёт *(=2D `bullet_hit`)*
✅ **Готов** — свой файл, вариантов: 12.

Бронированная цель приняла пулю и не разрушилась. Заметнее трёх остальных:
игрок должен понимать, что стреляет не туда.

> Bullet ricocheting off thick tank armor, sharp metallic clank with a short
> ringing ping, 0.35 seconds.

### `hit_armor_blast` — по броне, ракета или мина
⬜ **Нет файла** — в новом режиме молчит, нужно сгенерировать.

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
⬜ **Нет файла** — в новом режиме молчит, нужно сгенерировать.

> Enemy infantry rifle or light machine gun shot, thinner and lighter than the
> player's gun, dry crack with a small pop, 0.2 seconds.

### `enemy_cannon` — пушки бункеров, танков и лодок
⬜ **Нет файла** — в новом режиме молчит, нужно сгенерировать.

> Small enemy cannon shot from a bunker or light tank, short compact boom with
> a metallic punch, lighter than a big artillery gun, 0.4 seconds.

---

## Взрывы

Одно семейство: все шесть — варианты одного взрыва разного размера и среды.
По 3–4 варианта у каждого.

### `blast_small` — граната, миномёт *(=2D `explode2`)*
✅ **Готов** — свой файл, вариантов: 1.

> Small grenade explosion on the ground, tight dry pop-boom with a dirt and
> gravel spray, 1 second.

### `blast_missile` — ракета *(=2D `explode3`)*
✅ **Готов** — свой файл, вариантов: 1.

> Rocket warhead explosion, sharp high-energy blast with a fiery whoosh and a
> short crackling tail, snappier and bigger than a grenade, 1.2 seconds.

### `blast_water` — всплеск от взрыва в воде
✅ **Готов** — свой файл, вариантов: 1.

Граната или ракета упала в воду. Играет **поверх** взрыва самого оружия
(`blast_small` или `blast_missile`), так что здесь только вода: столб воды,
брызги, шлепок и дождь капель, без самого взрыва. Один всплеск на все
оружия. Только в современном режиме: оригинал воду не различал.

> Water splash from an explosion, a heavy slap of water thrown up into a tall
> column, spray and droplets falling back down, no explosion, no boom, no fire,
> 1.3 seconds.

### `blast` — уничтожение врага *(=2D `explode` + `enemy_hit`)*
✅ **Готов** — свой файл, вариантов: 1.

Уничтожен танк, грузовик, лодка, бункер. В обоих режимах сейчас звучит вместе с
`enemy_hit`, как `explode` в оригинале. Если удар уже есть в начале самого
файла, `enemy_hit` нужно отключить (см. его раздел), иначе удар прозвучит
дважды.

> Medium vehicle explosion, sharp crunchy impact at the start into a punchy
> boom with a metal burst and a short rumbling tail with falling debris,
> 1.5 seconds.

### `enemy_hit` — удар под взрывом *(=2D `enemy_hit`)*
✅ **Готов** — свой файл, вариантов: 3.

Короткий удар, который звучит **вместе** с `blast`: в оригинале
`play_hit_explode_sound` играет его под `explode`, и он даёт взрыву щелчок в
начале. Своего ползунка на вкладке «Звук» нет, только на «Микшере». Если новый
`blast` уже начинается с удара, `enemy_hit` можно не играть: `"modern":
{"with": ""}` у `blast` в `SOUNDS`. Без низов, ~0.2 с, 3–4 варианта.

> Short punchy impact hit on a vehicle, dry metallic thwack with a crunch,
> designed as the attack layer on top of an explosion, no boom, no tail,
> 0.2 seconds.

### `building` — разрушение здания *(=2D `hut`)*
✅ **Готов** — свой файл, вариантов: 5.

> Building destroyed by an explosion, heavy boom followed by cracking timber,
> crumbling masonry and a dusty collapse, 1.5 seconds.

### Пробитие танка босса *(=2D `bullet_hit`)*
Танк-босс получил первое повреждение: в броне появилась пробоина, но танк ещё
цел. Больше попадания, меньше взрыва. Два звука по тому, чем пробили; в
оригинале оба `bullet_hit`.

#### `breach_gun` — пулемётом (пятое попадание)
✅ **Готов** — свой файл, вариантов: 12.

> Heavy armor plate giving way under sustained machine gun fire, a last sharp
> bullet strike and a deep metallic crunch with a short burst of sparks and
> hissing, damaged but not destroyed, 0.6 seconds.

#### `breach_blast` — ракетой или миной
✅ **Готов** — свой файл, вариантов: 1.

Поверх взрыва оружия и `hit_armor_blast`, так что без взрыва.
> Heavy armor plate torn open, deep tearing metallic crunch, a groan of bent
> steel and a short burst of sparks and hissing, no explosion, damaged but not
> destroyed, 0.8 seconds.

### `player_explodes` — гибель BTR *(flat, =2D `player_explodes`)*
✅ **Готов** — свой файл, вариантов: 1.

> Player armored vehicle destroyed, heavy explosion with a crunching metal
> wreck and a dramatic descending low rumble, clearly a defeat moment,
> 2 seconds.

### Гибель солдата *(=2D `soldier_killed`)*
Три звука по тому, что убило: в оригинале один `soldier_killed` на всё, и
классический режим играет его для каждого. Без крика и крови, как в
оригинале. До 3 одновременно каждого.

#### `soldier_death_gun` — от пулемёта
✅ **Готов** — свой файл, вариантов: 16.

> Enemy foot soldier hit by machine gun fire and falling, a couple of sharp
> muffled bullet impacts on the body, then a short dull body thud on the
> ground with a quick cloth rustle, no voice, no gore, 0.5 seconds.

#### `soldier_death_blast` — от ракеты или мины
✅ **Готов** — свой файл, вариантов: 1.

Играет поверх взрыва самого оружия, так что здесь только солдат: без взрыва.
> Enemy foot soldier thrown by a blast, a quick whoosh of a body flung
> through the air and a heavy thud landing on the ground with scattering dirt,
> no explosion, no voice, no gore, 0.6 seconds.

#### `soldier_death_run_over` — под колёсами BTR
✅ **Готов** — свой файл, вариантов: 3.

> Enemy foot soldier knocked down by a heavy armored vehicle, a hard dull body
> impact against steel and a heavy thud on the ground, no engine, no voice,
> no gore, 0.5 seconds.

---

## Двигатели *(loop)*

Висят на машине и слышны, пока она едет. Все без атаки и без затухания,
цикл без щелчка на стыке, 2–4 с. Движок меняет только громкость, не высоту
тона, поэтому ровные обороты должен держать сам файл.

### `btr_idle` — BTR на холостых
⬜ **Нет файла** — в новом режиме молчит, нужно сгенерировать.

Когда BTR стоит. Громкость уходит вниз, когда он трогается.

> Armored personnel carrier diesel engine idling, low steady rumbling chug
> with a light mechanical rattle, seamless loop, 3 seconds.

### `btr_drive` — BTR в движении
⬜ **Нет файла** — в новом режиме молчит, нужно сгенерировать.

Накладывается поверх `btr_idle` с ростом скорости. Тот же двигатель, те же
тембры, но под нагрузкой.

> Armored personnel carrier driving, the same diesel engine under load at
> higher revs, growling roar with tire and suspension rumble, steady cruising
> speed, seamless loop, 3 seconds.

### `tank_engine` — танки
⬜ **Нет файла** — в новом режиме молчит, нужно сгенерировать.

> Tank driving, heavy diesel engine rumble with squeaking and clanking steel
> tracks, steady, seamless loop, 3 seconds.

### `boat_engine` — лодки
⬜ **Нет файла** — в новом режиме молчит, нужно сгенерировать.

> Small military patrol boat cruising, buzzing outboard motor with water
> splashing and churning against the hull, steady, seamless loop, 3 seconds.

### `chinook` — Chinook *(flat, =2D `helicopter`)*
✅ **Готов** — свой файл, вариантов: 1.

Высаживает BTR в начале уровня.

> Heavy twin-rotor transport helicopter hovering, deep rhythmic thumping blade
> chop with a turbine whine underneath, steady, seamless loop, 2 seconds.

### `rescue_rotor` — спасательный вертолёт *(flat, =2D `helicopter2`)*
✅ **Готов** — свой файл, вариантов: 1.

Лёгкий вертолёт Little Bird, забирает пленных.

> Small light scout helicopter hovering, fast higher-pitched rotor chop and a
> light turbine whine, lighter than a transport helicopter, steady, seamless
> loop, 2 seconds.

---

## Интерфейс *(flat)*

Одна тембровая палитра на всех, общая с интерфейсом 2D-игры.

### `pickup` — пленный подобран *(=2D `pickup`)*
♻️ **Копия оригинала** — в новом режиме пока звучит звук из 2D-игры.

> Short friendly pickup chime, two quick rising bright notes, cheerful and
> clean, arcade style, 0.3 seconds.

### `rescue_pickup` — пленный в вертолёте *(=2D `helicopter_pickup`)*
✅ **Готов** — свой файл, вариантов: 1.

> Tiny soft confirmation blip, single bright tone, same timbre family as a
> pickup chime but smaller, 0.2 seconds.

### `upgrade` — улучшение оружия *(=2D `weapon_upgrade`)*
♻️ **Копия оригинала** — в новом режиме пока звучит звук из 2D-игры.

> Weapon power-up, rising three-note arpeggio with a metallic reload clack at
> the end, triumphant and energetic, 0.6 seconds.

### `extra_life` — дополнительная жизнь *(=2D `extra_life`)*
♻️ **Копия оригинала** — в новом режиме пока звучит звук из 2D-игры.

Жизнь за 20000 очков и потом за каждые 50000. Редкий и самый радостный сигнал
интерфейса, ярче улучшения оружия.

> Extra life fanfare, bright ascending four-note jingle ending on a held
> sparkling chord, joyful and rewarding, 1 second.

### `warning` — предупреждение о боссе
⬜ **Нет файла** — в новом режиме молчит, нужно сгенерировать.

Появляется баннер «Warning» перед боем с боссом. В оригинале звука не было.
Самый громкий и тревожный сигнал интерфейса.

> Boss warning alarm, urgent pulsing two-tone military klaxon, repeated three
> times, tense and loud but clean, 1.5 seconds.

### `pause` — пауза *(=2D `pause`)*
♻️ **Копия оригинала** — в новом режиме пока звучит звук из 2D-игры.

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
⬜ **Нет файла** — в новом режиме молчит, нужно сгенерировать.

> Gentle ocean shoreline, soft rolling waves washing on a sandy beach, calm
> wind, 20 seconds.

### `ambient_jungle` — джунгли
⬜ **Нет файла** — в новом режиме молчит, нужно сгенерировать.

> Tropical jungle at daytime, dense insect buzz and distant bird calls,
> leaves rustling in a light breeze, no animals close up, 20 seconds.
