# Звуковые эффекты: описания для генерации

Все 25 эффектов из `assets/soundeffects/`. У каждого указано, где он звучит в игре,
длительность нынешнего файла (это ориентир, а не требование) и prompt для
генератора. Prompt'ы написаны по-английски, потому что генераторы звука лучше
всего понимают английский.

## Общий стиль

Эту строку ставьте **в начало каждого** prompt'а. Из-за неё эффекты и звучат как
один набор: одна «камера», один масштаб, один характер.

> Stylized arcade military game sound effect, top-down action game, punchy and
> readable, slightly exaggerated like a modern cartoon-shaded game, tight and
> dry with almost no reverb, clean transient, no music, no voice, no background
> ambience, mono, 48 kHz.

Правила, которые держат набор единым:

- **Одна дистанция.** Всё слышно с камеры над полем боя, метров с 20–30: не в
  упор и не издалека.
- **Сухо.** Хвост у короткого эффекта не длиннее 0.3 с. Реверберацию движок
  добавит сам, если понадобится.
- **Иерархия громкости.** Интерфейс и оружие игрока — самые короткие и
  чёткие, взрывы — самые плотные по низам, враги чуть тише и «дальше» игрока.
- **Семейства.** Звуки одной группы делайте из общего материала: три взрыва —
  разные по размеру варианты одного взрыва, три сигнала интерфейса — одна
  тембровая «палитра».
- **Петли.** Звуки с пометкой *loop* должны зацикливаться без щелчка: без
  атаки в начале и без затухания в конце.

---

## Оружие игрока

### `machine_gun.ogg` — пулемёт джипа
Одиночный выстрел пулемёта игрока. Звучит на каждую пулю, до ~14 раз в секунду
при турбо, так что должен быть коротким и не утомлять. ~0.3 с.

> Single shot of a jeep-mounted light machine gun, sharp crisp crack with a
> short mechanical click, bright and snappy, very short decay, designed to be
> repeated rapidly without fatigue, 0.3 seconds.

### `throw.ogg` — бросок гранаты
Граната (и бомба самолёта) улетает по дуге. Не взрыв, а сам бросок. ~0.7 с.

> Grenade launched in an arc, soft hollow thump of a launcher followed by a
> short airy whoosh fading away, light and toy-like, no explosion, 0.7 seconds.

### `missile.ogg` — запуск ракеты
Ракета игрока после апгрейда; тот же звук — подтверждение в меню настроек.
~0.4 с.

> Small rocket launched from a vehicle, quick ignition pop and a short hissing
> rocket whoosh moving away, punchy and bright, 0.4 seconds.

---

## Оружие врагов

### `fire.ogg` — огнемёт супертанка
Огненная колонна босса-супертанка: после зарядки выбрасывается струя пламени.
~0.7 с.

> Heavy flamethrower burst from a boss tank, whooshing roaring gout of fire
> with a crackling edge, starts with a pressurized puff, powerful but short,
> 0.7 seconds.

### `laser.ogg` — лазер
Лазерные турели и ракеты «слона». Единственный «фантастический» звук набора —
держите его в той же сухой, плотной манере, без космических хвостов. ~0.65 с.

> Energy laser beam firing from a military turret, bright electric zap with a
> descending pitch sweep and a buzzing edge, sci-fi but grounded and gritty,
> 0.65 seconds.

---

## Попадания и взрывы

### `bullet_hit.ogg` — попадание по броне
Пуля попала в бронированную цель, которая не разрушилась (бронированный танк,
пушки босса, турели). ~0.45 с.

> Bullet ricocheting off thick armor plate, sharp metallic clank with a short
> ringing ping, no explosion, 0.45 seconds.

### `enemy_hit.ogg` — удар по врагу
Короткий удар, который звучит **вместе** со взрывом при уничтожении цели:
даёт взрыву «щелчок» в начале. Сам по себе почти без низов. ~0.2 с.

> Short punchy impact hit, dry thwack with a metallic crunch, designed as the
> attack layer on top of an explosion, very short, 0.2 seconds.

### `explode.ogg` — взрыв машины
Основной взрыв: уничтожен танк, грузовик, пушка. ~1.5 с.

> Medium vehicle explosion, punchy boom with a crunchy metal burst and a short
> rumbling tail with falling debris, 1.5 seconds.

### `explode2.ogg` — взрыв гранаты
Граната, бомба, миномёт, ракеты статуи. Меньше и суше, чем `explode`. ~1.1 с.

> Small grenade explosion on the ground, tight dry pop-boom with a dirt and
> gravel spray, smaller and shorter than a vehicle explosion, 1.1 seconds.

### `explode3.ogg` — взрыв ракеты
Разрыв ракеты игрока. Резче гранаты, с более высоким, «огненным» хлопком.
~1.3 с.

