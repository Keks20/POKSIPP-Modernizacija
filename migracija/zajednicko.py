"""
Zajednicka pravila za migraciju POKSIPP baze sa SQLite-a na MySQL.

Koriste ih i migrate.py i verify.py, da bi provera merila TACNO ono sto je
migracija uradila. Svako pravilo ovde je odluka o podacima - opisana je u
README.md, odeljak "Pravila pretvaranja".
"""

import argparse
import hashlib
import os
import re
import sqlite3
import sys
from datetime import datetime, timedelta
from decimal import Decimal, ROUND_HALF_UP

# Redosled je bitan: prvo tabele na koje drugi pokazuju (strani kljucevi).
TABELE = [
    ("ZAPOSLENI", "Sifra_zaposlenog", [
        "Sifra_zaposlenog", "Ime", "Prezime", "Uloga", "KorisnickoIme",
        "Lozinka", "Dostupan"]),
    ("MUSTERIJA", "Sifra_musterije", [
        "Sifra_musterije", "Ime", "Prezime", "Nalog", "Telefon_Hitno",
        "KorisnickoIme", "Lozinka", "Email"]),
    ("USLUGA", "Sifra_usluge", [
        "Sifra_usluge", "Naziv", "Cena"]),
    ("RESURS", "Sifra_resursa", [
        "Sifra_resursa", "Tip_Resursa", "Trenutno_u_Magacinu", "Kolicina_Nivo"]),
    ("pets", "id", [
        "id", "name", "species", "breed", "age", "image_blob", "Status",
        "Sifra_musterije", "Lokacija", "Alergije", "DatumPrijema", "DatumOdjave"]),
    ("DNEVNA_AKTIVNOST", "Sifra_aktivnosti", [
        "Sifra_aktivnosti", "Kategorija", "Vrsta_aktivnosti", "VremeOd", "VremeDo",
        "DuzinaTrajanja", "StatusAktivnosti", "Ocena", "ProcenaPonasanja",
        "Komentar", "Kolicina", "VremeObroka", "StatusOstalo",
        "Sifra_zaposlenog", "Sifra_ljubimca", "Sifra_usluge", "Sifra_resursa",
        "Kolicina_Utroska"]),
]

KOLONE_DATUM = {"DatumPrijema", "DatumOdjave", "VremeOd", "VremeDo"}
KOLONE_NOVAC = {"Cena"}                                            # DECIMAL(10,2)
KOLONE_KOLICINA = {"Trenutno_u_Magacinu", "Kolicina_Nivo", "Kolicina_Utroska"}  # DECIMAL(12,3)
# Strani kljucevi koji smeju da budu prazni: 0 ili '' znaci "nema" -> NULL
KOLONE_OPCIONI_FK = {"Sifra_usluge", "Sifra_resursa", "Sifra_musterije"}
# Tekst koji u MySQL-u ne sme da bude NULL: (tabela, kolona) -> vrednost umesto NULL
PODRAZUMEVANO = {
    ("pets", "Status"): "Aktivan",      # Delphi cita NULL kao 'Aktivan' (COALESCE)
    ("pets", "Lokacija"): "",
    ("pets", "Alergije"): "",
    ("USLUGA", "Cena"): Decimal("0.00"),
    ("RESURS", "Trenutno_u_Magacinu"): Decimal("0.000"),
    ("RESURS", "Kolicina_Nivo"): Decimal("0.000"),
}
# Kolone koje moraju da imaju vrednost - ako je nema, migracija staje i javlja
OBAVEZNO = {
    "ZAPOSLENI": ["Ime", "Prezime", "Uloga", "KorisnickoIme"],
    "MUSTERIJA": ["Ime", "Prezime", "KorisnickoIme"],
    "USLUGA": ["Naziv"],
    "RESURS": ["Tip_Resursa"],
    "pets": ["name"],
    "DNEVNA_AKTIVNOST": ["Kategorija", "Vrsta_aktivnosti", "VremeOd",
                         "Sifra_zaposlenog", "Sifra_ljubimca"],
}
# Jedinstvene kolone. MySQL (utf8mb4_unicode_ci) ne razlikuje velika i mala
# slova, a SQLite razlikuje - 'Admin' i 'admin' bi u MySQL-u bili duplikat.
JEDINSTVENO = {
    "ZAPOSLENI": ["KorisnickoIme"],
    "MUSTERIJA": ["KorisnickoIme", "Email"],
    "USLUGA": ["Naziv"],
    "RESURS": ["Tip_Resursa"],
}
DOZVOLJENO = {
    ("pets", "Status"): {"Aktivan", "Odjavljen"},
    ("DNEVNA_AKTIVNOST", "Kategorija"): {"Aktivnosti", "Hrana", "Ostalo"},
}

HEX64 = re.compile(r"^[0-9a-f]{64}$")


class GreskaPodataka(Exception):
    """Podatak koji ne moze da se prenese bez ljudske odluke."""


