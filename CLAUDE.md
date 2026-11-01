# AURA HEIST — инструкции для Claude Code

Полная документация проекта (концепция, экономика, задачи по фазам):
https://claude.ai/artifact/M3aNm4CUij3KdQhkTXVo5N

## Что это

Roblox-игра: tycoon + extraction. Игрок выносит из общей Meme Zone коллекционных
существ (мемлингов), эвакуируется с ними, ставит их на постаменты своей базы,
и они генерируют Aura. Aura тратится на улучшения. Аудитория 9–14 лет, мобильные в приоритете.

## Автор

Новичок в Roblox Studio. Объясняй простыми словами, по-русски.
После каждой задачи пиши, что именно проверить в Studio и где это найти.

## Стек и инструменты

- Roblox Studio + Rojo 7.7.1 (через Rokit, `rokit.toml`)
- Код пишем ТОЛЬКО в файлах этого репозитория, никогда в Studio
- Файлы `.luau`, комментарии на русском
- Git + GitHub: artjomsamokater-dev/aura-heist (private)

## Структура (default.project.json, создана `rojo init`)

- `src/shared` → `ReplicatedStorage.Shared` (Config, типы, утилиты)
- `src/server` → `ServerScriptService.Server` (`init.server.luau` = точка входа сервера)
- `src/client` → `StarterPlayer.StarterPlayerScripts.Client` (`init.client.luau` = точка входа клиента)

Планируемые сервисы сервера: PlayerData, Economy, Studio, Raid, Spawn,
Extraction, Enemy, Event, Analytics. Защита: RemoteGuard, RateLimiter.

## Жёсткие правила

1. Работаем по ОДНОЙ задаче из документации. Не начинай следующую без явного «дальше» от автора.
2. Сервер — источник истины. Клиент шлёт только ID объекта или действия, никогда суммы, цены, редкость или урон.
3. Все числа баланса — только в `src/shared/Config/*`. В коде сервисов чисел баланса нет.
4. BankedAura меняет только сервис Economy.
5. Любая награда выдаётся ровно один раз (флаг «выдано» до начисления).
6. Carried-мемлинги живут только в памяти сервера, при выходе игрока удаляются.
7. Сохранение — через ProfileStore с блокировкой сессии. Никогда не перезаписывать профиль пустым.
8. Никаких новых систем вне текущей задачи. Идеи — в список для фазы 7.
9. Только оригинальные персонажи, никакой чужой IP.
10. Не трогай `Workspace.Gravity` — эффекты только на персонажей.
11. После задачи: короткий итог + что проверить в Studio + предложи текст коммита. Коммит делает автор или ты по его согласию.
12. После каждой задачи обновляй раздел «Где остановились» в этом файле: что готово и какая задача следующая.
13. Игра на английском. Все тексты, которые видит игрок (подписи, кнопки, имена мемлингов), — только в
    `src/shared/Config/TextConfig.luau`, в коде сервисов строк для игрока нет. Сообщения в Output — по-русски, в коде.
14. Эвакуация с пустыми руками разрешена — это обычный способ вернуться в хаб.
15. Упал из зоны (с 7.5) — не смерть: мягкий возврат на ближайшую точку спавна или вход зоны, всё из рук теряется,
    вылазка продолжается. Упал в море у хаба — возврат на ближайшую точку без потерь (с паркура — на чекпоинт).
16. Потерянный мемлинг (выход, падение) возвращается на свою точку спавна через
    `ZoneConfig.LostRespawnSeconds` (10 с). Вынесенный через эвакуацию в зону не возвращается.
    Смерть в зоне (с 6.0): мемлинги выпадают на месте, `ZoneConfig.LootSeconds` (20 с) их может поднять
    только погибший, потом они возвращаются на точки спавна так же. Пока идёт туториал (с 7.5), смерть в зоне
    ничего не отнимает: новый персонаж появляется у входа той же зоны с тем же в руках.

## Стартовые числа (раздел 3 документации)

| Редкость | Aura/с на витрине | Цена продажи | Скорость при переноске | Шанс в безопасной части | Шанс в опасной части |
| --- | --- | --- | --- | --- | --- |
| Common | 1 | 20 | 16 | 80% | 0% |
| Rare | 4 | 80 | 16 | 20% | 55% |
| Epic | 15 | 300 | 14 | 0% | 38% |
| Legendary | 60 | 1200 | 11 | 0% | 7% |

Улучшения: постамент 4/5/6 = 100/300/900 Aura; слот рюкзака 2/3 = 150/500; хранилище ×2 = 250.
Старт: 3 постамента, 1 слот переноски, хранилище = 120 с дохода, эвакуация 3 с,
ресток зоны 180 с, подбор ≤ 10 студов, эвакуация ≤ 12 студов,
бонус отряда в радиусе 15 студов (с 6.0: +50% к доходу принесённых мемлингов навсегда, вместо +25% к цене
продажи), автосохранение 90 с.

MVP: 8 мемлингов (3 Common, 2 Rare, 2 Epic, 1 Legendary). Имена — оригинальные, придумай смешные.
Сейчас (7.7): Meme Zone 13, Golden Zone 8, Candy Chaos 5, Secret 1; в каждой зоне есть хотя бы один Legendary.

## Идеи для фазы 7 (не делать без отдельной задачи)

- Гонка за Legendary: Legendary несут вдвоём (оба игрока рядом держат его, скорость — общая;
  один отпустил — мемлинг падает). Записано в 6.0, пункт 5.

## Как добавить новую зону

Зона целиком описывается конфигами; код сервисов трогать не нужно (кроме новых моделей). `<Id>` — короткий Id зоны
латиницей (как `Meme`, `Golden`, `Candy`), один и тот же во всех файлах.

1. `src/shared/Config/ZoneConfig.luau`: добавить `<Id>` в конец `ZoneOrder` и запись в `Zones` —
   `SpawnChances` (Safe и Danger, сумма в каждой = 100; Legendary только в Danger — проверяет тест), `AccessCost` (nil — бесплатно; число — ворота у портала),
   `Tutorial = false`.
2. `src/shared/Config/MemelingConfig.luau`: мемлинги с `Zone = "<Id>"` и `IncomeMultiplier` (константа зоны, как
   `CANDY_INCOME`). Обязательно хотя бы один Legendary (тест и предупреждение при старте); на каждую редкость с шансом
   > 0 нужен хотя бы один мемлинг.
3. `src/server/Visual/MemelingBuilders.luau` — строитель `Builders.<MemelingId>` на каждого нового мемлинга
   (стиль D: глаза разного размера с бликом, румянец, глянец, тень, деталь сзади, одна яркая черта).
