# Android, pakiety offline i POMOC — odbiór

APK pilotażowy zawiera tę samą aplikację HTML/JS co wersja WWW, wraz z bibliotekami. Uruchomienie menu i zapisanych map nie wymaga połączenia z GitHub Pages. Logowanie, dołączenie QR, przesyłanie pozycji, POMOC i pobranie nowej TAKTYKI wymagają internetu.

## Pakiet offline
1. Zaloguj terminal lub dołącz kodem. Przypisz zdarzenie.
2. Ustaw widok mapy na obszar do 25 km². Otwórz „MAPY OFFLINE”.
3. Nadaj nazwę, wybierz zdarzenie i pobierz. Gotowy pakiet zawiera obszar OSM (drogi, budynki, lasy, wody i hydranty oznaczone w OSM) oraz opublikowaną TAKTYKĘ. Nie zawiera BDL ani K-GESUT.
4. Dopiero pełna odpowiedź mapy i TAKTYKI jest zapisywana w IndexedDB. Anulowanie/błąd nie tworzy pozornie gotowego pakietu. Pakiet ma datę oraz granice obszaru.
5. Otwórz „Zapisane mapy i TAKTYKA offline” z menu startowego APK. Przetestuj w trybie samolotowym po zamknięciu aplikacji.

Pakiet jest przypisany do ostatniego użytkownika urządzenia. Dla QR ważność nie przekracza czasu sesji; dla konta pakiet wygasa po 30 dniach. Lokalnego urządzenia bez internetu nie można poinformować natychmiast o zamknięciu zdarzenia lub odebraniu dostępu. Pakiet jest wyraźnie oznaczony jako historyczny. Usunięcie danych aplikacji usuwa mapy. Nie zapisujemy tokenów w pakiecie.

Dane bazowe pobierane są pojedynczym zapytaniem Overpass, nie z zabronionego hurtowego pobierania tile.openstreetmap.org. Przy większej liczbie użytkowników potrzebny jest dedykowany serwer danych lub dostawca offline; publiczny Overpass nie daje SLA. Licencja i atrybucja OSM/ODbL pozostają na mapie.

## POMOC / ważny komunikat
Przytrzymaj 2 sekundy, sprawdź zdarzenie i potwierdź. Krótkie dotknięcie nie wysyła zgłoszenia. Widoczny jest nadawca, tekst, czas i pozycja z chwili zgłoszenia. Jest to prośba o pilny kontakt, nie potwierdzenie odebrania przez wszystkie osoby.

Uczestnicy z aktywną aplikacją i połączeniem odświeżają listę co 3 sekundy. Zgłoszenie odwołuje nadawca albo SK/SZTAB zarządzający zdarzeniem. QR nie może odwołać cudzego zgłoszenia. Zgłoszenia nie przechodzą do innych zdarzeń QR. Brak internetu lub potwierdzenia serwera jest pokazany jawnie. Nie ma kolejki odroczonych zgłoszeń.

## Odbiór na Androidzie
- Instalacja APK, logowanie, ponowne uruchomienie, telefon tel: oraz nawigacja zewnętrzna.
- Uprawnienia lokalizacji: zgoda, odmowa, ponowna zgoda; publikacja pozycji przy otwartym terminalu.
- Pobrany pakiet: restart w trybie samolotowym, zoom, linia wodna, punkty, odcinki, usunięcie pakietu.
- Przerwij pobieranie i odłącz sieć: brak komunikatu o pełnym sukcesie.
- KDR publikuje nową warstwę online, pobierz nowy pakiet — stary pozostaje historyczny.
- POMOC: dotknięcie krótkie, przytrzymanie, anulowanie, potwierdzenie; drugi terminal i SK widzą to samo. Odwołanie propaguje się.
- Offline POMOC nie wyświetla potwierdzenia wysłania.
- Android może ograniczać WebView/GPS po wygaszeniu ekranu. Ten APK nie obiecuje niezależnego publikowania GPS w tle ani powiadomień push.

Wydanie jest podpisane kluczem debug przez CI do odbioru pilotażowego. Publikacja w Google Play i stały klucz aktualizacji wymagają skonfigurowania podpisu wydania; kolejne niezależne buildy debug mogą wymagać odinstalowania poprzedniej wersji. Nie stosować operacyjnie bez testu na fizycznych urządzeniach.
