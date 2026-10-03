# MenuBarFold

MenuBarFold to natywna aplikacja dla macOS 27, która porządkuje ikony na górnym pasku. Użytkownik sam wybiera, które aplikacje mają być zawsze widoczne, które pojawiają się dopiero po rozwinięciu i które mają pozostać ukryte. Domyślnym językiem jest angielski; w ustawieniach można wybrać polski albo język systemu.

## Co potrafi

- Zwijanie i rozwijanie zwykłych ukrytych ikon główną strzałką, która zawsze pozostaje widoczna.
- Układanie ikon przez `Command + przeciągnięcie`.
- Opcjonalna sekcja zawsze ukryta z separatorem `|` i własną strzałką, widoczną dopiero po rozwinięciu głównej sekcji.
- Automatyczne zwijanie po wybranym czasie.
- Rozwijanie po najechaniu kursorem.
- Globalny skrót klawiszowy.
- Uruchamianie po zalogowaniu.
- Obsługa wielu monitorów.
- Ochrona wskaźników użycia mikrofonu i kamery.
- Interfejs po angielsku i polsku, Dark Mode oraz etykiety VoiceOver.
- Brak analityki, sieci, konta, odczytu plików i procesu pomocniczego.

## Jak używać

1. Uruchom aplikację i przyznaj jej dostęp w `Ustawienia systemowe → Prywatność i bezpieczeństwo → Dostępność`.
2. Przytrzymaj `Command` i ustaw ikony zawsze ukryte po lewej stronie separatora `|`.
3. Zwykłe ukryte ikony ustaw między separatorem `|` i główną strzałką, a widoczne ikony po prawej stronie głównej strzałki.
4. Główna strzałka `<` rozwija zwykłe ukryte ikony. Po rozwinięciu zmienia się w `>` i pojawia się druga strzałka sterująca sekcją zawsze ukrytą.
5. Kliknij strzałkę prawym przyciskiem, aby otworzyć szybkie menu. `Option + klik` włącza tryb układania.

## Budowanie

Projekt był testowany na macOS 27.0.1, Xcode 27 i Swift 6.4.

```sh
./script/build_and_run.sh --verify
```

Gotowa aplikacja powstanie w `dist/MenuBarFold.app`. Skrypt tworzy pakiet `.app`, kopiuje tłumaczenia, generuje ikonę, podpisuje wersję deweloperską i sprawdza, czy proces się uruchomił.

Testy i diagnostyka:

```sh
./script/build_and_run.sh --test
./script/build_and_run.sh --diagnose
```

## Ograniczenia macOS 27

Apple nie udostępnia publicznego API do ukrywania ikon innych aplikacji. Mechanizm dostępny w macOS 27 jest częścią trybu assessment, dlatego aplikacja musi być dystrybuowana poza App Store i działać bez sandboxa.

Podczas zwinięcia:

- ukrywanie działa na poziomie całej aplikacji, nie pojedynczej ikony;
- elementy systemowe Apple pozostają widoczne;
- Now Playing i Live Activities mogą zniknąć;
- kliknięcie zegara może nie otworzyć Centrum powiadomień do czasu rozwinięcia paska;
- przyszła aktualizacja macOS może zmienić prywatny mechanizm.

MenuBarFold stosuje zasadę „fail open”. Jeśli czegoś nie może ustalić bezpiecznie, pokazuje cały pasek. Podczas użycia mikrofonu lub kamery także zwalnia ograniczenie, aby zachować systemowe wskaźniki prywatności.

Więcej szczegółów zawierają dokumenty [Architektura](ARCHITECTURE.md) i [Wydanie aplikacji](RELEASING.md).
