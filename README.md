# FIREMAP

Mobilna mapa sytuacyjna zastępów dla rejonu Radomska.

## Widok zastępu
`index.html`: pełnoekranowa mapa, GPS, statusy W bazie / Dysponowany / Na miejscu / Powrót, automatyczne śledzenie własnego pojazdu, podgląd innych zastępów, punkty POŻAR/MZ oraz nawigacja Google Maps.

## Panel SK KP PSP Radomsko
`dispatcher.html`: zabezpieczone logowanie Supabase Auth, podgląd zastępów, dodawanie POŻAR/MZ przez koordynaty lub kliknięcie mapy oraz zamykanie zdarzeń.

## Aktualizacja bazy do v2
1. Uruchom `supabase_v2.sql` w Supabase SQL Editor.
2. W Supabase Authentication → Users utwórz użytkownika `sk@firemap.local` i ustaw hasło SK.
3. Nie zapisuj hasła dyżurnego w publicznym repozytorium.