4. `src/shared/Config/StyleConfig.luau`: `Characters.<MemelingId>` — цвета мемлингов; `ZoneThemes.<Id>` — тема зоны
   через `themeFrom({...})` (полы, холмы, грибы, край, облака, великаны, туман и свет опасной части);
   `PortalThemes.<Id>` — цвета воронки и кольца портала.
5. `src/shared/Config/TextConfig.luau`: `ZoneNames.<Id>` (вывеска портала, указатели, пол зоны),
   `PortalInfos.<Id>` (табличка у портала), `MemelingNames.<MemelingId>`.
6. `src/shared/Config/MapConfig.luau`:
   - `Zones.<Id> = zoneLayout(Vector3.new(X, ZONE_FLOOR_Y + 1, Z), edgeKinds?)` — центр верха пола; зоны держать
     в 500 студах друг от друга и от хаба; `edgeKinds` — великаны по краю (`Rocks`, `Crystal`, `Can`, `Popsicle`,
     `Donut`, `Lollipop`; новые виды — в `server/Visual/IslandEdges`);
   - `PortalRotations.<Id>` — угол портала в хабе (+90 — на 90° против часовой: 90° → 0°). Заняты: 90° Meme,
     270° Golden, 0° Candy; 180° — киоск, кружка и вход в паркур. Для четвёртого портала нужна перестановка хаба
     (BEST HAUL, Props, Decor.Bushes — проверить, что не налезают на подиум шириной 26);
   - `Portal.Statues.Ids.<Id>` — 4 мемлинга этой зоны для статуй у портала.
7. `src/shared/Config/HazardConfig.luau`: `Zones.<Id>` — планки (`Lasers`) и плиты (`Plates`) в опасной части.
8. `src/shared/Config/EnemyConfig.luau`: `Zones.<Id>` — `Kind` (Id из `Kinds`), `Count`, `SpawnPoints`. Новый вид
   врага — запись в `Kinds` (скорость, урон, замах, размер), `EnemyBuilders.<Kind>` в MemelingBuilders и
   `StyleConfig.Characters.<Kind>` (поле `Body` обязательно).
9. Тесты: в `tests/RarityRoll.spec.luau` — тест зоны (число мемлингов по редкостям, доход, шансы, цена входа);
   в `tests/BountyRule.spec.luau` — общее число кандидатов. Потом `scripts/check.ps1`.

Что подхватится само: портал с воротами и кнопкой Unlock (ZoneAccess, профиль `zoneAccess`), стрелка на указателях
хаба, спавн и ресток, эвакуация (EXTRACT и SLOW EXIT), враги, ловушки, холмы и тропинки, край острова и облака,
падение из зоны, BOUNTY, экран результата, /memelings. Колесо сыра и туториал — только в `ZoneConfig.FirstZone`.

## Где остановились

Задачи 0.1–4.4 и 5.1–5.7 готовы:
- Фаза 0 (0.1–0.6): Studio, VS Code, Rojo, rojo init, связь со Studio, GitHub,
  Test place «AURA HEIST TEST» (private), Config-модули.
- 1.1: серый прототип карты из кода (хаб, 8 участков с постаментами, портал,
  зона на высоте Y = 300), сервисы MapBuilder, Studio, Raid (InHub / InRaid).
- 1.2: сервис Spawn ставит Common-мемлингов (серые кубы с именем) на точки спавна из MapConfig.
- 1.3: подбор через ProximityPrompt, все проверки в Raid на сервере; Carried — в памяти сервера,
  куб приварен к персонажу, при смерти / новом персонаже / выходе теряется.
  Security/RemoteGuard и Security/RateLimiter (минимально), числа — в SecurityConfig.
- 1.4: сервис Extraction — площадка эвакуации в зоне, удержание 3 с, отмена при уходе или смерти,
  награда ровно один раз (флаг Rewarded у вылазки в Raid). После успеха — хаб, InHub,
  мемлинги в списке витрины в Studio (только память сервера). Невидимые стены по краям зоны
  и страховка: игрок InRaid ниже пола зоны → как после смерти, новый персонаж в хабе.
- 1.5: вынесенные мемлинги встают на постаменты участка (куб с именем и «+N/s»), лишние — «в запас».
  Постамент копит Aura (доход редкости × время, максимум Storage.StartSeconds секунд дохода),
  над ним видно накопленное. Collect — ProximityPrompt, проверка на сервере (владелец, дистанция,
  rate limit), начисление только через новый сервис Economy (BankedAura в памяти сервера).
  Игроку числа показываются округлёнными вниз (shared/Util/FormatNumber).
- 1.6: HUD на клиенте (client/Controllers/HudController): слева сверху золотая карточка
  «SAFE AT BASE» (BankedAura) и синяя «In hands: N/M · LOST IF YOU DIE». В InRaid — маркер
  «EXTRACT» над площадкой (виден сквозь стены) и стрелка у края экрана, если площадка за кадром.
  Клиент только читает атрибуты игрока (BankedAura, CarriedCount, CarrySlots, RaidState).
- 1.7 (визуальный проход, вне плана): весь вид — в `src/shared/Config/StyleConfig.luau`
  (палитра, материалы, частицы, свет, шрифт, цвета HUD). Яркие цвета: свой у хаба, каждого участка
  и зоны; у зоны безопасная половина (бирюза) и опасная (красная, восточнее MapConfig.Zone.DangerFromX).
  Неон + частицы у портала и EXTRACT. Мемлинги — круглое тело цвета редкости + два глаза,
  у Epic/Legendary свет и искры. Свет (Atmosphere, Bloom, ColorCorrection, Sky) — сервис LightingSetup.
- 1.7b (правки визуала по скриншотам): HUD ниже панели Roblox и окна чата; свет без пересвета;
  без силового поля при появлении; пол зоны тёмный с узором плиткой, опасная часть тёмно-красная;
  имена мемлингов видны только вблизи (35 студов), имя владельца — на самой табличке (SurfaceGui),
  маркер EXTRACT прячется вблизи; мемлинги в 2 раза крупнее, Common с оранжевым контуром.
  Размеры мемлинга и подписей переехали из MapConfig в StyleConfig.
