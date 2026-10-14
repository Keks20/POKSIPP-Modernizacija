unit frmMain;
interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Layouts,
  uNavFrames, fraWelcome, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf,
  FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef, FireDAC.Stan.ExprFuncs,
  FireDAC.Phys.SQLiteWrapper.Stat, FireDAC.FMXUI.Wait, Data.DB,
  FireDAC.Comp.Client, FireDAC.Comp.DataSet, uUserStore, System.IOUtils,
  FMX.Objects, uPetModel;

type
  TForm5 = class(TForm)
    layHost: TLayout;
    FDQuery1: TFDQuery;
    FDConnection1: TFDConnection;
    procedure FormCreate(Sender: TObject);
    procedure FDConnection1AfterConnect(Sender: TObject);
  private
    procedure KreirajTabele;
    procedure DodajKoloneAkoNedostaju;
    procedure HesirajStareLozinke;
    procedure UcitajTestPodatke;
    procedure LoadPetsFromDB;
    procedure SeedUsluga(const ANaziv: string; ACena: Double);
    procedure SeedResurs(const ATip: string; ATrenutno, ANivo: Double);
  public
  end;

var
  Form5: TForm5;

implementation

{$R *.fmx}

procedure TForm5.FDConnection1AfterConnect(Sender: TObject);
begin
  FDConnection1.ExecSQL(
    'CREATE TABLE IF NOT EXISTS ZAPOSLENI (' +
    'Sifra_zaposlenog INTEGER PRIMARY KEY AUTOINCREMENT, ' +
    'Ime VARCHAR(50), ' +
    'Prezime VARCHAR(50), ' +
    'Uloga VARCHAR(50), ' +
    'KorisnickoIme VARCHAR(50) UNIQUE, ' +
    'Lozinka VARCHAR(50), ' +
    'Dostupan INTEGER DEFAULT 1)'
  );

  FDConnection1.ExecSQL(
    'CREATE TABLE IF NOT EXISTS MUSTERIJA (' +
    'Sifra_musterije INTEGER PRIMARY KEY AUTOINCREMENT, ' +
    'Ime VARCHAR(50), ' +
    'Prezime VARCHAR(50), ' +
    'Nalog VARCHAR(50), ' +
    'Telefon_Hitno VARCHAR(20), ' +
    'KorisnickoIme VARCHAR(50) UNIQUE, ' +
    'Lozinka VARCHAR(50))'
  );

  FDConnection1.ExecSQL(
    'CREATE TABLE IF NOT EXISTS DNEVNA_AKTIVNOST (' +
    'Sifra_aktivnosti INTEGER PRIMARY KEY AUTOINCREMENT, ' +
    'Kategorija VARCHAR(20), ' +
    'Vrsta_aktivnosti VARCHAR(100), ' +
    'VremeOd DATETIME, ' +
    'VremeDo DATETIME, ' +
    'DuzinaTrajanja VARCHAR(50), ' +
    'StatusAktivnosti VARCHAR(50), ' +
    'Ocena INTEGER, ' +
    'ProcenaPonasanja TEXT, ' +
    'Komentar TEXT, ' +
    'Kolicina VARCHAR(50), ' +
    'VremeObroka VARCHAR(20), ' +
    'StatusOstalo TEXT, ' +
    'Sifra_zaposlenog INTEGER, ' +
    'Sifra_ljubimca INTEGER, ' +
    'FOREIGN KEY(Sifra_zaposlenog) REFERENCES ZAPOSLENI(Sifra_zaposlenog), ' +
    'FOREIGN KEY(Sifra_ljubimca) REFERENCES pets(id))'
  );

  // USLUGA - katalog usluga (MOV: USLUGA, IDEF0 A1)
  FDConnection1.ExecSQL(
    'CREATE TABLE IF NOT EXISTS USLUGA (' +
    'Sifra_usluge INTEGER PRIMARY KEY AUTOINCREMENT, ' +
    'Naziv VARCHAR(100), ' +
    'Cena REAL)'
  );

  // RESURS - magacin / zalihe (MOV: RESURS, IDEF0 A2.4 Azuriranje zaliha)
  FDConnection1.ExecSQL(
    'CREATE TABLE IF NOT EXISTS RESURS (' +
    'Sifra_resursa INTEGER PRIMARY KEY AUTOINCREMENT, ' +
    'Tip_Resursa VARCHAR(100), ' +
    'Trenutno_u_Magacinu REAL, ' +
    'Kolicina_Nivo REAL)'
  );

  FDConnection1.ExecSQL(
    'INSERT INTO ZAPOSLENI (Ime, Prezime, Uloga, KorisnickoIme, Lozinka, Dostupan) ' +
    'SELECT ''Osoblje'', ''Osobljic'', ''Osoblje'', ''osoblje'', ''osoblje123'', 1 ' +
    'WHERE NOT EXISTS (SELECT 1 FROM ZAPOSLENI WHERE KorisnickoIme = ''osoblje'')'
  );

  FDConnection1.ExecSQL(
    'INSERT INTO MUSTERIJA (Ime, Prezime, Nalog, Telefon_Hitno, KorisnickoIme, Lozinka) ' +
    'SELECT ''Jovana'', ''Jovanovic'', ''Standard'', ''0641234567'', ''vlasnik1'', ''pass123'' ' +
    'WHERE NOT EXISTS (SELECT 1 FROM MUSTERIJA WHERE KorisnickoIme = ''vlasnik1'')'
  );

  // Admin nalog -> pregled zaposlenih i njihovih unosa
  FDConnection1.ExecSQL(
    'INSERT INTO ZAPOSLENI (Ime, Prezime, Uloga, KorisnickoIme, Lozinka, Dostupan) ' +
    'SELECT ''Admin'', ''Administrator'', ''Admin'', ''admin'', ''admin123'', 1 ' +
    'WHERE NOT EXISTS (SELECT 1 FROM ZAPOSLENI WHERE KorisnickoIme = ''admin'')'
  );

  // Radnik Nikola (osoblje3)
  FDConnection1.ExecSQL(
    'INSERT INTO ZAPOSLENI (Ime, Prezime, Uloga, KorisnickoIme, Lozinka, Dostupan) ' +
    'SELECT ''Nikola'', ''Nikolic'', ''Negovatelj'', ''osoblje3'', ''nikola123'', 1 ' +
    'WHERE NOT EXISTS (SELECT 1 FROM ZAPOSLENI WHERE KorisnickoIme = ''osoblje3'')'
  );


  // Jos jedan radnik (Jelena - osoblje4)
  FDConnection1.ExecSQL(
    'INSERT INTO ZAPOSLENI (Ime, Prezime, Uloga, KorisnickoIme, Lozinka, Dostupan) ' +
    'SELECT ''Jelena'', ''Jelic'', ''Negovatelj'', ''osoblje4'', ''jelena123'', 1 ' +
    'WHERE NOT EXISTS (SELECT 1 FROM ZAPOSLENI WHERE KorisnickoIme = ''osoblje4'')'
  );


  // NAPOMENA: ovde su ranije bili UPDATE lozinki za osoblje3/osoblje4 i DELETE
  // naloga osoblje1, osoblje2 i vlasnik2. Izvrsavali su se pri SVAKOM pokretanju,
  // pa su vracali promenjene lozinke na staro i brisali nove musterije sa tim
  // korisnickim imenom. Jednokratno ciscenje je vec uradjeno, pa su uklonjeni.

  // Seed katalog usluga (cenovnik)
  SeedUsluga('Setnja', 500);
  SeedUsluga('Kupanje', 800);
  SeedUsluga('Hranjenje', 300);
  SeedUsluga('Igra i socijalizacija', 400);
  SeedUsluga('Veterinarski pregled', 1500);

  // Seed magacin (zalihe): tip, trenutno, minimalni nivo
  SeedResurs('Suva hrana (g)', 5000, 1000);
  SeedResurs('Vlazna hrana (g)', 3000, 800);
  SeedResurs('Sampon (ml)', 2000, 500);
  SeedResurs('Higijenske maramice (kom)', 200, 50);
