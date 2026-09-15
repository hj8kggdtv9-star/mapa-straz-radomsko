# FIREMAP — szybkie uruchomienie sztabu

## Przygotowanie kont (jednorazowo)

W panelu SK otwórz „Utwórz konto SZTABU”. Formularz proponuje kolejne nazwy SZTAB 1, SZTAB 2 itd. oraz identyfikator sztab-1, sztab-2. Wygeneruj silne hasło, utwórz konto i przekaż dane obsadzie. Nie ma wspólnego ani publicznego hasła. Można przygotować konta przed akcją; nowe konta pojawiają się na liście logowania SZTAB.

## Uruchomienie akcji

1. Wybierz rodzaj dostępu SZTAB, konto z listy i wpisz jego hasło.
2. W karcie „Uruchom akcję SZTABU” podaj nazwę akcji, województwo, powiat i czas dostępu: 24 h, 3, 7, 14 lub 30 dni.
3. Naciśnij „Uruchom akcję i pokaż QR”. Powstaje aktywna akcja oraz kod 6-cyfrowy i QR. Kod może być też skopiowany jako link.
4. Zastęp skanuje QR albo otwiera external-join.html, podaje kod, jednostkę, kryptonim i typ pojazdu. Dane organizacyjne są opcjonalne. Zezwala na GPS.
5. Wspólna mapa pokazuje zastępy sztabu; „Pokaż wszystkie zastępy” dopasowuje widok. Powiat ustawia pozycję początkową — nie ogranicza transmisji ani mapy.
6. Każdy zastęp może otworzyć TAKTYKĘ, rysować punkty, odcinki, zaopatrzenie wodne, strefy, zasięg pożaru i linie. „Zapisz i udostępnij” publikuje własne elementy dla sztabu i jego zastępów. Elementy innych autorów są widoczne, ale nieedytowalne przez zastęp.

Czas dostępu liczony jest od wygenerowania kodu, do wyświetlonego terminu. Późniejsze dołączenie nie przesuwa terminu. Nowy kod nie przedłuża już wydanych sesji. Zakończenie akcji kończy jej sesje wcześniej. Aby kontynuować po wygaśnięciu, zastęp dołącza nowym kodem.

Jedno konto ma jedną aktywną akcję tworzoną szybkim formularzem. Ponowienie dla tej samej nazwy i obszaru generuje kolejny kod; zmiana akcji wymaga zakończenia poprzedniej. Jeśli sztab prowadzi również inne aktywne zdarzenia, jego zastępy QR widzą wzajemne pozycje i taktykę w ramach tego samego sztabu. Sztaby pozostają odizolowane nawet przy pracy w tym samym powiecie.

## Wdrożenie

Najpierw wykonać w jednej transakcji migrację `supabase/migrations/20260915085854_rapid_sztab.sql`, następnie opublikować klienta. Nie wykonywać ponownie county_access.sql. Migracja nie tworzy kont, nie zmienia haseł ani przynależności istniejących pojazdów. Dodaje metadane szybkiej akcji i autorstwo rysunków sesji gościnnej; istniejące rysunki użytkowników zachowują autorów.

Goście korzystają wyłącznie z RPC z weryfikacją tokenu sesji, aktywności zdarzenia i terminu. Nie otrzymują bezpośrednich praw zapisu tabel. Edycja/usuwanie sprawdza właściciela po stronie bazy. Nowe funkcje SECURITY DEFINER dostępne dla anon są świadomym interfejsem sesji QR, nie ogólnym dostępem do danych. Wewnętrzna walidacja znajduje się w prywatnym schemacie.

## Weryfikacja

```sh
npm ci --prefix tests/test-runtime --ignore-scripts
node tests/local-db-test.cjs
node tests/test-county-ui.cjs
node tests/test-operational-errors.cjs
node tests/tactical-editor.cjs
node tests/test-guest-tactical.cjs
```

Test SQL obejmuje dwa sztaby, sesje z różnych zdarzeń tego samego sztabu, 1/3/7/14/30 dni, odrzucenie ponad 30 dni, wspólną taktykę, cudze edycje/usuwanie, nieprawidłowy token/geometrię, wygaśnięcie i zamknięcie. Testy JS sprawdzają również, że zwykły zalogowany edytor nie traktuje rysunków gościa jako własnych.

Test produkcyjny `tests/test-rapid-hq.sql` tworzy wyłącznie syntetyczne dane w transakcji i kończy się ROLLBACK. Nie dowodzi to działania rzeczywistych tokenów Auth ani przeglądarek. Odbiór na urządzeniach: dwa telefony QR, laptop sztabu, publikacja punktu i linii, widoczność na drugim telefonie/SK, brak edycji cudzej taktyki, zamknięcie akcji i odrzucenie ponownego zapisu.

TAKTYKA gości odświeża się przez okresowy odczyt (około 2,5 s przy aktywnej stronie), pozycje innych zastępów około 3 s. Rysowanie lokalne nie publikuje automatycznie. Nadal obowiązują ograniczenia GPS przeglądarki w tle; do pracy w terenie należy sprawdzić konkretne telefony.
