# 🍏 ŠankFinder za iOS - Navodila za Zagon in Namestitev

Čestitke! ŠankFinder ima sedaj **popolnoma pravo, nativno iOS aplikacijo** (napisano v SwiftUI), zgrajeno točno po tvojih željah:
- 🗺️ **Tvoj lastni zemljevid:** Uporablja **OpenStreetMap / Carto Voyager** ploščice namesto Applove grafike.
- 🚶 **Tvoj OSRM strežnik:** Peš poti se računajo neposredno prek `https://sankfinder.sluga.me/`.
- 🍺 **Oblikovanje:** Prepoznavna `BeerGold` zlata tema in temen način.
- 🎯 **Vse funkcije:** Baza barov (Geoapify), peš navigacija korak za korakom, Alko merilnik promilov, Pivska ruleta, Resnica ali Izziv ter Pivska klapa.

Ker **nimaš Maca**, je vse pripravljeno tako, da aplikacijo v oblaku zgradi brezplačni Mac strežnik preko **GitHub Actions**.

---

## 🛠️ 1. KORAK: Zagon gradnika v oblaku (Brez Maca)

1. **Če še nimaš Git repozitorija na svojem računalniku:**
   V mapi projekta zaženi:
   ```powershell
   git init
   git add .
   git commit -m "Dodana nativna iOS aplikacija in GitHub Actions"
   ```
2. Na [GitHub.com](https://github.com) ustvari nov zasebni ali javni repozitorij (npr. `SankFinder`).
3. Poveži ga in pošlji kodo:
   ```powershell
   git remote add origin https://github.com/TVOJE_UPORABNISKO_IME/SankFinder.git
   git branch -M main
   git push -u origin main
   ```
4. **Prenos zgrajene aplikacije (.IPA):**
   - Na GitHubu odpri zavihek **Actions**.
   - Klikni na postopek **Build ŠankFinder iOS (.IPA)** (lahko klikneš tudi gumb *Run workflow*).
   - Virtualni Mac v oblaku bo v ~2 minutah prevedel celotno aplikacijo.
   - Ko se postopek zaključi z zeleno kljukico, na dnu strani pod **Artifacts** klikni in prenesi **`SankFinder-iOS-IPA`** (to je tvoja `.ipa` datoteka za telefon).

---

## 📱 2. KORAK: Namestitev na iPhone (iz Windows računalnika)

Izberi eno od dveh brezplačnih metod:

### A) Z orodjem Sideloadly (Najhitrejša metoda, 1 minuta)
1. Na Windows računalnik prenesi brezplačni program [Sideloadly](https://sideloadly.io/).
2. iPhone s kablom poveži z računalnikom (če te telefon vpraša »Zaupaj temu računalniku?«, potrdi s kodo).
3. V Sideloadly povleci datoteko `SankFinder.ipa`.
4. Vpiši svoj Apple ID in klikni **Start**.
5. Čez 30 sekund je ikona ŠankFinder na tvojem iPhonu!
6. Na telefonu pojdi v:
   *Nastavitve (Settings) -> Splošno (General) -> Upravljanje naprav (VPN & Device Management)* -> klikni svoj Apple ID in izberi **Zaupaj (Trust)**.

---

### B) Z orodjem AltStore (Za samodejno podaljševanje »ZA ZMERAJ«)
1. Prenesi [AltServer za Windows](https://altstore.io/).
2. Namesti AltStore na svoj telefon.
3. Preko AltStore izberi `SankFinder.ipa` in jo namesti.
4. **Kako deluje za zmeraj:** Ko je tvoj računalnik prižgan in povezan na isti domači Wi-Fi kot tvoj iPhone, AltServer samodejno v ozadju podaljšuje certifikat. Aplikacija tako **nikoli ne poteče**!

---

## 📂 Struktura iOS projekta

Vsa koda se nahaja v mapi `iosApp/`:
- `SankFinder/Views/Components/CustomMapView.swift` – OpenStreetMap Carto Voyager ploščice, ki povsem prekrijejo Apple Maps
- `SankFinder/Services/NetworkManager.swift` – Povezava na tvoj OSRM strežnik `sankfinder.sluga.me` in Geoapify
- `SankFinder/Views/Tabs/MapTabView.swift` – Glavni zaslon z zemljevidom in navigacijo
- `SankFinder/Views/Tabs/BarsListView.swift` – Seznam barov z razdaljami in filtri
- `SankFinder/Views/Tabs/GamesView.swift` – Alko merilnik promilov po meri, Ruleta in Resnica/Izziv
- `SankFinder/Views/Tabs/SquadView.swift` – Pivska klapa in runda tracker
- `SankFinder/Views/Tabs/SettingsView.swift` – Nastavitve strežnikov in radija
- `SankFinder.xcodeproj` – Projekt za prevajanje
