unit uUserStore;

interface

uses
System.SysUtils, System.Generics.Collections,FireDAC.Comp.Client,uPetModel;

var
   // Baza konekcija
  DB: TFDConnection;

  // Ljubimci niz
  Pets: array[0..9] of TPet;
  ActivePetIndex: Integer = -1;
  SelectedPetID: Integer = 0;

  // Sesija ulogovanog korisnika
  LoggedInUserID: Integer = 0;
  LoggedInRole: string = '';       // 'ZAPOSLENI', 'MUSTERIJA', ili 'USER'
  LoggedInUsername: string = '';
  LoggedInImePrezime: string = ''; // Ime i prezime za prikaz

// Lozinka se u bazi cuva kao SHA-256 hes (64 heks znaka), nikad kao obican tekst.
function HesLozinke(const Lozinka: string): string;

// Jedinica resursa iz naziva u zagradi: 'Suva hrana (g)' -> 'g'
function JedinicaResursa(const TipResursa: string): string;

// Pretvara unos kolicine u broj u jedinici resursa.
// Prihvata tacku i zarez i jedinice g/kg i ml/l:
//   '280g' -> 280,  '1,5 kg' -> 1500 (za resurs u g),  '0.5l' -> 500 (za resurs u ml).
// Bez jedinice ('280') broj se uzima u jedinici resursa.
function PretvoriKolicinu(const Unos, TipResursa: string;
  out Kolicina: Double; out Greska: string): Boolean;

// Skida kolicinu sa zaliha samo ako je ima dovoljno (provera i izmena u jednom upitu).
// Poziva se unutar transakcije, zajedno sa upisom u DNEVNA_AKTIVNOST.
function SkiniSaZaliha(IdResursa: Integer; Kolicina: Double;
  out Greska: string): Boolean;

// Obracun boravka po cenovniku: sve usluge zabelezene za ljubimca od dana prijema.
// Vraca tekst racuna (stavka po stavka), a ukupan iznos u Ukupno.
function ObracunBoravka(IdLjubimca: Integer; out Ukupno: Double): string;

// Dijalog za promenu lozinke prijavljenog zaposlenog (osoblje i admin).
procedure PromeniLozinkuZaposlenog(SifraZaposlenog: Integer);

implementation

uses System.Hash, System.UITypes, FMX.Dialogs, FMX.DialogService;

function HesLozinke(const Lozinka: string): string;
begin
  Result := THashSHA2.GetHashString(Lozinka);
end;

function JedinicaResursa(const TipResursa: string): string;
var
  p1, p2: Integer;
begin
  Result := '';
  p1 := LastDelimiter('(', TipResursa);
  p2 := LastDelimiter(')', TipResursa);
  if (p1 > 0) and (p2 > p1) then
    Result := LowerCase(Trim(Copy(TipResursa, p1 + 1, p2 - p1 - 1)));
end;

// Koliko jedinica U ima u jednoj jedinici Iz (npr. Iz='kg', U='g' -> 1000)
function FaktorJedinice(const Iz, U: string; out Faktor: Double): Boolean;
begin
  Result := True;
  if Iz = U then
    Faktor := 1
  else if (Iz = 'kg') and (U = 'g') then
    Faktor := 1000
  else if (Iz = 'g') and (U = 'kg') then
    Faktor := 0.001
  else if (Iz = 'l') and (U = 'ml') then
    Faktor := 1000
  else if (Iz = 'ml') and (U = 'l') then
    Faktor := 0.001
  else if ((Iz = 'komad') or (Iz = 'komada') or (Iz = 'kom.')) and (U = 'kom') then
    Faktor := 1
  else
    Result := False;
end;

function PretvoriKolicinu(const Unos, TipResursa: string;
  out Kolicina: Double; out Greska: string): Boolean;
var
  s, sBroj, sJed, sJedResursa: string;
  i: Integer;
  Broj, Faktor: Double;
begin
  Result := False;
  Kolicina := 0;
  Greska := '';

  s := LowerCase(StringReplace(Trim(Unos), ' ', '', [rfReplaceAll]));

  // Broj na pocetku (cifre, tacka, zarez), a ostatak je jedinica
  i := 1;
  while (i <= Length(s)) and CharInSet(s[i], ['0'..'9', '.', ',']) do
    Inc(i);
  sBroj := StringReplace(Copy(s, 1, i - 1), ',', '.', [rfReplaceAll]);
  sJed  := Copy(s, i, MaxInt);

  if (sBroj = '') or
     not TryStrToFloat(sBroj, Broj, TFormatSettings.Invariant) or
     (Broj <= 0) then
  begin
    Greska := 'Unesite kolicinu kao broj veci od nule (npr. 280g ili 1,5kg).';
    Exit;
  end;

  sJedResursa := JedinicaResursa(TipResursa);

  // Bez jedinice u unosu (ili resurs nema jedinicu) - broj je vec u jedinici resursa
  if (sJed = '') or (sJedResursa = '') then
  begin
    Kolicina := Broj;
    Result := True;
    Exit;
  end;

  if not FaktorJedinice(sJed, sJedResursa, Faktor) then
  begin
    Greska := 'Jedinica "' + sJed + '" ne odgovara resursu (' + sJedResursa + ').';
    Exit;
  end;

  Kolicina := Broj * Faktor;
  Result := True;
end;

function SkiniSaZaliha(IdResursa: Integer; Kolicina: Double;
  out Greska: string): Boolean;
var
  Q: TFDQuery;
