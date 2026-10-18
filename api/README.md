# Faza 3: POKSIPP API (Laravel 13)

REST API nad istom MySQL bazom `poksipp` koju pravi migracija iz Faze 2. Tabele su iste kao u Delphi aplikaciji (`ZAPOSLENI`, `MUSTERIJA`, `pets`, `DNEVNA_AKTIVNOST`…), pa se ništa ne preimenuje i ne kopira.

## Pokretanje (XAMPP)

1. U XAMPP Control Panelu pokreni **MySQL**. Baza `poksipp` mora da postoji, a pravi je `..\migracija\migrate.py`.
2. U ovom folderu, samo prvi put:

   ```
   composer install
   php artisan migrate
   ```

   `migrate` dodaje samo dve Laravelove tabele: `migrations` i `personal_access_tokens` (tokeni za prijavu). Tabele POKSIPP-a ne dira.

3. Pokreni server:

   ```
   php artisan serve
   ```

   API je na `http://127.0.0.1:8000/api`.

4. U Postman-u uvezi `postman\POKSIPP.postman_collection.json` (Import). Pokreni jednu od prijava, pa ostale pozive. Token se sam sačuva.

Podešavanja baze su u `.env` (`DB_DATABASE=poksipp`, `DB_USERNAME=root`, prazna lozinka, kao u XAMPP-u).

## Web stranica za vlasnike

Ista aplikacija ima i stranicu za vlasnike ljubimaca: `http://127.0.0.1:8000` (posle `php artisan serve`).

- Prijava istim nalogom kao u Delphiju (korisničko ime ili email). Zaposleni koriste Delphi.
- **Moji ljubimci:** kartice sa slikom, boksom i statusom. Vlasnik vidi samo svoje ljubimce.
- **Detalji:** račun za boravak i dnevnik (sve, aktivnosti, hrana, ostalo), 20 zapisa po strani.
- **Slika:** vlasnik postavlja sliku svog ljubimca. Server je okrene kako treba (EXIF sa telefona), smanji na najviše 800 px i snimi kao JPEG bez metapodataka (nestaje i GPS lokacija). Slika ide u `pets.image_blob`, pa je odmah vidi i osoblje u Delphiju.

Za slike PHP treba ekstenzije `gd` i `exif` i veći limit za otpremanje (`upload_max_filesize = 6M`, `memory_limit = 256M` u `php.ini`).

## Prijava i uloge

`POST /api/prijava` sa `korisnicko_ime` i `lozinka` vraća token. Svaki sledeći zahtev ga šalje u zaglavlju:

```
Authorization: Bearer 3|tyIbyg...
Accept: application/json
```

Lozinke su iste kao u Delphi aplikaciji (SHA-256 heš u bazi). Token važi 12 sati.

| Uloga | Ko je to | Sme |
| --- | --- | --- |
| `admin` | ZAPOSLENI sa ulogom Admin | sve |
| `zaposleni` | ostali zaposleni (Negovatelj, Osoblje…) | čitanje svega, magacin, vlasnici |
| `musterija` | vlasnik (MUSTERIJA), prijava i preko emaila | samo svoji ljubimci, dnevnik i račun |

Zaposleni koga admin deaktivira u Delphiju gubi pristup odmah, i kad je token već izdat. Uloga se proverava iz baze pri svakom zahtevu.

## Rute

| Metod | Ruta | Ko | Šta |
| --- | --- | --- | --- |
| POST | `/prijava` | svi | token |
| POST | `/registracija` | svi | novi vlasnik (pravila iz `fraRegister.pas`) |
| GET | `/ja` | prijavljeni | ko je prijavljen |
| POST | `/odjava` | prijavljeni | briše token |
| GET | `/usluge` | prijavljeni | cenovnik |
| GET | `/ljubimci` | prijavljeni | spisak (`?status=Aktivan` ili `Odjavljen`) |
| GET | `/ljubimci/{id}` | prijavljeni | jedan ljubimac |
| GET | `/ljubimci/{id}/dnevnik` | prijavljeni | dnevnik, 50 po strani (`?kategorija=Aktivnosti`, `Hrana`, `Ostalo`) |
| GET | `/ljubimci/{id}/racun` | prijavljeni | račun za boravak |
| GET | `/ljubimci/{id}/slika` | prijavljeni | slika (JPEG/PNG) |
| POST | `/ljubimci/{id}/slika` | vlasnik (svoj), admin | nova slika, polje `slika` (multipart) |
| GET | `/resursi` | admin, zaposleni | magacin i šta je ispod minimuma |
| GET | `/musterije` | admin, zaposleni | vlasnici |
| GET | `/zaposleni` | admin | zaposleni bez admina |
| POST | `/ljubimci` | admin | prijem u pansion |
| PUT | `/ljubimci/{id}` | admin | izmena podataka |
| POST | `/ljubimci/{id}/odjava` | admin | odjava, vraća račun |

