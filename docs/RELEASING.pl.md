# Wydawanie aplikacji

MenuBarFold jest dystrybuowany bezpośrednio jako notaryzowany obraz DMG. Publiczne wydanie musi korzystać z certyfikatu **Developer ID Application**, Hardened Runtime, bezpiecznego znacznika czasu oraz notaryzacji Apple. Podpis Apple Development lub ad-hoc nadaje się wyłącznie do lokalnego developmentu.

Automatyczny proces znajduje się w `.github/workflows/release.yml`. Działa na runnerze GitHub `xcode-27`, buduje uniwersalną aplikację `arm64 + x86_64` i publikuje DMG w GitHub Releases.

## Dlaczego DMG zamiast PKG

Oba formaty wymagają podpisu Developer ID i notaryzacji Apple, jeśli instalacja ma przejść normalnie przez Gatekeepera. Płaski instalator `.pkg` wymagałby dodatkowo certyfikatu **Developer ID Installer**, a znajdująca się w nim aplikacja nadal musiałaby być podpisana certyfikatem **Developer ID Application**.

Apple zaleca instalator, gdy program składa się z wielu części, musi zapisywać pliki w kilku konkretnych miejscach albo uruchamia własny kod instalacyjny. MenuBarFold jest jedną samodzielną aplikacją kopiowaną do `/Applications`, dlatego DMG ma mniej sekretów i elementów procesu, nie wymaga interfejsu instalatora i łatwiej go później odinstalować. Do PKG warto wrócić dopiero wtedy, gdy aplikacja dostanie uprzywilejowany helper lub będzie instalować pliki poza własnym pakietem.

Workflow uwierzytelnia notaryzację zespołowym kluczem App Store Connect API. Samo zwykłe Apple ID nie wystarczy: certyfikat Developer ID jest dostępny w ramach Apple Developer Program, a dane do notaryzacji muszą należeć do tego zespołu deweloperskiego.

## Wynik workflow

Dla taga `v0.2.0` powstaną:

```text
MenuBarFold-0.2.0.dmg
MenuBarFold-0.2.0.dmg.sha256
```

Numer taga bez `v` staje się `CFBundleShortVersionString`, a numer uruchomienia GitHub Actions staje się numerycznym `CFBundleVersion`. Ekran „O aplikacji” odczytuje wersję bezpośrednio z gotowego pakietu.

DMG zawiera:

- wersję Release aplikacji;
- architektury Apple Silicon i Intel;
- stały identyfikator `io.github.menubarfold.MenuBarFold`;
- skrót do katalogu Applications;
- podpis Developer ID z Hardened Runtime i timestampem;
- dołączony bilet notaryzacji Apple.

Po opublikowaniu pierwszej wersji nie zmieniaj bundle ID. Uprawnienie Accessibility i zaufanie macOS zależą od tożsamości oraz podpisu aplikacji.

## Jednorazowa konfiguracja Apple

### 1. Certyfikat Developer ID Application

