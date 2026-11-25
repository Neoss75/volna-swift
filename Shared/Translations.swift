/// One text per line: Russian ‖ Ukrainian ‖ English. {} is replaced by a value, what follows # only tells equal words apart.
/// scripts/check-texts.py makes sure that nothing is missing.
enum Translations {
    static let text = #"""
файл не найден: его переместили или удалили в «Файлах»‖файл не знайдено: його перемістили або видалили у «Файлах»‖file not found: it was moved or deleted in Files
У всех песен уже есть обложки‖Усі пісні вже мають обкладинки‖All songs already have covers
Ищу обложки: ‖Шукаю обкладинки: ‖Looking for covers:
песня‖пісня‖song
песни‖пісні‖songs
песен‖пісень‖songs
Добавлено: ‖Додано: ‖Added:
уже в списке: {}‖вже у списку: {}‖already in the list: {}
не удалось: {}‖не вдалося: {}‖failed: {}
Папок пока нет. Добавьте папку целиком‖Папок ще немає. Додайте папку цілком‖No folders yet. Add a whole folder
Новые песни в папках: {}‖Нові пісні в папках: {}‖New songs in folders: {}
Новых песен в папках нет‖Нових пісень у папках немає‖No new songs in folders
Сохранено‖Збережено‖Saved
Файл не открывается‖Файл не відкривається‖The file cannot be opened
Возвращено из файла‖Повернуто з файлу‖Restored from the file
Удалено: «{}»‖Видалено: «{}»‖Removed: “{}”
Удалено ‖Видалено ‖Removed
Отменить‖Скасувати‖Undo
Возвращено‖Повернуто‖Restored
Убрано из избранного‖Прибрано з обраного‖Removed from favourites
Добавлено в избранное‖Додано в обране‖Added to favourites
Плейлист создан. Добавляйте песни через «⋯»‖Плейлист створено. Додавайте пісні через «⋯»‖Playlist created. Add songs with “⋯”
Добавлено в «{}»‖Додано в «{}»‖Added to “{}”
Уже есть в «{}»‖Вже є в «{}»‖Already in “{}”
Убрано из плейлиста‖Прибрано з плейлиста‖Removed from the playlist
Плейлист удалён, песни остались‖Плейлист видалено, пісні залишилися‖Playlist deleted, the songs stay
Обложка убрана‖Обкладинку прибрано‖Cover removed
Сыграет следующей‖Зіграє наступною‖Will play next
Добавлено в очередь‖Додано в чергу‖Added to the queue
Перемешивание включено‖Перемішування увімкнено‖Shuffle on
Перемешивание выключено‖Перемішування вимкнено‖Shuffle off
Повтор: ‖Повтор: ‖Repeat:
выключен‖вимкнено‖off
вся очередь‖вся черга‖whole queue
один трек‖один трек‖one song
Сначала добавьте музыку: «Песни» → «+»‖Спочатку додайте музику: «Пісні» → «+»‖Add some music first: Songs → “+”
Не удалось включить звук: {}‖Не вдалося увімкнути звук: {}‖Could not start the sound: {}
Это начало списка‖Це початок списку‖This is the start of the list
не удалось открыть файл‖не вдалося відкрити файл‖could not open the file
Таймер сна: воспроизведение остановлено‖Таймер сну: відтворення зупинено‖Sleep timer: playback stopped
Столбики‖Стовпчики‖Bars
Пики‖Піки‖Peaks
Зеркало‖Дзеркало‖Mirror
Индикатор‖Індикатор‖LED meter
Точки‖Крапки‖Dots
Спектр‖Спектр‖Spectrum
Ленты‖Стрічки‖Ribbons
Осциллограф‖Осцилограф‖Oscilloscope
Стереофигура‖Стереофігура‖Stereo figure
Горы‖Гори‖Mountains
Потоки‖Потоки‖Streams
Калейдоскоп‖Калейдоскоп‖Kaleidoscope
Мозаика‖Мозаїка‖Mosaic
Капля‖Крапля‖Drop
Сияние‖Сяйво‖Aurora
Конфетти‖Конфеті‖Confetti
Искры‖Іскри‖Sparks
Пульс‖Пульс‖Pulse
Звёзды‖Зірки‖Stars
Лепестки‖Пелюстки‖Petals
Круг‖Коло‖Ring
Стрелки L/R‖Стрілки L/R‖VU meters L/R
Выключено‖Вимкнено‖Off
Цвета: ‖Кольори: ‖Colours:
Визуализация: ‖Візуалізація: ‖Visualisation:
Статистика сброшена‖Статистику скинуто‖Statistics reset
Пока ничего не прослушано. Статистика копится сама, пока играет музыка.‖Поки нічого не прослухано. Статистика накопичується сама, поки грає музика.‖Nothing played yet. Statistics collect by themselves while music plays.
Всего {} · {} · сегодня {}‖Усього {} · {} · сьогодні {}‖Total {} · {} · today {}
прослушивание‖прослуховування‖play
прослушивания‖прослуховування‖plays
прослушиваний‖прослуховувань‖plays
Неизвестный исполнитель‖Невідомий виконавець‖Unknown artist
 дБ‖ дБ‖ dB
{} ч {} мин‖{} год {} хв‖{} h {} min
{} мин‖{} хв‖{} min
{} с‖{} с‖{} s
%.1f МБ‖%.1f МБ‖%.1f MB
{} кбит/с‖{} кбіт/с‖{} kbps
VBR ≈ {} кбит/с‖VBR ≈ {} кбіт/с‖VBR ≈ {} kbps
≈ {} кбит/с‖≈ {} кбіт/с‖≈ {} kbps
 кбит/с‖ кбіт/с‖ kbps
%g кГц‖%g кГц‖%g kHz
{} бит / {}‖{} біт / {}‖{} bit / {}
В тон плеера‖У тон плеєра‖Player accent
По уровню‖За рівнем‖By level
Радуга‖Веселка‖Rainbow
Огонь‖Вогонь‖Fire
Неон‖Неон‖Neon
Раздел‖Розділ‖Section
Поиск по названию, артисту…‖Пошук за назвою, артистом…‖Search titles, artists…
Очистить поиск‖Очистити пошук‖Clear search
Все‖Усі‖All
♥ Избранное‖♥ Обране‖♥ Favourites
Без потерь‖Без втрат‖Lossless
Недавние‖Недавні‖Recent
Часто играют‖Часто грають‖Most played
Давно не слушали‖Давно не слухали‖Not played lately
+ Плейлист‖+ Плейлист‖+ Playlist
Сортировка‖Сортування‖Sort
По добавлению‖За додаванням‖By date added
По названию‖За назвою‖By title
По исполнителю‖За виконавцем‖By artist
Разные исполнители‖Різні виконавці‖Various artists
Без альбома‖Без альбому‖No album
Папок пока нет. Добавьте папку целиком, и новые песни из неё будут появляться сами.‖Папок ще немає. Додайте папку цілком, і нові пісні з неї з’являтимуться самі.‖No folders yet. Add a whole folder, and new songs from it will appear by themselves.
Список пуст. Добавьте файлы или папку.‖Список порожній. Додайте файли або папку.‖The list is empty. Add files or a folder.
Файлы‖Файли‖Files
Папку‖Папку‖Folder
альбом‖альбом‖album
альбома‖альбоми‖albums
альбомов‖альбомів‖albums
Папка‖Папка‖Folder
Играть‖Грати‖Play
Перемешать‖Перемішати‖Shuffle
Показано {} из {}‖Показано {} з {}‖Showing {} of {}
Переименовать‖Перейменувати‖Rename
Удалить‖Видалити‖Delete
Удалить все‖Видалити всі‖Remove all
Удалить ({})‖Видалити ({})‖Remove ({})
Убрать из плеера: {}? Файлы останутся на месте.‖Прибрати з плеєра: {}? Файли залишаться на місці.‖Remove from the player: {}? The files stay where they are.
Убрать из плеера‖Прибрати з плеєра‖Remove from the player
Удалить плейлист «{}»? Песни останутся.‖Видалити плейлист «{}»? Пісні залишаться.‖Delete the playlist “{}”? The songs stay.
Удалить плейлист‖Видалити плейлист‖Delete playlist
Ничего не найдено‖Нічого не знайдено‖Nothing found
В избранном пока пусто. Нажмите ♥ у песни, чтобы добавить её сюда.‖В обраному поки порожньо. Натисніть ♥ біля пісні, щоб додати її сюди.‖No favourites yet. Tap ♥ next to a song to add it here.
Плейлист пуст. Добавьте песни через «⋯» → «Добавить в плейлист».‖Плейлист порожній. Додайте пісні через «⋯» → «Додати в плейлист».‖The playlist is empty. Add songs with “⋯” → “Add to playlist”.
Песен без потерь пока нет. Это файлы FLAC, ALAC, WAV и AIFF.‖Пісень без втрат поки немає. Це файли FLAC, ALAC, WAV та AIFF.‖No lossless songs yet. These are FLAC, ALAC, WAV and AIFF files.
Здесь появятся песни, которые вы слушаете чаще всего.‖Тут з’являться пісні, які ви слухаєте найчастіше.‖The songs you play most will appear here.
Название‖Назва‖Title
Исполнитель‖Виконавець‖Artist
Альбом‖Альбом‖Album
Меняется только в плеере, сам файл «{}» остаётся как есть.‖Змінюється лише в плеєрі, сам файл «{}» залишається як є.‖Changes only in the player, the file “{}” stays as it is.
Поменять местами название и исполнителя‖Поміняти місцями назву та виконавця‖Swap title and artist
Вернуть из файла‖Повернути з файлу‖Restore from the file
Изменить‖Змінити‖Edit
Отмена‖Скасувати‖Cancel
Сохранить‖Зберегти‖Save
текст песни‖текст пісні‖lyrics
Найти в интернете‖Знайти в інтернеті‖Find online
Вставить текст‖Вставити текст‖Paste lyrics
Изменить текст‖Змінити текст‖Edit lyrics
Удалить текст‖Видалити текст‖Delete lyrics
Действия с текстом‖Дії з текстом‖Lyrics actions
Закрыть текст‖Закрити текст‖Close lyrics
Сначала выберите песню.‖Спочатку виберіть пісню.‖Choose a song first.
Ищу текст на lrclib.net…‖Шукаю текст на lrclib.net…‖Looking on lrclib.net…
Текста для этой песни пока нет.‖Тексту для цієї пісні поки немає.‖No lyrics for this song yet.
Поиск отправит название и исполнителя на сайт lrclib.net. Ещё можно добавить вместе с песней файл .lrc с тем же именем.‖Пошук надішле назву та виконавця на сайт lrclib.net. Ще можна додати разом із піснею файл .lrc з тим самим ім’ям.‖The search sends the title and the artist to lrclib.net. You can also add a .lrc file with the same name together with the song.
Найден текст с синхронизацией‖Знайдено текст із синхронізацією‖Synced lyrics found
Найден текст‖Знайдено текст‖Lyrics found
Текст не найден. Его можно вставить вручную‖Текст не знайдено. Його можна вставити вручну‖No lyrics found. You can paste them by hand
Не удалось связаться с lrclib.net. Проверьте интернет‖Не вдалося зв’язатися з lrclib.net. Перевірте інтернет‖Could not reach lrclib.net. Check the internet connection
Текст удалён‖Текст видалено‖Lyrics deleted
Вставьте текст. Строки вида [01:23.45] будут подсвечиваться в такт песне.‖Вставте текст. Рядки на кшталт [01:23.45] підсвічуватимуться в такт пісні.‖Paste the lyrics. Lines like [01:23.45] light up in time with the song.
Текст песни‖Текст пісні‖Lyrics
Добавить папку‖Додати папку‖Add folder
Добавить файлы‖Додати файли‖Add files
Закрыть‖Закрити‖Close
Список песен‖Список пісень‖Song list
Очередь‖Черга‖Queue
Эквалайзер‖Еквалайзер‖Equaliser
Настройки‖Налаштування‖Settings
Статистика‖Статистика‖Statistics
Играть следующей‖Грати наступною‖Play next
В конец очереди‖У кінець черги‖Add to queue
Убрать из избранного‖Прибрати з обраного‖Remove from favourites
В избранное‖В обране‖Add to favourites
Добавить в плейлист‖Додати в плейлист‖Add to playlist
Новый плейлист‖Новий плейлист‖New playlist
Убрать из «{}»‖Прибрати з «{}»‖Remove from “{}”
Найти другую обложку‖Знайти іншу обкладинку‖Find another cover
Найти обложку в интернете‖Знайти обкладинку в інтернеті‖Find a cover online
Убрать найденную обложку‖Прибрати знайдену обкладинку‖Remove the found cover
Изменить название…‖Змінити назву…‖Edit title…
Удалить из плеера‖Видалити з плеєра‖Remove from the player
файл не открывается‖файл не відкривається‖the file cannot be opened
без потерь‖без втрат‖lossless
Действия с песней‖Дії з піснею‖Song actions
Очередь пуста. Откройте «Песни» и выберите трек.‖Черга порожня. Відкрийте «Пісні» та виберіть трек.‖The queue is empty. Open Songs and choose one.
Нажатие на песню в списке запускает весь список с этого места. Перетащите строку, чтобы поменять порядок; смахните, чтобы убрать.‖Натискання на пісню у списку запускає весь список із цього місця. Перетягніть рядок, щоб змінити порядок; змахніть, щоб прибрати.‖Tapping a song in a list plays the whole list from there. Drag a row to change the order, swipe to remove it.
Эквалайзер включён‖Еквалайзер увімкнено‖Equaliser on
Сбросить‖Скинути‖Reset
Свой‖Свій‖Custom
 герц‖ герц‖ hertz
Предусилитель‖Передпідсилювач‖Preamp
10 полос, ±12 дБ. Двойное нажатие на полосу сбрасывает её в ноль. Крайние полосы поднимают весь самый низ и весь верх, до 20 кГц.‖10 смуг, ±12 дБ. Подвійне натискання на смугу скидає її в нуль. Крайні смуги піднімають увесь найнижчий діапазон і весь верх, до 20 кГц.‖10 bands, ±12 dB. Double-tap a band to set it to zero. The outer bands lift all of the lowest bass and all of the top, up to 20 kHz.
всего прослушано‖усього прослухано‖played in total
разные песни‖різні пісні‖different songs
разных песен‖різних пісень‖different songs
сегодня‖сьогодні‖today
Последние 7 дней, минут в день‖Останні 7 днів, хвилин на день‖Last 7 days, minutes a day
Чаще всего‖Найчастіше‖Most played
раз‖раз‖time
раза‖рази‖times
раз#мн‖разів‖times
Исполнители‖Виконавці‖Artists
Пока пусто.‖Поки порожньо.‖Nothing here yet.
Сбросить статистику‖Скинути статистику‖Reset statistics
Сбросить всю статистику прослушиваний? Это нельзя отменить.‖Скинути всю статистику прослуховувань? Це не можна скасувати.‖Reset all listening statistics? This cannot be undone.
сег.‖сьог.‖today
Нажмите на столбик, чтобы увидеть точное значение.‖Натисніть на стовпчик, щоб побачити точне значення.‖Tap a bar to see the exact value.
Вс‖Нд‖Sun
Пн‖Пн‖Mon
Вт‖Вт‖Tue
Ср‖Ср‖Wed
Чт‖Чт‖Thu
Пт‖Пт‖Fri
Сб‖Сб‖Sat
Ищу обложку…‖Шукаю обкладинку…‖Looking for a cover…
Выберите обложку‖Виберіть обкладинку‖Choose a cover
Обложка не найдена‖Обкладинку не знайдено‖No cover found
iTunes просит подождать минуту, попробуйте позже‖iTunes просить зачекати хвилину, спробуйте пізніше‖iTunes asks to wait a minute, try again later
Не удалось связаться с iTunes. Проверьте интернет‖Не вдалося зв’язатися з iTunes. Перевірте інтернет‖Could not reach iTunes. Check the internet connection
Обложка сохранена‖Обкладинку збережено‖Cover saved
Не удалось скачать обложку‖Не вдалося завантажити обкладинку‖Could not download the cover
Читаю песни…‖Читаю пісні…‖Reading songs…
Волна‖Волна‖Volna
ПРЯМОЙ‖ПРЯМИЙ‖DIRECT
Файл без потерь‖Файл без втрат‖Lossless file
Прямой вывод‖Прямий вивід‖Direct output
Hi-Res: песня идёт без пересчёта частоты‖Hi-Res: пісня йде без перерахунку частоти‖Hi-Res: the song plays at its own sample rate
Режим Hi-Res включён, сейчас не используется‖Режим Hi-Res увімкнено, зараз не використовується‖Hi-Res mode is on, not in use now
Обложка. Смахивание переключает песню‖Обкладинка. Змахування перемикає пісню‖Cover. Swipe to change the song
Ничего не выбрано‖Нічого не вибрано‖Nothing chosen
Добавить в избранное‖Додати в обране‖Add to favourites
Откройте «Песни» и добавьте музыку‖Відкрийте «Пісні» та додайте музику‖Open Songs and add some music
Откройте «Песни» и выберите трек‖Відкрийте «Пісні» та виберіть трек‖Open Songs and choose one
{} из {}‖{} з {}‖{} of {}
выравн. ‖вирівн. ‖gain
Позиция в треке‖Позиція в треку‖Position in the song
Предыдущий‖Попередній‖Previous
Пауза‖Пауза‖Pause
Следующий‖Наступний‖Next
Повтор‖Повтор‖Repeat
Таймер сна: остановка после этого трека‖Таймер сну: зупинка після цього треку‖Sleep timer: stops after this song
Таймер сна: ‖Таймер сну: ‖Sleep timer:
Песни‖Пісні‖Songs
Громкость‖Гучність‖Volume
Скрыть громкость‖Сховати гучність‖Hide volume
Плейлист {}‖Плейлист {}‖Playlist {}
Переименовать плейлист‖Перейменувати плейлист‖Rename playlist
Заставка. Нажмите, чтобы вернуться к плееру‖Заставка. Натисніть, щоб повернутися до плеєра‖Screensaver. Tap to return to the player
Обработка звука‖Обробка звуку‖Sound processing
Выравнивание громкости‖Вирівнювання гучності‖Loudness levelling
Воспроизведение‖Відтворення‖Playback
Hi-res и вывод‖Hi-res і вивід‖Hi-res and output
Оформление‖Оформлення‖Appearance
Визуализация‖Візуалізація‖Visualisation
Библиотека и файлы‖Бібліотека та файли‖Library and files
Обложки‖Обкладинки‖Covers
Тексты песен‖Тексти пісень‖Lyrics
О приложении‖Про застосунок‖About
Выключен‖Вимкнено‖Off
бас +‖бас +‖bass +
лимитер включён‖лімітер увімкнено‖limiter on
лимитер выключен‖лімітер вимкнено‖limiter off
Включено‖Увімкнено‖On
кроссфейд {} с‖кросфейд {} с‖crossfade {} s
без пауз‖без пауз‖gapless
без кроссфейда‖без кросфейду‖no crossfade
таймер сна‖таймер сну‖sleep timer
Тёмная‖Темна‖Dark
Светлая‖Світла‖Light
Как в системе‖Як у системі‖Same as iPhone
плейлист‖плейлист‖playlist
плейлиста‖плейлисти‖playlists
плейлистов‖плейлистів‖playlists
Поиск в iTunes включён‖Пошук в iTunes увімкнено‖iTunes search on
Поиск выключен‖Пошук вимкнено‖Search off
Показан вместо обложки‖Показано замість обкладинки‖Shown instead of the cover
Открывается кнопкой на главном экране‖Відкривається кнопкою на головному екрані‖Opens with a button on the main screen
Пока ничего не прослушано‖Поки нічого не прослухано‖Nothing played yet
Всего ‖Усього ‖Total
Волна ‖Волна ‖Volna
центр‖центр‖centre
Л ‖Л ‖L
П ‖П ‖R
Тембр‖Тембр‖Tone
Усиление баса‖Підсилення басу‖Bass boost
Открыть эквалайзер‖Відкрити еквалайзер‖Open the equaliser
Стерео‖Стерео‖Stereo
Баланс‖Баланс‖Balance
Защита от искажений‖Захист від спотворень‖Distortion protection
Лимитер‖Лімітер‖Limiter
Убирает хрип, когда бас или эквалайзер сильно подняты.‖Прибирає хрип, коли бас або еквалайзер сильно підняті.‖Removes crackling when the bass or the equaliser is turned up a lot.
Сбросить обработку‖Скинути обробку‖Reset processing
Выравнивать громкость между песнями‖Вирівнювати гучність між піснями‖Level loudness between songs
Плеер один раз измеряет громкость каждой песни и подстраивает её, чтобы тихие и громкие треки звучали одинаково. Сами файлы не меняются.‖Плеєр один раз вимірює гучність кожної пісні та підлаштовує її, щоб тихі й гучні треки звучали однаково. Самі файли не змінюються.‖The player measures every song once and adjusts it, so that quiet and loud songs sound the same. The files do not change.
Измерения‖Вимірювання‖Measurements
Измерено {} из {}‖Виміряно {} з {}‖Measured {} of {}
 · идёт измерение…‖ · триває вимірювання…‖ · measuring…
Текущая песня: ‖Поточна пісня: ‖Current song:
Измерить всю библиотеку‖Виміряти всю бібліотеку‖Measure the whole library
Вся библиотека уже измерена‖Усю бібліотеку вже виміряно‖The whole library is already measured
Измеряю громкость: ‖Вимірюю гучність: ‖Measuring loudness:
Переход между песнями‖Перехід між піснями‖Between songs
Кроссфейд‖Кросфейд‖Crossfade
выкл‖вимк‖off
Конец песни плавно затухает, а следующая нарастает поверх него. Работает при автоматическом переходе. Кнопки «вперёд» и «назад» и свайп по обложке переключают сразу.‖Кінець пісні плавно згасає, а наступна наростає поверх нього. Працює під час автоматичного переходу. Кнопки «вперед» і «назад» та свайп по обкладинці перемикають одразу.‖The end of a song fades out while the next one fades in over it. Works when songs change by themselves. The next and previous buttons and a swipe on the cover switch at once.
Без пауз‖Без пауз‖Gapless
Песни без пауз между собой‖Пісні без пауз між собою‖No gaps between songs
Следующая песня начинается ровно в конце предыдущей: важно для концертов и альбомов, где музыка не прерывается. Работает, когда кроссфейд выключен и у обеих песен одинаковая частота и число каналов.‖Наступна пісня починається рівно в кінці попередньої: важливо для концертів та альбомів, де музика не переривається. Працює, коли кросфейд вимкнено і в обох пісень однакова частота та кількість каналів.‖The next song starts exactly where the last one ends: it matters for concerts and albums without breaks. Works when crossfade is off and both songs have the same sample rate and number of channels.
Скорость‖Швидкість‖Speed
Сохранять высоту тона‖Зберігати висоту тону‖Keep the pitch
Обычная скорость‖Звичайна швидкість‖Normal speed
Таймер сна‖Таймер сну‖Sleep timer
1 час‖1 година‖1 hour
{} минут‖{} хвилин‖{} minutes
Таймер сна: {} минут‖Таймер сну: {} хвилин‖Sleep timer: {} minutes
После трека‖Після треку‖After this song
Файл‖Файл‖File
{} бит / ‖{} біт / ‖{} bit /
Частота‖Частота‖Sample rate
Подстраивать вывод под файл‖Підлаштовувати вивід під файл‖Match the output to the file
Значок LOSSLESS на главном экране: файл без потерь (FLAC, ALAC, WAV, AIFF). Он говорит о файле, а не о наушниках.‖Значок LOSSLESS на головному екрані: файл без втрат (FLAC, ALAC, WAV, AIFF). Він говорить про файл, а не про навушники.‖The LOSSLESS mark on the main screen: a lossless file (FLAC, ALAC, WAV, AIFF). It is about the file, not the headphones.
Значок HI-RES на главном экране: контур означает, что режим включён, закрашенный — что песня выше качества CD и идёт на ЦАП без пересчёта.‖Значок HI-RES на головному екрані: контур означає, що режим увімкнено, зафарбований — що пісня вища за якість CD і йде на ЦАП без перерахунку.‖The HI-RES mark on the main screen: an outline means the mode is on, a filled one means the song is better than CD quality and reaches the DAC without resampling.
Работает с внешним ЦАП по USB-C или HDMI: он переключается на частоту песни, и она идёт без пересчёта. Динамик и Bluetooth работают на своей частоте, её поменять нельзя, а Bluetooth к тому же сжимает звук.‖Працює із зовнішнім ЦАП через USB-C або HDMI: він перемикається на частоту пісні, і вона йде без перерахунку. Динамік і Bluetooth працюють на своїй частоті, її змінити не можна, а Bluetooth до того ж стискає звук.‖Works with an external DAC over USB-C or HDMI: it switches to the sample rate of the song, so nothing is resampled. The speaker and Bluetooth have a fixed rate, and Bluetooth compresses the sound as well.
Обработка‖Обробка‖Processing
Выключает всё, что меняет звук: эквалайзер, бас, баланс, лимитер, выравнивание и скорость. Ваши настройки сохраняются и вернутся, когда вы выключите этот режим.‖Вимикає все, що змінює звук: еквалайзер, бас, баланс, лімітер, вирівнювання та швидкість. Ваші налаштування зберігаються й повернуться, коли ви вимкнете цей режим.‖Turns off everything that changes the sound: equaliser, bass, balance, limiter, levelling and speed. Your settings are kept and come back when you turn this mode off.
Тема‖Тема‖Theme
Цвет‖Колір‖Colour
Как выглядит‖Як виглядає‖Preview
Визуализация выключена.‖Візуалізацію вимкнено.‖Visualisation is off.
Включите песню, чтобы увидеть движение.‖Увімкніть пісню, щоб побачити рух.‖Play a song to see it move.
Цвета‖Кольори‖Colours
низкие‖низькі‖low
тихо‖тихо‖quiet
высокие‖високі‖high
громко‖гучно‖loud
Режим‖Режим‖Mode
На главном экране нажатие на визуализацию меняет режим, долгое нажатие — цвета.‖На головному екрані натискання на візуалізацію змінює режим, довге натискання — кольори.‖On the main screen a tap on the visualisation changes the mode, a long press changes the colours.
Заставка‖Заставка‖Screensaver
Включать заставку‖Вмикати заставку‖Use the screensaver
Если играет музыка и вы столько не касаетесь экрана, визуализация открывается на весь экран. Нажатие возвращает плеер. Поверх списков, настроек и текста песни заставка не появляется.‖Якщо грає музика і ви стільки не торкаєтеся екрана, візуалізація відкривається на весь екран. Натискання повертає плеєр. Поверх списків, налаштувань і тексту пісні заставка не з’являється.‖When music plays and you do not touch the screen for this long, the visualisation fills the screen. A tap brings the player back. It does not appear over lists, settings or lyrics.
10 секунд‖10 секунд‖10 seconds
20 секунд‖20 секунд‖20 seconds
30 секунд‖30 секунд‖30 seconds
1 минута‖1 хвилина‖1 minute
Как на главном экране‖Як на головному екрані‖Same as the main screen
Не гасить экран во время заставки‖Не гасити екран під час заставки‖Keep the screen on
Если выключено, iPhone погаснет сам через время из своих настроек («Экран и яркость → Автоблокировка»), музыка при этом играет дальше. Если включено, экран не гаснет и батарея садится быстрее.‖Якщо вимкнено, iPhone згасне сам через час зі своїх налаштувань («Екран і яскравість → Автоблокування»), музика при цьому грає далі. Якщо увімкнено, екран не гасне і батарея сідає швидше.‖If off, the iPhone dims by its own setting (Display & Brightness → Auto-Lock) and the music goes on. If on, the screen stays lit and the battery drains faster.
Показать сейчас‖Показати зараз‖Show now
Сейчас в плеере‖Зараз у плеєрі‖In the player now
В избранном‖В обраному‖Favourites
Плейлисты‖Плейлисти‖Playlists
Общий размер файлов‖Загальний розмір файлів‖Total file size
%.0f МБ‖%.0f МБ‖%.0f MB
Папки‖Папки‖Folders
Искать новые песни при запуске‖Шукати нові пісні під час запуску‖Look for new songs at start
Папок: {}. Песни, которые вы убрали из плеера, при обновлении не возвращаются.‖Папок: {}. Пісні, які ви прибрали з плеєра, під час оновлення не повертаються.‖Folders: {}. Songs you removed from the player do not come back on refresh.
Ищу…‖Шукаю…‖Looking…
Обновить сейчас‖Оновити зараз‖Refresh now
Добавить‖Додати‖Add
Папку целиком‖Папку цілком‖Whole folder
Песни не копируются: плеер играет их там, где они лежат в «Файлах». Удаление из списка сами файлы не трогает. Если переместить или удалить файл, песня перестанет открываться.‖Пісні не копіюються: плеєр грає їх там, де вони лежать у «Файлах». Видалення зі списку самі файли не чіпає. Якщо перемістити або видалити файл, пісня перестане відкриватися.‖Songs are not copied: the player plays them where they are in Files. Removing a song from the list does not touch the file. If a file is moved or deleted, the song stops opening.
Искать обложки в интернете‖Шукати обкладинки в інтернеті‖Find covers online
Для песен без своей обложки плеер ищет её в каталоге iTunes по исполнителю и альбому. Туда отправляются только эти названия. Найденная обложка сохраняется и дальше видна без интернета.‖Для пісень без власної обкладинки плеєр шукає її в каталозі iTunes за виконавцем та альбомом. Туди надсилаються лише ці назви. Знайдена обкладинка зберігається й надалі видно без інтернету.‖For songs without a cover the player looks in the iTunes catalogue by artist and album. Only these names are sent there. A found cover is saved and then shows without the internet.
Библиотека‖Бібліотека‖Library
Найдено обложек: {}. Без обложки: ‖Знайдено обкладинок: {}. Без обкладинки: ‖Covers found: {}. Without a cover:
Идёт поиск, осталось {}. iTunes отвечает не чаще раза в 3 секунды, так что это займёт несколько минут.‖Триває пошук, залишилося {}. iTunes відповідає не частіше ніж раз на 3 секунди, тож це займе кілька хвилин.‖Searching, {} left. iTunes answers at most once in 3 seconds, so this takes a few minutes.
Найти для всей библиотеки‖Знайти для всієї бібліотеки‖Find for the whole library
Показывать текст вместо обложки‖Показувати текст замість обкладинки‖Show lyrics instead of the cover
Текст открывается и кнопкой с облачком внизу главного экрана. Строки с временем подсвечиваются в такт песне, нажатие на строку перематывает к ней.‖Текст відкривається і кнопкою з хмаринкою внизу головного екрана. Рядки з часом підсвічуються в такт пісні, натискання на рядок перемотує до нього.‖The speech bubble button at the bottom of the main screen opens lyrics too. Timed lines light up with the song, a tap on a line jumps to it.
Откуда берётся текст‖Звідки береться текст‖Where lyrics come from
Из самого файла, из файла .lrc с тем же именем, с сайта lrclib.net по вашему нажатию «Найти в интернете» или вставленный вручную. На lrclib.net отправляются название, исполнитель и длительность песни.‖Із самого файлу, з файлу .lrc з тим самим ім’ям, із сайту lrclib.net за вашим натисканням «Знайти в інтернеті» або вставлений вручну. На lrclib.net надсилаються назва, виконавець і тривалість пісні.‖From the file itself, from a .lrc file with the same name, from lrclib.net when you tap “Find online”, or pasted by hand. The title, artist and length of the song are sent to lrclib.net.
Музыкальный плеер для файлов на вашем iPhone.‖Музичний плеєр для файлів на вашому iPhone.‖A music player for the files on your iPhone.
Что уходит в интернет‖Що йде в інтернет‖What goes online
Только названия песен и исполнителей: в iTunes для поиска обложек, если он включён, и на lrclib.net, когда вы ищете текст. Сами файлы, статистика и плейлисты остаются на телефоне.‖Лише назви пісень і виконавців: в iTunes для пошуку обкладинок, якщо його увімкнено, і на lrclib.net, коли ви шукаєте текст. Самі файли, статистика та плейлисти залишаються на телефоні.‖Only names of songs and artists: to iTunes for cover search, if it is on, and to lrclib.net when you look for lyrics. Files, statistics and playlists stay on the phone.
Ничего не играет‖Нічого не грає‖Nothing is playing
Предыдущая‖Попередня‖Previous
Следующая‖Наступна‖Next
Название песни‖Назва пісні‖Song title
Ровно‖Рівно‖Flat
Бас‖Бас‖Bass
Рок‖Рок‖Rock
Поп‖Поп‖Pop
Вокал‖Вокал‖Vocal
Джаз‖Джаз‖Jazz
Классика‖Класика‖Classical
Электроника‖Електроніка‖Electronic
Верха‖Верхи‖Treble
Янтарь‖Бурштин‖Amber
Мята‖М’ята‖Mint
Коралл‖Корал‖Coral
Лаванда‖Лаванда‖Lavender
Небо‖Небо‖Sky
Роза‖Троянда‖Rose
Альбомы‖Альбоми‖Albums
Аудио‖Аудіо‖Audio
Графика‖Графіка‖Graphics
Музыка‖Музика‖Music
Прочее‖Інше‖Other
файл .lrc‖файл .lrc‖.lrc file
из файла‖з файлу‖from the file
добавлен вручную‖додано вручну‖added by hand
lrclib.net · синхронный‖lrclib.net · синхронний‖lrclib.net · synced
Язык‖Мова‖Language
«Как в системе» берёт язык из настроек iPhone.‖«Як у системі» бере мову з налаштувань iPhone.‖“Same as iPhone” takes the language from the iPhone settings.
Названия песен и исполнителей не переводятся.‖Назви пісень і виконавців не перекладаються.‖Names of songs and artists are not translated.
Путь звука‖Шлях звуку‖Sound path
Показывает по шагам, что происходит со звуком от файла до наушников.‖Показує крок за кроком, що відбувається зі звуком від файлу до навушників.‖Shows step by step what happens to the sound from the file to the headphones.
динамики iPhone‖динаміки iPhone‖iPhone speakers
разговорный динамик‖розмовний динамік‖earpiece
наушники по проводу‖навушники по дроту‖wired headphones
Bluetooth, режим звонка‖Bluetooth, режим дзвінка‖Bluetooth, call mode
машина (CarPlay)‖автомобіль (CarPlay)‖car (CarPlay)
линейный выход‖лінійний вихід‖line out
со сжатием‖зі стисненням‖compressed
Распаковка‖Розпакування‖Decoding
внутри плеера звук 32-битный‖усередині плеєра звук 32-бітний‖the player works in 32 bit
пересчитывается‖перераховується‖resampled
без пересчёта‖без перерахунку‖not resampled
ничего не меняет‖нічого не змінює‖changes nothing
обработка обойдена‖обробку обійдено‖processing bypassed
Громкость iPhone‖Гучність iPhone‖iPhone volume
Устройство‖Пристрій‖Device
На выходе‖На виході‖At the output
задержка {} мс‖затримка {} мс‖latency {} ms
моно‖моно‖mono
стерео‖стерео‖stereo
каналов: {}‖каналів: {}‖channels: {}
эквалайзер‖еквалайзер‖equaliser
баланс‖баланс‖balance
скорость‖швидкість‖speed
лимитер‖лімітер‖limiter
Включите песню, чтобы увидеть весь путь.‖Увімкніть пісню, щоб побачити весь шлях.‖Play a song to see the whole path.
По Bluetooth звук сжимается ещё раз перед отправкой, поэтому без потерь он не дойдёт. Каким способом, iPhone приложениям не сообщает (обычно AAC).‖По Bluetooth звук стискається ще раз перед надсиланням, тому без втрат він не дійде. Яким способом, iPhone застосункам не повідомляє (зазвичай AAC).‖Over Bluetooth the sound is compressed once more before it is sent, so it cannot arrive lossless. The iPhone does not tell apps how (usually AAC).
Наушники в режиме звонка: звук сильно упрощён. Закройте приложение, которое использует микрофон.‖Навушники в режимі дзвінка: звук сильно спрощено. Закрийте застосунок, який використовує мікрофон.‖The headphones are in call mode: the sound is much simpler. Close the app that uses the microphone.
Динамики iPhone работают на своей частоте. Чтобы услышать файл без потерь, нужны наушники по проводу или ЦАП.‖Динаміки iPhone працюють на своїй частоті. Щоб почути файл без втрат, потрібні навушники по дроту або ЦАП.‖The iPhone speakers have their own rate. To hear a lossless file you need wired headphones or a DAC.
По AirPlay звук передаётся по Wi-Fi. В каком виде он доходит, iPhone приложениям не сообщает.‖По AirPlay звук передається через Wi-Fi. У якому вигляді він доходить, iPhone застосункам не повідомляє.‖AirPlay sends the sound over Wi-Fi. The iPhone does not tell apps in what form it arrives.
Звук идёт по проводу, но частота пересчитана.‖Звук іде по дроту, але частоту перераховано.‖The sound goes over a wire, but it is resampled.
Звук идёт по проводу на частоте песни.‖Звук іде по дроту на частоті пісні.‖The sound goes over a wire at the sample rate of the song.
ЦАП работает не на частоте песни, она пересчитывается. Включите «Подстраивать вывод под файл»; если уже включено, ЦАП такую частоту не умеет.‖ЦАП працює не на частоті пісні, вона перераховується. Увімкніть «Підлаштовувати вивід під файл»; якщо вже увімкнено, ЦАП такої частоти не вміє.‖The DAC does not run at the rate of the song, so it is resampled. Turn on “Match the output to the file”; if it is on already, the DAC does not support this rate.
Частота песни сохранена, но плеер меняет звук обработкой. Чтобы убрать её, включите «Прямой вывод».‖Частоту пісні збережено, але плеєр змінює звук обробкою. Щоб прибрати її, увімкніть «Прямий вивід».‖The rate of the song is kept, but the player changes the sound. To avoid that, turn on “Direct output”.
Песня уходит на ЦАП на своей частоте, плеер ничего не меняет. Разрядность на выходе iPhone не сообщает, громкость лучше держать на 100%.‖Пісня йде на ЦАП на своїй частоті, плеєр нічого не змінює. Розрядність на виході iPhone не повідомляє, гучність краще тримати на 100%.‖The song reaches the DAC at its own rate and the player changes nothing. The iPhone does not report the output bit depth; keep the volume at 100%.
Что получаем‖Що отримуємо‖What you get
Выбрать устройство‖Вибрати пристрій‖Choose a device
Музыка на паузе: ЦАП переключится на частоту песни, когда она заиграет.‖Музика на паузі: ЦАП перемкнеться на частоту пісні, коли вона заграє.‖The music is paused: the DAC switches to the rate of the song when it plays.
Плеер ещё не готов‖Плеєр ще не готовий‖The player is not ready yet
В избранном пока пусто‖В обраному поки порожньо‖There are no favourites yet
Играю избранное‖Граю обране‖Playing favourites
В плеере пока нет песен‖У плеєрі поки немає пісень‖There are no songs in the player yet
Играю вперемешку‖Граю уперемішку‖Shuffling
Продолжаю‖Продовжую‖Resuming
Такой песни в плеере нет‖Такої пісні в плеєрі немає‖There is no such song in the player
Играю «{}»‖Граю «{}»‖Playing “{}”
Такого исполнителя в плеере нет‖Такого виконавця в плеєрі немає‖There is no such artist in the player
Такого плейлиста нет‖Такого плейлиста немає‖There is no such playlist
Плейлист пуст‖Плейлист порожній‖The playlist is empty
Siri и команды‖Siri та команди‖Siri and Shortcuts
Что можно сказать‖Що можна сказати‖What you can say
Включи избранное в Волне‖Включи избранное в Волне‖Play favourites in Volna
Перемешай музыку в Волне‖Перемешай музыку в Волне‖Shuffle music in Volna
Включи музыку в Волне‖Включи музыку в Волне‖Play music in Volna
Включи песню … в Волне‖Включи песню … в Волне‖Play the song … in Volna
Включи исполнителя … в Волне‖Включи исполнителя … в Волне‖Play the artist … in Volna
Включи плейлист … в Волне‖Включи плейлист … в Волне‖Play the playlist … in Volna
Название плеера в фразе обязательно. Пауза, следующая песня и громкость работают и без него, для того, что уже играет.‖Назва плеєра у фразі обов’язкова. Пауза, наступна пісня та гучність працюють і без неї, для того, що вже грає.‖The name of the player has to be in the phrase. Pause, next song and volume work without it for what is already playing.
Фразы работают на языке Siri: русском или английском. Украинского у Siri пока нет.‖Фрази працюють мовою Siri: російською або англійською. Української в Siri поки немає.‖Phrases work in the language of Siri: Russian or English. Siri has no Ukrainian yet.
Команды‖Команди‖Shortcuts
Эти же действия есть в приложении «Команды»: там их можно повесить на кнопку «Действие» или в автоматизацию.‖Ці ж дії є в застосунку «Команди»: там їх можна призначити кнопці «Дія» або додати в автоматизацію.‖The same actions are in the Shortcuts app, where they can go on the Action button or into an automation.
Исходный звук уже сжат с потерями, а по Bluetooth звук сжимается ещё раз. Каким способом, iPhone приложениям не сообщает (обычно AAC).‖Вихідний звук уже стиснутий із втратами, а по Bluetooth він стискається ще раз. Яким способом, iPhone застосункам не повідомляє (зазвичай AAC).‖The source is already lossy, and over Bluetooth the sound is compressed once more. The iPhone does not tell apps how (usually AAC).
Исходный звук сжат с потерями, лучше него на выходе не станет. Динамики iPhone работают на своей частоте, в таком случае это почти не слышно.‖Вихідний звук стиснутий із втратами, кращим за нього звук на виході не стане. Динаміки iPhone працюють на своїй частоті, у такому разі це майже не чутно.‖The source is lossy, the output cannot be better than it. The iPhone speakers have their own rate, with such sound it can hardly be heard.
Исходный звук сжат с потерями, лучше него на выходе не станет.‖Вихідний звук стиснутий із втратами, кращим за нього звук на виході не стане.‖The source is lossy, the output cannot be better than it.
Радио‖Радіо‖Radio
Избранное‖Обране‖Favourites
Станции‖Станції‖Stations
Вернуться к песням‖Повернутися до пісень‖Back to the songs
Добавить по ссылке‖Додати за посиланням‖Add by link
Добавить список станций‖Додати список станцій‖Add a list of stations
Это поток HLS, а не список станций‖Це потік HLS, а не список станцій‖This is an HLS stream, not a list of stations
В этом списке нет ссылок на станции‖У цьому списку немає посилань на станції‖There are no links to stations in this list
Добавлено станций: {}‖Додано станцій: {}‖Stations added: {}
пропущено строк: {}‖пропущено рядків: {}‖lines skipped: {}
Это не похоже на ссылку‖Це не схоже на посилання‖This does not look like a link
Станция «{}» добавлена‖Станцію «{}» додано‖Station “{}” added
Эта станция уже есть‖Така станція вже є‖This station is already there
Не удалось открыть ссылку: {}‖Не вдалося відкрити посилання: {}‖Could not open the link: {}
станции по этой ссылке больше нет‖станції за цим посиланням більше немає‖there is no station at this link any more
станция отвечает ошибкой {}‖станція відповідає помилкою {}‖the station answers with error {}
потоки HLS (.m3u8) пока не поддерживаются‖потоки HLS (.m3u8) поки не підтримуються‖HLS streams (.m3u8) are not supported yet
потоки OGG и Opus пока не поддерживаются‖потоки OGG і Opus поки не підтримуються‖OGG and Opus streams are not supported yet
это видео, а не радио‖це відео, а не радіо‖this is video, not radio
по этой ссылке не радиопоток‖за цим посиланням не радіопотік‖there is no radio stream at this link
формат этого потока не распознан‖формат цього потоку не розпізнано‖the format of this stream is not recognised
станция прервала передачу‖станція перервала передачу‖the station stopped sending
Прямой эфир‖Прямий ефір‖Live
Подключаюсь…‖Підключаюся…‖Connecting…
Набираю запас звука…‖Набираю запас звуку…‖Buffering…
Связь пропала, подключаюсь снова…‖Зв’язок зник, підключаюся знову…‖Connection lost, connecting again…
На паузе‖На паузі‖Paused
запас {} с‖запас {} с‖{} s in store
Новая станция‖Нова станція‖New station
Изменить станцию‖Змінити станцію‖Edit the station
Ссылка‖Посилання‖Link
Вставить из буфера‖Вставити з буфера‖Paste
Подходит ссылка на поток (MP3, AAC) или на целый список .m3u или .pls. Название можно не писать.‖Підійде посилання на потік (MP3, AAC) або на цілий список .m3u чи .pls. Назву можна не писати.‖A link to a stream (MP3, AAC) or to a whole .m3u or .pls list will do. The name may be left empty.
Открываю ссылку…‖Відкриваю посилання…‖Opening the link…
Станций пока нет. Добавьте список .m3u или .pls из «Файлов» или вставьте ссылку.‖Станцій поки немає. Додайте список .m3u або .pls із «Файлів» чи вставте посилання.‖No stations yet. Add a .m3u or .pls list from Files, or paste a link.
Поиск станции…‖Пошук станції…‖Search stations…
станция‖станція‖station
станции‖станції‖stations
станций‖станцій‖stations
HLS, пока не играет‖HLS, поки не грає‖HLS, not playable yet
Изменить…‖Змінити…‖Edit…
Убрать станции из плеера: {}?‖Прибрати станції з плеєра: {}?‖Remove stations from the player: {}?
Убрать станции‖Прибрати станції‖Remove stations
Список‖Список‖List
Включи радио … в Волне‖Включи радио … в Волне‖Play the radio … in Volna
Такой станции нет‖Такої станції немає‖There is no such station
Станций в плеере пока нет‖Станцій у плеєрі поки немає‖There are no stations in the player yet
"""#
}