# ---------------------------------------------------------------------
#  Pretvaranje vrednosti
# ---------------------------------------------------------------------
def u_datum(v, opis):
    """SQLite nema pravi tip za datum. FireDAC ga cuva kao tekst, ali u bazi
    moze da se nadje i broj (julijanski dan ili Unix vreme). Sve pretvaramo
    u datetime bez delova sekunde (MySQL DATETIME bez preciznosti)."""
    if v is None or (isinstance(v, str) and v.strip() == ""):
        return None
    if isinstance(v, (int, float)):
        if v > 1e9:                                   # Unix sekunde
            d = datetime(1970, 1, 1) + timedelta(seconds=float(v))
        elif v > 2_000_000:                           # julijanski dan (SQLite)
            d = datetime(1970, 1, 1) + timedelta(days=float(v) - 2440587.5)
        elif v > 10_000:                              # Delphi TDateTime (dani od 30.12.1899.)
            d = datetime(1899, 12, 30) + timedelta(days=float(v))
        else:
            raise GreskaPodataka(f"{opis}: broj '{v}' nije prepoznat kao datum")
        return d.replace(microsecond=0)
    s = str(v).strip().replace("T", " ")
    for fmt in ("%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M",
                "%Y-%m-%d", "%d.%m.%Y %H:%M:%S", "%d.%m.%Y %H:%M", "%d.%m.%Y"):
        try:
            return datetime.strptime(s, fmt).replace(microsecond=0)
        except ValueError:
            pass
    raise GreskaPodataka(f"{opis}: tekst '{v}' nije prepoznat kao datum")


def u_decimal(v, mesta, opis):
    if v is None or (isinstance(v, str) and v.strip() == ""):
        return None
    try:
        d = Decimal(str(v).replace(",", "."))
    except Exception:
        raise GreskaPodataka(f"{opis}: '{v}' nije broj")
    return d.quantize(Decimal(1).scaleb(-mesta), rounding=ROUND_HALF_UP)


def u_lozinku(v, opis):
    """Lozinke moraju biti SHA-256 hes (64 heks znaka), kao sto ih Delphi cuva.
    Ako je neka ostala kao obican tekst (baza nije otvorena novom verzijom
    aplikacije), hesira se ovde na isti nacin kao THashSHA2.GetHashString."""
    if v is None:
        return None
    s = str(v)
    if s == "":
        return None
    if HEX64.match(s.lower()):
        return s.lower()
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


def pretvori_red(tabela, kolone, red):
    """Jedan red iz SQLite-a -> tuple vrednosti spremnih za MySQL."""
    izlaz = []
    for kol, v in zip(kolone, red):
        opis = f"{tabela}.{kol} (red {red[0]})"
        if isinstance(v, str):
            v = v.strip() if kol not in ("Komentar", "ProcenaPonasanja", "StatusOstalo") else v
        if kol in KOLONE_DATUM:
            v = u_datum(v, opis)
        elif kol in KOLONE_NOVAC:
            v = u_decimal(v, 2, opis)
        elif kol in KOLONE_KOLICINA:
            v = u_decimal(v, 3, opis)
        elif kol in KOLONE_OPCIONI_FK:
            v = None if v in (None, "", 0, "0") else int(v)
        elif kol == "Lozinka":
            v = u_lozinku(v, opis)
        elif kol == "Email":
            v = None if v in (None, "") else v
        elif kol == "Dostupan":
            v = 1 if v in (None, "") else (1 if int(v) else 0)
        elif kol == "image_blob":
            v = bytes(v) if v is not None else None
        if v is None and (tabela, kol) in PODRAZUMEVANO:
            v = PODRAZUMEVANO[(tabela, kol)]
        izlaz.append(v)
    return tuple(izlaz)


# ---------------------------------------------------------------------
#  Citanje SQLite baze
# ---------------------------------------------------------------------
def procitaj_sqlite(putanja):
    """Vraca {tabela: [redovi kao tuple, sortirani po kljucu]}.
    Kolone koje u staroj bazi ne postoje (npr. DatumPrijema) vracaju se kao NULL."""
    if not os.path.exists(putanja):
        sys.exit(f"SQLite baza ne postoji: {putanja}")
    con = sqlite3.connect(f"file:{putanja}?mode=ro", uri=True)   # samo citanje
    podaci = {}
    for tabela, kljuc, kolone in TABELE:
        postojece = {r[1] for r in con.execute(f'PRAGMA table_info("{tabela}")')}
        if not postojece:
            podaci[tabela] = []
            continue
        izraz = ", ".join(f'"{k}"' if k in postojece else "NULL" for k in kolone)
        podaci[tabela] = con.execute(
            f'SELECT {izraz} FROM "{tabela}" ORDER BY "{kljuc}"').fetchall()
    con.close()
    return podaci