end;

procedure TForm5.SeedUsluga(const ANaziv: string; ACena: Double);
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FDConnection1;
    Q.SQL.Text :=
      'INSERT INTO USLUGA (Naziv, Cena) ' +
      'SELECT :n, :c WHERE NOT EXISTS ' +
      '(SELECT 1 FROM USLUGA WHERE Naziv = :n2)';
    Q.ParamByName('n').AsString  := ANaziv;
    Q.ParamByName('c').AsFloat   := ACena;
    Q.ParamByName('n2').AsString := ANaziv;
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

procedure TForm5.SeedResurs(const ATip: string; ATrenutno, ANivo: Double);
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FDConnection1;
    Q.SQL.Text :=
      'INSERT INTO RESURS (Tip_Resursa, Trenutno_u_Magacinu, Kolicina_Nivo) ' +
      'SELECT :t, :tr, :niv WHERE NOT EXISTS ' +
      '(SELECT 1 FROM RESURS WHERE Tip_Resursa = :t2)';
    Q.ParamByName('t').AsString    := ATip;
    Q.ParamByName('tr').AsFloat    := ATrenutno;
    Q.ParamByName('niv').AsFloat   := ANivo;
    Q.ParamByName('t2').AsString   := ATip;
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

procedure TForm5.FormCreate(Sender: TObject);
var
  LDatabasePath: string;
