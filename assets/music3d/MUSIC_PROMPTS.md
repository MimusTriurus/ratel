# Музыка 3D-превью: промпты для SUNO

Пять частей музыки из `Level3DAudio.MUSIC` (`src/game3d/level3d_audio.gd`), по
папке на режим: `assets/music3d/classic/` — оригинал с NES, не меняется;
`assets/music3d/modern/` — то, что заменяется, файл за файлом, под тем же
именем. Звуковые эффекты описаны в
[SFX_PROMPTS_3D.md](../soundeffects/SFX_PROMPTS_3D.md).

Игра играет их цепочкой: `start` один раз → `stage0_intro` один раз →
`stage0_repeat` по кругу; с триггера босса `boss_intro` один раз →
`boss_repeat` по кругу. Интро кончается и сразу, без паузы, начинается петля.

## Файлы и промпты

У каждого файла свой промпт: интро и петля генерируются отдельно. Темп,
размер и тональность у интро и его петли **обязаны совпадать** — они стоят в
обоих промптах одинаково; иначе переход из одного в другое будет слышен.

| файл | такты / длина | Style (поле Style of Music) | Exclude styles | Lyrics (структура) |
|---|---|---|---|---|
| `start.ogg` | 3 такта, ~7.2 с | instrumental, modern military action game soundtrack with retro arcade roots, short heroic fanfare jingle, 100 BPM, 4/4, D minor, bold brass fanfare, marching snare roll, orchestral hit, bright square-wave lead doubling the brass, ends on a sustained final chord, clean punchy mix | vocals, choir, long intro, fade out, ambient | `[Instrumental]`<br>`[Intro: snare roll]`<br>`[Brass fanfare]`<br>`[Final chord]`<br>`[End]` |
| `stage0_intro.ogg` | 2 такта, ~4.8–5.6 с | instrumental, modern military action game soundtrack with retro arcade roots, short intro leading into a jungle combat march, 100 BPM, 4/4, C major, drum fill with marching snare, rising brass pickup, synth bass entering, builds straight into the main theme, does not end, no final chord | vocals, choir, fade out, ending, ambient, slow build | `[Instrumental]`<br>`[Intro: drum fill]`<br>`[Brass pickup]`<br>`[Build into main theme]` |
| `stage0_repeat.ogg` | 16 тактов, ~38.4 с | instrumental, modern military action game soundtrack with retro arcade roots, upbeat jungle combat march, 100 BPM, 4/4, C major, punchy live drums and marching snare, driving synth bass, memorable bright square-wave lead doubled by brass, call-and-response brass, orchestral hits, constant energy, steady groove for looping | vocals, choir, intro, breakdown, fade out, ending, tempo change | `[Instrumental]`<br>`[Main Theme A]`<br>`[Main Theme B]`<br>`[Main Theme A]`<br>`[Main Theme B]` |
| `boss_intro.ogg` | 4 такта, ~8.0 с | instrumental, modern military action game soundtrack with retro arcade roots, tense boss battle intro, 120 BPM, 4/4, A minor, pounding toms, low brass swell, rising tension, alarm-like synth stabs, builds straight into the battle theme, does not end, no final chord | vocals, choir, fade out, ending, ambient, calm | `[Instrumental]`<br>`[Intro: pounding toms]`<br>`[Low brass swell]`<br>`[Rising tension into battle theme]` |
| `boss_repeat.ogg` | 8 тактов, 16.0 с | instrumental, modern military action game soundtrack with retro arcade roots, tense boss battle, 120 BPM, 4/4, A minor, heavy low brass ostinato, pounding toms, urgent staccato strings, menacing synth lead, relentless, steady groove for looping | vocals, choir, intro, breakdown, fade out, ending, tempo change | `[Instrumental]`<br>`[Battle Theme]`<br>`[Battle Theme]`<br>`[Battle Theme]` |

## Настройки SUNO — одни для всех

| настройка | значение | зачем |
|---|---|---|
| Instrumental | вкл. | без голоса |
| Модель | последняя (v4.5 и новее) | лучше держит темп и структуру |
| Style Influence | высоко, ~70–80 % | держаться BPM, тональности и инструментов из Style |
| Weirdness | низко, ~20–30 % | ровный, предсказуемый трек, без неожиданных смен |
| Длина | не задаётся | генерировать длинный трек и резать самим (ниже) |

## Порядок работы

1. **Сначала петля** (`*_repeat`): по ней слышно, нравится ли тема. Сделать
   2–4 генерации, выбрать одну.
2. **Потом интро** (`*_intro`) тем же стилем, темпом и тональностью. Если
   переход с интро на петлю не складывается, другой способ: взять интро и
   петлю из **одной** генерации петли — её начало, до того как тема пошла по
   кругу, и есть интро.
3. **Резать по тактам** (ffmpeg, по известному BPM): такт 4/4 при 100 BPM —
   2.4 с, при 120 BPM — 2.0 с.
   - Петля: место, где тема повторяется без изменений, ровно целыми тактами:
     16 тактов при 100 BPM = 38.4 с, 8 тактов при 120 BPM = 16.0 с. Начало и
     конец — на сильную долю. На концах — 5–10 мс мягкого наложения, не fade:
     конец петли переходит в её же начало.
   - Интро: целыми тактами, и кончается ровно там, где петля начинается.
4. **Формат**: стерео, Ogg Vorbis 44.1 кГц, под именем из таблицы в
   `assets/music3d/modern/`. Громкость — на вкладке «Микшер» меню Escape.

## Чего не писать

Konami, Jackal, названия треков и имена композиторов: SUNO блокирует имена
правообладателей и артистов, а копия чужой мелодии нам и не нужна. Только
жанр, инструменты, настроение, темп.

Темп и тональность в таблице оценены по файлам грубо: перед генерацией
проверьте их на слух. Длины оригинала ложатся на целые такты 4/4 — при
100 BPM 16 тактов дают 38.4 с против оригинальных 38.3 — и на это стоит
опираться: петля должна быть целым числом тактов, иначе шов слышен.