> Rocket warhead explosion, sharp high-energy blast with a fiery whoosh and a
> short crackling tail, snappier than a grenade, 1.3 seconds.

### `hut.ogg` — рушится постройка
Разрушен дом или хижина (и корабельные пушки босса). Не столько взрыв,
сколько обвал: доски, солома, камень. ~1.2 с.

> Small wooden building collapsing from an explosion, muffled boom followed by
> cracking timber, falling planks and a dusty crumble, 1.2 seconds.

### `hq_explodes.ogg` — гибель штаба
Самый большой звук игры: уничтожен штаб в конце уровня (и супертанк). Серия
взрывов, нарастающая к финальному. ~5.5 с.

> Huge enemy headquarters destroyed, a chain of cascading explosions building
> up to a massive final blast, deep rumbling low end and a long crumbling
> debris tail, cinematic but still punchy, 5.5 seconds.

### `player_explodes.ogg` — гибель джипа
Джип игрока уничтожен. Должен читаться как поражение: тяжелее обычного
взрыва машины и заметно отличаться от него. ~2 с.

> Player jeep destroyed, heavy explosion with a crunching metal wreck and a
> dramatic descending low rumble, clearly a defeat moment, 2 seconds.

### `soldier_killed.ogg` — солдат убит
Пехотинец врага погиб (пуля или наезд). В оригинале без голоса — держите
мультяшным, без крика и крови. ~0.4 с.

> Enemy foot soldier knocked down, short comic cartoony thud with a quick
> falling blip, no voice, no gore, 0.4 seconds.

---

## Техника (loop)

### `helicopter.ogg` — вертолёт *(loop)*
Чинук: высаживает джип в начале уровня и забирает пленных. Проигрывается,
пока вертолёт на экране. Цикл ~1 с.

> Heavy twin-rotor transport helicopter hovering, rhythmic thumping blade chop
> with a turbine whine underneath, steady, seamless loop, 1 second.

### `helicopter2.ogg` — вертолёт босса *(loop)*
Боевой вертолёт-босс. Тот же семейный звук, что `helicopter`, но легче,
быстрее и агрессивнее. Цикл ~1 с.

> Attack helicopter hovering, fast aggressive rotor chop, higher-pitched and
> tighter than a transport helicopter, menacing turbine whine, seamless loop,
> 1 second.

### `plane.ogg` — самолёт *(loop)*
Вражеский бомбардировщик пролетает над полем. Цикл ~1 с.

> Propeller warplane flying overhead, steady droning engine buzz, slightly
> gritty, seamless loop, 1 second.

---

## Подбор и награды

### `pickup.ogg` — пленный подобран
Джип подобрал освобождённого пленного; тот же звук — навигация в меню. Самый
частый сигнал интерфейса. ~0.3 с.

> Short friendly pickup chime, two quick rising bright notes, cheerful and
> clean, arcade style, 0.3 seconds.

### `helicopter_pickup.ogg` — пленный поднят в вертолёт
Каждый пленный, поднявшийся в вертолёт. Короче и мягче `pickup`, того же
тембра. ~0.2 с.

> Tiny soft confirmation blip, single bright tone, same timbre family as a
> pickup chime but smaller, 0.2 seconds.

### `weapon_upgrade.ogg` — улучшение оружия
Освобождён пленный с флагом: граната сменилась ракетой, ракета стала мощнее.
~0.6 с.

> Weapon power-up, rising three-note arpeggio with a metallic reload clack at
> the end, triumphant and energetic, 0.6 seconds.

### `extra_life.ogg` — дополнительная жизнь
Подобрана звезда. Самая «праздничная» из наград. ~0.6 с.

> Extra life reward jingle, bright sparkling ascending fanfare of short notes
> with a shimmer, joyful, 0.6 seconds.

---

## Интерфейс и заставки

### `pause.ogg` — пауза
Пауза и открытие/закрытие меню Escape. ~0.9 с.

> Game pause jingle, short neutral two-tone chime with a soft decay, calm and
> clean, 0.9 seconds.

### `intro_type.ogg` — печать титров
Каждая буква в титрах заставки. Очень короткий, повторяется быстро. ~0.08 с.

> Single typewriter key tick, tiny crisp mechanical click, extremely short,
> designed to repeat rapidly, 0.08 seconds.

### `intro_ching.ogg` — титр напечатан
Звучит, когда в заставке допечатана строка. ~0.5 с.

> Typewriter carriage bell, bright metallic ding with a short ring, 0.5
> seconds.

### `well_done.ogg` — печать «Mission accomplished»
Каждая буква поздравительного текста после победы над боссом. Тот же тип,
что `intro_type`, но чуть светлее и «электроннее». ~0.07 с.

> Single electronic teletype blip, tiny bright digital tick, extremely short,
> designed to repeat rapidly, 0.07 seconds.
