# Telefon terminala

Zastęp zalogowany: Ustawienia pojazdu → Telefon terminala (opcjonalnie). Zapis aktualizuje telefon istniejącego pojazdu oraz zapamiętuje numer w danych tego urządzenia. Kolejne publikacje GPS przekazują numer, także dla powiązanego KDR. Puste pole usuwa numer.

Zastęp QR: pole telefonu w formularzu dołączenia. Późniejsza edycja: Zastępy i dane terminala → Telefon terminala → Zapisz telefon. Błąd zapisu telefonu jest widoczny i nie blokuje dołączenia/GPS; numer można ponownie zapisać.

Kliknięcie markera zastępu w SK, SZTAB i Zastępie pokazuje link „Zadzwoń” (tel:). Dotyczy także ostatniej znanej pozycji. Link otwiera obsługę połączeń w urządzeniu; użytkownik potwierdza telefonowanie.

Numer jest widoczny w dotychczasowym zakresie dostępu do danego pojazdu. Nie wprowadzono publicznego katalogu telefonów. Nowy RPC peers_with_contact rozszerza wyłącznie wynik dotychczasowego tokenowego external_force_peers. Setter gościa sprawdza aktywną sesję, zdarzenie i pojazd; nie przyjmuje ID pojazdu do dowolnej edycji. Walidacja dopuszcza 7–15 cyfr i opcjonalny plus. Spacje, nawiasy i myślniki są usuwane w kliencie.

Wdrożenie: migracja terminal_phone, tests/test-terminal-phone.sql (ROLLBACK), następnie klient. Stare wersje klientów i RPC pozostają zgodne. Test lokalny: node tests/local-db-test.cjs oraz node tests/test-terminal-phone.cjs. Telefonowania na fizycznym urządzeniu nie testowano.
