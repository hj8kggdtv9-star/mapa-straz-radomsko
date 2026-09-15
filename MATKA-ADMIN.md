# Administrator FIREMAP (MATKA)

Panel: `admin.html` (link na ekranie logowania).

Pierwsze wejście: istniejące konto administratora platformy `sk@firemap.local` i jego dotychczasowe hasło. Panel nie rozszerza dostępu operacyjnego tego konta. W sekcji „Utwórz niezależne konto MATKA” administrator może utworzyć osobny login `admin.<identyfikator>@firemap.local`. Nowa tożsamość ma tylko wpis w `firemap_platform_admins`, bez profilu operacyjnego i powiatu, a więc bez map, pojazdów i taktyki. Hasło pokazywane jest po utworzeniu i nie jest zapisywane w repozytorium. Sesja panelu jest oddzielona od sesji operacyjnej przeglądarki.

Panel umożliwia aktywację powiatu wraz z SK, tworzenie SK/SZTAB/OSP/JRG, wyszukiwanie i filtrowanie, zmianę nazwy, przypisanie do powiatu, reset hasła, wyłączenie/włączenie oraz trwałe wycofanie konta. Przeniesienie konta z przypisanymi pojazdami lub historią sztabu jest blokowane. Nazwa i przypisanie nie zmieniają loginu.

Usunięcie oznacza `archived_at` i `enabled=false`, a nie fizyczne kasowanie Auth. To zachowuje powiązania i historię. Nie można przywrócić takiego konta przez panel; można utworzyć nowe konto z innym identyfikatorem. Wycofanie SK zwalnia miejsce na nowy profil SK powiatu. Wyłączenie/wycofanie blokuje operacyjne odczyty i zapisy także ze starym JWT. Nie zamyka akcji i nie unieważnia sesji QR zastępów: tym zarządza się osobno w zdarzeniu. Reset hasła zmienia kolejne logowanie; nie jest funkcją natychmiastowego odebrania dostępu. Do tego służy wyłączenie.

Konta administratorów są chronione przed resetem, wyłączeniem, przeniesieniem i usunięciem przez ten panel. Nie ma publicznej możliwości samodzielnego przyznania roli administratora: każdy request sprawdza Auth getUser i istniejący wpis platform_admins, a konto operacyjne administratora, jeśli istnieje, musi być aktywne. Procedura zmian kont dostępna tylko dla service_role; także wewnętrznie sprawdza operatora. Zwykłe SK zachowuje dotychczasowe tworzenie jednostek i reset haseł własnego powiatu.

## Wdrożenie
1. Migracja `supabase/migrations/20260915133037_matka_admin.sql` w jednej transakcji.
2. `tests/test-matka.sql` na bazie: dane syntetyczne, całość kończy ROLLBACK.
3. Edge `manage-platform`, plik `manage-platform.js`, JWT gateway wyłączone wyłącznie ze względu na własną weryfikację użytkownika przez Auth getUser i kontrolę uprawnień w kodzie. Klucz service_role tylko po stronie serwera.
4. Publikacja frontend.
5. Ręczny odbiór: główny administrator loguje się, tworzy niezależne konto MATKA, zapisuje hasło. Test konta jednostki: wyłączenie, stara sesja, ponowne włączenie, usunięcie i zachowanie historii. Test zwykłego SK: odmowa dostępu do panelu MATKA.

Testy: `node tests/test-platform.cjs`, `node tests/local-db-test.cjs`. Nie wykonano rzeczywistego logowania administratora ani testów fizycznych urządzeń. Brak automatycznego tworzenia kont produkcyjnych podczas wdrożenia.
