# Odbiór FIREMAP — 15 września 2026

## Poprawki przygotowane 14 września

- GPS, statusy i KDR wykonują zapisy kolejno. Każdy zapis wymaga potwierdzenia oczekiwanych identyfikatorów rekordów. Błąd, wyjątek sieciowy lub zero rekordów nie powodują potwierdzenia sukcesu. Status lokalny zmienia się dopiero po potwierdzeniu. Nie jest to kolejka offline — po błędzie operator ponawia operację.
- Zapis pozycji pojazdu i KDR jest jednym zbiorczym upsertem. Oczekiwanie na pierwszy GPS jest opisane jako oczekiwanie, nie jako udany zapis.
- Funkcje tworzenia kont sprawdzają wynik sprzątania także po wyjątku. Nieudane sprzątanie zwraca PROVISIONING_CLEANUP_REQUIRED i zapisuje identyfikatory do logu bez haseł/tokenów. Przy niepewnym usunięciu użytkownika pozostawiają powiat do sprawdzenia.
- Odpowiedzi funkcji kont mają Cache-Control: no-store.
- Panel QR wyjaśnia, że zablokowanie kodu dotyczy nowych dołączeń; istniejące sesje kończą się po wygaśnięciu lub zamknięciu zdarzenia.

## Dane sprawdzone na produkcji (odczyt, 14 września)

Jeden lokalny pojazd bez właściciela, status BASE, bez pasującego aktywnego konta. Zero kont bez powiatu i zero kont Auth FIREMAP bez profilu. Nie zmieniono właściciela historycznego rekordu. Brak podstaw do przypisania go po nazwie; nowe zgłoszenie z istniejącego konta korzysta z własnego identyfikatora. Nie rozszerzać RLS, aby dowolny terminal mógł przejmować stare rekordy.

Jeśli historyczny rekord trzeba zachować operacyjnie: administrator potwierdza jego vehicle_id i właściwy account_id oraz zgodność county_id, zapisuje dotychczasowe wartości i dopiero wtedy wykonuje jednostkowe przypisanie. Test lokalny potwierdza, że takie jawne przypisanie przywraca zapis. Zmiana nie wymaga ponowienia county_access.sql.

## Testy automatyczne

```sh
npm ci --prefix tests/test-runtime --ignore-scripts
node tests/local-db-test.cjs
node tests/test-county-ui.cjs
node tests/test-operational-errors.cjs
```

Testy są lokalne. PGlite korzysta z zapisanych metadanych; nie dowodzi zgodności produkcyjnych GRANT/REVOKE, Auth, Realtime ani zachowania urządzeń. test-operational-errors uruchamia funkcje kont z atrapami awarii i rzeczywisty handler statusu z atrapą odpowiedzi bazy. Nie jest pełnym testem przeglądarkowym. Pierwotnej migracji nie uruchamiać ponownie na produkcji.

## Przebieg odbioru

Przygotować laptop SK, dwa fizyczne terminale, wydzielone zdarzenie TEST oraz konta dwóch powiatów. Nie zmieniać aktywnych zdarzeń operacyjnych. Zapisywać godzinę, wersję aplikacji, urządzenie, wynik i dowód. Puste pola oznaczają niewykonany test.

| Próba | Oczekiwany wynik | Wynik / dowód |
|---|---|---|
| Logowanie istniejącej jednostki, SK i SZTAB | Właściwa rola i zakres danych | |
| Utworzenie konta jednostki i sztabu przez Auth | Nowe konto loguje się i ma właściwy powiat | |
| Izolacja dwóch powiatów (API i mapa) | Brak cudzych odczytów/zapisów | |
| Pierwszy GPS, statusy, KDR | Potwierdzenie na terminalu zgodne z bazą i mapą SK | |
| Brak sieci przy zmianie statusu/KDR | Brak komunikatu sukcesu i brak potwierdzonej lokalnej zmiany; ponowienie działa | |
| Szybkie statusy podczas wysyłania GPS | Końcowy status nie wraca do starszej wartości | |
| GPS poza powiatem | Własne SK nadal widzi pojazd | |
| QR LOCAL/WOO/COO/EXTERNAL | Dołączenie i widoczność wyłącznie do właściwego zdarzenia | |
| Zablokowanie kodu | Nowe dołączenie odrzucone, już dołączony terminal działa | |
| Koniec zdarzenia i wygaśnięcie | Stary token gościa nie zapisuje GPS i nie odczytuje zastępów | |
| Realtime | Zarejestrowane zdarzenia WebSocket, nie tylko cykliczny odczyt; brak danych innego powiatu | |
| Reset hasła/wyłączenie konta | Zweryfikowane nowe logowanie i stara sesja, także po odświeżeniu tokenu | |
| Zablokowanie ekranu, tło, utrata sieci, powrót | Znane zachowanie GPS; SK rozpoznaje ostatnią znaną pozycję | |
| Zmiana konta na tym samym telefonie | Brak wysyłania jako poprzedni użytkownik | |

Pełny odbiór wymaga rzeczywistych wyników. W razie regresji klienta wrócić do poprzedniej wersji klienta; funkcje Edge można przywrócić z poprzedniego commitu. Nie przywracać publicznych praw zapisu pojazdów. Poprawki tego pakietu nie wymagają zmian schematu, uprawnień ani haseł istniejących kont.
