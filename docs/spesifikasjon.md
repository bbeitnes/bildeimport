# Bildeimport – spesifikasjon

Enkel Mac-app for import av bilder og videoer. Beslutninger fra samtalen 24. oktober 2026, oppdatert med avklaringene som ble gjort før designet og implementeringen.

## Formål og målgruppe

Appen skal gjøre det svært enkelt for en eldre person å importere bilder og videoer fra et eksternt minnekort til en valgt hovedmappe på Macen eller en annen tilkoblet disk. Grensesnittet skal være grafisk, intuitivt og lett å forstå.

## Plattform og distribusjon

- Appen heter **Bildeimport**.
- Første versjon fungerer bare på Mac med Apple Silicon (M1, M2 og nyere) og nyeste macOS. Minstekravet er macOS 15.
- Appen er laget med SwiftUI og Swift Package Manager. Utviklingen gjøres med Claude Code.
- All kode, alle filnavn og alle kommentarer i koden er på engelsk. All tekst brukeren ser, er på norsk bokmål.
- Appen pakkes som en DMG-fil som lastes ned fra GitHub-repositoriet `bildeimport` under Releases. GitHub Actions bygger DMG-filen når en versjonstagg som `v1.0.0` pushes.
- Appen signeres ikke med Apple Developer-medlemskap i denne omgang. Den signeres ad hoc, og README forklarer hvordan appen godkjennes første gang via Systeminnstillinger → Personvern og sikkerhet → «Åpne likevel».

## Brukerflyt

1. Brukeren setter inn minnekortet. Appen oppdager kortet og viser hvor mange bilder og videoer det inneholder.
2. Hovedmappen er allerede valgt fra forrige gang, for eksempel «Bilder». Den kan byttes med knappen «Velg en annen mappe».
3. Brukeren trykker «Importer».
4. Appen viser fremdrift og kopierer bildene og videoene til riktig år og dato.
5. Appen viser en tydelig oppsummering. Brukeren trykker «Løs ut minnekortet», og appen bekrefter at kortet trygt kan tas ut.

Brukeren skal ikke måtte velge en årsmappe eller opprette datomapper selv. Appen forklarer at mapper for år og dato lages automatisk inni hovedmappen.

### Skjermbilder

| Skjermbilde | Innhold |
| --- | --- |
| Sett inn minnekortet | Stort kortikon, kort forklaring og valgt hovedmappe |
| Flere minnekort funnet | Vises bare når flere kort er satt inn. Brukeren velger kort fra en liste |
| Klar til å importere | Antall filer på kortet, hovedmappen, eksempel på mappestruktur og en stor «Importer»-knapp |
| Kopierer bildene | Stor fremdriftslinje, «312 av 1 204 filer», omtrentlig tid igjen, advarsel om ikke å ta ut kortet og en «Avbryt»-knapp |
| Ferdig | Oppsummering, «Løs ut minnekortet» og «Vis bildene» |
| Nå kan du trygt ta ut kortet | Bekreftelse etter utløsing |

### Utseende

- Stor tekst og høy kontrast. Brødtekst er 19–21 punkter, og titler er 34 punkter.
- Hvert skjermbilde har én tydelig hovedknapp.
- Appen har ingen menyer brukeren må lete i, og bare ett vindu. Når vinduet lukkes, avsluttes appen.

## Minnekort

- En flyttbar disk regnes som minnekort når den har en kameramappe: `DCIM`, `PRIVATE/M4ROOT`, `PRIVATE/AVCHD`, `AVF_INFO` eller `MP_ROOT`. Vanlige USB-disker og interne disker ignoreres.
- Når ett kort er satt inn, velges det automatisk. Når flere kort er satt inn, velger brukeren kort fra en liste.
- Hele kortet gjennomsøkes, også alle undermapper.
- Hovedmappen kan ikke ligge på selve minnekortet.

## Filer som skal importeres

- Både bilder og videoer importeres. Formatstøtten er bred.
- Bilder: JPG, JPEG, HEIC, HEIF, HIF, PNG, TIFF, GIF, BMP, WebP, AVIF og JPEG XL.
- RAW: Olympus (ORF, ORI), Canon (CR2, CR3, CRW), Sony (ARW, SR2, SRF) og andre vanlige RAW-formater som DNG, NEF, RAF, RW2 og PEF.
- Video: MOV, MP4, M4V, MTS, M2TS, MPG, AVI, 3GP, MKV, WMV, MOD og TOD.
- Hjelpe- og systemfiler som `.THM`, `.XML`, `.XMP`, kameradatabaser og skjulte filer kopieres ikke.
- Originalene blir liggende urørt på kortet. Import betyr kopiering, ikke flytting.

## Dato og mappestruktur

