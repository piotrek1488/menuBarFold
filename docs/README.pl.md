# MenuBarFold

MenuBarFold to natywna aplikacja dla macOS 27, która porządkuje ikony na górnym pasku. Użytkownik sam wybiera, które aplikacje mają być zawsze widoczne, które pojawiają się po rozwinięciu głównej sekcji, a które pozostają za osobnym przyciskiem sekcji „Zawsze ukryte”.

Aplikacja jest napisana w Swift, SwiftUI i AppKit. Domyślnym językiem jest angielski, a polski można wybrać w ustawieniach.

## Pobieranie i instalacja

1. Pobierz najnowszy plik `MenuBarFold-<wersja>.dmg` z [GitHub Releases](../../../releases/latest).
2. Otwórz DMG i przeciągnij **MenuBarFold** na skrót **Applications**.
3. Uruchom `/Applications/MenuBarFold.app`.
4. Przyznaj dostęp w **Ustawienia systemowe → Prywatność i bezpieczeństwo → Dostępność**.
5. Wybierz **Ułóż ikony** i ustaw trzy strefy paska menu.

Publiczny DMG jest podpisany certyfikatem Developer ID, sprawdzony przez usługę notaryzacji Apple i ma dołączoną sumę SHA-256. Aplikacja musi pozostać w systemowym katalogu `/Applications`; kopia uruchomiona z innego miejsca celowo nie włączy filtrowania ikon.

Używamy DMG zamiast instalatora PKG, ponieważ MenuBarFold jest jedną samodzielną aplikacją. Oba formaty wymagają notaryzacji, a PKG dołożyłby osobny certyfikat Developer ID Installer bez poprawy tego sposobu instalacji. Szczegóły są w [instrukcji wydania](RELEASING.pl.md).

## Obecne działanie paska

Przytrzymaj Command i ułóż elementy w takiej kolejności:

```text
ikony zawsze ukryte   |   zwykłe ukryte ikony   <   ikony zawsze widoczne
```

Przyciski działają następująco:

| Stan | Widoczne elementy |
| --- | --- |
| Wszystko zwinięte | Tylko główny przycisk `<` i ikony zawsze widoczne |
| Otwarta zwykła sekcja | Zwykłe ukryte ikony, separator `|`, drugi przycisk `<` i główny przycisk `>` |
| Otwarta sekcja „Zawsze ukryte” | Obie ukryte sekcje są widoczne, a drugi przycisk zmienia się w `>` |
| Kliknięcie głównego `>` | Obie ukryte sekcje zostają zwinięte i pozostaje tylko główny `<` |

Drugi przycisk celowo pozostaje w jednym miejscu po rozwinięciu sekcji „Zawsze ukryte”. Przenoszenie go za ostatnią ikonę wymagałoby ponownego układania elementów przez macOS po każdym kliknięciu.

MenuBarFold nie wymusza już systemowego przycisku `«` i nie tworzy sztucznych elementów poszerzających pasek. Główna strzałka, separator oraz druga strzałka mają stałą tożsamość przez cały czas działania aplikacji. Dzięki temu sama aplikacja nie przestawia ikon podczas zwijania, a zachowanie jest takie samo na ekranie MacBooka z notchem, monitorach bez notcha i w układach z wieloma ekranami.

Po aktualizacji ze starszej wersji, która używała systemowego overflow, wejdź raz w **Ułóż ikony** i ustaw właściwą kolejność. Następne zwinięcia nie tworzą już elementów paska od nowa.

## Funkcje

- Osobne sekcje ikon zwykle ukrytych i zawsze ukrytych.
- Główna strzałka, która pozostaje dostępna przy zwiniętym pasku.
- Stała druga strzałka, pojawiająca się dopiero po otwarciu zwykłej sekcji.
- Układanie ikon przez Command + przeciągnięcie z separatorem `|`.
- Automatyczne zwijanie po wybranym czasie.
- Rozwijanie po najechaniu kursorem.
- Globalne skróty klawiaturowe.
- Uruchamianie po zalogowaniu.
- Obsługa wielu monitorów, z notchem i bez notcha.
- Bezpieczne odświeżanie po zmianie ekranów, wybudzeniu oraz uruchomieniu lub zamknięciu aplikacji.
- Ochrona wskaźników mikrofonu i kamery przez tymczasowe pokazanie całego paska.
- Interfejs po angielsku i polsku, Dark Mode, nawigacja klawiaturą i etykiety VoiceOver.
- Brak analityki, sieci, konta, procesu pomocniczego i komend powłoki w aplikacji.

## Dlaczego macOS 27 wymaga nowego rozwiązania