begin
  Result := False;
  Greska := '';
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := DB;
    // Zalihe se umanjuju samo ako ih ima dovoljno. Ranije je MAX(0, ...) cutke
    // spustao stanje na nulu i belezio potrosnju koje u magacinu nije bilo.
    Q.SQL.Text :=
      'UPDATE RESURS SET Trenutno_u_Magacinu = Trenutno_u_Magacinu - :k ' +
      'WHERE Sifra_resursa = :r AND Trenutno_u_Magacinu >= :k2';
    Q.ParamByName('k').AsFloat    := Kolicina;
    Q.ParamByName('r').AsInteger  := IdResursa;
    Q.ParamByName('k2').AsFloat   := Kolicina;
    Q.ExecSQL;

    if Q.RowsAffected > 0 then
    begin
      Result := True;
      Exit;
    end;

    Q.SQL.Text :=
      'SELECT Tip_Resursa, Trenutno_u_Magacinu FROM RESURS WHERE Sifra_resursa = :r';
    Q.ParamByName('r').AsInteger := IdResursa;
    Q.Open;
    if Q.IsEmpty then
      Greska := 'Izabrani resurs ne postoji u magacinu.'
    else
      Greska := 'Nema dovoljno na stanju: ' + Q.FieldByName('Tip_Resursa').AsString +
        ' (dostupno ' + FormatFloat('0.##', Q.FieldByName('Trenutno_u_Magacinu').AsFloat) +
        ', potrebno ' + FormatFloat('0.##', Kolicina) + ').' + #13#10 +
        'Administrator treba da dopuni zalihu.';
  finally
    Q.Free;
  end;
end;

function ObracunBoravka(IdLjubimca: Integer; out Ukupno: Double): string;
var
  Q: TFDQuery;
  dCena, dStavka: Double;
  nBroj: Integer;
begin
  Ukupno := 0;
  Result := '';
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := DB;
    // Svaka usluga se broji onoliko puta koliko je zabelezena, po trenutnoj ceni.
    Q.SQL.Text :=
      'SELECT u.Naziv, u.Cena, COUNT(*) AS Broj ' +
      'FROM DNEVNA_AKTIVNOST da ' +
      'JOIN USLUGA u ON u.Sifra_usluge = da.Sifra_usluge ' +
      'JOIN pets p ON p.id = da.Sifra_ljubimca ' +
      'WHERE da.Sifra_ljubimca = :p ' +
      '  AND (p.DatumPrijema IS NULL OR da.VremeOd >= p.DatumPrijema) ' +
      'GROUP BY u.Sifra_usluge, u.Naziv, u.Cena ' +
      'ORDER BY u.Naziv';
    Q.ParamByName('p').AsInteger := IdLjubimca;
    Q.Open;
    while not Q.Eof do
    begin
      nBroj   := Q.FieldByName('Broj').AsInteger;
      dCena   := Q.FieldByName('Cena').AsFloat;
      dStavka := nBroj * dCena;
      Ukupno  := Ukupno + dStavka;
      Result  := Result + Q.FieldByName('Naziv').AsString + ': ' +
        IntToStr(nBroj) + ' x ' + FormatFloat('#,##0.##', dCena) + ' = ' +
        FormatFloat('#,##0.##', dStavka) + ' RSD' + #13#10;
      Q.Next;
    end;
  finally
    Q.Free;
  end;

  if Result = '' then
    Result := 'Nema naplativih usluga.' + #13#10;
  Result := Result + #13#10 + 'UKUPNO: ' + FormatFloat('#,##0.##', Ukupno) + ' RSD';
end;

procedure PromeniLozinkuZaposlenog(SifraZaposlenog: Integer);
begin
  if SifraZaposlenog <= 0 then Exit;
  // #1 na pocetku natpisa = polje za lozinku (unos se ne vidi)
  TDialogService.InputQuery('Promena lozinke',
    [#1'Trenutna lozinka', #1'Nova lozinka (bar 6 znakova)', #1'Ponovite novu lozinku'],
    ['', '', ''],
    procedure(const AResult: TModalResult; const AValues: array of string)
    var
      Q: TFDQuery;
      sStara, sNova, sPonovo: string;
    begin
      if (AResult <> mrOk) or (Length(AValues) < 3) then Exit;
      sStara  := Trim(AValues[0]);
      sNova   := Trim(AValues[1]);
      sPonovo := Trim(AValues[2]);

      if Length(sNova) < 6 then
      begin
        ShowMessage('Nova lozinka mora imati bar 6 znakova.');
        Exit;
      end;
      if sNova <> sPonovo then
      begin
        ShowMessage('Nove lozinke se ne poklapaju.');
        Exit;
      end;

      Q := TFDQuery.Create(nil);
      try
        Q.Connection := DB;
        // Menja se samo ako je trenutna lozinka tacna
        Q.SQL.Text :=
          'UPDATE ZAPOSLENI SET Lozinka = :nova ' +
          'WHERE Sifra_zaposlenog = :id AND Lozinka = :stara';
        Q.ParamByName('nova').AsString  := HesLozinke(sNova);
        Q.ParamByName('id').AsInteger   := SifraZaposlenog;
        Q.ParamByName('stara').AsString := HesLozinke(sStara);
        Q.ExecSQL;
        if Q.RowsAffected = 0 then
          ShowMessage('Trenutna lozinka nije tacna.')
        else
          ShowMessage('Lozinka je promenjena.');
      finally
        Q.Free;
      end;
    end);
end;

end.
