# Wydawanie aplikacji

MenuBarFold korzysta z bezpłatnego procesu wydawania na GitHubie. Workflow buduje DMG podpisany ad-hoc i nie wymaga konta Apple, członkostwa Apple Developer Program, sekretów z certyfikatami ani danych do notaryzacji.

Koszt tego rozwiązania trzeba komunikować uczciwie: Apple nie potwierdza tożsamości autora i nie skanuje artefaktu przez usługę notaryzacji. Gatekeeper blokuje pierwsze uruchomienie, dopóki użytkownik nie utworzy wyjątku **Otwórz mimo to** tylko dla tej aplikacji. Darmowego wydania nie wolno opisywać jako notaryzowanego albo zweryfikowanego przez Apple.

## Dlaczego DMG zamiast PKG

PKG nie omija płatnego wymogu Apple. Zaufany DMG potrzebuje certyfikatu **Developer ID Application**. Zaufany PKG wymaga dodatkowo **Developer ID Installer**, a aplikacja w środku nadal musi mieć podpis **Developer ID Application**.

Apple zaleca instalator, kiedy program składa się z wielu części, zapisuje pliki w kilku konkretnych miejscach albo uruchamia własny kod instalacyjny. MenuBarFold jest jedną samodzielną aplikacją kopiowaną do `/Applications`, więc DMG jest prostszy do instalacji i usunięcia.

## Co tworzy bezpłatny workflow

Dla taga takiego jak `v0.2.0` plik `.github/workflows/release.yml` publikuje:

```text
MenuBarFold-0.2.0.dmg
MenuBarFold-0.2.0.dmg.sha256
```

Tag bez `v` staje się `CFBundleShortVersionString`, a numer uruchomienia GitHub Actions staje się `CFBundleVersion`. DMG zawiera:

- `MenuBarFold.app` i skrót do `/Applications`;
- natywny plik wykonywalny `arm64` dla Apple Silicon;
- stały bundle ID `io.github.menubarfold.MenuBarFold`;
- Hardened Runtime i podpis ad-hoc;
- brak certyfikatu Developer ID i brak biletu notaryzacji.

Suma kontrolna pozwala wykryć niepełne albo zmienione pobranie po porównaniu z plikiem dołączonym do wydania. Nie jest niezależnym dowodem tożsamości autora, bo oba pliki pochodzą z tego samego GitHub Release.

## Koszt w wygodzie i uprawnieniach

Podpis ad-hoc identyfikuje tylko jeden konkretny build. Nowa wersja zmienia hash katalogu kodu, więc macOS może potraktować aktualizację jak inną aplikację. Użytkownik powinien zakładać, że po aktualizacji trzeba będzie:

1. ponownie użyć **Otwórz mimo to**;
2. usunąć poprzedni wpis MenuBarFold z Accessibility;
3. dodać lub włączyć nowy wpis `/Applications/MenuBarFold.app`.

Na własnym Macu autora lepiej używać `./script/build_and_run.sh --verify`. Skrypt wybiera pierwszy zainstalowany lokalnie certyfikat, na przykład Apple Development, i korzysta z niego tak długo, jak jest dostępny. Taki podpis nadal nie jest podpisem do zaufanej publicznej dystrybucji.

Nie obchodź tych ograniczeń przez globalne wyłączenie Gatekeepera. Opisana procedura tworzy wyjątek tylko dla MenuBarFold.

## Konfiguracja repozytorium

Bezpłatny workflow nie potrzebuje żadnych sekretów związanych z Apple. Potrzebuje wyłącznie domyślnego `GITHUB_TOKEN` z prawem do tworzenia wydań. Workflow deklaruje:

```yaml
permissions:
  contents: write
```

Jeżeli polityka organizacji wymusza token tylko do odczytu, włącz zapis w **Settings → Actions → General → Workflow permissions**.

## Publikowanie wersji

### 1. Sprawdź kod

Przed utworzeniem taga:

```sh
./script/build_and_run.sh --test
./script/build_and_run.sh --verify
git status --short
```

Sprawdź też obie ukryte sekcje na macOS 27, na ekranie z notchem i monitorze zewnętrznym. Zaktualizuj `CHANGELOG.md` i upewnij się, że repozytorium jest czyste.

### 2. Utwórz i wypchnij tag

Tag musi mieć dokładny format `vMAJOR.MINOR.PATCH`:

```sh
git tag -a v0.2.0 -m "MenuBarFold 0.2.0"
git push origin v0.2.0
```

Wysłanie taga uruchamia **Release DMG**. Workflow można też powtórzyć przez **Actions → Release DMG → Run workflow**, wskazując istniejący tag.

### 3. Pobierz wynik