Vlasnik koji traži tuđeg ljubimca dobija 404, a ne 403. Tako ne saznaje ni da taj ljubimac postoji.

Greške: `{"poruka": "..."}`. Za greške u unosu (422) Laravel vraća `{"message": "...", "errors": {"polje": ["..."]}}`.

## Pravila preuzeta iz Delphija

| Pravilo | Delphi | API |
| --- | --- | --- |
| Prijava: prvo zaposleni, pa vlasnik (i preko emaila) | `fraLogin.pas` | `AuthController@prijava` |
| Korisničko ime slobodno i kod vlasnika i kod zaposlenih, email jedinstven | `fraRegister.pas` | `RegistracijaRequest` |
| Vlasnik vidi samo svoje ljubimce | `fraDnevnikMusterije.pas` | `Ljubimac::vidljiviZa` |
| Prijem: vlasnik mora postojati, boks slobodan, `A3` → `Boks A3`, prazne alergije → `Nema poznatih` | `fraAdmin.pas` | `LjubimacController@store` |
| Odjava: ne dok je aktivnost „U toku”; boks se oslobađa; ljubimac ostaje u bazi | `fraAdmin.pas` | `LjubimacController@odjava` |
| Račun: usluge od datuma prijema, po trenutnoj ceni | `uUserStore.ObracunBoravka` | `Services\ObracunBoravka` |

Prijem i izmena proveravaju boks i upisuju u istoj transakciji, sa zaključavanjem reda. Dva admina ne mogu istovremeno da smeste dva ljubimca u isti boks. Delphi tu proveru radi bez transakcije.

## Testovi

```
php artisan test
```

Testovi rade nad posebnom bazom **`poksipp_test`**, a ne nad `poksipp`. Prave je sami, iz iste šeme koju koristi migracija (`..\migracija\schema_mysql.sql`). MySQL u XAMPP-u mora biti pokrenut. Ako se baza u `phpunit.xml` ne završava na `_test`, testovi odbijaju da rade, jer brišu tabele.

## Zajednička baza (od Faze 4)

Delphi aplikacija i API rade nad istom MySQL bazom `poksipp`. Ljubimac primljen u Delphiju odmah se vidi u API-ju, i obrnuto.

- Delphi se povezuje šifrovano (TLS), sa proverom sertifikata servera. Podešavanja su u `poksi.ini` pored `poksi.exe`.
- `migrate.py` se više ne pokreće: odbija da radi kad baza ima podatke, jer bi ih obrisala (vidi `..\migracija\README.md`).

## Šta je gde

| Fajl | Šta |
| --- | --- |
| `app/Models` | Eloquent modeli nad postojećim tabelama (`$table`, `$primaryKey`, `$timestamps = false`) |
| `app/Http/Controllers/Api` | prijava, ljubimci, spiskovi |
| `app/Http/Requests` | validacija i poruke na srpskom |
| `app/Http/Resources` | izgled JSON odgovora (srpski ključevi, nezavisni od naziva kolona) |
| `app/Http/Middleware/ProveraUloge.php` | provera uloge (`uloga:admin`) |
| `app/Services/ObracunBoravka.php` | račun |
| `app/Services/ObradaSlike.php` | provera, okretanje i smanjenje slike |
| `app/Http/Controllers/Web`, `resources/views/web` | web stranica za vlasnike |
| `routes/web.php` | rute web stranice |
| `app/Support/Lozinka.php` | SHA-256, isto kao Delphi i migracija |
| `routes/api.php` | sve rute |
| `tests/Feature` | 49 testova |
| `postman` | Postman kolekcija |
