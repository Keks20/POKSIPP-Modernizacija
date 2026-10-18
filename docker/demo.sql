-- =====================================================================
--  POKSIPP - demo podaci (izmisljeni ljudi i ljubimci)
--
--  Ubacuju se u Docker bazu kad u docker/podaci nema tvog dump-a.
--  Sluze za probu i za javni repozitorijum: nema pravih imena,
--  telefona ni lozinki.
--
--  Nalozi (lozinke su SHA-256, isto kao u Delphiju):
--    admin    / admin123   - Administrator
--    osoblje3 / nikola123  - Negovatelj
--    osoblje4 / jelena123  - Osoblje
--    vlasnik1 / pass123    - vlasnik (Reks i Maca)
--    vlasnik2 / pass123    - vlasnik (Zuca)
-- =====================================================================

SET NAMES utf8mb4;

INSERT INTO ZAPOSLENI (Sifra_zaposlenog, Ime, Prezime, Uloga, KorisnickoIme, Lozinka, Dostupan) VALUES
  (1, 'Marko',  'Petrović', 'Admin',      'admin',    '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', 1),
  (2, 'Nikola', 'Nikolić',  'Negovatelj', 'osoblje3', '3eaf0ff39b53c1e893971406e247f70fcad2b1d40674d696eea726e6953089c7', 1),
  (3, 'Jelena', 'Jelić',    'Osoblje',    'osoblje4', 'dc76a2836b9dbb1e021d7f86189200089a5b4bc772866bef1704d0425391562f', 1);

INSERT INTO MUSTERIJA (Sifra_musterije, Ime, Prezime, Nalog, Telefon_Hitno, KorisnickoIme, Lozinka, Email) VALUES
  (1, 'Jovana', 'Marković', NULL, '060 000 0001', 'vlasnik1', '9b8769a4a742959a2d0298c36fb70623f2dfacda8436237df08d8dfd5b37374c', 'jovana@primer.rs'),
  (2, 'Petar',  'Ilić',     NULL, '060 000 0002', 'vlasnik2', '9b8769a4a742959a2d0298c36fb70623f2dfacda8436237df08d8dfd5b37374c', 'petar@primer.rs');

INSERT INTO USLUGA (Sifra_usluge, Naziv, Cena) VALUES
  (1, 'Setnja',                 500.00),
  (2, 'Kupanje',                800.00),
  (3, 'Hranjenje',              300.00),
  (4, 'Igra i socijalizacija',  400.00),
  (5, 'Veterinarski pregled',  1500.00);

INSERT INTO RESURS (Sifra_resursa, Tip_Resursa, Trenutno_u_Magacinu, Kolicina_Nivo) VALUES
  (1, 'Suva hrana (g)',            4720, 1000),
  (2, 'Vlazna hrana (g)',          3000,  800),
  (3, 'Sampon (ml)',                350,  500),
  (4, 'Higijenske maramice (kom)',  195,   50);

-- Datumi su relativni, pa demo uvek izgleda kao "trenutni boravak"
INSERT INTO pets (id, name, species, breed, age, image_blob, Status, Sifra_musterije, Lokacija, Alergije, DatumPrijema, DatumOdjave) VALUES
  (1, 'Reks', 'Pas',   'Ovčar',     '3 godine', NULL, 'Aktivan', 1, 'Boks A1', 'Nema poznatih', DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 9 HOUR, NULL),
  (2, 'Maca', 'Mačka', 'Persijska', '5 godina', NULL, 'Aktivan', 1, 'Boks A2', 'Piletina',      DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 10 HOUR, NULL),
  (3, 'Žuća', 'Pas',   'Mešanac',   '7 godina', NULL, 'Aktivan', 2, 'Boks B1', 'Nema poznatih', DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 12 HOUR, NULL);

INSERT INTO DNEVNA_AKTIVNOST
  (Kategorija, Vrsta_aktivnosti, VremeOd, VremeDo, DuzinaTrajanja, StatusAktivnosti,
   ProcenaPonasanja, Komentar, Kolicina, VremeObroka, StatusOstalo,
   Sifra_zaposlenog, Sifra_ljubimca, Sifra_usluge, Sifra_resursa, Kolicina_Utroska) VALUES
  ('Aktivnosti', 'Setnja - jutarnja',
     DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 9 HOUR, DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 585 MINUTE,
     '45 min', 'Zavrseno', 'Odlican, druzeljubiv', 'Lepo je setao oko parka', NULL, NULL, NULL,
     2, 1, 1, NULL, NULL),
  ('Hrana', 'Suva hrana (g)',
     DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 510 MINUTE, DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 510 MINUTE,
     '0 min', 'Zavrseno', NULL, 'Dobar apetit', '280g', '08:30', NULL,
     2, 1, 3, 1, 280),
  ('Aktivnosti', 'Trening poslusnosti',
     DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 16 HOUR, DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 990 MINUTE,
     '30 min', 'Zavrseno', 'Sluša komande', NULL, NULL, NULL, NULL,
     3, 1, NULL, NULL, NULL),
  ('Aktivnosti', 'Kupanje',
     CURDATE() + INTERVAL 10 HOUR, CURDATE() + INTERVAL 640 MINUTE,
     '40 min', 'Zavrseno', 'Mirna', NULL, NULL, NULL, NULL,
     3, 2, 2, NULL, NULL),
  ('Ostalo', 'Sampon (ml)',
     CURDATE() + INTERVAL 10 HOUR, CURDATE() + INTERVAL 10 HOUR,
     '0 min', 'Zavrseno', NULL, 'Bila je mirna', '50', NULL, 'Okupana, iščešljana',
     3, 2, NULL, 3, 50);
