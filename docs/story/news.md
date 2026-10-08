# Новости после этапов

Черновик текстов для слоя 3 подачи сюжета (`docs/gdd.md` §2.4): новости
после этапа на площадке SUPPLY. Брифинги — `docs/story/briefings.md`, рация
— `docs/story/radio.md`.

**Формат.** После каждого этапа выходят две новости, одна против другой:

- **международная газета «The Evening Dispatch»:** заголовок, подзаголовок
  и цифры из прохождения;
- **радио хунты «Voice of Order»:** пропаганда, которая всё отрицает. Чем
  дальше по кампании, тем истеричнее её тон.

Тексты на английском, как всё в игре.

**Переменные** (в фигурных скобках):

- `{rescued}` — сколько вывезли за этап;
- `{lost}` — сколько погибло вместе с машиной;
- `{total}` — сколько вывезли всего за кампанию;
- `{missing}` — сколько не вывезли за кампанию (только в финале).

---

## После этапа 1 — блокпост на Ашре

> **THE EVENING DISPATCH**
> **MERCENARIES STRIKE AT ASHRA CHECKPOINT**
> *{rescued} hostages flown out. Junta armour column "destroyed to the last tank."*

> **VOICE OF ORDER:** "Minor bandit activity on the Ashra has been contained. Citizens are reminded that rumours are a crime."

## После этапа 2 — древний город

> **THE EVENING DISPATCH**
> **ANCIENT CITY BECOMES BATTLEFIELD**
> *Heritage groups protest. {total} hostages now free. Junta airfield silent.*

> **VOICE OF ORDER:** "The statues of our ancestors were desecrated by foreign criminals. They will be avenged."

## После этапа 3 — порт Кальмир

> **THE EVENING DISPATCH**
> **KALMIR HARBOUR ABLAZE — HOSTAGE SHIP NEVER SAILS**
> *Junta flagship sunk at anchor. {rescued} more brought home.*

> **VOICE OF ORDER:** "The port is closed for scheduled maintenance. The navy remains invincible."

## После этапа 4 — болото и железная дорога

> **THE EVENING DISPATCH**
> **"RATEL" — WHO ARE THE MEN BEHIND THE RESCUE?**
> *Private contractors hired by an insurer, sources say. Junta gunship downed in the swamps.*

> **VOICE OF ORDER:** "There are no mercenaries. There is no gunship. The railway is operating normally."

Здесь газета впервые называет отряд по имени: вокруг R.A.T.E.L. начинается
шум.

## После этапа 5 — минная долина

> **THE EVENING DISPATCH**
> **ROAD TO CAPITAL OPEN**
> *Armour depot gutted. Generals defect. Vassar "has not been seen in public for days."*

> **VOICE OF ORDER:** "General Vassar is in excellent health and personally commands the defence. Stay in your homes."

## После этапа 6 — финал

Новости после этапа здесь не выходят: их место занимает финал на
кадрах-комиксах (`docs/gdd.md` §2.4, слой 4). Последним кадром финала может
стать газета:

> **THE EVENING DISPATCH**
> **MAMBA FALLS**
> *Junta collapses. All {total} hostages accounted for. Insurer confirms: "Contract fulfilled."*

Если вывезли не всех, вместо «All {total} hostages accounted for»:
*«{total} hostages home. {missing} still listed as missing.»*

---

## Варианты по итогам этапа

Подзаголовок газеты меняется в зависимости от того, как прошёл этап:

| Итог | Подзаголовок |
|---|---|
| Никого не потеряли | *"Not one left behind," says contractor.* |
| Потеряли 1–2 | *{rescued} rescued, {lost} killed in the crossfire.* |
| Потеряли больше половины | *Rescue turns bloody: {lost} hostages dead.* |
| Не вывезли никого | *Rescue fails. Junta parades "captured spies."* |

Когда этап прошёл чисто, у радио хунты есть запасная реплика:
*«VOICE OF ORDER: …This broadcast has been interrupted.»* Шипение и тишина
— хунта уже не справляется.

---

## Как это выглядит

- **Газета.** Полоса крупным планом на столе в ангаре SUPPLY, рядом кружка
  и карта. Держится 3–4 секунды или до нажатия кнопки.
- **Радио.** Одна строка внизу экрана, в modern поверх радиошума.
- **Стиль.** В 8-bit полоса превращается в пиксельный экран в духе титров
  NES.

## Открытые вопросы

- Название газеты придумано, но настоящих газет с «Dispatch» в названии
  много. Перед релизом проверить, как и остальные названия.
- Как сочетаются стандартный подзаголовок этапа и подзаголовок по итогам:
  заменяет один другой или идут оба.
- Русская локализация.
