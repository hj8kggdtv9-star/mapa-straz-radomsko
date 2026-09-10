# Powiatowe SK — przygotowane wdrożenie

Status: przygotowane i przetestowane lokalnie. Produkcyjna migracja została dwukrotnie odrzucona przez automatyczną kontrolę ryzyka. Nie zastosowano jej inną drogą. Nie wdrożono funkcji ani interfejsu zależnych od nowego schematu.

## Działanie

- Każdy aktywowany powiat ma jedno domyślne konto SK oraz własną listę kont OSP/JRG.
- SK widzi własne jednostki niezależnie od ich położenia GPS oraz gości przypisanych kodem do własnego zdarzenia.
- SK tworzy konta i generuje lub ustawia hasła tylko swoim jednostkom. Reset hasła dotyczy kolejnych logowań, nie wylogowuje istniejących sesji.
- Administrator platformy (dotychczasowe konto SK Radomsko) aktywuje kolejne powiaty. To uprawnienie nie daje dostępu do map innych powiatów.
- Logowanie obejmuje rodzaj konta, województwo, aktywowany powiat i jednostkę; tryb SZTAB pozostaje dostępny.
- QR obsługuje LOCAL/WOO/COO/EXTERNAL. Kod i sesja nadal mają maksymalnie 7 dni ważności, z wcześniejszym zakończeniem przy zamknięciu zdarzenia.
- Nowe konta dostają hasła z generatora kryptograficznego lub hasło podane przez operatora. Hasła nie są zapisywane w repozytorium ani w tabeli kont.

## Istniejące dane

Sprawdzono bieżące profile: dotychczasowe wdrożenie obejmuje SK/JRG/OSP Radomsko oraz istniejący sztab. Są przypisywane do powiatu radomszczańskiego. Konta Auth i ich hasła nie są modyfikowane przez migrację. Pojazdy otrzymują właściciela na podstawie istniejącego jednoznacznego przypisania nazwy konta; niepowiązane historyczne pojazdy pozostają w powiecie, bez przypisywania ich przypadkowej jednostce.

## Weryfikacja bez dostępu do produkcji

```sh
npm ci --prefix tests/test-runtime
node tests/local-db-test.cjs
node tests/test-county-ui.cjs
```

Pierwszy test uruchamia PostgreSQL/PGlite z pgcrypto, odtwarza schemat, ograniczenia, RLS, funkcje i triggery z metadanych produkcyjnych oraz stosuje migrację na syntetycznych danych. Nie łączy się z Supabase. Sprawdza tworzenie zdarzeń, izolację SK i jednostek, brak możliwości zmiany właściciela, zapis starego formatu GPS poza dawnym obszarem, przypisanie do zdarzenia, QR LOCAL/WOO, odczyt pozostałych zastępów, izolację sztabu i zakończenie sesji. Drugi sprawdza uprawnienia funkcji tworzącej konta i resetującej hasła oraz integrację skryptów klienta.

Testy lokalne przeszły. Nie wykonano testu na fizycznych terminalach, produkcyjnego Realtime ani pełnego tworzenia konta w produkcyjnym Supabase Auth.

## Kolejność po zatwierdzeniu migracji produkcyjnej

1. Ponownie odczytać stan schematu i kont; sprawdzić, czy nie dodano innych powiatów od przygotowania zmiany.
2. Zastosować `county_access.sql` jako jedną transakcję na `vqgipvwcvbhabvfipodl`. Migracja ma krótki limit oczekiwania na blokady; błąd ma wycofać całą transakcję.
3. Wykonać `tests/test-counties.sql` w transakcji z ROLLBACK. Test korzysta z istniejącego SK Radomsko, ale wszystkie jego operacje i syntetyczne dane zostają wycofane.
4. Wdrożyć Edge Functions: `manage-county.js` jako `manage-county` oraz zmienione `create-sztab.js` jako `create-sztab`. Obie weryfikują token przez `auth.getUser` i uprawnienia z tabel bazy; kontrola JWT bramy jest wyłączona na rzecz tej weryfikacji.
5. Dopiero wtedy scalić klienta do `main` i poczekać na GitHub Pages. Przetestować logowanie SK, OSP, SZTAB, tworzenie konta jednostki i dołączenie QR na dwóch urządzeniach.

Główne ryzyko: zastąpienie dawnych szerokich praw zapisu pojazdów kontrolą właściciela. Lokalne testy obejmują istniejący format zapisu przeglądarki. Nie należy publikować klienta ani funkcji serwerowych przed wdrożeniem i sprawdzeniem schematu.
