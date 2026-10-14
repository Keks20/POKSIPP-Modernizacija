-- =====================================================================
--  POKSIPP - sema baze za MySQL / MariaDB (XAMPP)
--  Faza 2: migracija sa SQLite-a (Delphi) na MySQL
--
--  Pravila:
--   * Nazivi tabela i kolona su ISTI kao u Delphi aplikaciji, da bi Delphi
--     u Fazi 4 mogao da predje na MySQL samo promenom konekcije.
--     (Preimenovanje 'pets' -> 'LJUBIMAC' ide tek kad Delphi vise ne koristi bazu.)
--   * utf8mb4 = ispravna slova c, c, s, z, dj i emoji.
--   * InnoDB = transakcije i strani kljucevi koji se zaista proveravaju
--     (SQLite ih je imao samo "na papiru").
--   * Novac i kolicine su DECIMAL, ne REAL, da nema gresaka u zaokruzivanju.
--
--  Pokrece se iz migrate.py (ne rucno) - fajl brise i pravi tabele iznova.
-- =====================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS DNEVNA_AKTIVNOST;
DROP TABLE IF EXISTS pets;
DROP TABLE IF EXISTS RESURS;
DROP TABLE IF EXISTS USLUGA;
DROP TABLE IF EXISTS MUSTERIJA;
DROP TABLE IF EXISTS ZAPOSLENI;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
--  ZAPOSLENI - osoblje i administrator
-- ---------------------------------------------------------------------
CREATE TABLE ZAPOSLENI (
  Sifra_zaposlenog INT          NOT NULL AUTO_INCREMENT,
  Ime              VARCHAR(50)  NOT NULL,
  Prezime          VARCHAR(50)  NOT NULL,
  Uloga            VARCHAR(50)  NOT NULL,              -- Admin, Negovatelj, Osoblje, Neaktivan...
  KorisnickoIme    VARCHAR(50)  NOT NULL,
  Lozinka          CHAR(64)     NULL,                  -- SHA-256 hes; NULL = deaktiviran nalog
  Dostupan         TINYINT(1)   NOT NULL DEFAULT 1,
  PRIMARY KEY (Sifra_zaposlenog),
  UNIQUE KEY uq_zaposleni_korisnicko_ime (KorisnickoIme)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  MUSTERIJA - vlasnici ljubimaca
-- ---------------------------------------------------------------------
CREATE TABLE MUSTERIJA (
  Sifra_musterije  INT          NOT NULL AUTO_INCREMENT,
  Ime              VARCHAR(50)  NOT NULL,
  Prezime          VARCHAR(50)  NOT NULL,
  Nalog            VARCHAR(50)  NULL,
  Telefon_Hitno    VARCHAR(20)  NULL,
  KorisnickoIme    VARCHAR(50)  NOT NULL,
  Lozinka          CHAR(64)     NULL,                  -- SHA-256 hes
  Email            VARCHAR(100) NULL,                  -- prazan email se cuva kao NULL
  PRIMARY KEY (Sifra_musterije),
  UNIQUE KEY uq_musterija_korisnicko_ime (KorisnickoIme),
  UNIQUE KEY uq_musterija_email (Email)              -- vise NULL-ova je dozvoljeno
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  USLUGA - cenovnik (MOV: USLUGA, relacija OBUHVATA)
-- ---------------------------------------------------------------------
CREATE TABLE USLUGA (
  Sifra_usluge     INT           NOT NULL AUTO_INCREMENT,
  Naziv            VARCHAR(100)  NOT NULL,
  Cena             DECIMAL(10,2) NOT NULL DEFAULT 0,   -- RSD
  PRIMARY KEY (Sifra_usluge),
  UNIQUE KEY uq_usluga_naziv (Naziv),
  CONSTRAINT ck_usluga_cena CHECK (Cena >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  RESURS - magacin (MOV: RESURS, IDEF0 A2.4 Azuriranje zaliha)
--  Jedinica je u nazivu u zagradi: 'Suva hrana (g)'
-- ---------------------------------------------------------------------
CREATE TABLE RESURS (
  Sifra_resursa        INT           NOT NULL AUTO_INCREMENT,
  Tip_Resursa          VARCHAR(100)  NOT NULL,
  Trenutno_u_Magacinu  DECIMAL(12,3) NOT NULL DEFAULT 0,
  Kolicina_Nivo        DECIMAL(12,3) NOT NULL DEFAULT 0,   -- minimalni nivo
  PRIMARY KEY (Sifra_resursa),
  UNIQUE KEY uq_resurs_tip (Tip_Resursa),
  CONSTRAINT ck_resurs_stanje CHECK (Trenutno_u_Magacinu >= 0),
  CONSTRAINT ck_resurs_nivo   CHECK (Kolicina_Nivo >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  pets - ljubimci (naziv ostaje zbog Delphi aplikacije)
--  Novo: strani kljuc ka vlasniku (problem #19 iz audita)
-- ---------------------------------------------------------------------
CREATE TABLE pets (
  id               INT           NOT NULL AUTO_INCREMENT,
  name             VARCHAR(50)   NOT NULL,
  species          VARCHAR(50)   NULL,
  breed            VARCHAR(50)   NULL,
  age              VARCHAR(30)   NULL,
  image_blob       MEDIUMBLOB    NULL,
  Status           VARCHAR(20)   NOT NULL DEFAULT 'Aktivan',   -- Aktivan / Odjavljen
  Sifra_musterije  INT           NULL,
  Lokacija         VARCHAR(50)   NOT NULL DEFAULT '',          -- boks; prazan posle odjave
  Alergije         VARCHAR(255)  NOT NULL DEFAULT '',
  DatumPrijema     DATETIME      NULL,
  DatumOdjave      DATETIME      NULL,
  PRIMARY KEY (id),
  KEY ix_pets_vlasnik (Sifra_musterije),
  KEY ix_pets_status (Status),
  CONSTRAINT fk_pets_musterija FOREIGN KEY (Sifra_musterije)
    REFERENCES MUSTERIJA (Sifra_musterije) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_pets_status CHECK (Status IN ('Aktivan', 'Odjavljen'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  DNEVNA_AKTIVNOST - dnevnik: Aktivnosti, Hrana, Ostalo
-- ---------------------------------------------------------------------
CREATE TABLE DNEVNA_AKTIVNOST (
  Sifra_aktivnosti  INT           NOT NULL AUTO_INCREMENT,
  Kategorija        VARCHAR(20)   NOT NULL,      -- Aktivnosti / Hrana / Ostalo
  Vrsta_aktivnosti  VARCHAR(100)  NOT NULL,
  VremeOd           DATETIME      NOT NULL,
  VremeDo           DATETIME      NULL,
  DuzinaTrajanja    VARCHAR(50)   NULL,
  StatusAktivnosti  VARCHAR(50)   NULL,          -- U toku / Zavrseno
  Ocena             INT           NULL,
  ProcenaPonasanja  TEXT          NULL,
  Komentar          TEXT          NULL,
  Kolicina          VARCHAR(50)   NULL,          -- kako je uneto, npr. '1,5kg'
  VremeObroka       VARCHAR(20)   NULL,
  StatusOstalo      TEXT          NULL,
  Sifra_zaposlenog  INT           NOT NULL,
  Sifra_ljubimca    INT           NOT NULL,
  Sifra_usluge      INT           NULL,          -- NULL = bez usluge (ranije 0)
  Sifra_resursa     INT           NULL,
  Kolicina_Utroska  DECIMAL(12,3) NULL,          -- u jedinici resursa
  PRIMARY KEY (Sifra_aktivnosti),
  KEY ix_akt_ljubimac_vreme (Sifra_ljubimca, VremeOd),
  KEY ix_akt_zaposleni_status (Sifra_zaposlenog, StatusAktivnosti),
  KEY ix_akt_usluga (Sifra_usluge),
  KEY ix_akt_resurs (Sifra_resursa),
  CONSTRAINT fk_akt_zaposleni FOREIGN KEY (Sifra_zaposlenog)
    REFERENCES ZAPOSLENI (Sifra_zaposlenog) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_akt_ljubimac FOREIGN KEY (Sifra_ljubimca)
    REFERENCES pets (id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_akt_usluga FOREIGN KEY (Sifra_usluge)
    REFERENCES USLUGA (Sifra_usluge) ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT fk_akt_resurs FOREIGN KEY (Sifra_resursa)
    REFERENCES RESURS (Sifra_resursa) ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT ck_akt_kategorija CHECK (Kategorija IN ('Aktivnosti', 'Hrana', 'Ostalo'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