begin
  LDatabasePath := ExtractFilePath(ParamStr(0)) + 'Baza';
  if not DirectoryExists(LDatabasePath) then
    LDatabasePath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\Baza');
  if not DirectoryExists(LDatabasePath) then
  begin
    LDatabasePath := ExtractFilePath(ParamStr(0)) + 'Baza';
    ForceDirectories(LDatabasePath);
  end;

  FDConnection1.Connected := False;
  FDConnection1.DriverName := 'SQLITE';
  FDConnection1.Params.Values['Database'] :=
    IncludeTrailingPathDelimiter(LDatabasePath) + 'users.db';

  try
    FDConnection1.Open;
    DB := FDConnection1;
    KreirajTabele;
    DodajKoloneAkoNedostaju;
    HesirajStareLozinke;
    UcitajTestPodatke;
    LoadPetsFromDB;
    TNavFrames.Init(layHost);
    TNavFrames.Go(TFrame1.Create(nil));
  except
    on E: Exception do
      ShowMessage('Greska pri povezivanju sa bazom: ' + E.Message);
  end;
end;

procedure TForm5.KreirajTabele;
begin
  FDQuery1.SQL.Text :=
    'CREATE TABLE IF NOT EXISTS pets (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  name TEXT,' +
    '  species TEXT,' +
    '  breed TEXT,' +
    '  age TEXT,' +
    '  image_blob BLOB,' +
    '  Status VARCHAR(50),' +
    '  Sifra_musterije INT,' +
    '  Lokacija TEXT DEFAULT '''''+
    ')';
  FDQuery1.ExecSQL;

  FDQuery1.SQL.Text :=
    'CREATE TABLE IF NOT EXISTS ZAPOSLENI (' +
    '  Sifra_zaposlenog INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  Ime VARCHAR(50),' +
    '  Prezime VARCHAR(50),' +
    '  Uloga VARCHAR(50),' +
    '  KorisnickoIme VARCHAR(50) UNIQUE,' +
    '  Lozinka VARCHAR(50),' +
    '  Dostupan INTEGER DEFAULT 1' +
    ')';
  FDQuery1.ExecSQL;

  FDQuery1.SQL.Text :=
    'CREATE TABLE IF NOT EXISTS MUSTERIJA (' +
    '  Sifra_musterije INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  Ime VARCHAR(50),' +
    '  Prezime VARCHAR(50),' +
    '  Nalog VARCHAR(50),' +
    '  Telefon_Hitno VARCHAR(20),' +
    '  KorisnickoIme VARCHAR(50) UNIQUE,' +
    '  Lozinka VARCHAR(50)' +
    ')';
  FDQuery1.ExecSQL;

  FDQuery1.SQL.Text :=
    'CREATE TABLE IF NOT EXISTS DNEVNA_AKTIVNOST (' +
    '  Sifra_aktivnosti INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  Kategorija VARCHAR(20),' +
    '  Vrsta_aktivnosti VARCHAR(100),' +
    '  VremeOd DATETIME,' +
    '  VremeDo DATETIME,' +
    '  DuzinaTrajanja VARCHAR(50),' +
    '  StatusAktivnosti VARCHAR(50),' +
    '  Ocena INT,' +
    '  ProcenaPonasanja TEXT,' +
    '  Komentar TEXT,' +
    '  Kolicina VARCHAR(50),' +
    '  VremeObroka VARCHAR(20),' +
    '  StatusOstalo TEXT,' +
    '  Sifra_zaposlenog INT,' +
    '  Sifra_ljubimca INT,' +
    '  FOREIGN KEY (Sifra_zaposlenog) REFERENCES ZAPOSLENI(Sifra_zaposlenog),' +
    '  FOREIGN KEY (Sifra_ljubimca) REFERENCES pets(id)' +
    ')';
  FDQuery1.ExecSQL;
end;

procedure TForm5.DodajKoloneAkoNedostaju;

  function KolonaPostoji(const ATable, AColName: string): Boolean;
  var
    Q: TFDQuery;
  begin
    Result := False;
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := FDConnection1;
      Q.SQL.Text := 'PRAGMA table_info(' + ATable + ')';
      Q.Open;
      while not Q.Eof do
      begin
        if SameText(Q.FieldByName('name').AsString, AColName) then
        begin
          Result := True;
          Break;
        end;
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  end;

  procedure TryAdd(const ATable, AColDef: string);
  var
    sColName: string;
    nSpace: Integer;
  begin
    sColName := Trim(AColDef);
    nSpace := Pos(' ', sColName);
    if nSpace > 0 then
      sColName := Copy(sColName, 1, nSpace - 1);
    if not KolonaPostoji(ATable, sColName) then
      FDConnection1.ExecSQL('ALTER TABLE ' + ATable + ' ADD COLUMN ' + AColDef);
  end;

begin
  TryAdd('DNEVNA_AKTIVNOST', 'Kategorija VARCHAR(20)');
  TryAdd('DNEVNA_AKTIVNOST', 'ProcenaPonasanja TEXT');
  TryAdd('DNEVNA_AKTIVNOST', 'Kolicina VARCHAR(50)');
  TryAdd('DNEVNA_AKTIVNOST', 'VremeObroka VARCHAR(20)');
  TryAdd('DNEVNA_AKTIVNOST', 'StatusOstalo TEXT');
  TryAdd('pets', 'Lokacija TEXT DEFAULT ''''');
  TryAdd('pets', 'Alergije TEXT DEFAULT ''''');
  TryAdd('MUSTERIJA', 'Email TEXT');

  // Veze aktivnosti ka katalogu usluga (OBUHVATA) i magacinu (TROSI)
  TryAdd('DNEVNA_AKTIVNOST', 'Sifra_usluge INT');
  TryAdd('DNEVNA_AKTIVNOST', 'Sifra_resursa INT');
  TryAdd('DNEVNA_AKTIVNOST', 'Kolicina_Utroska REAL');

  // Prijem i odjava ljubimca (boravak u pansionu i obracun)
  TryAdd('pets', 'DatumPrijema DATETIME');
  TryAdd('pets', 'DatumOdjave DATETIME');

  // Ispravi stare zapise sa Admin/Adminovic -> Osoblje/Osobljic
  FDConnection1.ExecSQL(
    'UPDATE ZAPOSLENI SET Prezime = ''Osobljic'' ' +
    'WHERE KorisnickoIme = ''osoblje'' AND Prezime = ''Admin''');
  FDConnection1.ExecSQL(
    'UPDATE ZAPOSLENI SET Ime = ''Osoblje'', Prezime = ''Osobljic'' ' +
    'WHERE Ime = ''Admin'' AND Prezime = ''Adminovic'' AND KorisnickoIme <> ''admin''');

  // Osiguraj da admin nalog UVEK ima ispravnu ulogu i ime

  FDConnection1.ExecSQL(
    'UPDATE ZAPOSLENI SET Uloga = ''Admin'', Ime = ''Admin'', Prezime = ''Administrator'' ' +
    'WHERE KorisnickoIme = ''admin''');

  // Postavi Lokaciju za test ljubimce koji je nemaju
  FDConnection1.ExecSQL(
    'UPDATE pets SET Lokacija = ''Boks A1'' ' +
    'WHERE lower(name) = ''maca'' AND (Lokacija IS NULL OR Lokacija = '''')');
  FDConnection1.ExecSQL(
    'UPDATE pets SET Lokacija = ''Boks A2'' ' +
    'WHERE lower(name) = ''reks'' AND (Lokacija IS NULL OR Lokacija = '''')');

  // Postavi test alergije za ljubimce koji ih nemaju
  FDConnection1.ExecSQL(
    'UPDATE pets SET Alergije = ''Piletina'' ' +
    'WHERE lower(name) = ''maca'' AND (Alergije IS NULL OR Alergije = '''')');
  FDConnection1.ExecSQL(
    'UPDATE pets SET Alergije = ''Nema poznatih'' ' +
    'WHERE lower(name) = ''reks'' AND (Alergije IS NULL OR Alergije = '''')');
