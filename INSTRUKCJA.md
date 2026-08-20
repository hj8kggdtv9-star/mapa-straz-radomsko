# Uruchomienie mapy strażackiej

## Supabase
1. Otwórz projekt Supabase.
2. Wejdź w SQL Editor i utwórz New query.
3. Wklej zawartość pliku `supabase.sql` i kliknij Run.
4. W Project Settings / API odczytaj Project URL i publiczny anon/publishable key. Nie używaj service_role.

## GitHub Pages
1. Repozytorium -> Settings -> Pages.
2. Source: Deploy from a branch.
3. Branch: main, folder: /(root).
4. Save.

Po publikacji otwórz stronę HTTPS, wybierz `Ustaw Supabase`, wpisz Project URL oraz anon/publishable key, a następnie `Połącz / udostępnij pozycję`.

## Wersja 1
To MVP. Każdy znający adres strony może wejść na mapę. Przed użyciem operacyjnym należy dodać uwierzytelnianie użytkowników/kod dostępu oraz dokładne granice powiatów.