- 2.1: сохранение. ProfileStore (loleris, Apache 2.0) вшит в `src/server/Packages/ProfileStore.luau`
  с коммита 45c9847, лицензия — `licenses/ProfileStore-LICENSE.txt`; check.ps1 его не проверяет.
  Сервис PlayerData: профиль `Player_<UserId>` в DataStore `PlayerProfiles`, блокировка сессии,
  автосейв по EconomyConfig.AutosaveSeconds, сохранение при выходе и BindToClose; не загрузился —
  кик с текстом из TextConfig. Схема (schemaVersion 1): bankedAura, showcase {pedestal, memelingId,
  lastCollect}, reserve {memelingId}, upgrades {pedestals, carrySlots, storage}, stats (сейчас схема 3, см. 4.3 и 5.6).
  Economy и Studio работают с данными профиля; накопление постамента — shared/Util/PedestalMath
  (от lastCollect, не больше лимита — так же считается офлайн-доход). В портал нельзя без профиля.
- 2.2: улучшения. На участке 6 мест под постаменты (некупленные — полупрозрачные), ряд золотых
  кнопок Pedestal / Backpack / Storage с ценой следующего уровня. Покупка: ProximityPrompt «Buy»
  с удержанием → сервер проверяет владельца, дистанцию, rate limit, уровень и цену (shared/Util/UpgradeValues
  из UpgradeConfig), списывает только через Economy.TrySpend; после покупки 1 с паузы, чтобы
  двойной клик не купил два уровня. Новый постамент сразу забирает мемлинга из запаса.
- 2.3: продажа. На постаменте вторая кнопка «Sell» (F, удержание 0,6 с): мемлинг уходит из профиля,
  потом начисляется цена из MemelingConfig.Rarities[].SellPrice и накопленная на постаменте Aura;
  освободившийся постамент занимает мемлинг из запаса. Синяя площадка «Reserve: N» на участке
  продаёт самого старого мемлинга из запаса. Общие проверки действий на участке — checkPlotAction в Studio.
- 2.4: офлайн-доход проверен автотестами `tests/PedestalMath.spec.luau` (консольный luau 0.744.0 через Rokit):
  10 минут и сутки офлайн — не больше лимита хранилища (Common 120, Legendary 7200, ×2 → 240),
  время «назад» не даёт минус, дробный остаток после сбора копится дальше, повторный сбор — ноль.
- 2.5: защита. RemoteEvent в игре нет; все кнопки (подбор, Collect, Buy, Sell ×2) подключены через
  `RemoteGuard.ConnectPrompt` — общий лимит на любые действия игрока (AnyAction), «жив», дистанция до
  кнопки, предупреждение о спаме в Output раз в SpamWarnSeconds. Второй слой — в обработчиках
  (свой лимит, участок, состояние, цена, «уже выдано»). Портал — пауза + состояние; эвакуацию считает
  сервер по позиции. Тесты `tests/RateLimiter.spec.luau`: спам 100 запросов → проходит только лимит.
  Новые кнопки и будущие RemoteEvent подключать только через RemoteGuard.
- 3.1: все 4 редкости в зоне. Точка спавна → часть зоны (Safe/Danger по MapConfig.Zone.DangerFromX) →
  редкость по ZoneConfig.SpawnChances → случайный мемлинг этой редкости. Выбор — чистые функции
  shared/Util/RarityRoll; тест `tests/RarityRoll.spec.luau` — 10 000 спавнов, допуск ±1,5 п.п.
- 3.2: замедление. Скорость = минимум CarrySpeed редкостей в руках, не быстрее обычной
  (shared/Util/CarrySpeed + тест). Обычная скорость запоминается на Humanoid (атрибут BaseWalkSpeed);
  Raid пересчитывает скорость при подборе, потере (смерть, выход, падение) и эвакуации.
- 3.3: рюкзак. Лимит в зоне — купленный уровень (UpgradeValues.CarrySlots), HUD читает CarrySlots /
  CarriedCount. Раскладка в StyleConfig.Memeling.CarrySlotOffsets: первый перед грудью,
  второй и третий стопкой на голове (не закрывают обзор), дальше — выше по стопке.
- 3.4: ловушки в опасной части (HazardConfig: урон, тайминги, места; цвета — StyleConfig.Hazards).
  Лазерная планка ездит по дорожке с рельсами и мигает у концов перед проездом; 4 плиты-«хлопушки»
  горят оранжевым 1 с перед ударом и бьют по очереди. Когда и где — shared/Util/HazardMath по времени
  сервера (+ тест); урон считает сервис Hazards раз в 0,1 с геометрией (без Touched), для планки —
  по всей пройденной полосе. Урон наносит только сервис Damage (запоминает источник). Картинку
  рисует client/Controllers/HazardController по тем же формулам. Урон 25 / 35 — с одного раза не умирают.
- 3.5: враг Grumblob (оригинальный: ворчливый ядовито-зелёный желейный шар с сердитыми бровями).
  EnemyConfig.Chaser: Count (сейчас 3, мест до 6), скорость 13 (игрок 16, с Legendary 11), радиусы,
  урон 20 с перезарядкой 1,5 с. Сервис Enemy: Humanoid + PathfindingService (путь раз в 0,75 с,
  сквозь стены нет), только внутри опасной части (shared/Util/EnemyMath + тест), спит без игроков рядом
  («Zzz»), касание — расстояние раз в 0,1 с, раз в 30 с пишет в Output свою нагрузку.
- 3.6: смерть. Любая смерть (ловушка, враг, Reset, падение из зоны) → Raid.onDeath: всё из рук
  теряется (вернётся на точки через 10 с), вылазка закрыта (награду не выдать), эвакуация отменяется
  (нужен живой персонаж), витрина и Aura не трогаются, stats.deaths в профиле +1, в Output — причина
  (атрибут LastDamageSource от сервиса Damage).
- 1.8 (арт-дирекшн, вне плана; механика не менялась): StyleConfig.Palette — 5 цветов (крем, коралл,
  солнце, мята, слива) + оттенки, других цветов в игре нет; один материал SmoothPlastic, Neon только
  у светящегося. 8 мемлингов — у каждого свой силуэт из примитивов (в 5.4 заменены на MemelingBuilders:
  тост-котик, яйцо-рыцарь, батон, лапша-ниндзя, носок-пират, огурец-диско, профессор, сонный динозавр);
  редкость — цвет тела и свечение. Участки в одном стиле (кремовый пол, арка с табличкой, ограда,
  коврик), отличаются акцентом; постаменты и кнопки круглые (видимый Look поверх невидимой логической
  детали). Хаб: дорожка к порталу, рамка и столб света, игрок появляется лицом к порталу. Зона: ворота
  у входа и в опасную часть, дорожка к EXTRACT, столб света над EXTRACT, грибы и кристаллы-ориентиры;
  в зону игрок попадает лицом к EXTRACT. Свет: ShadowMap (default.project.json), солнце под углом,
  мягкая цветокоррекция. HUD: скруглённые панели с обводкой и тенью, иконки, крупное главное число.