def pretvori_sve(podaci):
    """Pretvara sve redove i proverava strane kljuceve PRE upisa u MySQL.
    Vraca (pretvoreni_podaci, lista_gresaka)."""
    izlaz, greske = {}, []
    for tabela, kljuc, kolone in TABELE:
        redovi = []
        for red in podaci[tabela]:
            try:
                redovi.append(pretvori_red(tabela, kolone, red))
            except GreskaPodataka as e:
                greske.append(str(e))
        izlaz[tabela] = redovi

    for tabela, _, kolone in TABELE:
        for red in izlaz[tabela]:
            for kol in OBAVEZNO.get(tabela, []):
                v = red[kolone.index(kol)]
                if v is None or (isinstance(v, str) and v == ""):
                    greske.append(f"{tabela} {red[0]}: kolona {kol} je prazna")
            for (t, kol), dozv in DOZVOLJENO.items():
                if t == tabela and red[kolone.index(kol)] not in dozv:
                    greske.append(f"{tabela} {red[0]}: {kol} = '{red[kolone.index(kol)]}'"
                                  f" (dozvoljeno: {', '.join(sorted(dozv))})")
        for kol in JEDINSTVENO.get(tabela, []):
            vidjeno = {}
            for red in izlaz[tabela]:
                v = red[kolone.index(kol)]
                if v is None:
                    continue
                kljuc_mala = str(v).lower()
                if kljuc_mala in vidjeno:
                    greske.append(f"{tabela}: '{v}' (red {red[0]}) i red {vidjeno[kljuc_mala]}"
                                  f" imaju istu vrednost u {kol} (bez obzira na velika slova)")
                else:
                    vidjeno[kljuc_mala] = red[0]

    def kljucevi(tab):
        return {r[0] for r in izlaz[tab]}

    zap, mus, lju = kljucevi("ZAPOSLENI"), kljucevi("MUSTERIJA"), kljucevi("pets")
    usl, res = kljucevi("USLUGA"), kljucevi("RESURS")
    k = [c for t, _, c in TABELE if t == "pets"][0]
    for r in izlaz["pets"]:
        vl = r[k.index("Sifra_musterije")]
        if vl is not None and vl not in mus:
            greske.append(f"pets id={r[0]} ({r[1]}): vlasnik {vl} ne postoji u MUSTERIJA")
    k = [c for t, _, c in TABELE if t == "DNEVNA_AKTIVNOST"][0]
    for r in izlaz["DNEVNA_AKTIVNOST"]:
        pr = lambda kol: r[k.index(kol)]
        if pr("Sifra_zaposlenog") not in zap:
            greske.append(f"DNEVNA_AKTIVNOST {r[0]}: zaposleni {pr('Sifra_zaposlenog')} ne postoji")
        if pr("Sifra_ljubimca") not in lju:
            greske.append(f"DNEVNA_AKTIVNOST {r[0]}: ljubimac {pr('Sifra_ljubimca')} ne postoji")
        if pr("Sifra_usluge") is not None and pr("Sifra_usluge") not in usl:
            greske.append(f"DNEVNA_AKTIVNOST {r[0]}: usluga {pr('Sifra_usluge')} ne postoji")
        if pr("Sifra_resursa") is not None and pr("Sifra_resursa") not in res:
            greske.append(f"DNEVNA_AKTIVNOST {r[0]}: resurs {pr('Sifra_resursa')} ne postoji")
        if pr("VremeOd") is None:
            greske.append(f"DNEVNA_AKTIVNOST {r[0]}: nema VremeOd")
    return izlaz, greske


# ---------------------------------------------------------------------
#  Parametri komandne linije (isti za migrate.py i verify.py)
# ---------------------------------------------------------------------
def argumenti(opis):
    ovde = os.path.dirname(os.path.abspath(__file__))
    p = argparse.ArgumentParser(description=opis)
    p.add_argument("--sqlite", default=os.path.join(
        ovde, "..", "Delphi", "Win32", "Debug", "Baza", "users.db"),
        help="putanja do SQLite baze (podrazumevano: baza Delphi aplikacije)")
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=3306)
    p.add_argument("--user", default="root")
    p.add_argument("--password", default="", help="XAMPP root nema lozinku")
    p.add_argument("--database", default="poksipp")
    p.add_argument("--prepisi", action="store_true",
                   help="migrate.py: obrisi i ponovo napuni bazu i kad vec ima podatke "
                        "(od Faze 4 Delphi i API upisuju direktno u MySQL!)")
    return p.parse_args()


def mysql_konekcija(a, sa_bazom=True):
    try:
        import pymysql
    except ImportError:
        sys.exit("Nedostaje biblioteka PyMySQL. Instaliraj je: pip install pymysql")
    try:
        return pymysql.connect(host=a.host, port=a.port, user=a.user,
                               password=a.password, charset="utf8mb4",
                               database=a.database if sa_bazom else None,
                               autocommit=False)
    except pymysql.err.OperationalError as e:
        sys.exit(f"Ne mogu da se povezem na MySQL ({a.host}:{a.port}): {e}\n"
                 f"Da li je MySQL pokrenut u XAMPP Control Panelu?")
