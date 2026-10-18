# Faza 2 — migracija baze sa SQLite-a na MySQL

Ovaj folder prebacuje podatke POKSIPP aplikacije iz SQLite baze (`Delphi\Win32\Debug\Baza\users.db`) u MySQL bazu `poksipp`. Druga skripta zatim proverava da je sve isto.

Original se ne menja: SQLite baza se otvara samo za čitanje.

| Fajl | Šta radi |
| --- | --- |
| `schema_mysql.sql` | Tabele za MySQL: isti nazivi kao u Delphiju, pravi tipovi, strani ključevi, provere |
| `zajednicko.py` | Pravila pretvaranja i provere podataka (koriste ih obe skripte) |
| `migrate.py` | Pravi bazu i tabele i prenosi sve podatke u jednoj transakciji |
| `verify.py` | Upoređuje SQLite i MySQL red po red i proverava kontrolne sume |
| `requirements.txt` | Python biblioteka koja treba (PyMySQL) |

## Pokretanje (XAMPP)

1. U XAMPP Control Panelu pokreni **MySQL** (Start).
2. Jednom instaliraj biblioteku:

   ```
   pip install -r requirements.txt
   ```

3. Iz ovog foldera pokreni:

   ```
   python migrate.py
   python verify.py
   ```

4. Rezultat pogledaj u phpMyAdmin-u (`http://localhost/phpmyadmin`), u bazi `poksipp`.

Migracija briše tabele i pravi ih iznova. Zato se, od Faze 4, pokreće samo jednom.

## Od Faze 4: migracija se pokreće samo jednom

Od Faze 4 Delphi aplikacija i Laravel API upisuju direktno u MySQL. Ponovna migracija bi obrisala sve što je uneto posle prve migracije.

Zato `migrate.py` staje ako baza `poksipp` već ima podatke:

```
MIGRACIJA NIJE POKRENUTA: baza 'poksipp' vec ima 18 redova.
```

Ako baš treba da se napuni iznova iz SQLite-a (na primer na drugom računaru za testiranje):

```
D:\xamppp\mysql\bin\mysqldump -u root poksipp > rezerva.sql
python migrate.py --prepisi
```

Rezervna kopija se vraća sa `D:\xamppp\mysql\bin\mysql -u root poksipp < rezerva.sql`.

`verify.py` poredi MySQL sa SQLite bazom, pa posle prvog unosa u Delphiju ili API-ju javlja razlike. To je očekivano: SQLite više nije glavna baza.

Ostali parametri (druga baza, lozinka, port) se vide sa `python migrate.py --help`. Primer:

```
python migrate.py --sqlite "C:\putanja\do\users.db" --password mojaLozinka
```

## Pravila pretvaranja

Ovo su odluke o podacima. Svaka je u kodu u `zajednicko.py`.

| Podatak | U SQLite-u | U MySQL-u | Zašto |
| --- | --- | --- | --- |
| Datumi | tekst ili broj (FireDAC, julijanski dan, Delphi `TDateTime`) | `DATETIME`, bez delova sekunde | SQLite nema tip za datum |
| Cene | `REAL` | `DECIMAL(10,2)` | novac bez grešaka u zaokruživanju |
| Količine u magacinu i utrošak | `REAL` | `DECIMAL(12,3)` | isto |
| Usluga ili resurs = `0` | `0` | `NULL` | `0` nije postojeća šifra, pa bi strani ključ pukao |
| `pets.Status` prazan | `NULL` | `'Aktivan'` | Delphi ionako čita `NULL` kao „Aktivan” |
| `pets.Lokacija`, `Alergije` prazni | `NULL` | `''` | isto značenje |
| Email prazan | `''` | `NULL` | jedinstven email dozvoljava više praznih |
| Lozinka kao običan tekst | tekst | SHA-256 heš | isto kao Delphi `THashSHA2` |
| Šifre (ID) | — | iste | na njih pokazuju strani ključevi; `AUTO_INCREMENT` nastavlja dalje |

## Šta se proverava pre upisa

Ako nešto od ovoga ne valja, `migrate.py` staje **pre** nego što dira MySQL i ispiše šta treba popraviti:

- strani ključevi: aktivnost pokazuje na nepostojećeg ljubimca, zaposlenog, uslugu ili resurs;
- obavezna polja: ime, korisničko ime, kategorija, vreme početka…;
- duplikati koje SQLite pušta, a MySQL ne (`admin` i `Admin`);
- dozvoljene vrednosti: kategorija `Aktivnosti`/`Hrana`/`Ostalo`, status `Aktivan`/`Odjavljen`;
- datumi koji ne mogu da se pročitaju.

## Šta je testirano

Testirano je na MariaDB 10.11 (XAMPP koristi MariaDB 10.4+):

- tvoja prava baza: 16 redova, provera prošla;
- kopija sa dodatim test podacima: datumi u 4 formata, usluga `0`, odjavljen ljubimac, prazan status, lozinka kao običan tekst, prazan email, slova č ć đ ž;
- migracija pokrenuta 3 puta zaredom: isti rezultat;
- namerno izmenjena vrednost u MySQL-u: `verify.py` je našao i red i kontrolnu sumu;
- loši podaci (nepostojeći ljubimac, duplikat `ADMIN`, kategorija `Setnja`, pogrešan datum): migracija odbijena, MySQL netaknut.

## Šta je namerno ostalo isto

Nazivi tabela i kolona (`pets`, `name`, `Sifra_musterije`…) su isti kao u Delphiju. U Fazi 4 Delphi prelazi na MySQL samo promenom konekcije, bez prepravljanja svakog upita.

Preimenovanje (npr. `pets` → `LJUBIMAC`) ide tek kad Delphi više ne koristi bazu.