- 4.1 (вне очереди): ресток. При старте и каждые ZoneConfig.RestockSeconds (сейчас 90 для теста,
  по документации 180) все свободные точки получают новых мемлингов по шансам своей части зоны.
  Журнал точек shared/Util/SpawnPointBook: занятые и ждущие возврата потерянного точки не трогаются;
  подобранный освобождает точку, а если её уже занял ресток — потерянный не возвращается (без дублей,
  тест `tests/SpawnPointBook.spec.luau`). Время следующего рестока — атрибут NextRestockAt на
  ReplicatedStorage; таймер «🔄 New memelings in m:ss» вверху по центру, у всех одинаковый.
- 4.2 (вне очереди): объявление о редком спавне. Если при спавне или рестоке появился мемлинг
  из ZoneConfig.AnnounceRarities (Epic, Legendary) — одно объявление на спавн, только про самого
  редкого (RarityRoll.Rarest + тест). Сервис Announcer: RemoteEvent ReplicatedStorage.Remotes.Announcement
  только сервер → клиенты (сервер его не слушает), шлёт Id редкости и части зоны. Клиент
  (AnnouncementController) показывает плашку цвета редкости вверху на 3,5 с; тексты — TextConfig.
  Имена всех RemoteEvent — src/shared/Remotes.luau. Вернувшийся потерянный мемлинг не объявляется.
- 4.3: бонус отряда. Два разных игрока завершили эвакуацию не дальше EconomyConfig.SquadBonus.Radius
  (15) друг от друга с разницей не больше WindowSeconds (5) → у принесённых обоими мемлингов флаг
  squadBonus в профиле, цена продажи +SellBonusPercent (25%, вниз). Правило — shared/Util/SquadRule
  (+ тест «рядом и вовремя»). Каждая эвакуация получает бонус один раз (флаг Bonus до выдачи);
  stats.squadBonuses. Плашка «👥 SQUAD BONUS!» обоим (Remotes.SquadBonus, сервер → игрок), на мемлинге
  отметка «👥 +25%». Схема профиля 2: reserve — записи {memelingId, squadBonus}; старые строки
  переводятся при загрузке (PlayerData.migrate).
- 4.4: событие Giant Object — «🧀 MEGA CHEESE WHEEL» (оригинальное колесо сыра с дырками и рожицей).
  EventConfig.GiantObject: пауза 25–40 с (случайно), предупреждение 2 с, скорость, урон 30 с перезарядкой,
  маршрут по опасной части. Сервис Event: не запускается без игроков в зоне; маршрут мигает полосой
  на полу и звучит сигнал; колесо anchored, катится через Tween (Tween двигает число 0→1, по нему
  позиция и поворот) и исчезает в конце. Урон — сервер раз в 0,1 с по пересечению, без Touched.
  Маршрут и время — shared/Util/GiantRoute (+ тест).
- Иконки вместо эмодзи: client/Ui/Icons рисует их из рамок (Aura, рюкзак, часы, отряд);
  check.ps1 не пропускает эмодзи в .luau (символы ▲ ▼ можно).
- 5.1: туториал из 6 шагов (shared/Util/TutorialSteps + тест): портал → подобрать → EXTRACT →
  подойти к постаменту → Collect → купить улучшение. Шаг засчитывает сервис Tutorial только по
  реальному действию (Tutorial.Notify из Raid, Extraction, Studio; «у постамента» — проверка сервера).
  Прогресс — data.tutorial {step, completed}; кто уже эвакуировался — туториал пройден. Клиент
  (TutorialController) по атрибуту TutorialStep рисует стрелку над целью, стрелку у края экрана и
  подсказку внизу с кнопкой Skip (RemoteEvent TutorialSkip через RemoteGuard.ConnectRemote).
  Положение участков для сервера и клиента — shared/Util/PlotLayout.
- 5.2: экран результата эвакуации (client/Controllers/ResultController): «EXTRACTED!», по строке на
  мемлинга (кружок цвета редкости, имя · редкость · +N/s), время вылазки, бонус отряда, кнопка
  «Back to base»; сам закрывается через StyleConfig.Hud.ResultSeconds (6 с). Сервер шлёт только Id,
  секунды и флаг (Remotes.ExtractionResult, сервер → игрок); время вылазки — Raid (run.StartedAt).
  Бонус, пришедший позже (первый в отряде), дорисовывается на открытом экране.
- 5.3: мобильное управление. PromptController переводит все ProximityPrompt в стиль Custom и рисует
  крупную кнопку в мире (действие, предмет, полоска удержания; на телефоне ×1,25); палец/мышь → 
  InputHoldBegin/End, клавиши E/F как раньше — проверки сервера не менялись. ActionButtonsController:
  круглые Drop и Extract справа над кнопкой прыжка (место — от реальной JumpButton), только когда нужны.
  Drop (G) — Remotes.DropCarried через RemoteGuard, Raid отпускает последнего мемлинга (вернётся на свою
  точку, как потерянный); Extract — персонаж сам идёт на площадку, эвакуацию засчитывает сервер.
- 5.5: аналитика воронки — сервис Analytics, единственное место с AnalyticsService. LogCustomEvent:
  FirstJoin (первая сессия профиля), TutorialStep (+ LogOnboardingFunnelStepEvent; пропуск — шаг 0),
  RaidStarted, MemelingPicked (редкость), ExtractionSuccess (число, самая редкая, Squad/Solo),
  PlayerDied (сколько потерял, причина), UpgradePurchased (id, уровень, цена), MemelingSold (редкость,
  цена), SessionEnded (секунды). Детали — CustomField01..03. Каждое событие пишется в Output «[Analytics] …»;
  в дашборд события идут только с живых серверов, не из Studio.
- 5.6 (вне плана): прогрессия. UpgradeConfig: постаменты до 10, рюкзак до 5, хранилище до ×4
  (первые цены из документации, дальше ×≈2,5). Постаменты на участке — 2 ряда по 5 (MapConfig),
  MapBuilder при старте проверяет, что мест хватает и ничего не налезает. Rebirth (EconomyConfig.Rebirth,
  формулы — shared/Util/RebirthMath + тест): когда куплено всё и есть цена, удержание 2 с на сливовой
  площадке → вся Aura сгорает (Economy.TrySpendAll), улучшения в 0, витрина и запас остаются
  (занятые постаменты не закрываются), доход постаментов +25% за каждый rebirth навсегда, цена
  следующего ×2, «REBIRTH N» над головой. Профиль — схема 3, поле rebirths.
  Отладка: /aura <число> в чате — только в Studio (сервис DebugCommands).
