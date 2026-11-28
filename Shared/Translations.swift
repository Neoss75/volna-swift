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
передана по Wi-Fi‖передана по Wi-Fi‖sent over Wi-Fi
в iCloud Drive‖в iCloud Drive‖in iCloud Drive
на внешнем диске‖на зовнішньому диску‖on an external drive
на iPhone‖на iPhone‖on iPhone
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
Только названия песен и исполнителей: в iTunes для поиска обложек, если он включён, и на lrclib.net, когда вы ищете текст, включён его автопоиск или тексты для радио. Радио подключается к серверам станций. Сами файлы, статистика и плейлисты остаются на телефоне.‖Лише назви пісень і виконавців: в iTunes для пошуку обкладинок, якщо його увімкнено, і на lrclib.net, коли ви шукаєте текст, увімкнено його автопошук або тексти для радіо. Радіо підключається до серверів станцій. Самі файли, статистика та плейлисти залишаються на телефоні.‖Only names of songs and artists: to iTunes for cover search, if it is on, and to lrclib.net when you look for lyrics, or their automatic search or lyrics for the radio are on. The radio connects to the servers of the stations. Files, statistics and playlists stay on the phone.
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
этот вид HLS не поддерживается‖цей вид HLS не підтримується‖this kind of HLS is not supported
потоки OGG и Opus пока не поддерживаются‖потоки OGG і Opus поки не підтримуються‖OGG and Opus streams are not supported yet
это видео, а не радио‖це відео, а не радіо‖this is video, not radio
по этой ссылке не радиопоток‖за цим посиланням не радіопотік‖there is no radio stream at this link
формат этого потока не распознан‖формат цього потоку не розпізнано‖the format of this stream is not recognised
станция прервала передачу‖станція перервала передачу‖the station stopped sending
Прямой эфир‖Прямий ефір‖Live
Подключаюсь…‖Підключаюся…‖Connecting…
≈ {} МБ/ч‖≈ {} МБ/год‖≈ {} MB/h
≈ %.1f ГБ/ч‖≈ %.1f ГБ/год‖≈ %.1f GB/h
Заполняю буфер: {} из {} с‖Заповнюю буфер: {} з {} с‖Buffering: {} of {} s
буфер‖буфер‖buffer
Радио: буфер‖Радіо: буфер‖Radio: buffer
Столько звука плеер набирает, прежде чем заиграть. Больше буфер: реже прерывается при плохой связи, но станция дольше включается.‖Стільки звуку плеєр набирає, перш ніж заграти. Більший буфер: рідше переривається за поганого зв’язку, але станція довше вмикається.‖The player collects this much sound before it plays. A bigger buffer means fewer breaks on a poor connection, but stations take longer to start.
Связь пропала, подключаюсь снова…‖Зв’язок зник, підключаюся знову…‖Connection lost, connecting again…
На паузе‖На паузі‖Paused
буфер {} с‖буфер {} с‖buffer {} s
Новая станция‖Нова станція‖New station
Изменить станцию‖Змінити станцію‖Edit the station
Ссылка‖Посилання‖Link
Вставить из буфера‖Вставити з буфера‖Paste
Подходит ссылка на поток (MP3, AAC, HLS) или на целый список .m3u или .pls. Название можно не писать.‖Підійде посилання на потік (MP3, AAC, HLS) або на цілий список .m3u чи .pls. Назву можна не писати.‖A link to a stream (MP3, AAC, HLS) or to a whole .m3u or .pls list will do. The name may be left empty.
Открываю ссылку…‖Відкриваю посилання…‖Opening the link…
Станций пока нет. Добавьте список .m3u или .pls из «Файлов» или вставьте ссылку.‖Станцій поки немає. Додайте список .m3u або .pls із «Файлів» чи вставте посилання.‖No stations yet. Add a .m3u or .pls list from Files, or paste a link.
Поиск станции…‖Пошук станції…‖Search stations…
станция‖станція‖station
станции‖станції‖stations
станций‖станцій‖stations
Изменить…‖Змінити…‖Edit…
Убрать станции из плеера: {}?‖Прибрати станції з плеєра: {}?‖Remove stations from the player: {}?
Убрать станции‖Прибрати станції‖Remove stations
Список‖Список‖List
Включи радио … в Волне‖Включи радио … в Волне‖Play the radio … in Volna
Такой станции нет‖Такої станції немає‖There is no such station
Станций в плеере пока нет‖Станцій у плеєрі поки немає‖There are no stations in the player yet
Проверить‖Перевірити‖Check
Проверить станции‖Перевірити станції‖Check the stations
не отвечает‖не відповідає‖no answer
Проверить, какие станции отвечают, и узнать их формат: {}? Займёт до {} мин и скачает до {} МБ, лучше по Wi-Fi. Не закрывайте плеер.‖Перевірити, які станції відповідають, і дізнатися їхній формат: {}? Займе до {} хв і завантажить до {} МБ, краще по Wi-Fi. Не закривайте плеєр.‖Check which stations answer and what they send: {}? Takes up to {} min and downloads up to {} MB, better on Wi-Fi. Keep the player open.
Убрать из плеера неответившие станции: {}? Они могли не ответить и из-за вашей сети. Избранные останутся.‖Прибрати з плеєра станції, що не відповіли: {}? Вони могли не відповісти й через вашу мережу. Обрані залишаться.‖Remove the stations that did not answer: {}? Your network may be the reason, too. Favourites stay.
Проверено {} из {}‖Перевірено {} з {}‖Checked {} of {}
Проверка закончена: {} из {}‖Перевірку завершено: {} з {}‖Check finished: {} of {}
Ни одна станция не ответила. Есть ли интернет?‖Жодна станція не відповіла. Чи є інтернет?‖No station answered. Is there internet?
отвечают: {} · молчат: {} · не тот формат: {}‖відповідають: {} · мовчать: {} · не той формат: {}‖answer: {} · silent: {} · wrong format: {}
Стоп‖Стоп‖Stop
Убрать ({})‖Прибрати ({})‖Remove ({})
Убрано станций: {}‖Прибрано станцій: {}‖Stations removed: {}
Наушники‖Навушники‖Headphones
Профиль не выбран‖Профіль не вибрано‖No profile
Сейчас подключено‖Зараз підключено‖Connected now
Профиль включён‖Профіль увімкнено‖Profile is on
Включён прямой вывод, поэтому профиль обойдён.‖Увімкнено прямий вивід, тому профіль не діє.‖Direct output is on, so the profile is bypassed.
С профилем звук тише: он опускает громкость, чтобы не было искажений. Сравнивайте на одинаковой громкости.‖З профілем звук тихіший: він знижує гучність, щоб не було спотворень. Порівнюйте на однаковій гучності.‖With a profile the sound is quieter: it lowers the volume to avoid distortion. Compare at the same loudness.
Убрать с этого устройства‖Прибрати з цього пристрою‖Remove from this device
Профиль не выбран. Найдите свою модель ниже.‖Профіль не вибрано. Знайдіть свою модель нижче.‖No profile yet. Find your model below.
Похоже, это одна из этих моделей:‖Схоже, це одна з цих моделей:‖Looks like one of these models:
Найти модель‖Знайти модель‖Find a model
AirPods, Sony, Sennheiser…‖AirPods, Sony, Sennheiser…‖AirPods, Sony, Sennheiser…
Из файла‖З файлу‖From a file
Свой профиль‖Свій профіль‖Own profile
Мой профиль‖Мій профіль‖My profile
Мои профили‖Мої профілі‖My profiles
Профиль: {}‖Профіль: {}‖Profile: {}
Профиль «{}» добавлен‖Профіль «{}» додано‖Profile “{}” added
Настроить‖Налаштувати‖Adjust
Другие устройства‖Інші пристрої‖Other devices
Плеер сам меняет профиль, когда вы подключаете другие наушники.‖Плеєр сам змінює профіль, коли ви підключаєте інші навушники.‖The player changes the profile by itself when you connect other headphones.
Без профиля‖Без профілю‖No profile
Забыть устройство‖Забути пристрій‖Forget the device
Откуда профили‖Звідки профілі‖Where the profiles come from
Измерения {} моделей из открытого проекта AutoEq (лицензия MIT). Профиль выравнивает звук наушников, поверх него работает обычный эквалайзер.‖Вимірювання {} моделей із відкритого проєкту AutoEq (ліцензія MIT). Профіль вирівнює звук навушників, поверх нього працює звичайний еквалайзер.‖Measurements of {} models from the open AutoEq project (MIT licence). A profile evens out the sound of the headphones, the usual equaliser works on top of it.
Профили наушников: AutoEq, © Jaakko Pasanen, лицензия MIT.‖Профілі навушників: AutoEq, © Jaakko Pasanen, ліцензія MIT.‖Headphone profiles: AutoEq, © Jaakko Pasanen, MIT licence.
В этом файле нет фильтров. Подходит файл ParametricEQ из AutoEq.‖У цьому файлі немає фільтрів. Підійде файл ParametricEQ з AutoEq.‖There are no filters in this file. A ParametricEQ file of AutoEq will do.
фильтр‖фільтр‖filter
фильтра‖фільтри‖filters
фильтров‖фільтрів‖filters
{} Гц‖{} Гц‖{} Hz
Самое громкое место поднято на {}: возможны искажения.‖Найгучніше місце піднято на {}: можливі спотворення.‖The loudest point is raised by {}: distortion is possible.
Убавить предусилитель‖Зменшити передпідсилювач‖Lower the preamp
Добавить фильтр‖Додати фільтр‖Add a filter
Удалить фильтр‖Видалити фільтр‖Remove the filter
Вернуть как было‖Повернути як було‖Undo all
Точный эквалайзер‖Точний еквалайзер‖Precise equaliser
Готово‖Готово‖Done
Вид‖Вид‖Kind
Усиление‖Підсилення‖Gain
Острота (Q)‖Гострота (Q)‖Sharpness (Q)
Низкая полка‖Низька полиця‖Low shelf
Колокол‖Дзвін‖Bell
Высокая полка‖Висока полиця‖High shelf
профиль «{}»‖профіль «{}»‖profile “{}”
разбито по .cue: {}‖розбито за .cue: {}‖cut by .cue: {}
Выберите вместе с .cue сам музыкальный файл или добавьте папку целиком‖Виберіть разом із .cue сам музичний файл або додайте папку цілком‖Pick the music file together with the .cue, or add the whole folder
Дорожка {}‖Доріжка {}‖Track {}
Передача по Wi-Fi‖Передача через Wi-Fi‖Transfer over Wi-Fi
Музыка с компьютера через браузер‖Музика з комп’ютера через браузер‖Music from a computer in a browser
Как это работает‖Як це працює‖How it works
1. Откройте адрес выше в браузере на компьютере: Chrome, Edge, Safari или Firefox.‖1. Відкрийте адресу вище в браузері на комп’ютері: Chrome, Edge, Safari або Firefox.‖1. Open the address above in a browser on the computer: Chrome, Edge, Safari or Firefox.
2. Перетащите в окно браузера файлы или целые папки с музыкой.‖2. Перетягніть у вікно браузера файли або цілі папки з музикою.‖2. Drag files or whole music folders into the browser window.
3. Песни появятся в списке, в разделе «Папки» → «Wi-Fi».‖3. Пісні з’являться у списку, в розділі «Папки» → «Wi-Fi».‖3. The songs appear in the list, under Folders → Wi-Fi.
Приём работает, пока открыт этот экран, телефон при этом не гаснет.‖Приймання працює, поки відкритий цей екран, телефон при цьому не гасне.‖Receiving works while this screen is open, and the phone screen stays on.
Файлы лежат в «Файлах»: «На iPhone» → «Волна» → «Wi-Fi». Если убрать такую песню из плеера, её файл тоже удалится.‖Файли лежать у «Файлах»: «На iPhone» → «Волна» → «Wi-Fi». Якщо прибрати таку пісню з плеєра, її файл теж видалиться.‖The files are in Files: On My iPhone → Volna → Wi-Fi. Removing such a song from the player deletes its file too.
Адрес для браузера‖Адреса для браузера‖Address for the browser
Запускаю приём…‖Запускаю приймання…‖Starting…
Приём не запустился. Закройте этот экран и откройте снова.‖Приймання не запустилося. Закрийте цей екран і відкрийте знову.‖Receiving did not start. Close this screen and open it again.
Нет Wi-Fi‖Немає Wi-Fi‖No Wi-Fi
Подключите телефон к той же сети Wi-Fi, что и компьютер. Адрес появится сам.‖Підключіть телефон до тієї самої мережі Wi-Fi, що й комп’ютер. Адреса з’явиться сама.‖Connect the phone to the same Wi-Fi network as the computer. The address will appear by itself.
Принимаю: {}‖Приймаю: {}‖Receiving: {}
Жду файлы с компьютера‖Чекаю файли з комп’ютера‖Waiting for files from the computer
Телефон и компьютер должны быть в одной сети Wi-Fi.‖Телефон і комп’ютер мають бути в одній мережі Wi-Fi.‖The phone and the computer must be on the same Wi-Fi network.
Принято‖Отримано‖Received
Файлов: {}‖Файлів: {}‖Files: {}
Уже были на телефоне: {}‖Вже були на телефоні: {}‖Already on the phone: {}
Неподходящее имя файла‖Невідповідна назва файлу‖Unsuitable file name
Это не музыка‖Це не музика‖This is not music
на телефоне нет места‖на телефоні немає місця‖no room on the phone
На телефоне нет места‖На телефоні немає місця‖No room on the phone
Не получилось сохранить файл‖Не вдалося зберегти файл‖The file could not be saved
не получилось сохранить‖не вдалося зберегти‖could not be saved
связь оборвалась‖зв’язок обірвався‖the connection broke
Волна: передача музыки‖Волна: передача музики‖Volna: music transfer
Файлы попадут на iPhone и сразу появятся в списке песен.‖Файли потраплять на iPhone і одразу з’являться у списку пісень.‖The files go to the iPhone and appear in the song list right away.
Перетащите сюда файлы или папки с музыкой‖Перетягніть сюди файли або папки з музикою‖Drop music files or folders here
Выбрать файлы‖Вибрати файли‖Choose files
Выбрать папку‖Вибрати папку‖Choose a folder
Не закрывайте на телефоне экран передачи, пока идёт отправка. Телефон и компьютер должны быть в одной сети Wi-Fi.‖Не закривайте на телефоні екран передачі, поки триває надсилання. Телефон і комп’ютер мають бути в одній мережі Wi-Fi.‖Keep the transfer screen open on the phone while sending. The phone and the computer must be on the same Wi-Fi network.
ждёт‖чекає‖waiting
Отправляю: {}‖Надсилаю: {}‖Sending: {}
на телефоне‖на телефоні‖on the phone
уже было‖вже було‖already there
не отправлено‖не надіслано‖not sent
нет связи с телефоном‖немає зв’язку з телефоном‖no connection to the phone
Пропущено, не музыка: {}‖Пропущено, не музика: {}‖Skipped, not music: {}
Уже на телефоне: {}‖Вже на телефоні: {}‖Already on the phone: {}
МБ‖МБ‖MB
ГБ‖ГБ‖GB
Отправка ещё идёт‖Надсилання ще триває‖Still sending
Выше или ниже на полутоны, скорость при этом не меняется. Удобно, чтобы подпевать в своей тональности.‖Вище або нижче на півтони, швидкість при цьому не змінюється. Зручно, щоб підспівувати у своїй тональності.‖Higher or lower in semitones, the speed stays the same. Handy for singing along in your own key.
Двойное нажатие: в избранное‖Подвійне натискання: в обране‖Double tap: favourite
Лёгкая вибрация при нажатиях‖Легка вібрація при натисканнях‖Light vibration on taps
Обычная тональность‖Звичайна тональність‖Normal pitch
Остановлю в конце песни‖Зупиню в кінці пісні‖I will stop at the end of the song
Остановлю через {} минут‖Зупиню через {} хвилин‖I will stop in {} minutes
Отклик‖Відгук‖Feedback
Следующая настройка эквалайзера‖Наступне налаштування еквалайзера‖Next equaliser preset
Таймер сна выключен‖Таймер сну вимкнено‖Sleep timer off
Такой настройки нет‖Такого налаштування немає‖No such preset
Телефон слегка отзывается на кнопки плеера, смахивание обложки и лайк.‖Телефон злегка відгукується на кнопки плеєра, змахування обкладинки та лайк.‖The phone responds lightly to the player buttons, cover swipes and likes.
Тональность‖Тональність‖Pitch
Эквалайзер выключен‖Еквалайзер вимкнено‖Equaliser off
Эквалайзер: ‖Еквалайзер: ‖Equaliser:
обычная‖звичайна‖normal
тональность {}‖тональність {}‖pitch {}
Таймер сна 30 минут в Волне‖Таймер сну 30 хвилин у Волні‖Sleep timer 30 minutes in Volna
Эквалайзер Рок в Волне‖Еквалайзер Рок у Волні‖Equaliser Rock in Volna
Пункт управления‖Пункт керування‖Control Centre
Кнопки «Волны» можно добавить в Пункт управления и на экран блокировки: играть или пауза, следующая песня, эквалайзер. Откройте Пункт управления, нажмите «+», затем «Добавить элемент» и найдите «Волна».‖Кнопки «Волни» можна додати в Пункт керування та на екран блокування: грати або пауза, наступна пісня, еквалайзер. Відкрийте Пункт керування, натисніть «+», потім «Додати елемент» і знайдіть «Волна».‖Volna buttons can be added to Control Centre and the Lock Screen: play or pause, next song, equaliser. Open Control Centre, tap «+», then Add a Control, and look for Volna.
В iTunes и на lrclib.net отправятся только исполнитель и название песни. Выключить можно в настройках, в разделе «Обложки».‖До iTunes і на lrclib.net підуть лише виконавець і назва пісні. Вимкнути можна в налаштуваннях, у розділі «Обкладинки».‖Only the artist and the song title go to iTunes and lrclib.net. You can turn this off in the settings, under “Covers”.
Включить‖Увімкнути‖Turn on
Волна может найти текст и обложку песни, которая сейчас играет на радио.‖Волна може знайти текст і обкладинку пісні, що зараз грає на радіо.‖Volna can find the lyrics and the cover of the song playing on the radio now.
Когда станция сообщает, какая песня играет, Волна ищет её обложку в iTunes и текст на lrclib.net. Отправляются только исполнитель и название. Текст открывается кнопкой с облачком. По умолчанию выключено.‖Коли станція повідомляє, яка пісня грає, Волна шукає її обкладинку в iTunes і текст на lrclib.net. Надсилаються лише виконавець і назва. Текст відкривається кнопкою з хмаринкою. Типово вимкнено.‖When the station says which song is playing, Volna looks for its cover on iTunes and its lyrics on lrclib.net. Only the artist and the title are sent. The lyrics open with the speech bubble button. Off by default.
Обложки и тексты для радио‖Обкладинки й тексти для радіо‖Covers and lyrics for the radio
Станция не сообщает, какая песня сейчас играет.‖Станція не повідомляє, яка пісня зараз грає.‖The station does not say which song is playing.
Текста для этой песни не нашлось.‖Тексту для цієї пісні не знайшлося.‖No lyrics found for this song.
 из копии пока не найдены в плеере. Когда вы их добавите, Волна вернёт им избранное, плейлисты, тексты и исправленные названия.‖ з копії поки не знайдено в плеєрі. Коли ви їх додасте, Волна поверне їм обране, плейлисти, тексти та виправлені назви.‖ from the backup are not in the player yet. When you add them, Volna gives them back their favourites, playlists, lyrics and corrected names.
