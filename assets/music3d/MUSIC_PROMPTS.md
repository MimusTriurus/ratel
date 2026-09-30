# Музыка 3D-превью: промпты для SUNO

Пять частей музыки из `Level3DAudio.MUSIC` (`src/tools/level3d_audio.gd`), по
папке на режим: `assets/music3d/classic/` — оригинал с NES, не меняется;
`assets/music3d/modern/` — то, что заменяется. Звуковые эффекты описаны в
[SFX_PROMPTS_3D.md](../soundeffects/SFX_PROMPTS_3D.md).

| файл | длина | темп (оценка) | такты | как играет |
|---|---|---|---|---|
| `start.ogg` | 7.2 с | ~100 BPM | 3 | один раз, заставка перед высадкой |
| `stage0_intro.ogg` | 5.6 с | ~100 BPM | 2 | один раз, затем петля этапа |
| `stage0_repeat.ogg` | 37.2 с | ~100 BPM | 16 | петля этапа |
| `boss_intro.ogg` | 7.6 с | ~120 BPM | 4 | один раз, от триггера босса |
| `boss_repeat.ogg` | 16.0 с | ~120 BPM | 8 | петля босса |

Темп и тональность оценены по файлам грубо: перед генерацией проверьте на слух.
Длины ложатся на целые такты 4/4 — при 100 BPM такт 2.4 с, и 16 тактов дают
38.4 с против оригинальных 38.3. Это главное: петля должна быть целым числом
тактов, иначе шов слышен.

## Общие правила

1. **Без имён.** Не пишите в промпте Konami, Jackal и названия треков: SUNO
   блокирует имена правообладателей и артистов, и копия чужой мелодии нам не
   нужна. Только жанр, инструменты, настроение, темп.
2. **Instrumental включён**, структура — метатегами в поле Lyrics: `[Intro]`,
   `[Main Theme]`, `[Loop]`, `[End]`.
3. **BPM и размер — всегда** в Style. SUNO их не гарантирует, но держится
   ближе.
4. **Генерировать длинный трек и резать самим.** Точной длины SUNO не даёт:
   интро и петлю вырезать по границам тактов (ffmpeg, по известному BPM).
5. **Формат:** стерео, затем Ogg Vorbis 44.1 кГц под тем же именем в
   `assets/music3d/modern/`. Громкость — на вкладке «Микшер» меню Escape.

**Общий стиль** — в начало Style каждого трека, чтобы музыка была одной игрой:

> instrumental, modern military action game soundtrack with retro arcade roots,
> punchy live drums and marching snare, driving synth bass, bright square-wave
> lead doubled by brass, orchestral hits, energetic, heroic, clean mix, no
> vocals

---

## `start` — заставка перед высадкой
3 такта, ~7 с, звучит один раз и ведёт в этап.

Style:
> [общий стиль], short heroic fanfare, 100 BPM, 4/4, D minor, brass and snare
> roll, ends on a sustained chord

Lyrics:
```
[Intro]
[Brass fanfare]
[Snare roll]
[Final chord]
[End]
```

## `stage0_intro` + `stage0_repeat` — этап
Интро 2 такта, затем петля 16 тактов. Новые версии уже есть: этот промпт
нужен, чтобы остальные треки звучали с ними в одном стиле, или для замены.

Style:
> [общий стиль], upbeat jungle combat march, 100 BPM, 4/4, C major, steady
> groove for looping, memorable lead melody, call-and-response brass, constant
> energy, no breakdown, no fade

Lyrics:
```
[Intro: drum fill and brass pickup]
[Main Theme A]
[Main Theme B]
[Main Theme A]
[Main Theme B]
```

## `boss_intro` + `boss_repeat` — босс
Интро 4 такта, затем петля 8 тактов.

Style:
> [общий стиль], tense boss battle, 120 BPM, 4/4, A minor, heavy low brass
> ostinato, pounding toms, urgent staccato strings, menacing synth lead,
> relentless, steady loop, no breakdown, no fade

Lyrics:
```
[Intro: rising tension, toms and low brass]
[Battle Theme]
[Battle Theme]
[Battle Theme]
```

---

## Как резать

- **Петля.** Место, где тема повторяется без изменений, ровно по тактам:
  16 тактов при 100 BPM = 38.4 с, 8 тактов при 120 BPM = 16.0 с. Начало и
  конец — на сильную долю.
- **Интро.** Кусок прямо перед петлёй, тоже целыми тактами, чтобы петля
  продолжила его без паузы: `Level3DAudio` играет интро и сразу петлю.
- **Без затуханий.** На концах петли — 5–10 мс мягкого наложения, не fade: её
  конец переходит в её же начало.