- 5.7 (вне плана): зона 224 × 224 (было 160 × 160, площадь ×≈2), на Y = 300. Граница опасной части
  X = 14 (доли частей прежние), вход X = −90, EXTRACT X = 90; ворота, дорожка, грибы и кристаллы — под
  новый размер. 20 точек спавна (12 safe, 8 danger), разнесены. Лазеров теперь список HazardConfig.Lasers
  (2: вдоль Z и вдоль X; время проезда — атрибут планки), плит 6, маршрут Giant Object — по новой карте.
  Враги: Count = 5, места по всей опасной части, в круг EnemyConfig.Chaser.ExtractionKeepOut (20) вокруг
  EXTRACT не заходят (EnemyMath.PushOutOfCircle + тест). У врагов подписи нет. Имена мемлингов вдвое
  меньше, видны ближе 25 студов; в руках мемлинг уменьшен до 0,6 (MapBuilder.ScaleMemeling), подпись скрыта.
- 5.4: модели мемлингов в стиле «D · Микс» (механика не менялась). src/server/Visual: MemelingKit (общие приёмы:
  глаза разного размера с бликом, румянец, глянец сверху-слева, гранёная тень справа, кольцо редкости) и
  MemelingBuilders (функция-строитель на каждого из 8 и BuildEnemy для Grumblob). Ядро — невидимый Part
  (StyleConfig.Memeling.CoreSize), детали приварены, ≤ ~25 штук. Тело — цвет персонажа (StyleConfig.Characters,
  исключение из палитры), редкость — кольцо (Rarities[].Color); PointLight и искры только у Epic и Legendary.
  Своя модель из ServerStorage.MemelingModels[Id] (PrimaryPart = Part, Pivot = центр, лицо в −Z) важнее кода.
  Контур #2A1638 ставит клиент (client/Controllers/OutlineController) по тегу Outlined: в руках → свои постаменты
  (атрибут OwnerUserId) → ближние; не больше StyleConfig.Outline.MaxCount (25, лимит Roblox 31).
  Отладка в Studio: /memelings — ряд из всех 8 перед игроком (повтор убирает).
- 5.4b (правки моделей, механика не менялась): контура не было, потому что Highlight висел на невидимом ядре.
  Теперь видимые детали лежат в Model StyleConfig.Outline.Figure («Figure») внутри ядра, Highlight — на ней
  (Adornee = Model, Occluded, без заливки); клиент пишет в Output «[Outline] Активных контуров: N».
  Размер по редкости — StyleConfig.Memeling.RarityScale (Common 1, Rare 1,1, Epic 1,2, Legendary 1,4): мемлинг
  растёт вверх (низ на месте), подписи выше, дальность подбора — от края (shared/Util/MemelingSize + тест),
  в руках стопка считается по реальной высоте (CarryFront / CarryHeadTop / CarryStackGap вместо CarrySlotOffsets).
  Legendary без пересвета: кольцо не неон, мягкий полупрозрачный ореол (Halo), свет слабее. Переделаны
  Snoozeasaurus (голова с мордой, дуги-глаза, корона, шипы по спине, хвост), Bonk (короткий стальной боёк,
  крупное лицо, усы), Pickle (две руки вверх, очки-звёзды, крупный диско-шар на нитке над рукой), Grumbloaf
  (глаза по центру). Сзади у каждого деталь: хвост, плащ, наклейка, пупырышки, обмотка, шипы.
- 6.0 (правки по критике перед тестом, отдельный коммит на пункт):
  1) Бонус отряда больше не меняет цену продажи: принесённые в отряде навсегда дают +50% дохода на постаменте
     (EconomyConfig.SquadBonus.IncomeBonusPercent, SquadRule.IncomeMultiplier, Studio.getRate).
  2) Вторая точка эвакуации у входа (MapConfig.Zone.SideExtractionPosition, жёлтая, «SLOW EXIT»): 8 с,
     радиус 7, только без Epic/Legendary в руках (ZoneConfig.SideEvacuation, shared/Util/ExtractionRule + тест).
     Extraction ведёт список точек; Raid выставляет атрибут SideExtractionBlocked; маркер HUD и кнопка Extract
     ведут к ближайшей доступной (client/Util/ExtractTarget).
  3) Смерть в зоне — лут на месте смерти (Spawn.DropAsLoot, состояние Dropped): ZoneConfig.LootSeconds (20) поднять
     может только погибший, потом — на точку спавна (Spawn.Lose). Клиент владельца: золотая подсветка сквозь
     стены (OutlineController) и «YOUR LOOT 0:15» (LootController); у остальных кнопка подбора скрыта.
     Падение из зоны и выход — всё теряется, как раньше.
  4) Grumblob: скорость 10 (тест: убегает даже с Legendary; без лута отрыв 6 студов/с).
  5) Идея «Legendary несут вдвоём» — в разделе «Идеи для фазы 7».
  6) HUD: рюкзак и таймер рестока только в зоне; под иконкой Aura плашка «AURA»; карточки 49 px вместо 74;
     Skip туториала через 10 с (StyleConfig.Hud.TutorialSkipDelaySeconds); объявления у самого верха, компактнее.
  7) Портал: невидимая деталь-вход + сливовая неоновая воронка с тёмной серединой, вихрь искр к центру,
     кольцо из 12 бусин (вращает client/Controllers/PortalController), гул (Sound, StyleConfig.Portal.Hum —
     встроенный звук ветра, замедленный). Бежевая дорожка от точки появления к порталу убрана (декор без функции).
  8) Свободный участок подписан «Empty plot».