Po sukcesie GitHub Releases zawiera DMG i plik `.sha256`. Te same pliki są przechowywane jako artifact o nazwie `MenuBarFold-<wersja>-unnotarized`.

Opis wydania zawiera ostrzeżenie, że build ma podpis ad-hoc i wymaga ręcznego zatwierdzenia.

## Co sprawdza workflow

Proces:

1. sprawdza format oraz istnienie taga;
2. uruchamia testy Swift;
3. buduje aplikację Release dla `arm64`;
4. włącza Hardened Runtime;
5. tworzy podpis ad-hoc przez `codesign -s -`;
6. sprawdza architekturę `arm64` przez `lipo`;
7. sprawdza integralność podpisu aplikacji i DMG przez `codesign`;
8. tworzy DMG oraz sumę SHA-256;
9. publikuje oba pliki z ostrzeżeniem o braku notaryzacji.

To potwierdza integralność buildu. Nie zastępuje notaryzacji i nie powoduje, że Gatekeeper zaufa autorowi.

## Lokalne pakowanie

Domyślne polecenie korzysta z darmowej ścieżki:

```sh
SWIFT_BUILD_ARCHS="arm64" \
CODE_SIGN_IDENTITY="-" \
./script/package_release.sh 0.2.0
```

Wynik pojawi się w `dist/`. Skrypt wyświetli ostrzeżenie o wymaganym ręcznym zatwierdzeniu.

macOS 27 działa na Macach z Apple Silicon. Xcode 27 oznacza `x86_64` jako przestarzałe przy minimalnym targecie macOS 27, dlatego wydanie nie zawiera nieużywanej części Intel.

## Instalacja pobranego wydania

1. Opcjonalnie sprawdź sumę w katalogu zawierającym oba pobrane pliki:

   ```sh
   shasum -a 256 -c MenuBarFold-0.2.0.dmg.sha256
   ```

2. Otwórz DMG i przeciągnij MenuBarFold do Applications.
3. Spróbuj uruchomić `/Applications/MenuBarFold.app`; macOS zablokuje aplikację.
4. Zamknij ostrzeżenie, nie przenosząc aplikacji do Kosza.
5. Otwórz **Ustawienia systemowe → Prywatność i bezpieczeństwo**, przewiń do sekcji **Bezpieczeństwo** i kliknij **Otwórz mimo to** przy MenuBarFold.
6. Potwierdź **Otwórz**, a następnie przyznaj Accessibility.

Nie używaj `spctl --master-disable` i nie zalecaj wyłączania Gatekeepera dla całego Maca.

## Checklista wydania

- suma kontrolna jest prawidłowa;
- DMG zawiera MenuBarFold i skrót Applications;
- opis wydania jasno mówi o braku notaryzacji;
- **Otwórz mimo to** uruchamia kopię z Applications;
- pierwsza konfiguracja Accessibility działa;
- zwinięty pasek pokazuje jeden główny `<`;
- główny przycisk pokazuje zwykłe ikony, `|` i drugi `<`;
- drugi przycisk pokazuje i ukrywa zawsze ukryte ikony bez zmiany położenia;
- wielokrotne zwijanie zachowuje kolejność ustawioną przez Command i przeciągnięcie;
- ekrany z notchem i bez notcha działają spójnie;
- auto fold, hover, skrót i uruchamianie po zalogowaniu działają;
- interfejs mieści się po angielsku i polsku;
- odebranie Accessibility bezpiecznie pokazuje cały pasek.

## Opcjonalne zaufane wydanie w przyszłości

Skrypt pakowania zachowuje ścisły tryb Developer ID. Wymaga płatnego Apple Developer Program, certyfikatu **Developer ID Application** i zespołowych danych do notaryzacji:

```sh
export CODE_SIGN_IDENTITY="Developer ID Application: Nazwa (TEAMID)"
export REQUIRE_DEVELOPER_ID=1
export SKIP_NOTARIZATION=0
export NOTARYTOOL_KEY="/bezpieczna/sciezka/AuthKey_KEYID.p8"
export NOTARYTOOL_KEY_ID="KEYID"
export NOTARYTOOL_ISSUER_ID="ISSUER-UUID"
./script/package_release.sh 0.2.0
```

Ten tryb wysyła DMG do Apple, czeka na wynik, dołącza ticket i uruchamia ocenę Gatekeepera. Domyślny workflow GitHuba celowo go nie używa.

## Dokumentacja źródłowa

- [Apple: Safely open apps on your Mac](https://support.apple.com/en-us/102445)
- [Apple: Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Apple: Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates)
- [Apple: Code Signing Requirement Language](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/RequirementLang/RequirementLang.html)
- [GitHub: Managing releases in a repository](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)
