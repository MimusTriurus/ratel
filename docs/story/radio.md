# Рация в бою

Черновик текстов для слоя 2 подачи сюжета (`docs/gdd.md` §2.4): реплика в
одну строку с маленьким портретом в углу HUD; игра не останавливается.
Персонажи — §2.2. Брифинги — `docs/story/briefings.md`.

**Формат.** Реплики короткие, до 30–35 знаков, чтобы влезать в строку HUD.
На каждое событие — несколько вариантов, они чередуются. Тексты на
английском, как всё в игре.

**Кто говорит.** Экипаж того игрока, с которым случилось событие: у P1 —
Badger и Wire («Альфа»), у P2 — Fuse и Echo («Браво»). За вертолёт говорит
Cap. Everly в бою звучит только при потере пленных. В одиночной игре
звучит только «Альфа».

---

## Основные события

### 1. HELP на ангаре

Пленные внутри.

| Альфа | Браво |
|---|---|
| BADGER: Hut's calling. Open it up. | FUSE: Someone's knocking. Let's knock back. |
| WIRE: People in there! | ECHO: Voices in the hangar. |
| BADGER: There's our payday. | FUSE: Door's in the way. Not for long. |

### 2. Подбор пленного

| Альфа | Браво |
|---|---|
| WIRE: Hop in, we're leaving! | ECHO: Got one. Hang on to something. |
| BADGER: You're with us now. | FUSE: Welcome aboard. Mind the launcher. |
| WIRE: Plenty of room. Kind of. | ECHO: One more for the list. |

### 3. Вертолёт на подлёте

Cap, для обоих экипажей.

- CAP: Bird inbound. Keep the LZ clear.
- CAP: Two minutes. Have them ready.
- CAP: I'm on the pad. Don't make me wait.
- CAP: Full house. Heading out. *(взлетает со всеми пленными)*

### 4. Выход босса

Вместе с баннером WARNING.

| Альфа | Браво |
|---|---|
| BADGER: Here it comes. | ECHO: Big contact, dead ahead. |
| WIRE: Oh, that's big. | FUSE: Finally. Something worth a rocket. |
| BADGER: Hold your ground. | ECHO: Signal spike. That's the boss. |

### 5. Смерть напарника

Только в коопе; говорит выживший экипаж.

| Альфа о Браво | Браво об Альфе |
|---|---|
| BADGER: Bravo's down! Cover them! | FUSE: Alpha's hit! Badger! |
| WIRE: Fuse! Echo! Talk to me! | ECHO: Alpha's off the air. |
| BADGER: Hold on, Bravo. | FUSE: I'll get them back. |

## Дополнительные события

### 6. Свой респаун

Вернулся после гибели.

- BADGER: Back in the saddle.
- WIRE: That one hurt.
- FUSE: Spare parts, again.
- ECHO: Back online.

### 7. Апгрейд пусковой

Носильщик оружия; 3-й, 8-й, 13-й, 18-й пленный.

- FUSE: Launcher upgraded. Oh, I like this.
- WIRE: More boom!
- BADGER: Bigger stick. Use it.

### 8. Пленные погибли вместе с машиной

Единственное место, где Everly вступает в бою: потери звучат тяжелее, а
её голос остаётся редким.

- EVERLY: That's a loss, Mr. Callahan.
- EVERLY: Arden Mutual will note that.
- BADGER: …We'll come back for the rest.

### 9. Босс уничтожен

- BADGER: Scratch one.
- FUSE: That's what a rocket's for.
- ECHO: Target down. Area quiet.
- WIRE: Did you see that?!

## Реплики на один раз, по этапу

Звучат один раз за этап, на первом появлении нужного врага или места.

| Этап | Реплика |
|---|---|
| 1 | WIRE: Boats on the river! Watch the banks. |
| 2 | FUSE: Statues are moving. Statues. Are. Moving. |
| 3 | ECHO: Periscope, port side! |
| 4 | WIRE: The jeep hates this mud. I hate this mud. |
| 5 | BADGER: Mines. Follow my tracks exactly. |
| 6 | ECHO: That's the HQ. Vassar's in there. |

---

## Как часто, чтобы не надоедало

- **Одна реплика на экране,** держится около 2,5 секунды.
- **Глобальная пауза** 6–8 секунд между репликами.
- **Своя пауза у каждого события.** Подбор пленного — не чаще раза в 20
  секунд, иначе на втором пленном будет надоедать.
- **Приоритет, если события совпали:** смерть напарника > босс > потеря
  пленных > вертолёт > HELP > апгрейд > подбор > респаун. Реплика с низким
  приоритетом просто пропускается, в очередь не встаёт.
- **Варианты не повторяются подряд:** берётся случайный из тех, что не
  звучали в прошлый раз.
- **Отключаемость.** Рацию можно выключить в настройках, как субтитры.

## Открытые вопросы

- Тайминги и паузы — черновые, подобрать на игре.
- Русская локализация.
- Реплики для устройств (NITRO, MINES, AIRSTRIKE): нужны ли.