Больше не ждать‖Більше не чекати‖Stop waiting
В копию попадают настройки, эквалайзер, профили наушников, радиостанции, статистика, избранное, плейлисты, исправленные названия и тексты песен. Самой музыки в ней нет, поэтому файл маленький.‖До копії потрапляють налаштування, еквалайзер, профілі навушників, радіостанції, статистика, обране, плейлисти, виправлені назви та тексти пісень. Самої музики в ній немає, тому файл маленький.‖The backup holds the settings, the equaliser, headphone profiles, radio stations, statistics, favourites, playlists, corrected names and lyrics. The music itself is not in it, so the file is small.
Волна, копия‖Волна, копія‖Volna backup
Восстановить‖Відновити‖Restore
Восстановить из копии‖Відновити з копії‖Restore from a backup
Восстановить из копии?‖Відновити з копії?‖Restore from the backup?
Восстановление‖Відновлення‖Restoring
Всё, кроме музыки, в одном файле‖Усе, крім музики, в одному файлі‖Everything but the music in one file
Выберите файл копии. Настройки, станции, профили наушников и статистика заменятся теми, что в копии. Избранное и плейлисты добавятся к нынешним.‖Виберіть файл копії. Налаштування, станції, профілі навушників і статистика заміняться тими, що в копії. Обране та плейлисти додадуться до теперішніх.‖Pick the backup file. The settings, stations, headphone profiles and statistics are replaced with those in the backup. Favourites and playlists are added to the ones you have.
Ждут своих файлов‖Чекають на свої файли‖Waiting for their files
Ждут своих файлов: ‖Чекають на свої файли: ‖Waiting for their files: 
Копия восстановлена‖Копію відновлено‖Backup restored
Копия восстановлена. Узнано песен: {} из {}‖Копію відновлено. Упізнано пісень: {} з {}‖Backup restored. Songs recognised: {} of {}
Копия от {}.‖Копія від {}.‖Backup of {}.
Копия сохранена‖Копію збережено‖Backup saved
Лучше всего положить файл в iCloud Drive: тогда он не пропадёт вместе с телефоном.‖Найкраще покласти файл в iCloud Drive: тоді він не зникне разом із телефоном.‖iCloud Drive is the best place for the file: then it is not lost with the phone.
На новом телефоне сначала добавьте музыку, потом восстановите копию. Можно и наоборот: Волна узнает песни, когда вы их добавите.‖На новому телефоні спершу додайте музику, потім відновіть копію. Можна й навпаки: Волна впізнає пісні, коли ви їх додасте.‖On a new phone add the music first, then restore the backup. The other way round works too: Volna recognises the songs when you add them.
Настройки, станции, профили наушников и статистика будут заменены.‖Налаштування, станції, профілі навушників і статистику буде замінено.‖The settings, stations, headphone profiles and statistics will be replaced.
Не удалось сохранить копию‖Не вдалося зберегти копію‖Could not save the backup
Резервная копия‖Резервна копія‖Backup
Сохранить копию‖Зберегти копію‖Save a backup
Это не файл копии Волны‖Це не файл копії Волни‖This is not a Volna backup file
не удалось разобрать файл OGG‖не вдалося розібрати файл OGG‖could not read the OGG file
Повтор отрезка выключен‖Повтор відрізка вимкнено‖Loop off
Начало отрезка: {}. Нажмите ещё раз в конце‖Початок відрізка: {}. Натисніть ще раз у кінці‖Loop start: {}. Tap again at the end
Отрезок слишком короткий, нужна хотя бы секунда‖Відрізок закороткий, потрібна хоча б секунда‖Too short, at least one second is needed
Повтор отрезка {}–{}‖Повтор відрізка {}–{}‖Looping {}–{}
Повтор отрезка‖Повтор відрізка‖A-B loop
включён‖увімкнено‖on
начало отмечено, нажмите в конце‖початок позначено, натисніть у кінці‖start marked, tap at the end
Утро‖Ранок‖Morning
День‖День‖Day
Вечер‖Вечір‖Evening
Ночь‖Ніч‖Night
Здесь появятся песни, которые вы чаще всего слушаете в этом месяце.‖Тут з'являться пісні, які ви найчастіше слухаєте цього місяця.‖The songs you play most this month will appear here.
Здесь появятся песни, которые вы обычно слушаете в это время суток.‖Тут з'являться пісні, які ви зазвичай слухаєте в цю пору доби.‖The songs you usually play at this time of day will appear here.
Пропускать тишину в начале и в конце‖Пропускати тишу на початку й у кінці‖Skip silence at the start and the end
Если в начале или в конце песни есть тишина дольше пары десятых секунды, она не играет, и следующая песня начинается сразу. Тишина находится вместе с волной песни, поэтому у новых песен срабатывает со второго включения.‖Якщо на початку або в кінці пісні є тиша довша за кілька десятих секунди, вона не грає, і наступна пісня починається одразу. Тиша знаходиться разом із хвилею пісні, тому в нових пісень спрацьовує з другого увімкнення.‖If a song has more than a few tenths of a second of silence at the start or the end, it is not played and the next song starts at once. The silence is found together with the waveform, so for new songs it works from the second play.
AirPlay и другие колонки‖AirPlay та інші колонки‖AirPlay and other speakers
Искать текст сам‖Шукати текст самостійно‖Find lyrics by itself
Когда начинается песня без текста, Волна один раз спрашивает о ней lrclib.net и сохраняет найденное. Отправляются название, исполнитель и длительность. По умолчанию выключено.‖Коли починається пісня без тексту, Волна один раз питає про неї lrclib.net і зберігає знайдене. Надсилаються назва, виконавець і тривалість. Типово вимкнено.‖When a song without lyrics starts, Volna asks lrclib.net about it once and keeps what it finds. The title, artist and length are sent. Off by default.
Моно‖Моно‖Mono
Оба наушника играют одно и то же: удобно с одним наушником или когда одно ухо слышит хуже.‖Обидва навушники грають одне й те саме: зручно з одним навушником або коли одне вухо чує гірше.‖Both earphones play the same: handy with one earphone or when one ear hears less.
Поиск‖Пошук‖Search
Добавь в избранное в Волне‖Додай в обране у Волні‖Add to favourites in Volna
Одинаковых песен не нашлось.‖Однакових пісень не знайшлося.‖No identical songs found.
Отмечена копия, которая останется. Волна выбрала лучшую: без потерь, с большим битрейтом. Можно отметить другую.‖Позначено копію, яка залишиться. Волна вибрала найкращу: без втрат, з більшим бітрейтом. Можна позначити іншу.‖The marked copy stays. Volna picked the best one: lossless, with a higher bitrate. You can mark another.
Дубликаты‖Дублікати‖Duplicates
Убрать лишние‖Прибрати зайві‖Remove extra copies
Убрать из плеера: ‖Прибрати з плеєра: ‖Remove from the player: 
Файлы останутся в «Файлах» (кроме присланных по Wi-Fi). Лайки, плейлисты и статистика лишних копий перейдут к оставленной.‖Файли залишаться у «Файлах» (крім надісланих по Wi-Fi). Лайки, плейлисти та статистика зайвих копій перейдуть до залишеної.‖The files stay in Files (except those sent over Wi-Fi). Likes, playlists and statistics of the extra copies go to the one that stays.
Одинаковых песен нет.‖Однакових пісень немає.‖No identical songs.
Лишних копий: {}.‖Зайвих копій: {}.‖Extra copies: {}.
Найти дубликаты‖Знайти дублікати‖Find duplicates
Одинаковые — это те же исполнитель, название и длина. Волна предложит оставить лучшую копию, лишние уберёт из плеера, а их лайки, плейлисты и статистику передаст оставленной.‖Однакові — це ті самі виконавець, назва й тривалість. Волна запропонує залишити найкращу копію, зайві прибере з плеєра, а їхні лайки, плейлисти та статистику передасть залишеній.‖Identical means the same artist, title and length. Volna offers to keep the best copy, removes the extra ones from the player and gives their likes, playlists and statistics to the one that stays.
В дорогу‖У дорогу‖On the road
Кнопки плеера‖Кнопки плеєра‖Player buttons
Обычные‖Звичайні‖Standard
Стекло‖Скло‖Glass
Матовое‖Матове‖Frosted
Хром‖Хром‖Chrome
Прозрачность‖Прозорість‖Transparency
Если в настройках iPhone включено «Понижение прозрачности», кнопки становятся непрозрачными.‖Якщо в налаштуваннях iPhone увімкнено «Зменшення прозорості», кнопки стають непрозорими.‖If Reduce Transparency is on in the iPhone settings, the buttons become solid.
Будильник‖Будильник‖Alarm
Разрешите Волне будильники: Настройки iPhone → Приложения → Волна.‖Дозвольте Волні будильники: Параметри iPhone → Програми → Волна.‖Allow alarms for Volna: iPhone Settings → Apps → Volna.
Доброе утро‖Доброго ранку‖Good morning
Слушать‖Слухати‖Listen
Не удалось поставить будильник‖Не вдалося поставити будильник‖Could not set the alarm
Остановить в‖Зупинити о‖Stop at
Поставить‖Поставити‖Set
Таймер сна: остановлю в {}‖Таймер сну: зупиню о {}‖Sleep timer: stopping at {}
один раз‖один раз‖once
по будням‖у будні‖on weekdays
по выходным‖у вихідні‖at weekends
каждый день‖щодня‖every day
Будить в это время‖Будити в цей час‖Wake me at this time
Время‖Час‖Time
Дни не выбраны: будильник прозвонит один раз.‖Дні не вибрано: будильник продзвенить один раз.‖No days chosen: the alarm rings once.
Звонит как будильник iPhone: и в беззвучном режиме, и в «Не беспокоить».‖Дзвонить як будильник iPhone: і в беззвучному режимі, і в «Не турбувати».‖Rings like the iPhone alarm: in silent mode and in Do Not Disturb too.
Звонок‖Дзвінок‖Sound
Стандартный звук‖Стандартний звук‖Standard sound
Песня, что играет сейчас‖Пісня, що грає зараз‖The song playing now
Звучат первые 30 секунд песни. Чтобы выбрать другую, включите её и вернитесь сюда.‖Звучать перші 30 секунд пісні. Щоб вибрати іншу, увімкніть її та поверніться сюди.‖The first 30 seconds of the song ring. To choose another, play it and come back here.
После «Слушать»‖Після «Слухати»‖After Listen
Песня будильника‖Пісня будильника‖The alarm song
Вся музыка вперемешку‖Уся музика впереміш‖All music shuffled
Сразу громко‖Одразу гучно‖Loud at once
3 минуты‖3 хвилини‖3 minutes
Нажмите «Слушать» на будильнике: Волна откроется и включит музыку, громкость будет нарастать плавно.‖Натисніть «Слухати» на будильнику: Волна відкриється й увімкне музику, гучність наростатиме плавно.‖Tap Listen on the alarm: Volna opens and plays music that grows louder bit by bit.
Музыка без звонка‖Музика без дзвінка‖Music without an alarm
Чтобы музыка включалась сама: приложение «Команды» → «Автоматизация» → «Время суток» → «Запускать сразу» → действие Волны «Разбудить музыкой».‖Щоб музика вмикалася сама: програма «Команди» → «Автоматизація» → «Час доби» → «Запускати одразу» → дія Волни «Розбудити музикою».‖For music to start by itself: the Shortcuts app → Automation → Time of Day → Run Immediately → the Volna action Wake me with music.
"""#
}