end;

// Lozinke se cuvaju kao SHA-256 hes (64 znaka). Sve lozinke koje su jos uvek
// obican tekst (stari nalozi i test nalozi iz seed-a) pretvaraju se ovde.
// Prijava ostaje ista: admin / admin123 i dalje radi.
procedure TForm5.HesirajStareLozinke;

  procedure Hesiraj(const ATabela, AKljuc: string);
  var
    Q, U: TFDQuery;
  begin
    Q := TFDQuery.Create(nil);
    U := TFDQuery.Create(nil);
    try
      Q.Connection := FDConnection1;
      U.Connection := FDConnection1;
      Q.SQL.Text :=
        'SELECT ' + AKljuc + ', Lozinka FROM ' + ATabela +
        ' WHERE Lozinka IS NOT NULL AND length(Lozinka) <> 64';
      Q.Open;
      Q.FetchAll;
      U.SQL.Text :=
        'UPDATE ' + ATabela + ' SET Lozinka = :h WHERE ' + AKljuc + ' = :id';
      while not Q.Eof do
      begin
        U.ParamByName('h').AsString   := HesLozinke(Q.FieldByName('Lozinka').AsString);
        U.ParamByName('id').AsInteger := Q.FieldByName(AKljuc).AsInteger;
        U.ExecSQL;
        Q.Next;
      end;
    finally
      U.Free;
      Q.Free;
    end;
  end;