- 6.1 (визуальный проход, отдельный коммит на пункт):
  1) Смысл цвета (шапка StyleConfig): Sun (жёлтый) — только интерактивное (кнопки, рамка портала, SLOW EXIT,
     запас, Rebirth, ободок постамента, кнопки HUD); Coral + Ink — только опасность; мята и светлая слива — фон;
     цвета редкостей сдвинуты, чтобы не совпадать с палитрой (Rare 3D9BFF, Epic D63CFF, Legendary FF8A1F).
     Колесо сыра — цвет предмета, но красные бока и красная подсветка маршрута.
  2) Фон: Baseplate растянут до 2048 и стал лавандовым «морем» (StyleConfig.Background, не Terrain — дешевле
     на телефоне, по нему можно ходить); пена по краю хаба и участков; мостики хаб → участки; 4 парящих
     острова (MapConfig.Background.Islands). Небо стандартное, розово-фиолетовый тон — Atmosphere + ColorCorrection.
  3) Участки ближе: MapConfig.Plots.RingRadius 90. На площади хаба — витрина «BEST HAUL» (сервис BestHaul:
     самый редкий мемлинг, вынесенный на сервере за сессию, + ник; заменяется только более редким) и
     гигантские кружка, кусок сыра, пончик (MapConfig.Hub.Props).
  4) Опасная часть: пол темнее, красно-чёрная лента по границе, красные столбы ворот с чёрными кольцами,
     череп из деталей под балкой; туман (частицы) и фиолетово-красный свет (PointLight) только над ней,
     светящиеся фиолетовые плиты-узор (декор). Общий Lighting не менялся.
  5) EXTRACT: сервер ставит атрибуты ExtractHoldStart / ExtractHoldSeconds, клиент (ExtractFxController)
     рисует круг из сегментов под ногами, писк ускоряется, в конце вспышка и конфетти; столб света 150 студов.
  6) Grumblob: замах EnemyConfig.Chaser.WindupSeconds (0,5 с) с радиуса WindupRadius — атрибут WindupUntil,
     клиент (HitFxController) рисует растущий красный шар; урон — только если игрок ещё в HitRadius.
     Колесо сыра: Remotes.Knockback (сервер → игрок, направление от сервера), клиент толкает персонажа
     (EventConfig.GiantObject: KnockbackSpeed / KnockbackUp / KnockbackSeconds), урон прежний.
  7) Плиты-хлопушки: чёрные трещины и кайма (SurfaceGui на верхней грани, StyleConfig.Hazards.SlamCracks).
- После 6.1 — портал: вход и по касанию, и по проверке позиции раз в MapConfig.Portal.CheckSeconds
  (shared/Util/PortalRule + тест); каждое касание — строка «[Portal] ник (касание/позиция): пустили / не пустили — причина»
  (одна причина не чаще раза в 2 с); при старте Raid проверяет триггер («[Portal] Триггер портала в порядке»).
  init.server запускает сервисы через xpcall: упавший сервис пишет «[Server] Сервис X упал…», следующие запускаются.
- Море: невидимые стены (MapBuilder.buildSeaWalls, MapConfig.Background.SeaWall*) по краю хаба и участков
  с проходами к мостикам и вдоль мостиков — уйти по морю нельзя.
- 6.2 (наполнить хаб, механика не менялась; коммит на пункт):
  1) Площадь круглая, MapConfig.Hub.Radius 50; участки на RingRadius 80, кольцо повёрнуто на
     Plots.AngleOffsetDegrees 22,5° (портал на 90° смотрит в промежуток); мостики ~8 студов. Пол — шахматная
     плитка двух оттенков мяты, кремовый круг у фонтана, дорожки к порталу, витрине и каждому мостику.
     Точка появления сдвинута на (0, 1.5, 14) — в центре фонтан. Места на площади — углы/радиусы (polar в MapConfig).
  2) Декор — server/Visual/HubDecor (MapConfig.Hub.Decor, StyleConfig.Hub.Decor): фонтан с брызгами, деревья,
     кусты-облачка, клумбы, фонари, скамейки, указатели MEME ZONE / BEST HAUL, гиганты телефон, банан,
     уточка, наушники (Props). Мелочь без теней и без столкновений.
  3) 5 декоративных мемлингов (MapConfig.Hub.Wanderers) ставит сервер, бродят/прыгают/машут на клиенте
     (client/Controllers/WandererController); гирлянды флажков над 4 дорожками.
  4) Кнопки участка — ряд по 9 студов + Rebirth на коврике; подписи «иконка + цена» (MapBuilder.addIconLabel,
     иконки перенесены в shared/Ui/Icons: + Pedestal, Box, Star); подробности — в тексте кнопки «Buy».
  5) Свободный участок: табличка «Join to claim!» и цветы (HubDecor.BuildClaimDecor), кнопки скрыты и
     выключены; MapBuilder.SetPlotClaimed переключает вид (Studio при занятии/освобождении).
  6) Портал: подиум из 3 ступеней с жёлтой каймой, колонны с крутящимися кристаллами, вывеска «MEME ZONE»
     (покачивается), 4 тусклые статуи-мемлинга, пульсирующая стрелка на полу, табличка-подсказка
     (MapConfig.Portal.Podium/Columns/Sign/Statues/Arrow/InfoSign); анимацию делает PortalController.
     Триггер не сдвинут; подпись-Billboard над порталом убрана (её заменила вывеска).
- 7.1 (агрессия врагов): почему стояли — по логике 3.5 враг спал, пока игрок дальше WakeRadius (90; от входа
  до врагов > 120), а проснувшись без цели шёл «домой» и стоял. Теперь: WakeRadius 200, без цели — патруль
  (EnemyConfig.PatrolRadius / PatrolWalkSpeed / PatrolPauseSeconds), охрана — Raid.OnPickup → враги ближе
  AggroRadius (45) гонятся, «!» на AlertSeconds и звук (StyleConfig.EnemyAlert); погоня до LeashRadius (70),
  безопасной части или EXTRACT (EnemyMath.ChaseBlock / ShouldAggro / PatrolPoint + тесты). Output раз в
  StatusLogSeconds (5): «[Enemy] Grumblob1: патруль — …», «бросил погоню …: причина».
