# Волна (Swift)

Нативная версия музыкального плеера «Волна» для iPhone: SwiftUI + AVAudioEngine.
Со временем заменит обёртку на Capacitor ([volna-ios](https://github.com/Neoss75/volna-ios)).

- Проект Xcode описан в `project.yml` (XcodeGen) и создаётся на сборочном Mac, `.xcodeproj` в репозитории нет.
- Сборка: GitHub Actions, `.github/workflows/testflight.yml` (macOS 15, Xcode 26). Без ключей Apple только проверяет сборку и сохраняет неподписанный `Volna-swift.ipa`; с ключами подписывает и отправляет в TestFlight.
- Bundle id `com.neoss75.volna.swift`, iOS 26+, только iPhone.
- Все текстовые файлы с переносами строк LF (`.gitattributes`, проверка в сборке).

## Что внутри

| Файл | Что делает |
|---|---|
| `Sources/Volna/Player.swift` | воспроизведение через AVAudioEngine, 10-полосный эквалайзер, фон, прерывания |
| `Sources/Volna/NowPlaying.swift` | экран блокировки и пульт: play/pause, предыдущая/следующая, перемотка |
| `Sources/Volna/Library.swift` | список песен; файлы остаются в «Файлах», хранятся закладки (bookmarks) |
| `Sources/Volna/MetadataReader.swift` | теги и обложки через AVAsset |
| `Sources/Volna/Views/` | экраны: список, мини-плеер, большой плеер, эквалайзер |