begin
  Hesiraj('ZAPOSLENI', 'Sifra_zaposlenog');
  Hesiraj('MUSTERIJA', 'Sifra_musterije');
end;

procedure TForm5.UcitajTestPodatke;
var
  Stream: TResourceStream;
begin


  // --- Test ljubimci ---
  FDQuery1.SQL.Text := 'SELECT COUNT(*) FROM pets';
  FDQuery1.Open;
  if FDQuery1.Fields[0].AsInteger = 0 then
  begin
    FDQuery1.Close;
    FDQuery1.SQL.Text :=
      'INSERT INTO pets (name, species, breed, age, image_blob, Status, Sifra_musterije, Lokacija, Alergije) ' +
      'VALUES (:name, :species, :breed, :age, :img, :status, :sid, :lok, :alerg)';

    FDQuery1.ParamByName('name').AsString    := 'Maca';
    FDQuery1.ParamByName('species').AsString := 'Macka';
    FDQuery1.ParamByName('breed').AsString   := 'Persijska';
    FDQuery1.ParamByName('age').AsString     := '2 godine';
    FDQuery1.ParamByName('status').AsString  := 'Aktivan';
    FDQuery1.ParamByName('alerg').AsString   := 'Piletina';
    FDQuery1.ParamByName('sid').AsInteger    := 1;
    FDQuery1.ParamByName('lok').AsString     := 'Boks A1';
    // Slika je samo rezerva (prikaz ide iz foldera Slike); ako resurs fali, preskoci
    try
      Stream := TResourceStream.Create(HInstance, 'PngImage_2', RT_RCDATA);
      try
        FDQuery1.ParamByName('img').LoadFromStream(Stream, ftBlob);
      finally
        Stream.Free;
      end;
    except
      FDQuery1.ParamByName('img').Clear;
    end;
    FDQuery1.ExecSQL;

    FDQuery1.ParamByName('name').AsString    := 'Reks';
    FDQuery1.ParamByName('species').AsString := 'Pas';
    FDQuery1.ParamByName('breed').AsString   := 'Ovcar';
    FDQuery1.ParamByName('age').AsString     := '4 godine';
    FDQuery1.ParamByName('status').AsString  := 'Aktivan';
    FDQuery1.ParamByName('alerg').AsString   := 'Nema poznatih';
    FDQuery1.ParamByName('sid').AsInteger    := 1;
    FDQuery1.ParamByName('lok').AsString     := 'Boks A2';
    try
      Stream := TResourceStream.Create(HInstance, 'PngImage_3', RT_RCDATA);
      try
        FDQuery1.ParamByName('img').LoadFromStream(Stream, ftBlob);
      finally
        Stream.Free;
      end;
    except
      FDQuery1.ParamByName('img').Clear;
    end;
    FDQuery1.ExecSQL;
  end
  else
    FDQuery1.Close;
end;

procedure TForm5.LoadPetsFromDB;
var
  Q: TFDQuery;
  i: Integer;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := DB;
    Q.SQL.Text := 'SELECT id, name, species, breed, age, image_blob FROM pets ORDER BY id';
    Q.Open;
    for i := Low(Pets) to High(Pets) do
      Pets[i] := Default(TPet); // FillChar nad zapisima sa stringovima curi memoriju
    i := 0;
    while (not Q.Eof) and (i <= High(Pets)) do
    begin
      Pets[i].Id        := Q.FieldByName('id').AsInteger;
      Pets[i].Name      := Q.FieldByName('name').AsString;
      Pets[i].Species   := Q.FieldByName('species').AsString;
      Pets[i].Breed     := Q.FieldByName('breed').AsString;
      Pets[i].Age       := Q.FieldByName('age').AsString;
      Pets[i].ImageBlob := Q.FieldByName('image_blob').AsBytes;
      Inc(i);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

end.