- 7.2 (вторая зона GOLDEN ZONE, три коммита):
  1) Рефактор: зоны — конфиг. ZoneConfig.ZoneOrder / Zones[Id] (шансы, AccessCost, Tutorial), геометрия —
     MapConfig.Zones[Id] (одна раскладка zoneLayout от центра верха пола), ловушки — HazardConfig.Zones[Id],
     враги — EnemyConfig.Zones[Id], мемлинги — MemelingConfig.Memelings[].Zone (+ IncomeMultiplier).
     MapBuilder строит Workspace.RaidZone_<Id>, всё по Id (GetZoneFolder / GetZoneEntryCFrame / GetExtractionPad /
     GetPortal(zoneId)); Spawn — свой журнал точек на зону, ресток всех зон одним таймером; Raid помнит зону
     (Raid.GetZone, атрибут RaidZone для клиента), порталы по зонам, PortalRule.noAccess; Extraction — точки
     своей зоны; Enemy/Hazards — по зонам; колесо сыра и туториал — только стартовая зона (ZoneConfig.FirstZone).
     Чистые правила — shared/Util/ZoneRule (+ тесты: Meme Zone как раньше). Профиль — схема 4, zoneAccess.
  2) Golden Zone на X = −500 (Y = 300), тема StyleConfig.ZoneThemes.Golden, 3 планки и 8 плит, 7 врагов;
     шансы без Common (Safe 70/30 Rare/Epic, Danger 40/45/15). 5 мемлингов только там, доход ×5
     (MemelingConfig.GoldenIncomeMultiplier; Studio.getRate и экран результата): BubbleTeaBandit, CactusCrooner
     (Rare), PizzaPigeon, RoboDuck (Epic), KingWaffleton (Legendary) — строители в MemelingBuilders.
  3) Портал Golden в хабе на 270°: MapBuilder.buildPortal(zoneId) строит портал стартовой зоны в модели
     Hub.Portal_<Id> и поворачивает (MapConfig.PortalRotations); цвета — StyleConfig.PortalThemes, статуи —
     мемлинги своей зоны. Перед платным порталом — золотые ворота (MapConfig.Portal.Gate) с замком «иконка + цена».
     Сервис ZoneAccess: «Unlock» удержание 1 с → проверки на сервере → Economy.TrySpend(25 000) → zoneAccess[Id]
     в профиль навсегда, атрибут ZoneAccess_<Id>; клиент (PortalController) прячет ворота у купивших.
     На указателях хаба — стрелки к обоим порталам; фонари и кусты отодвинуты от обоих подиумов.
- 7.3 (секретный паркур): узкий проход в невидимой стене у моря за гигантской кружкой (MapConfig.Obby.EntryAngle 180,
  GapHalfWidth), рядом знак «?» (единственная подсказка). 16 платформ (MapConfig.Obby.Platforms): спираль вверх
  между участками выше их стен, потом над морем к тайному острову; 2 чекпоинта. Детали — server/Visual/ObbyBuilder,
  логика — сервис SecretObby: корень ниже SeaCatchY (3,5) = упал в море → на последний чекпоинт (не смерть);
  остров → SecretRule (+ тест): первый раз Error404Kitten сразу на витрину (Studio.AddToShowcase, флаг
  secret.found до выдачи), потом EconomyConfig.SecretObby.DailyAura раз в сутки; жёлтая площадка возврата в хаб.
  Новая редкость Secret (MemelingConfig: доход Legendary ×2; в зонах не появляется — Zone = nil), кольцо
  переливается (StyleConfig.Rainbow, тег — client/Controllers/RainbowController). Профиль — схема 5, поле secret.
- 7.4 (магазин косметики за Aura, только внешний вид): ShopConfig — 6 категорий (CategoryOrder, MaxEquipped)
  и 35 вещей с ценами 5 000 – 2 000 000: 12 баннеров (до 3 флагштоков выше арки), декор студии (дорожка,
  фонтанчик, неон-вывеска с ником, статуя самого редкого мемлинга витрины, фейерверк раз в минуту),
  4 скина постаментов, 4 следа, 4 ауры, 6 титулов. Названия — TextConfig.ShopItemNames, вид —
  StyleConfig.Cosmetics / CosmeticsLayout / ShopUi, места на участке — MapConfig.Plots.Cosmetics.
  Сервис Shop: Remotes.ShopBuy / ShopEquip (клиент шлёт только Id — RemoteGuard.ConnectRemoteId), ShopRule
  (+ тест) — CanBuy / ToggleEquip, списание только Economy.TrySpend, профиль — схема 6, cosmetics {owned,
  equipped}; Rebirth не трогает. Картинка — server/Visual/CosmeticsBuilder; салют — client FireworksController.
  Клиент: ShopController (кнопка SHOP слева, киоск «Open shop» на площади на месте пончика, вкладки, карточки).
- Баг после Rebirth: мемлинги держали постаменты 4–10 открытыми, покупка «Pedestal» ничего не давала (цена
  уходила до 14 000). Теперь Rebirth (и загрузка старого сохранения с мемлингами на закрытых постаментах)
  пересобирает витрину — Studio.reflowShowcase / shared/Util/ShowcaseRule (+ тест «10 → 3 + 7, кнопка 100»):
  самые доходные на стартовые постаменты, остальные в запас по доходу (флаг отряда сохраняется), купленный
  постамент забирает лучшего из запаса. Подписи на постаменте — одна плашка в пикселях прямо над мемлингом
  (MapBuilder.AddStackLabel: имя и доход сверху, «N Aura» снизу, видно ближе 30 студов). «REBIRTH N» —
  маленькая подпись фиксированного размера выше имени (StyleConfig.PlotParts.RebirthTag*).
- 7.5 (мир не площадка; механика зон не менялась): море опущено (MapConfig.Background.SeaLevel −14), хаб и участки —
  острова на скалах. server/Visual/IslandEdges: у хаба уступ с травой, скала, 24 крупных камня, стена деревьев и
  кустов между мостиками (MapConfig.HubEdge; у мостиков и входа в паркур — проходы), под участками скала с камнями,
  пена у воды; 3 дальних острова. Зоны: каменное «дно» уступами, уступ вокруг пола, видимый забор по краю, на уступе
  камни, кристаллы и великаны (банка, эскимо, пончик), облака ниже края (MapConfig.Zones[Id].Edge, цвета — тема зоны).
  Невидимые стены остались. Всё без теней. Падение (shared/Util/FallRule + тест): в хабе — сервис FallRescue
  (MapConfig.FallRescue; с паркура — SecretObby.RescueOnRoute на чекпоинт, иначе дорожка у мостика или вход участка),
  в зоне — Raid.checkFallenPlayers (ближайшая точка спавна или вход, из рук теряется, это не смерть).
  7.5, вторая часть:
  4) Безопасная часть зоны не плоская (MapBuilder.buildSafeTerrain, MapConfig Decor.Hills / Shelters / MemelingPath*):
     9 невысоких холмов (верхушки больших шаров, по ним ходят), 4 гриба-укрытия, тропинки «ёлочкой» от дорожки к
     точкам спавна; при старте проверка, что холмы не налезают на точки и тропинки. Цвета: SAFE — бирюза + зелёный,
     DANGER — красно-фиолетовый пол, EXTRACT — золото (Palette.Sun, золотой PointLight над площадкой), SLOW EXIT —
     светлая слива. Lighting не менялся.
  5) «Охота» — сервис Bounty: раз в EconomyConfig.Bounty.IntervalSeconds (600) случайный мемлинг зон, не Secret и не тот
     же подряд (shared/Util/BountyRule + тест); атрибуты BountyMemelingId / BountyEndsAt на ReplicatedStorage.
     Вынесенный, пока он BOUNTY (решает Extraction в момент эвакуации), получает флаг bounty в профиле (showcase и
     reserve; переходит при пересборке и из запаса) — доход × IncomeMultiplier (2) в Studio.getRate, «BOUNTY x2» на
     постаменте и на экране результата (Remotes.ExtractionResult — пятый аргумент, флаги). Клиент
     (client/Controllers/BountyController): табличка над вывеской портала зоны этого мемлинга, плашка под таймером
     рестока в зоне, метка «BOUNTY x2» над такими мемлингами на полу.
  6) Туториал: Tutorial.IsActive; смерть в стартовой зоне с добычей → Raid.tutorialKeep, вылазка не закрывается,
     новый персонаж у входа зоны, модели пересоздаёт Spawn.RebuildCarried и Raid приваривает их снова.