macOS 27 zmienił wewnętrzną budowę paska menu. Poszerzanie separatora nie ukrywa już niezawodnie sąsiednich ikon, a MenuBarAgent nie udostępnia dawnego układu osobnych okien dla każdej ikony. MenuBarFold odczytuje właściciela i położenie elementów przez Accessibility, a następnie dynamicznie używa mechanizmu widoczności z macOS 27, aby dopuścić tylko potrzebne aplikacje.

Ten mechanizm jest prywatny i nie działa w aplikacji z sandboxem App Store. MenuBarFold ładuje go dopiero podczas działania i stosuje zasadę „fail open”: jeśli uprawnienie, framework, geometria ekranów albo klasyfikacja ikon są niepewne, ograniczenie zostaje zwolnione i pojawia się cały pasek.

## Wymagania

- macOS 27.0 lub nowszy.
- Przyznane uprawnienie Accessibility.
- Instalacja w systemowym katalogu `/Applications`.
- Dystrybucja bezpośrednia poza Mac App Store i bez App Sandbox.
- Stały podpis aplikacji. Wydania używają Developer ID; lokalny build wybiera dostępny certyfikat deweloperski, a w ostateczności podpis tymczasowy.

Kod można kompilować na macOS 14+ w zwykłym CI. Publiczne wydanie powstaje na runnerze GitHub `xcode-27` i deklaruje macOS 27 jako minimalną wersję systemu.

## Lokalne budowanie i uruchamianie

Testowane środowisko to macOS 27, Xcode 27 i Swift 6.4.

```sh
git clone <adres-repozytorium>
cd MenuBarFold
./script/build_and_run.sh --verify
```

Skrypt buduje `dist/MenuBarFold.app`, podpisuje aplikację pierwszym dostępnym lokalnym certyfikatem, instaluje dokładnie ten pakiet jako `/Applications/MenuBarFold.app`, uruchamia go i sprawdza proces.

Przydatne polecenia:

```sh
./script/build_and_run.sh --test
./script/build_and_run.sh --diagnose
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
```

Ekran „O aplikacji” odczytuje wersję z `CFBundleShortVersionString`, więc pokazuje numer lokalnego buildu albo taga wydania.

## Publikowanie wydania DMG

Repozytorium zawiera [workflow wydania](../.github/workflows/release.yml), który:

1. pobiera istniejący tag `vMAJOR.MINOR.PATCH`;
2. uruchamia testy na runnerze `xcode-27`;
3. importuje certyfikat Developer ID Application z sekretów GitHub Actions;
4. buduje uniwersalną aplikację `arm64 + x86_64` z Hardened Runtime;
5. tworzy, podpisuje, notaryzuje i stapluje DMG;
6. generuje sumę SHA-256;
7. tworzy GitHub Release i dodaje oba pliki.

Po jednorazowej konfiguracji certyfikatu i sekretów opisanej w [instrukcji wydania](RELEASING.pl.md) nową wersję publikuje się tak:

```sh
git tag -a v0.2.0 -m "MenuBarFold 0.2.0"
git push origin v0.2.0
```

Workflow można również uruchomić ponownie ręcznie dla istniejącego taga przez **Actions → Release DMG**.

## Ograniczenia macOS 27

- Ukrywanie działa na poziomie całej aplikacji, nie pojedynczej ikony. Jeżeli jedna aplikacja ma kilka ikon, wygrywa jej najbardziej widoczne położenie.
- Elementy systemowe Apple, takie jak zegar, Centrum sterowania, Wi-Fi, dźwięk i bateria, pozostają widoczne.
- Now Playing i Live Activities mogą zniknąć podczas aktywnego ograniczenia.
- Kliknięcie zegara może nie otworzyć Centrum powiadomień do czasu rozwinięcia paska.
- Ostateczną kolejnością nadal zarządza macOS. MenuBarFold nie rejestruje ponownie swoich kontrolek podczas zwijania, ale nie może zabronić systemowi lub innej aplikacji odtworzenia albo przesunięcia ikony po restarcie czy zmianie ekranów.
- Systemowy przycisk `«` może pojawić się naturalnie, gdy macOS zabraknie miejsca. MenuBarFold go nie ustawia i nim nie steruje.
- Przyszła aktualizacja macOS może zmienić albo usunąć prywatny mechanizm widoczności.

Podczas użycia mikrofonu lub kamery MenuBarFold zwalnia ograniczenie, aby zachować systemowy wskaźnik prywatności. macOS nie udostępnia publicznego API do wykrywania nagrywania ekranu przez inną aplikację, więc szeroki wskaźnik nagrywania nie może korzystać z tej samej ochrony.

Więcej informacji zawierają dokumenty [Architektura](ARCHITECTURE.md), [Wydawanie aplikacji](RELEASING.pl.md), [Contributing](../CONTRIBUTING.md) i [Security](../SECURITY.md).
