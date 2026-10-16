package com.example.sankfinder.ui.pages

import android.app.Activity
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Gavel
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.example.compose.BeerGold
import com.example.compose.DrajvGreen
import com.example.compose.DrajvRed
import kotlin.system.exitProcess

data class LegalSection(
    val number: String,
    val title: String,
    val content: String
)

val LEGAL_SECTIONS = listOf(
    LegalSection(
        number = "1",
        title = "SPLOŠNE DOLOČBE",
        content = """1.1. Ti Splošni pogoji uporabe in Politika zasebnosti (v nadaljevanju: Pogoji) urejajo pravice, obveznosti in odgovornosti med upravljavcem mobilne aplikacije ŠankFinder (v nadaljevanju: Ponudnik) ter vsakim uporabnikom (v nadaljevanju: Uporabnik) mobilne aplikacije ŠankFinder na platformah Android, Apple iOS in watchOS.

1.2. Z namestitvijo, zagonom ali uporabo katerekoli funkcionalnosti aplikacije ŠankFinder Uporabnik potrjuje, da je te Pogoje v celoti prebral, jih razume in se z njimi neomejeno strinja. Če se Uporabnik s Pogoji ne strinja, mora nemudoma prenehati z uporabo aplikacije in jo odstraniti s svoje naprave.

1.3. Aplikacija ŠankFinder je namenjena odkrivanju gostinskih lokalov, peš orientaciji v prostoru, družabni zabavi ter beleženju lastne zgodovine obiskov. Aplikacija je brezplačna in je na voljo po načelu »kakršna je« (as-is) in »kjer je na voljo« (as-available)."""
    ),
    LegalSection(
        number = "2",
        title = "STAROSTNA OMEJITEV (18+) IN ODGOVORNO RAVNANJE Z ALKOHOLOM",
        content = """2.1. Starostna omejitev: Zaradi tematske vsebine, povezane z gostinskimi lokali, pivskimi družabnimi igrami in beleženjem pijač, je uporaba aplikacije ŠankFinder dovoljena izključno polnoletnim osebam (starejšim od 18 let). Z uporabo aplikacije Uporabnik izrecno izjavlja in jamči, da je dopolnil 18 let.

2.2. Zdravstveno opozorilo v skladu z ZOPA:
»Minister za zdravje opozarja: Uživanje alkohola lahko škoduje zdravju!«

2.3. Odsotnost spodbujanja prekomernega pitja in izračuni zgolj za zabavo:
Funkcionalnosti aplikacije, kot so »Kolo sreče – Kdo plača rundo?«, »Ruleta šankov«, »Pivski Tracker / Runda števec« ter morebitni informativni izračuni promilov oziroma popitih enot, so ustvarjeni izključno za zabavne in družabne namene.
Noben podatek, števec ali izračun v aplikaciji nima medicinske, toksikološke ali pravne veljavnosti in ga pod nobenim pogojem ni dovoljeno uporabiti kot merilo sposobnosti za vožnjo ali upravljanje strojev.
Vsak Uporabnik pije na lastno odgovornost. Ponudnik ne prevzema nobene odgovornosti za zdravstvene, finančne ali prekrškovne posledice uživanja alkoholnih pijač.

2.4. Stroga prepoved uporabe v cestnem prometu (Vožnja pod vplivom alkohola):
Aplikacija ŠankFinder je zasnovana za varno vrnitev domov (peš ali s taksijem). Aplikacija ne ponuja avtomobilske navigacije in je strogo prepovedano uporabljati med vožnjo motornega vozila, kolesa ali električnega skiroja."""
    ),
    LegalSection(
        number = "3",
        title = "PEŠ NAVIGACIJA IN VARNOST V PROSTORU",
        content = """3.1. Informativna narava peš vodenja:
Modul za peš navigacijo uporablja kartografske podatke OpenStreetMap ter usmerjevalnik OSRM (Open Source Routing Machine) prek strežnika sankfinder.sluga.me in rezervnega strežnika routing.openstreetmap.de. Prikazane trase, razdalje in časi hoje (ETA) so zgolj informativni pripomoček.

3.2. Prednost dejanskih razmer na terenu:
Kartografski podatki morda ne odražajo trenutnih gradbišč, zapor cest, neosvetljenih poti, nevarnih prehodov ali sprememb prometne signalizacije. Uporabnik mora med hojo:
- Vedno spremljati dejansko okolico, promet in prometne predpise (ZPrCP);
- Uporabljati pločnike in označene prehode za pešce;
- Nikoli gledati v zaslon telefona ali pametne ure med prečkanjem cestišča.

3.3. Izključitev odgovornosti:
Ponudnik ne odgovarja za morebitne telesne poškodbe, nesreče, izgubo orientacije ali materialno škodo, ki bi nastala med uporabo peš navigacije ali zaradi nepravilnih podatkov o lokaciji (GPS odstopanj)."""
    ),
    LegalSection(
        number = "4",
        title = "PRAVILA UPORABE FUNKCIJE »PIVSKA KLAPA« (KLEPET IN LIVE RADAR)",
        content = """4.1. Delovanje skupinske sobe:
Funkcija »Pivska Klapa« omogoča ustvarjanje začasnih skupinskih sob s kodo, v katerih člani v realnem času delijo:
- Izbrano ime oziroma vzdevek;
- Stanje števca popitih pijač (Runda Tracker);
- Besedilna sporočila v klepetu;
- Svojo trenutno geografsko lokacijo (Live Radar na zemljevidu, ki se ob aktivni klapi sinhronizira vsakih 6 sekund).

4.2. Prostovoljno deljenje lokacije:
Z vstopom v sobo Pivske Klape se Uporabnik izrecno zaveda in soglaša, da bo njegova trenutna GPS lokacija vidna vsem ostalim članom, ki imajo kodo iste sobe, dokler sobe ne zapusti.

4.3. Pravila obnašanja in prepovedane vsebine (EULA / User-Generated Content):
Pri uporabi skupinskega klepeta in izbiri imena je strogo prepovedano objavljati ali pošiljati vsebine, ki:
- So žaljive, sovražne, diskriminatorne, nasilne ali nadlegujejo druge uporabnike;
- Vsebujejo nezakonite vsebine, grožnje ali osebne podatke tretjih oseb brez njihovega dovoljenja;
- Zlorabljajo delovanje strežnika (npr. pošiljanje neželenih sporočil – spam, poskusi vdorov ali ponarejanja paketov).

4.4. Moderiranje in ukrepi upravljavca:
V skladu z zahtevami trgovin Apple App Store in Google Play za uporabniško ustvarjeno vsebino si Ponudnik pridržuje pravico do skrbniškega pregleda aktivnih sob prek nadzornega sistema ter pravico, da brez predhodnega opozorila izbriše neprimerna sporočila, odstrani sobo ali trajno blokira napravo (deviceId / IP naslov) Uporabnika, ki krši te Pogoje."""
    ),
    LegalSection(
        number = "5",
        title = "ZUNANJE STORITVE, PODATKI O LOKALIH IN TAKSI SLUŽBE",
        content = """5.1. Podatki o gostinskih lokalih in pekarnah:
Podatki o bližnjih barovih, pubih, restavracijah in pekarnah (vključno z odpiralnimi časi, naslovi in telefonskimi številkami) se pridobivajo prek zunanjega servisa Geoapify Places API ter vgrajenih informativnih seznamov. Ponudnik ne jamči za 100-odstotno točnost odpiralnih časov (npr. v funkciji Burek Pavza) ali cen v lokalih.

5.2. Klic taksi službe:
Aplikacija v orodjih ponuja hitre gumbe za klic zunanjih izvajalcev taksi prevozov (npr. Taxi Metro, Taxi Laguna). Ponudnik aplikacije ŠankFinder ni prevoznik, ne posreduje pri naročilu prevoza in ne prevzema nobene odgovornosti za razpoložljivost, ceno ali izvedbo prevoza s strani izbrane taksi službe."""
    ),
    LegalSection(
        number = "6",
        title = "POLITIKA ZASEBNOSTI IN VARSTVO OSEBNIH PODATKOV (GDPR & ZVOP-2)",
        content = """Ponudnik obdeluje podatke v skladu s Splošno uredbo o varstvu podatkov (Uredba EU 2016/679 – GDPR) in Zakonom o varstvu osebnih podatkov (ZVOP-2) po načelu najmanjšega obsega podatkov (Data Minimization) in vgrajene zasebnosti (Privacy by Design).

6.1. Katere podatke aplikacija obdeluje in zakaj?
- Geolokacija (GPS) in kompas: Prikaz bližnjih lokalov, izračun peš poti (OSRM) in poravnava zemljevida. Obdeluje se na napravi; ob izračunu poti se koordinati pošljeta OSRM/Geoapify strežniku brez osebnega imena. Pravna podlaga: Izvajanje storitve / privolitev prek sistemskih dovoljenj OS.
- Lokacija in klepet v »Pivski Klapi«: Prikaz lokacije prijateljev na zemljevidu (Live Radar), števec pijač in skupinski klepet v živo. Obdeluje se na strežniku sankfinder.sluga.me v šifrirani obliki (AES-256-GCM). Pravna podlaga: Izrecna privolitev ob prostovoljnem vstopu v sobo Klape.
- Kamera, fotografije in podatki z računov (OCR / FURS QR): Prepoznava zneska, artiklov in davčne QR kode (ZOI/EOR) za osebni dnevnik obiskov. Obdeluje se izključno lokalno na telefonu (prek Apple Vision na iOS oz. Google ML Kit na Androidu). Slike računov se nikoli ne pošiljajo na strežnik. Pravna podlaga: Izrecna privolitev (uporaba skenerja).
- Tehnični identifikator naprave (deviceId) in telemetrija: Delovanje WebSocket povezave, dostava potisnih obvestil, preprečevanje zlorab (HMAC podpis) in diagnostika delovanja. Hranjeno kot naključno generiran anonimiziran ID v varni shrambi naprave ter na strežniku. Pravna podlaga: Zakoniti interes za varnost in delovanje sistema (čl. 6(1)(f) GDPR).

6.2. Kriptografska zaščita podatkov (Varnostni standardi):
- Zaščita na mobilni napravi: Celotna zgodovina obiskov, skenirani zneski in davčni računi so na napravi Uporabnika šifrirani z algoritmom AES-256-GCM. Šifrirni ključi so strojno zaščiteni v AndroidKeyStore / Apple Secure Enclave in se ne prenašajo v nezaščitene varnostne kopije.
- Zaščita med prenosom: Vsa komunikacija med aplikacijo in strežnikom sankfinder.sluga.me poteka prek šifriranega protokola HTTPS / WSS z obveznim TLS 1.3 ter kriptografskim podpisovanjem zahtevkov HMAC-SHA256, ki preprečuje prestrezanje in ponarejanje prometa.
- Zaščita na strežniku (At-Rest Encryption): Sporočila klepeta in GPS koordinate članov Pivske Klape se pred zapisom v strežniško bazo podatkov (SQLite) šifrirajo v pomnilniku z algoritmom AES-256-GCM (z naključnim 12-bajtnim IV vektorjem in 16-bajtnim avtentikacijskim žetonom).

6.3. Čas hrambe in samodejni izbris po 24 urah:
- Podatki na strežniku (Pivska Klapa & GPS koordinate): Na strežniku teče samodejni urni čistilec, ki nepovratno in trajno izbriše vse neaktivne sobe, vsa sporočila klepeta in vse zgodovinske GPS koordinate članov, ki so starejše od 24 ur.
- Podatki na telefonu (Zgodovina obiskov): Hranijo se izključno v šifrirani lokalni shrambi na telefonu Uporabnika, dokler jih Uporabnik sam ne izbriše v zavihku Zgodovina (gumb z ikono koša) ali z odstranitvijo aplikacije.

6.4. Pravice Uporabnika:
Uporabnik lahko kadarkoli v sistemskih nastavitvah telefona prekliče dovoljenje za dostop do lokacije (GPS), kamere ali potisnih obvestil; samostojno izbriše shranjene obiske in račune v aplikaciji; zapusti aktivno sobo Pivske Klape (s čimer se nemudoma prekine pošiljanje lokacije); ter na naslov contact@sluga.me pošlje zahtevo za izbris tehničnega zapisa svoje naprave (deviceId) ali vprašanje glede varstva podatkov. Uporabnik ima pravico do vložitve pritožbe pri Informacijskem pooblaščencu RS (gp.ip@ip-rs.si)."""
    ),
    LegalSection(
        number = "7",
        title = "INTELEKTUALNA LASTNINA IN PRIPIS VIROV (ATTRIBUTION)",
        content = """7.1. Izvorna koda, oblikovna podoba, logotip (zatič s pivskim kozarcem) in blagovna znamka ŠankFinder so izključna last Ponudnika. Prepovedano je kopiranje, dekompiliranje, obratni inženiring ali nepooblaščena distribucija aplikacije.

7.2. Kartografski viri in odprtokodne pravice:
- Kartografski podatki in slikovne ploščice zemljevida: © OpenStreetMap contributors (licenca Open Database License – ODbL, https://www.openstreetmap.org/copyright).
- Izračun peš poti: Project OSRM (http://project-osrm.org/) in routing.openstreetmap.de.
- Podatki o interesnih točkah (POI): Geoapify (https://www.geoapify.com/)."""
    ),
    LegalSection(
        number = "8",
        title = "KONČNE DOLOČBE IN REŠEVANJE SPOROV",
        content = """8.1. Ponudnik si pridržuje pravico do občasne posodobitve teh Pogojev ob dodajanju novih funkcionalnosti ali spremembi zakonodaje. O bistvenih spremembah bodo uporabniki obveščeni prek obvestila v aplikaciji.

8.2. Za razlago in presojo teh Pogojev se uporablja izključno pravo Republike Slovenije. Morebitne spore bosta stranki reševali sporazumno, v primeru neuspeha pa je za reševanje pristojno stvarno pristojno sodišče v Ljubljani.

8.3. Kontakt upravljavca:
Za vsa vprašanja, tehnično podporo ali prijavo neprimerne vsebine nam pišite na: contact@sluga.me."""
    )
)

