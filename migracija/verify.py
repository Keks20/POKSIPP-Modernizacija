"""
POKSIPP - provera migracije: da li je MySQL baza ista kao SQLite baza.

Za svaku tabelu:
  * broj redova mora da bude isti;
  * svaki red mora da bude isti, vrednost po vrednost (posle istih pravila
    pretvaranja koja koristi migrate.py - npr. 0 -> NULL za uslugu);
  * kontrolne sume: zbir cena, zbir stanja u magacinu, zbir utroska.

Na kraju ispisuje OK ili tacno koje vrednosti se razlikuju.
Izlazni kod: 0 = sve isto, 1 = ima razlika.

Pokretanje:  python verify.py
"""

import hashlib
import sys
from datetime import datetime
from decimal import Decimal

from zajednicko import TABELE, argumenti, mysql_konekcija, procitaj_sqlite, pretvori_sve

KONTROLNE_SUME = [
    ("USLUGA", "Cena"),
    ("RESURS", "Trenutno_u_Magacinu"),
    ("RESURS", "Kolicina_Nivo"),
    ("DNEVNA_AKTIVNOST", "Kolicina_Utroska"),
]


def normalizuj(v):
    """Ista vrednost iz Pythona i iz MySQL-a mora da izgleda isto."""
    if v is None:
        return None
    if isinstance(v, (bytes, bytearray)):
        return "blob:" + hashlib.sha1(bytes(v)).hexdigest()   # slike poredimo po otisku
    if isinstance(v, Decimal):
        return format(v.normalize(), "f")
    if isinstance(v, float):
        return format(Decimal(str(v)).normalize(), "f")
    if isinstance(v, datetime):
        return v.strftime("%Y-%m-%d %H:%M:%S")
    return str(v)


def main():
    a = argumenti("Provera migracije POKSIPP baze")
    ocekivano, greske = pretvori_sve(procitaj_sqlite(a.sqlite))
    if greske:
        print("SQLite baza ima probleme - prvo ih resi (vidi migrate.py):")
        for g in greske:
            print("  -", g)
        sys.exit(1)

    con = mysql_konekcija(a)
    cur = con.cursor()
    ukupno_razlika = 0

    print(f"{'Tabela':<18} {'SQLite':>7} {'MySQL':>7}  Rezultat")
    print("-" * 52)
    for tabela, kljuc, kolone in TABELE:
        lista = ", ".join(f"`{k}`" for k in kolone)
        cur.execute(f"SELECT {lista} FROM `{tabela}` ORDER BY `{kljuc}`")
        mysql_redovi = cur.fetchall()
        sqlite_redovi = ocekivano[tabela]

        razlike = []
        if len(mysql_redovi) != len(sqlite_redovi):
            razlike.append(f"broj redova: SQLite {len(sqlite_redovi)}, MySQL {len(mysql_redovi)}")

        po_kljucu = {r[0]: r for r in mysql_redovi}
        for s_red in sqlite_redovi:
            m_red = po_kljucu.get(s_red[0])
            if m_red is None:
                razlike.append(f"red {s_red[0]} ne postoji u MySQL-u")
                continue
            for kol, sv, mv in zip(kolone, s_red, m_red):
                if normalizuj(sv) != normalizuj(mv):
                    razlike.append(f"red {s_red[0]}, {kol}: SQLite={normalizuj(sv)!r} "
                                   f"MySQL={normalizuj(mv)!r}")

        rezultat = "OK" if not razlike else f"RAZLIKA ({len(razlike)})"
        print(f"{tabela:<18} {len(sqlite_redovi):>7} {len(mysql_redovi):>7}  {rezultat}")
        for r in razlike[:10]:
            print("      -", r)
        if len(razlike) > 10:
            print(f"      ... i jos {len(razlike) - 10}")
        ukupno_razlika += len(razlike)

    print("\nKontrolne sume")
    print("-" * 52)
    for tabela, kol in KONTROLNE_SUME:
        idx = [k for t, _, k in TABELE if t == tabela][0].index(kol)
        s_zbir = sum((r[idx] for r in ocekivano[tabela] if r[idx] is not None), Decimal(0))
        cur.execute(f"SELECT COALESCE(SUM(`{kol}`), 0) FROM `{tabela}`")
        m_zbir = Decimal(cur.fetchone()[0])
        isto = s_zbir == m_zbir
        if not isto:
            ukupno_razlika += 1
        print(f"{tabela + '.' + kol:<38} {normalizuj(s_zbir):>10}  {'OK' if isto else 'RAZLIKA: MySQL ' + normalizuj(m_zbir)}")

    cur.close()
    con.close()
    print()
    if ukupno_razlika:
        print(f"PROVERA NIJE PROSLA: {ukupno_razlika} razlika.")
        sys.exit(1)
    print("PROVERA PROSLA: MySQL baza je ista kao SQLite baza.")


if __name__ == "__main__":
    main()