- 7.6 (новые мемлинги, стиль D, механика не менялась): Meme Zone +5 — SoggyCereal, ChonkyDumpling (Common),
  SpicyNugget (Rare), ToiletPaperPrince (Epic), CosmicBurrito (Legendary); Golden Zone +3 — DiamondDonut (Rare),
  TrophyTurtle (Epic), SirMoneybags (Legendary, доход ×5 как у всей Golden). Строители — MemelingBuilders (у каждого
  яркая черта: ложка, пар, пламя, корона с мантией, шлем-пузырь, бриллиант, кубок-панцирь, цилиндр с моноклем),
  цвета — StyleConfig.Characters, имена — TextConfig.MemelingNames. Правило «в каждой зоне хотя бы один Legendary»:
  тест в RarityRoll.spec и предупреждение сервера при старте. /memelings — по ряду на зону, последний ряд — Secret.
- 7.7 (третья зона CANDY CHAOS, коммиты по частям):
  1) Виды врагов: EnemyConfig.Kinds (скорость, урон, замах, размер; общее поведение — Chaser), EnemyConfig.Zones[Id].Kind;
     Enemy хранит статы вида у каждого врага, MemelingBuilders.BuildEnemy(kindId, …); клиент берёт длительность замаха
     и размер из атрибутов врага (WindupSeconds, BodySize). Новый враг GummyBrute — мармеладный громила: скорость 7
     (патруль 4), урон 40, замах 0,8 с, тело 7.
  2) Зона Candy (Z = 500): вход 250 000 Aura (ворота у портала), шансы Safe Rare 60 / Epic 40, Danger Rare 35 / Epic 45 / Legendary 20
     (правило всех зон: Legendary только в опасной части — тест RarityRoll),
     6 GummyBrute, ловушки как в Golden, но быстрее; тема розово-голубая (ZoneThemes.Candy), по краю гигантские
     леденцы (IslandEdges, zoneLayout(top, edgeKinds)). 5 мемлингов, доход ×20 (MemelingConfig.CandyIncomeMultiplier):
     CottonCandyCloud, LollipopLlama (Rare), GummyWormGang, MarshmallowMage (Epic), ChocoKing (Legendary).
     Портал на 0° (PortalRotations.Candy = 90, розовая воронка); BEST HAUL переехал на 45° r 34 вместо гигантского
     телефона, кусты 14°/346° → 24°/336°.
  3) Раздел «Как добавить новую зону» в этом файле.
- 7.8 (интерфейс и витрины, механика не менялась; коммит на пункт):
  1) Меню слева (client/Controllers/MenuController, кнопка-иконка на месте прежней SHOP): Base, Collection, Upgrades,
     Rebirth, Shop; Quests и Daily rewards — с замком «Soon». Base / Upgrades / Rebirth — панели только для чтения
     (покупка и Rebirth по-прежнему на кнопках участка), числа — атрибуты сервера + UpgradeValues / RebirthMath.
     Окна открываются через client/Ui/Windows (одно окно за раз); магазин — пункт Shop и киоск.
  2) Коллекция (CollectionController): сетка по зонам (shared/Util/CollectionRule + тест), 3D-превью в ViewportFrame
     из шаблонов ReplicatedStorage.MemelingPreviews (строит MapBuilder), неоткрытые — тёмный силуэт с замком; карточка —
     модель вращается на подсвеченном постаменте, редкость, доход, цена, скорость, где водится, сколько есть; счётчик N/27.
     Профиль — схема 7, discovered (миграция: витрина, запас и Secret); отмечает Studio.AddToShowcase. Атрибуты
     CollectionDiscovered / CollectionOwned / UpgradeLevel_<id>.
  3) Витрина: стеклянный колпак над мемлингом на постаменте, подставка с неоновым кольцом и свечением цвета редкости
     (MapBuilder.AddGlassDome, StyleConfig.Showcase); без столкновений и лучей — Collect и Sell работают.
  4) HUD: под числом банка «+N Aura/s» и полоска заполнения хранилищ (атрибуты BaseIncome / BaseStored / BaseStorageCap
     от Studio.publishBaseStats).
  5) Эвакуация: крупная полоска «EXTRACTING... 2.1s» вверху по центру (ExtractFxController, StyleConfig.ExtractFx.Bar*).
  6) Портал: две висящие хоругви по бокам — цвет воронки зоны, золотая корона, название зоны (MapConfig.Portal.Banners).
  Баг после 7.8: подписи постамента (имя / +N/s / N Aura) оказались внутри колпака и прятались за стеклом. Теперь
  высота плашки — от верха постамента над колпаком (MapBuilder.GetDomeHeight, учитывает размер редкости), подписи
  AlwaysOnTop с MaxDistance 30; при перестройке постамента старые подписи удаляются все.

Проверка кода без Studio: `powershell -ExecutionPolicy Bypass -File scripts/check.ps1` —
luau-lsp analyze с типами Roblox, проверка кодировки (.luau без BOM и без «кракозябр»),
тесты `luau tests/run.luau`, rojo build в test.rbxl. Новые тесты подключать в `tests/run.luau`.

После 1.4: тексты для игрока вынесены в TextConfig, потерянные мемлинги возвращаются
на свою точку спавна через 10 с (решения автора — правила 13–16).

Фазы 1–5 закрыты (в 5.4 сделаны модели; звуков мемлингов пока нет), правки 6.0 и визуальный проход 6.1 перед тестом сделаны,
7.1 (агрессия врагов), 7.2 (Golden Zone), 7.3 (секретный паркур), 7.4 (магазин косметики), 7.5 (края островов, холмы, BOUNTY), 7.6 (8 новых мемлингов), 7.7 (зона Candy Chaos) и 7.8 (меню, коллекция, витрины, HUD) готовы.
Дальше по документации — «Ворота B»: закрытый тест (раздел 7, шаг 3).