@Composable
fun LegalTermsDialog(
    isConsentMode: Boolean,
    onDismiss: () -> Unit,
    onAccept: () -> Unit = {}
) {
    val context = LocalContext.current
    var showRejectAlert by remember { mutableStateOf(false) }

    Dialog(
        onDismissRequest = {
            if (!isConsentMode) onDismiss()
        },
        properties = DialogProperties(
            usePlatformDefaultWidth = false,
            dismissOnBackPress = !isConsentMode,
            dismissOnClickOutside = !isConsentMode
        )
    ) {
        Surface(
            modifier = Modifier.fillMaxSize(),
            color = Color(0xFF0F172A)
        ) {
            Column(modifier = Modifier.fillMaxSize()) {
                // Top header bar
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color(0xFF111827))
                        .padding(horizontal = 16.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.weight(1f)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Gavel,
                            contentDescription = null,
                            tint = BeerGold,
                            modifier = Modifier.size(24.dp)
                        )
                        Spacer(modifier = Modifier.width(10.dp))
                        Column {
                            Text(
                                text = "Pogoji uporabe & GDPR",
                                fontSize = 17.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color.White
                            )
                            Text(
                                text = "Pravne informacije in politika zasebnosti",
                                fontSize = 11.sp,
                                color = Color(0xFF94A3B8)
                            )
                        }
                    }

                    if (!isConsentMode) {
                        IconButton(onClick = onDismiss) {
                            Icon(
                                imageVector = Icons.Default.Close,
                                contentDescription = "Zapri",
                                tint = Color.White
                            )
                        }
                    }
                }

                // Content list
                LazyColumn(
                    modifier = Modifier
                        .weight(1f)
                        .padding(horizontal = 16.dp)
                ) {
                    item {
                        Spacer(modifier = Modifier.height(14.dp))

                        // App meta card
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(12.dp),
                            colors = CardDefaults.cardColors(containerColor = Color(0xFF1E293B)),
                            border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF334155))
                        ) {
                            Column(modifier = Modifier.padding(14.dp)) {
                                Text(
                                    text = "SPLOŠNI POGOJI UPORABE IN POLITIKA ZASEBNOSTI MOBILNE APLIKACIJE »ŠANKFINDER«",
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = BeerGold
                                )
                                Spacer(modifier = Modifier.height(6.dp))
                                Text(
                                    text = "Zadnja posodobitev: Oktober 2026   •   Veljavna različica: 1.2.1\nUpravljavec: Razvojna ekipa ŠankFinder (contact@sluga.me)",
                                    fontSize = 11.5.sp,
                                    color = Color(0xFFCBD5E1)
                                )
                            }
                        }

                        if (isConsentMode) {
                            Spacer(modifier = Modifier.height(12.dp))
                            Card(
                                modifier = Modifier.fillMaxWidth(),
                                shape = RoundedCornerShape(12.dp),
                                colors = CardDefaults.cardColors(containerColor = BeerGold.copy(alpha = 0.15f)),
                                border = androidx.compose.foundation.BorderStroke(1.dp, BeerGold.copy(alpha = 0.5f))
                            ) {
                                Row(
                                    modifier = Modifier.padding(12.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.Security,
                                        contentDescription = null,
                                        tint = BeerGold,
                                        modifier = Modifier.size(24.dp)
                                    )
                                    Spacer(modifier = Modifier.width(10.dp))
                                    Text(
                                        text = "Pred začetkom uporabe aplikacije ŠankFinder morate prebrati in potrditi spodnje Pogoje uporabe in Politiko zasebnosti (GDPR).",
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.Medium,
                                        color = Color.White
                                    )
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(14.dp))
                    }

                    items(LEGAL_SECTIONS.size) { index ->
                        val section = LEGAL_SECTIONS[index]
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 6.dp),
                            shape = RoundedCornerShape(12.dp),
                            colors = CardDefaults.cardColors(containerColor = Color(0xFF161F30)),
                            border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF243046))
                        ) {
                            Column(modifier = Modifier.padding(14.dp)) {
                                Text(
                                    text = "${section.number}. ${section.title}",
                                    fontSize = 14.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = BeerGold
                                )
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(
                                    text = section.content,
                                    fontSize = 12.5.sp,
                                    lineHeight = 18.sp,
                                    color = Color(0xFFE2E8F0)
                                )
                            }
                        }
                    }

                    item {
                        Spacer(modifier = Modifier.height(20.dp))
                        Text(
                            text = "© 2026 Razvojna ekipa ŠankFinder. Vse pravice pridržane.",
                            fontSize = 11.sp,
                            color = Color(0xFF64748B),
                            textAlign = TextAlign.Center,
                            modifier = Modifier.fillMaxWidth()
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                    }
                }

                // Bottom actions
                Surface(
                    modifier = Modifier.fillMaxWidth(),
                    color = Color(0xFF111827),
                    tonalElevation = 8.dp,
                    border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF1F2937))
                ) {
                    if (isConsentMode) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 12.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Button(
                                onClick = onAccept,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(48.dp),
                                shape = RoundedCornerShape(12.dp),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = BeerGold,
                                    contentColor = Color.Black
                                )
                            ) {
                                Text("Sprejmi pogoje uporabe in nadaljuj", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            }

                            OutlinedButton(
                                onClick = { showRejectAlert = true },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(44.dp),
                                shape = RoundedCornerShape(12.dp),
                                border = androidx.compose.foundation.BorderStroke(1.dp, DrajvRed.copy(alpha = 0.6f)),
                                colors = ButtonDefaults.outlinedButtonColors(contentColor = DrajvRed)
                            ) {
                                Text("Zavrni in zapri aplikacijo", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                            }
                        }
                    } else {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 12.dp)
                        ) {
                            Button(
                                onClick = onDismiss,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(46.dp),
                                shape = RoundedCornerShape(12.dp),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = BeerGold,
                                    contentColor = Color.Black
                                )
                            ) {
                                Text("Zapri", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            }
                        }
                    }
                }
            }
        }
    }

    if (showRejectAlert) {
        AlertDialog(
            onDismissRequest = { showRejectAlert = false },
            icon = {
                Icon(
                    imageVector = Icons.Default.Warning,
                    contentDescription = null,
                    tint = DrajvRed,
                    modifier = Modifier.size(32.dp)
                )
            },
            title = {
                Text(
                    text = "Pogoji niso bili sprejeti",
                    fontWeight = FontWeight.Bold,
                    fontSize = 17.sp,
                    textAlign = TextAlign.Center
                )
            },
            text = {
                Text(
                    text = "Za uporabo mobilne aplikacije ŠankFinder je zakonsko obvezno sprejetje Splošnih pogojev uporabe in Politike zasebnosti (GDPR). Ker se s pogoji ne strinjate, se bo aplikacija zdaj zaprla.",
                    fontSize = 13.5.sp,
                    color = MaterialTheme.colorScheme.onSurface,
                    textAlign = TextAlign.Center
                )
            },
            confirmButton = {
                Button(
                    onClick = {
                        showRejectAlert = false
                        (context as? Activity)?.finishAffinity() ?: exitProcess(0)
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = DrajvRed)
                ) {
                    Text("V redu (Zapri aplikacijo)", color = Color.White, fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showRejectAlert = false }) {
                    Text("Nazaj na pogoje")
                }
            }
        )
    }
}