- Opptaksdato bestemmer hvor filen lagres, ikke datoen importen utføres.
- Under hovedmappen opprettes årsmapper med formatet `ÅÅÅÅ` og datomapper med formatet `ÅÅÅÅ-MM-DD`.
- Bilder og videoer fra samme dag lagres i samme datomappe. RAW og JPG av samme bilde havner dermed sammen.
- Manglende mapper opprettes automatisk, og eksisterende mapper brukes.
- Ett kort kan inneholde filer fra flere år. Filene fordeles automatisk.

### Rekkefølge for dato

1. Opptaksdato fra filens metadata:
   - For bilder brukes EXIF-feltet `DateTimeOriginal`, deretter `DateTimeDigitized` og til slutt TIFF-feltet `DateTime`. Datoen brukes slik kameraet skrev den, fordi det er lokal tid der bildet ble tatt.
   - For Sony-video brukes XML-filen ved siden av klippet, for eksempel `C0001M01.XML`. Den har lokal tid med tidssone.
   - For annen video brukes QuickTime-feltet for opprettelsesdato med tidssone når det finnes. Ellers brukes opprettelsestiden i UTC, omregnet til Macens tidssone. En video tatt 00:30 norsk tid havner da på riktig dag.
2. Filens endringsdato på kortet, når metadata mangler dato.
3. Mappen `Ukjent dato` direkte under hovedmappen, når ingen av datoene er brukbare.

Datoer før 1990 eller mer enn ett år frem i tid regnes som feil kameraklokke og brukes ikke.

Eksempel med «Bilder» som hovedmappe:

```text
Bilder/
    2025/
        2025-12-31/
            IMG_1234.CR3
            IMG_1234.JPG
    2026/
        2026-10-24/
            P1012345.ORF
            C0001.MP4
    Ukjent dato/
        bilde_uten_dato.jpg
```

## Hovedmappe

- Appen husker hovedmappen til neste gang. Standardvalget første gang er brukerens Bilder-mappe.
- Mappen kan byttes med «Velg en annen mappe».
- Hvis hovedmappen ligger på en ekstern disk som ikke er koblet til, viser appen for eksempel: «Disken "Bilder-disk" er ikke koblet til. Koble den til, eller velg en annen mappe.» Import er ikke mulig før mappen er tilgjengelig.

## Beskyttelse av filer og duplikater

- Eksisterende filer overskrives aldri.
- En fil regnes som allerede importert når en fil med samme navn finnes i datomappen og
  - har samme størrelse og samme endringstidspunkt (innenfor 2 sekunder). Dette avgjøres uten å lese filene, slik at en ny import av et kort som er importert før, går raskt. Appen beholder kortets endringstidspunkt når den kopierer.
  - eller har samme størrelse og identisk innhold når filene sammenlignes byte for byte. Dette brukes når endringstidspunktet er ulikt.
- Filer som allerede er importert, hoppes over i stillhet og telles i oppsummeringen.
- En annen fil med samme navn får et nummer: `IMG_1234 (2).JPG`, deretter `(3)` og så videre. Nummererte filer sjekkes også for identisk innhold, slik at en ny import av samme kort ikke lager flere kopier.
- Hver fil kopieres først under et skjult midlertidig navn, sammenlignes med originalen og får først deretter sitt endelige navn. En halvveis kopiert fil blir aldri liggende.
- Før kopieringen starter, kontrollerer appen at det er nok ledig plass. Filer som etter navn og størrelse ser ut til å være importert fra før, regnes ikke med.
- Macen holdes våken mens appen kopierer.

## Avbryte og ta ut kortet

- «Avbryt» stopper etter filen som kopieres. Det som allerede er kopiert, beholdes.
- Hvis kortet tas ut under kopieringen, stopper appen trygt og forklarer at resten kan hentes ved å sette inn kortet igjen og trykke «Importer».

## Oppsummering

Oppsummeringen viser bare linjer som gjelder:

- Antall nye bilder og videoer som er kopiert.
- Antall filer som allerede var importert og ble hoppet over.
- Antall filer som fikk dato fra filen fordi opptaksdato manglet.
- Antall filer som fikk et nummer i navnet.
- Antall filer uten dato som ligger i `Ukjent dato`.
- Filer som ikke kunne kopieres, med navn. Originalene ligger fortsatt på kortet.
- Hvilke årsmapper som fikk nye bilder, for eksempel «Bildene ligger i Bilder › 2025 og Bilder › 2026».

Knappene er «Løs ut minnekortet» og «Vis bildene». Appen løser ikke ut kortet automatisk.

## Ikke med i første versjon

- Støtte for Intel-Mac og eldre macOS.
- Signering og notarisation hos Apple.
- Valg av enkeltbilder, forhåndsvisning av bilder og sletting fra kortet.
- Andre språk enn norsk.
