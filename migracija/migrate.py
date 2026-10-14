"""
POKSIPP - migracija baze sa SQLite-a (Delphi aplikacija) na MySQL/MariaDB.

Sta radi, redom:
  1. Cita SQLite bazu SAMO ZA CITANJE (original se ne menja).
  2. Pretvara podatke po pravilima iz zajednicko.py i proverava ih
     (strani kljucevi, obavezna polja, duplikati). Ako nesto ne valja,
     staje PRE nego sto dira MySQL i ispisuje sta treba popraviti.
  3. Pravi bazu 'poksipp' (ako ne postoji) i tabele iz schema_mysql.sql
     (stare tabele brise - migracija moze da se pokrene koliko god puta).
  4. Upisuje sve podatke u JEDNOJ transakciji: ili sve, ili nista.

Pokretanje (XAMPP, MySQL pokrenut):
    pip install pymysql
    python migrate.py
Ostali parametri: python migrate.py --help
"""

import os
import sys
import time

from zajednicko import TABELE, argumenti, mysql_konekcija, procitaj_sqlite, pretvori_sve


def izvrsi_semu(cur, putanja):
    """Izvrsava SQL fajl naredbu po naredbu (deli po ';' na kraju reda)."""
    with open(putanja, encoding="utf-8") as f:
        linije = [l for l in f.read().splitlines() if not l.strip().startswith("--")]
    tekst = "\n".join(linije)
    for naredba in tekst.split(";\n"):
        naredba = naredba.strip().rstrip(";")
        if naredba:
            cur.execute(naredba)


def main():
    a = argumenti("Migracija POKSIPP baze sa SQLite-a na MySQL")
    ovde = os.path.dirname(os.path.abspath(__file__))
    sema = os.path.join(ovde, "schema_mysql.sql")
    pocetak = time.time()

    # --- 1. i 2. Citanje i provera (MySQL se jos ne dira) ---
    print(f"SQLite: {os.path.abspath(a.sqlite)}")
    sirovo = procitaj_sqlite(a.sqlite)
    podaci, greske = pretvori_sve(sirovo)
    if greske:
        print("\nMIGRACIJA NIJE POKRENUTA - podaci imaju probleme koje treba resiti:")
        for g in greske:
            print("  -", g)
        print("\nPopravi ih u Delphi aplikaciji ili u bazi, pa pokreni ponovo.")
        sys.exit(1)

    # --- 3. Baza i tabele ---
    con = mysql_konekcija(a, sa_bazom=False)
    cur = con.cursor()
    cur.execute(f"CREATE DATABASE IF NOT EXISTS `{a.database}` "
                f"CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
    cur.execute(f"USE `{a.database}`")
    izvrsi_semu(cur, sema)       # DDL u MySQL-u se sam potvrdjuje (implicit commit)

    # --- 4. Podaci u jednoj transakciji ---
    try:
        con.begin()
        for tabela, _, kolone in TABELE:
            redovi = podaci[tabela]
            if not redovi:
                print(f"  {tabela:<18} 0 redova")
                continue
            lista = ", ".join(f"`{k}`" for k in kolone)
            mesta = ", ".join(["%s"] * len(kolone))
            # Sifre (ID) se prenose iste - na njih pokazuju strani kljucevi.
            # AUTO_INCREMENT u MySQL-u sam nastavlja od najvece sifre.
            cur.executemany(f"INSERT INTO `{tabela}` ({lista}) VALUES ({mesta})", redovi)
            print(f"  {tabela:<18} {len(redovi)} redova")
        con.commit()
    except Exception as e:
        con.rollback()
        print(f"\nGRESKA pri upisu - nista nije upisano (rollback): {e}")
        sys.exit(1)
    finally:
        cur.close()
        con.close()

    print(f"\nMigracija zavrsena za {time.time() - pocetak:.1f} s. "
          f"Sledeci korak: python verify.py")


if __name__ == "__main__":
    main()