Dołącz do Apple Developer Program i utwórz [certyfikat Developer ID Application](https://developer.apple.com/help/account/certificates/create-developer-id-certificates). Certyfikat razem z kluczem prywatnym musi być widoczny w Keychain Access.

W **Keychain Access → My Certificates** wyeksportuj certyfikat oraz klucz prywatny do zabezpieczonego hasłem pliku `.p12`.

Profil provisioning nie jest potrzebny. MenuBarFold jest aplikacją macOS dystrybuowaną bezpośrednio, bez prywatnych entitlementów. App Sandbox musi pozostać wyłączony.

### 2. Zespołowy klucz App Store Connect API

W **App Store Connect → Users and Access → Integrations → Team Keys** utwórz zespołowy klucz API, który może korzystać z usługi notaryzacji. Plik `.p8` pobierz od razu; Apple pozwala zrobić to tylko raz.

Musi to być **Team Key**. Indywidualne klucze App Store Connect nie działają z `notarytool`.

Zapisz:

- Key ID;
- Issuer ID;
- pełną zawartość pliku `.p8`.

### 3. Sekrety GitHub Actions

W repozytorium otwórz **Settings → Secrets and variables → Actions → New repository secret** i dodaj:

| Sekret | Wartość |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | Plik Developer ID `.p12` zapisany jako Base64 |
| `P12_PASSWORD` | Hasło ustawione podczas eksportu `.p12` |
| `KEYCHAIN_PASSWORD` | Nowe losowe hasło do tymczasowego keychaina w CI |
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID zespołowego klucza API |
| `APP_STORE_CONNECT_API_ISSUER_ID` | Issuer ID zespołowego klucza API |
| `APP_STORE_CONNECT_API_KEY_P8` | Pełna tekstowa zawartość klucza `.p8` |

Wartość certyfikatu przygotujesz na Macu tak:

```sh
base64 -i DeveloperIDApplication.p12 | pbcopy
```

Zawartość schowka wklej do `BUILD_CERTIFICATE_BASE64`. Pliku `.p8` nie koduj do Base64 — wklej go jako tekst do `APP_STORE_CONNECT_API_KEY_P8`.

Nie dodawaj certyfikatu, klucza ani haseł do Gita. Workflow importuje certyfikat tylko do tymczasowego keychaina na jednorazowym runnerze GitHub i usuwa materiały po zakończeniu.

### 4. Uprawnienia workflow

Workflow deklaruje `contents: write`, żeby tworzyć GitHub Release. Jeżeli polityka organizacji wymusza token tylko do odczytu, włącz zapis w **Settings → Actions → General → Workflow permissions**.

## Publikowanie wersji

### 1. Przygotuj kod

Przed utworzeniem taga:

1. zaktualizuj `CHANGELOG.md`;
2. uruchom wszystkie testy;
3. sprawdź aplikację zainstalowaną w `/Applications` na macOS 27;
4. sprawdź obie sekcje ikon na ekranie z notchem oraz monitorze zewnętrznym;
5. upewnij się, że repozytorium jest czyste.

```sh
./script/build_and_run.sh --test
./script/build_and_run.sh --verify
git status --short
```

### 2. Utwórz i wypchnij tag

Tag musi mieć dokładny format `vMAJOR.MINOR.PATCH`:

```sh
git tag -a v0.2.0 -m "MenuBarFold 0.2.0"
git push origin v0.2.0
```

To uruchamia workflow **Release DMG**. Nie trzeba ręcznie zmieniać wersji w kodzie ani tłumaczeniach.

### 3. Pobierz DMG

Po udanym zakończeniu workflow otwórz stronę **Releases** repozytorium. Znajdziesz tam DMG i sumę SHA-256. Te same pliki są również zapisane jako artifact uruchomienia GitHub Actions.

Jeżeli proces zatrzyma się po utworzeniu szkicu wydania, usuń przyczynę i uruchom **Actions → Release DMG → Run workflow**, podając istniejący tag. Workflow podmieni pliki i opublikuje szkic dopiero po przejściu wszystkich kontroli.

## Co sprawdza workflow

Proces:

1. sprawdza format oraz istnienie taga;
2. uruchamia testy Swift;
3. importuje `.p12` do tymczasowego keychaina;
4. potwierdza, że to certyfikat Developer ID Application;
5. buduje aplikację Release dla `arm64` i `x86_64`;
6. sprawdza obie architektury przez `lipo`;
7. weryfikuje podpis aplikacji i DMG;
8. wysyła DMG do Apple przez `xcrun notarytool --wait`;
9. dołącza i sprawdza bilet notaryzacji;
10. uruchamia ocenę Gatekeepera przez `spctl`;
11. generuje sumę SHA-256;
12. publikuje pliki i usuwa tymczasowe dane podpisu.

Brak właściwego certyfikatu lub sekretu zatrzymuje wydanie. Workflow nie publikuje publicznie pliku podpisanego ad-hoc albo Apple Development.

## Lokalny test tworzenia DMG

Układ DMG można sprawdzić bez Developer ID i bez notaryzacji:

```sh
REQUIRE_DEVELOPER_ID=0 \
SKIP_NOTARIZATION=1 \
SWIFT_BUILD_ARCHS=arm64 \
./script/package_release.sh 0.2.0
```

Powstanie `dist/MenuBarFold-0.2.0.dmg`, ale nie jest to publiczne wydanie. Nie wysyłaj tego pliku do GitHub Releases.

Pełny proces można uruchomić lokalnie po zainstalowaniu Developer ID i wskazaniu zespołowego klucza API:

```sh
export NOTARYTOOL_KEY="/bezpieczna/sciezka/AuthKey_KEYID.p8"
export NOTARYTOOL_KEY_ID="KEYID"
export NOTARYTOOL_ISSUER_ID="ISSUER-UUID"
./script/package_release.sh 0.2.0
```

## Sprawdzanie pobranego wydania

```sh
shasum -a 256 -c MenuBarFold-0.2.0.dmg.sha256
diskutil image info MenuBarFold-0.2.0.dmg
xcrun stapler validate MenuBarFold-0.2.0.dmg
spctl --assess --type open \
  --context context:primary-signature \
  --verbose=4 \
  MenuBarFold-0.2.0.dmg
```

Po zamontowaniu obrazu:

```sh
codesign --verify --deep --strict --verbose=2 \
  "/Volumes/MenuBarFold 0.2.0/MenuBarFold.app"
codesign -dvvv "/Volumes/MenuBarFold 0.2.0/MenuBarFold.app"
lipo -archs "/Volumes/MenuBarFold 0.2.0/MenuBarFold.app/Contents/MacOS/MenuBarFold"
```

Oczekiwane architektury to `arm64 x86_64`, a nazwa podpisu musi zaczynać się od `Developer ID Application:`.

## Checklista funkcjonalna

Pobrany DMG przetestuj na czystym koncie macOS 27:

- DMG otwiera się, a skrót Applications działa;
- Gatekeeper akceptuje aplikację bez obchodzenia zabezpieczeń;
- pierwsza konfiguracja Accessibility działa;
- kopia spoza `/Applications` bezpiecznie odmawia ukrywania;
- zwinięty pasek pokazuje jeden główny `<`;
- główny przycisk pokazuje zwykłe ikony, `|` i drugi `<`;
- drugi przycisk pokazuje i ukrywa strefę „Zawsze ukryte” bez zmiany swojego miejsca;
- przesunięcie `|` i wyjście z trybu układania prawidłowo zmienia klasyfikację ikon;
- wielokrotne zwijanie zachowuje kolejność ustawioną przez Command + przeciągnięcie;
- działanie jest zgodne na ekranie MacBooka z notchem oraz monitorach bez notcha;
- podłączanie, odłączanie i pionowe ustawienie monitorów bezpiecznie odświeża układ;
- auto fold, hover, skrót globalny oraz uruchamianie po zalogowaniu działają;
- mikrofon lub kamera zwalnia ograniczenie;
- interfejs mieści się po angielsku i polsku;
- odebranie Accessibility pokazuje cały pasek.

## Typowe błędy

`A Developer ID Application certificate is required`

: Zaimportowany `.p12` zawiera Apple Development, nie ma klucza prywatnego albo został błędnie wyeksportowany.

`Missing APP_STORE_CONNECT_API_* secret`

: Brakuje jednej z wartości zespołowego klucza API. Klucz indywidualny nie działa z `notarytool`.

`Invalid` z `notarytool`

: Otwórz log submission pokazany przez `notarytool`. Najczęstsze przyczyny to zły typ certyfikatu, brak Hardened Runtime, nieprawidłowy timestamp albo debugowe entitlementy.

Gatekeeper akceptuje DMG, ale Accessibility resetuje się po aktualizacji

: Sprawdź, czy bundle ID i tożsamość Developer ID nie zmieniły się między wydaniami. Aplikację należy zastąpić w `/Applications`, a nie uruchamiać bezpośrednio z zamontowanego DMG.

## Dokumentacja źródłowa

- [Apple: Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Apple: Customizing the notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- [GitHub: Installing an Apple certificate on macOS runners](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)
- [GitHub: Managing releases in a repository](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)
