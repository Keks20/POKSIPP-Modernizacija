# POKSIPP u Docker-u

Jedna komanda podiže web stranicu za vlasnike, API i MySQL bazu, bez XAMPP-a i bez PHP-a na računaru.
To je ista postavka koja kasnije ide na server.

| Šta | Gde |
| --- | --- |
| Sajt za vlasnike | http://localhost:8080 |
| API | http://localhost:8080/api |
| Baza (HeidiSQL, DBeaver…) | `127.0.0.1`, port `3307`, korisnik `poksipp`, lozinka iz `.env` |

Portovi su namerno drugačiji od XAMPP-a (80/8000 i 3306), pa XAMPP i Docker mogu da rade istovremeno.

## Prvo pokretanje

Treba ti Docker Desktop (uključen, ikonica kita dole desno).

1. Kopiraj `docker\env-primer.txt` u koren repozitorijuma (gde je `docker-compose.yml`) pod imenom `.env`.
   U PowerShell-u, iz korena: `Copy-Item docker\env-primer.txt .env`
2. Napravi ključ aplikacije. U folderu `api`:

   ```
   php artisan key:generate --show
   ```

   Ceo rezultat (`base64:...`) upiši u `.env` kao `APP_KEY=base64:...`.
3. Po želji: ubaci svoju bazu umesto demo podataka (vidi `docker/podaci/README.md`).
4. Iz korena repozitorijuma:

   ```
   docker compose up -d --build
   ```

   Prvi put traje nekoliko minuta (skida PHP i MariaDB i instalira pakete). Posle toga traje par sekundi.
5. Otvori http://localhost:8080.

## Demo nalozi

Ako nisi ubacio svoju bazu, baza kreće sa izmišljenim podacima (`docker/demo.sql`):

| Nalog | Lozinka | Uloga |
| --- | --- | --- |
| `admin` | `admin123` | administrator (API) |
| `osoblje3` | `nikola123` | negovatelj (API) |
| `vlasnik1` | `pass123` | vlasnik: Reks i Maca (sajt i API) |
| `vlasnik2` | `pass123` | vlasnik: Žuća |

## Svakodnevne komande

| Komanda | Šta radi |
| --- | --- |
| `docker compose up -d` | pali sve (u pozadini) |
| `docker compose down` | gasi sve; **podaci u bazi ostaju** |
| `docker compose ps` | šta radi i da li je baza „healthy” |
| `docker compose logs -f app` | greške sajta i API-ja (Ctrl+C za izlaz) |
| `docker compose exec app php artisan test` | svih 49 testova, nad bazom `poksipp_test` u Docker-u |
| `docker compose up -d --build` | posle izmene koda u `api/`: pravi novi image |
| `docker compose down -v` | gasi sve **i briše bazu**; sledeći start pravi je iznova |

## Kako je složeno

- `docker-compose.yml`: dva kontejnera, `db` (MariaDB 10.11) i `app` (PHP 8.5 + Apache + Laravel iz `api/`).
- `docker/Dockerfile`: image za `app`. Ekstenzije `pdo_mysql`, `gd`, `exif` i `intl`, Composer paketi i kod.
- `docker/db-init/01-poksipp.sh`: radi samo pri prvom pokretanju baze. Pravi šemu iz `migracija/schema_mysql.sql`, pa ubacuje tvoj dump ili demo podatke.
- `docker/start.sh`: pri svakom startu `app` kontejnera pokreće `php artisan migrate` (tabele za tokene), pa Apache.
- Baza živi u Docker volume-u `db-podaci`. Zato preživi `docker compose down`, a nestaje tek sa `-v`.

## Delphi i Docker baza

Delphi za sada ostaje na XAMPP bazi (port 3306, TLS sa našim sertifikatima). Docker baza je posebna baza,
pa ono što uneseš u Delphiju ne vidiš na `localhost:8080`, nego na sajtu iz XAMPP postavke (`php artisan serve`).
Da bi i Delphi radio nad Docker bazom, Docker bazi trebaju isti TLS sertifikati. To radimo kad se baza seli na server.

## Kad nešto ne radi

- **`APP_KEY nije podesen`** u `docker compose logs app`: korak 2 iz „Prvo pokretanje”.
- **Port je zauzet** (`port is already allocated`): u `docker-compose.yml` promeni levi broj (`"8080:80"` → `"8081:80"`).
- **Demo podaci umesto tvojih**: dump je dodat posle prvog pokretanja. `docker compose down -v`, pa `docker compose up -d`.
