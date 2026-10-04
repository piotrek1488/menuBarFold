# MenuBarFold

MenuBarFold to natywna aplikacja dla macOS 27, która porządkuje ikony na górnym pasku. Użytkownik sam wybiera, które aplikacje mają być zawsze widoczne, które pojawiają się dopiero po rozwinięciu i które mają pozostać ukryte. Domyślnym językiem jest angielski; w ustawieniach można wybrać polski albo język systemu.

## Co potrafi

- Zwijanie i rozwijanie zwykłych ukrytych ikon strzałką MenuBarFold, która zawsze pozostaje widoczna.
- Układanie ikon przez `Command + przeciągnięcie`.
- Osobna kompaktowa strzałka dla ikon zawsze ukrytych. Pojawia się dopiero po rozwinięciu zwykłej sekcji i pozostaje w stałym miejscu podczas pokazywania lub ukrywania tej strefy.
- Automatyczne zwijanie po wybranym czasie.
- Rozwijanie po najechaniu kursorem.
- Globalny skrót klawiszowy.
- Uruchamianie po zalogowaniu.
- Obsługa wielu monitorów.
- Ochrona wskaźników użycia mikrofonu i kamery.
- Interfejs po angielsku i polsku, Dark Mode oraz etykiety VoiceOver.
- Brak analityki, sieci, konta, odczytu plików i procesu pomocniczego.

## Jak używać

1. Umieść aplikację w systemowym katalogu `/Applications` (czyli `Aplikacje`) i uruchom ją stamtąd. Jest to wymagane w macOS 27; kopia uruchomiona z innego katalogu nie włączy ukrywania, aby nie zniknęły jej własne przyciski.
2. Przyznaj jej dostęp w `Ustawienia systemowe → Prywatność i bezpieczeństwo → Dostępność`.
3. Przytrzymaj `Command` i ustaw ikony zawsze ukryte po lewej stronie separatora `|`.
4. Zwykłe ukryte ikony ustaw między separatorem `|` i główną strzałką, a widoczne ikony po prawej stronie głównej strzałki.
5. Główna strzałka MenuBarFold `<` rozwija zwykłe ukryte ikony i zmienia się w `>`. Dopiero wtedy pojawia się druga strzałka `<`, która rozwija ikony zawsze ukryte i po rozwinięciu zmienia się w `>`.
6. Kliknij strzałkę prawym przyciskiem, aby otworzyć szybkie menu. `Option + klik` włącza tryb układania.

## Budowanie

Projekt był testowany na macOS 27.0.1, Xcode 27 i Swift 6.4.

```sh
./script/build_and_run.sh --verify
```

Gotowa aplikacja powstanie w `dist/MenuBarFold.app`. Skrypt tworzy pakiet `.app`, kopiuje tłumaczenia, generuje ikonę, podpisuje wersję deweloperską, instaluje tę samą podpisaną kopię jako `/Applications/MenuBarFold.app` i sprawdza, czy proces się uruchomił.

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
- macOS nadal zarządza końcową kolejnością paska. MenuBarFold zachowuje stałe identyfikatory swoich elementów i nie rejestruje ich ponownie podczas zwijania, ale nie może zablokować zmian wykonanych przez system lub inną aplikację po restarcie albo zmianie ekranów;
- przyszła aktualizacja macOS może zmienić prywatny mechanizm.

MenuBarFold stosuje zasadę „fail open”. Jeśli czegoś nie może ustalić bezpiecznie, pokazuje cały pasek. Podczas użycia mikrofonu lub kamery także zwalnia ograniczenie, aby zachować systemowe wskaźniki prywatności.

Więcej szczegółów zawierają dokumenty [Architektura](ARCHITECTURE.md) i [Wydanie aplikacji](RELEASING.md).
