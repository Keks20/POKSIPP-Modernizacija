unit fraAdmin;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.StrUtils,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Layouts, FMX.Objects, FMX.ListBox,
  FMX.DialogService,
  FireDAC.Comp.Client, uUserStore, uNavFrames;

type
  TFrameAdmin = class(TFrame)
    // --- ZAGLAVLJE ---
    layHeader: TLayout;
    lblNaslov: TLabel;
    lblImeAdmin: TLabel;
    rectOdjava: TRectangle;

    // --- GLAVNI SADRZAJ ---
    scrollContent: TScrollBox;

    // ---- LISTA ZAPOSLENIH ----
    lblZaposleniTitle: TLabel;
    lbZaposleni: TListBox;

    // ---- PROFIL SELEKTOVANOG RADNIKA ----
    rectProfil: TRectangle;
    lblProfilIme: TLabel;
    lblProfilUloga: TLabel;
    lblProfilKorIme: TLabel;
    lblProfilDostupnost: TLabel;

    // ---- UNOSI RADNIKA ----
    lblUnosiTitle: TLabel;
    lblBrojUnosi: TLabel;
    lbUnosi: TListBox;

    // ---- CENOVNIK USLUGA ----
    lblCenovnikTitle: TLabel;
    lbCenovnik: TListBox;

    // ---- MAGACIN / ZALIHE ----
    lblMagacinTitle: TLabel;
    lbMagacin: TListBox;

    // ---- IZMENA CENE ----
    rectIzmeniCenu: TRectangle;
    lblIzmeniCenu: TLabel;

    // ---- DOPUNA MAGACINA ----
    rectDopuni: TRectangle;
    lblDopuni: TLabel;

    // ---- POPUP DETALJA UNOSA ----
    rectPopup: TRectangle;
    rectPopupCard: TRectangle;
    lblPopupNaslov: TLabel;
    lblPopupDetalji: TLabel;
    rectPopupZatvori: TRectangle;
    lblPopupX: TLabel;

    // ---- UPRAVLJANJE (dodato) ----
    rectDodajZaposlenog: TRectangle;
    lblDodajZaposlenog: TLabel;
    rectUkloniZaposlenog: TRectangle;
    lblUkloniZaposlenog: TLabel;
    rectDodajUslugu: TRectangle;
    lblDodajUslugu: TLabel;
    rectDodajResurs: TRectangle;
    lblDodajResurs: TLabel;

    // ---- LJUBIMCI U PANSIONU (prijem / odjava) ----
    lblLjubimciTitle: TLabel;
    lbLjubimciAdmin: TListBox;
    rectPrimiLjubimca: TRectangle;
    lblPrimiLjubimca: TLabel;
    rectOdjaviLjubimca: TRectangle;
    lblOdjaviLjubimca: TLabel;

    procedure Loaded; override;
    procedure rectOdjavaClick(Sender: TObject);
    procedure lbZaposleniClick(Sender: TObject);
    procedure lbCenovnikClick(Sender: TObject);
    procedure lbUnosiClick(Sender: TObject);
    procedure rectPopupClick(Sender: TObject);
    procedure rectPopupZatvoriClick(Sender: TObject);
    procedure rectIzmeniCenuClick(Sender: TObject);
    procedure rectDopuniClick(Sender: TObject);
    procedure rectDodajZaposlenogClick(Sender: TObject);
    procedure rectUkloniZaposlenogClick(Sender: TObject);
    procedure rectDodajUsluguClick(Sender: TObject);
    procedure rectDodajResursClick(Sender: TObject);
    procedure rectPrimiLjubimcaClick(Sender: TObject);
    procedure rectOdjaviLjubimcaClick(Sender: TObject);
    procedure lblImeAdminClick(Sender: TObject);
  private
    FZapIDs: TArray<Integer>;
    FZapCount: Integer;
    FUslugaIDs: TArray<Integer>;
    FUslugaCount: Integer;
    FMagIDs: TArray<Integer>;   // Sifra_resursa po stavci magacina
    FMagCount: Integer;
    FUnosDetalji: TArray<string>;  // ranije [0..199]: unosi posle 200. se nisu otvarali
    function JeZauzet(ASifra: Integer): Boolean;
    procedure IzmeniCenuUsluge(idUsluga: Integer);
    procedure DopuniResurs(idResurs: Integer);
    procedure UcitajZaposlene;
    procedure PrikaziRadnika(ASifra: Integer);
    procedure UcitajCenovnik;
    procedure UcitajMagacin;
    procedure UcitajLjubimceAdmin;
    function KorisnickoImeZauzeto(const AKorIme: string): Boolean;
  private
    FLjubIDs: TArray<Integer>;  // id ljubimca za svaku stavku u lbLjubimciAdmin
  end;

implementation

{$R *.fmx}

procedure TFrameAdmin.Loaded;
begin
  inherited;
  rectPopup.Visible := False;
  lblImeAdmin.Text := LoggedInImePrezime + '  ·  promeni lozinku';
  lblImeAdmin.Width := 250;
  UcitajZaposlene;

  if (lbZaposleni.Count > 0) and (FZapCount > 0) then
  begin
    lbZaposleni.ItemIndex := 0;
    PrikaziRadnika(FZapIDs[0]);
  end;

  UcitajCenovnik;
  UcitajMagacin;
  UcitajLjubimceAdmin;
end;

// -------------------------------------------------------
//  Da li radnik trenutno ima aktivnost "U toku" (zauzet)
// -------------------------------------------------------
function TFrameAdmin.JeZauzet(ASifra: Integer): Boolean;
var
  Q: TFDQuery;
begin
  Result := False;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := DB;
    Q.SQL.Text :=
      'SELECT COUNT(*) FROM DNEVNA_AKTIVNOST ' +
      'WHERE Sifra_zaposlenog = :z AND StatusAktivnosti = ''U toku''';
    Q.ParamByName('z').AsInteger := ASifra;
    Q.Open;
    Result := Q.Fields[0].AsInteger > 0;
    Q.Close;
  finally
    Q.Free;
  end;
end;

// -------------------------------------------------------
//  Cenovnik usluga (USLUGA)
// -------------------------------------------------------
procedure TFrameAdmin.UcitajCenovnik;
var
  Q: TFDQuery;
  Item: TListBoxItem;
begin
  lbCenovnik.BeginUpdate;
  try
    lbCenovnik.Clear;
    FUslugaCount := 0;
    FUslugaIDs := nil;
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := DB;
      Q.SQL.Text := 'SELECT Sifra_usluge, Naziv, Cena FROM USLUGA ORDER BY Naziv';
      Q.Open;
      while not Q.Eof do
      begin
        SetLength(FUslugaIDs, FUslugaCount + 1);
        FUslugaIDs[FUslugaCount] := Q.FieldByName('Sifra_usluge').AsInteger;

        Item := TListBoxItem.Create(lbCenovnik);
        Item.Text := Q.FieldByName('Naziv').AsString + '   ·   ' +
          FormatFloat('0.##', Q.FieldByName('Cena').AsFloat) + ' RSD';
        lbCenovnik.AddObject(Item);

        Inc(FUslugaCount);
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    lbCenovnik.EndUpdate;
  end;
end;

// -------------------------------------------------------
//  Magacin / zalihe (RESURS) - read-only, upozorenje na nizak nivo
// -------------------------------------------------------
procedure TFrameAdmin.UcitajMagacin;
var
  Q: TFDQuery;
  Item: TListBoxItem;
  dTren, dNivo: Double;
begin
  lbMagacin.BeginUpdate;
  try
    lbMagacin.Clear;
    FMagCount := 0;
    FMagIDs := nil;
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := DB;
      Q.SQL.Text :=
        'SELECT Sifra_resursa, Tip_Resursa, Trenutno_u_Magacinu, Kolicina_Nivo ' +
        'FROM RESURS ORDER BY Tip_Resursa';
      Q.Open;
      while not Q.Eof do
      begin
        SetLength(FMagIDs, FMagCount + 1);
        FMagIDs[FMagCount] := Q.FieldByName('Sifra_resursa').AsInteger;

        dTren := Q.FieldByName('Trenutno_u_Magacinu').AsFloat;
        dNivo := Q.FieldByName('Kolicina_Nivo').AsFloat;

        Item := TListBoxItem.Create(lbMagacin);
        Item.Text := Q.FieldByName('Tip_Resursa').AsString + '   ·   ' +
          'Na stanju: ' + FormatFloat('0.##', dTren) +
          ' (min: ' + FormatFloat('0.##', dNivo) + ')';
        if dTren <= dNivo then
          Item.Text := Item.Text + '   - NIZAK NIVO!';
        lbMagacin.AddObject(Item);
        Inc(FMagCount);
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    lbMagacin.EndUpdate;
  end;
end;

// -------------------------------------------------------
//  Ucitaj listu svih zaposlenih (bez admin naloga)
// -------------------------------------------------------
procedure TFrameAdmin.UcitajZaposlene;
var
  Q: TFDQuery;
  Item: TListBoxItem;
begin
  lbZaposleni.BeginUpdate;
  try
    lbZaposleni.Clear;
    FZapCount := 0;
    FZapIDs := nil;

    Q := TFDQuery.Create(nil);
    try
      Q.Connection := DB;
      Q.SQL.Text :=
        'SELECT Sifra_zaposlenog, Ime, Prezime, Uloga, Dostupan ' +
        'FROM ZAPOSLENI ' +
        'WHERE lower(Uloga) <> ''admin'' ' +
        'ORDER BY Ime, Prezime';
      Q.Open;

      while not Q.Eof do
      begin
        SetLength(FZapIDs, FZapCount + 1);
        FZapIDs[FZapCount] := Q.FieldByName('Sifra_zaposlenog').AsInteger;

        Item := TListBoxItem.Create(lbZaposleni);
        Item.Text := Q.FieldByName('Ime').AsString + ' ' +
                     Q.FieldByName('Prezime').AsString + '   ·   ' +
          IfThen(SameText(Q.FieldByName('Uloga').AsString, 'Neaktivan'), 'Neaktivan',
            IfThen(JeZauzet(Q.FieldByName('Sifra_zaposlenog').AsInteger),
                   'Zauzet', 'Dostupan'));
        Item.ItemData.Detail := Q.FieldByName('Uloga').AsString;
        lbZaposleni.AddObject(Item);

        Inc(FZapCount);
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    lbZaposleni.EndUpdate;
  end;
end;

// -------------------------------------------------------
//  Prikazi profil + unose selektovanog radnika
// -------------------------------------------------------
procedure TFrameAdmin.PrikaziRadnika(ASifra: Integer);
var
  Q: TFDQuery;
  Item: TListBoxItem;
  sPet, sDetalj, sKat: string;
  i: Integer;
begin
  if ASifra <= 0 then Exit;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := DB;

    // --- Profil ---
    Q.SQL.Text :=
      'SELECT Ime, Prezime, Uloga, KorisnickoIme, Dostupan ' +
      'FROM ZAPOSLENI WHERE Sifra_zaposlenog = :z';
    Q.ParamByName('z').AsInteger := ASifra;
    Q.Open;

    if Q.IsEmpty then
    begin
      Q.Close;
      Exit;
    end;

    lblProfilIme.Text   := Q.FieldByName('Ime').AsString + ' ' +
                           Q.FieldByName('Prezime').AsString;
    lblProfilUloga.Text := 'Uloga: ' + Q.FieldByName('Uloga').AsString;
    lblProfilKorIme.Text := 'Korisnicko ime: ' +
                            Q.FieldByName('KorisnickoIme').AsString;

    Q.Close;

    // Dostupnost se racuna iz aktivnosti "U toku" (ne iz staticke kolone)
    if JeZauzet(ASifra) then
    begin
      lblProfilDostupnost.Text := #$25CF' Zauzet';
      lblProfilDostupnost.TextSettings.FontColor := TAlphaColors.Red;
    end
    else
    begin
      lblProfilDostupnost.Text := #$25CF' Dostupan';
      lblProfilDostupnost.TextSettings.FontColor := TAlphaColors.Green;
    end;

    // --- Unosi radnika (najskoriji na vrhu) ---
    lbUnosi.BeginUpdate;
    try
      lbUnosi.Clear;
      FUnosDetalji := nil; // FillChar nad stringovima je curio memoriju

      Q.SQL.Text :=
        'SELECT da.Kategorija, da.Vrsta_aktivnosti, da.VremeOd, da.VremeDo, ' +
        '       da.DuzinaTrajanja, da.StatusAktivnosti, da.ProcenaPonasanja, ' +
        '       da.Komentar, da.Kolicina, da.VremeObroka, da.StatusOstalo, ' +
        '       p.name AS PetName ' +
        'FROM DNEVNA_AKTIVNOST da ' +
        'LEFT JOIN pets p ON p.id = da.Sifra_ljubimca ' +
        'WHERE da.Sifra_zaposlenog = :z ' +
        'ORDER BY da.VremeOd DESC, da.Sifra_aktivnosti DESC';
      Q.ParamByName('z').AsInteger := ASifra;
      Q.Open;

      Q.FetchAll; // RecordCount broji samo ucitane redove (prvih 50) bez ovoga
      lblBrojUnosi.Text := '(' + IntToStr(Q.RecordCount) + ' unosa)';

      if Q.IsEmpty then
      begin
        Item := TListBoxItem.Create(lbUnosi);
        Item.Text := 'Nema unosa za ovog radnika';
        lbUnosi.AddObject(Item);
      end
      else
      begin
        i := 0;
        while not Q.Eof do
        begin
          sPet := Q.FieldByName('PetName').AsString;
          if sPet = '' then sPet := '(nepoznat ljubimac)';
          sKat := Q.FieldByName('Kategorija').AsString;

          Item := TListBoxItem.Create(lbUnosi);
          Item.Text := Q.FieldByName('Vrsta_aktivnosti').AsString +
                       '  (' + sKat + ')  ·  ' + sPet + '  ·  ' +
                       FormatDateTime('dd.mm. hh:nn',
                         Q.FieldByName('VremeOd').AsDateTime);
          lbUnosi.AddObject(Item);

          // Puni detalji za popup
          sDetalj :=
            'Kategorija: ' + sKat + #13#10 +
            'Vrsta: ' + Q.FieldByName('Vrsta_aktivnosti').AsString + #13#10 +
            'Ljubimac: ' + sPet;

          // Vreme (od-do) i Trajanje se prikazuju samo za Aktivnosti.
          // Hrana ima "Vreme obroka", a Ostalo svoje vreme - pa za njih ne
          // dupliramo VremeOd ni bespotrebno "Trajanje: 0 min".
          if sKat = 'Aktivnosti' then
          begin
            sDetalj := sDetalj + #13#10 +
              'Vreme: ' + FormatDateTime('dd.mm.yyyy. hh:nn',
                Q.FieldByName('VremeOd').AsDateTime);
            if Q.FieldByName('VremeDo').AsDateTime > 0 then
              sDetalj := sDetalj + ' - ' +
                FormatDateTime('hh:nn', Q.FieldByName('VremeDo').AsDateTime);
          end;

          sDetalj := sDetalj + #13#10 +
            'Status: ' + Q.FieldByName('StatusAktivnosti').AsString;

          if (sKat = 'Aktivnosti') and
             (Trim(Q.FieldByName('DuzinaTrajanja').AsString) <> '') then
            sDetalj := sDetalj + #13#10 +
              'Trajanje: ' + Q.FieldByName('DuzinaTrajanja').AsString;
          if Trim(Q.FieldByName('ProcenaPonasanja').AsString) <> '' then
            sDetalj := sDetalj + #13#10 +
              'Procena: ' + Q.FieldByName('ProcenaPonasanja').AsString;
          if Trim(Q.FieldByName('VremeObroka').AsString) <> '' then
            sDetalj := sDetalj + #13#10 +
              'Vreme obroka: ' + Q.FieldByName('VremeObroka').AsString;
          if Trim(Q.FieldByName('Kolicina').AsString) <> '' then
            sDetalj := sDetalj + #13#10 +
              'Kolicina: ' + Q.FieldByName('Kolicina').AsString;
          if Trim(Q.FieldByName('StatusOstalo').AsString) <> '' then
            sDetalj := sDetalj + #13#10 +
              'Status (ostalo): ' + Q.FieldByName('StatusOstalo').AsString;
          if Trim(Q.FieldByName('Komentar').AsString) <> '' then
            sDetalj := sDetalj + #13#10 +
              'Komentar: ' + Q.FieldByName('Komentar').AsString;

          SetLength(FUnosDetalji, i + 1);
          FUnosDetalji[i] := sDetalj;

          Inc(i);
          Q.Next;
        end;
      end;
      Q.Close;
    finally
      lbUnosi.EndUpdate;
    end;
  finally
    Q.Free;
  end;
end;

procedure TFrameAdmin.lbZaposleniClick(Sender: TObject);
begin
  if (lbZaposleni.ItemIndex < 0) or
     (lbZaposleni.ItemIndex >= FZapCount) then Exit;
  PrikaziRadnika(FZapIDs[lbZaposleni.ItemIndex]);
end;

// -------------------------------------------------------
//  Klik na uslugu u cenovniku -> izmena cene (admin)
// -------------------------------------------------------
procedure TFrameAdmin.IzmeniCenuUsluge(idUsluga: Integer);
var
  sNaziv: string;
  dStara: Double;
  Q: TFDQuery;
begin
  // Trenutni naziv i cena (za prikaz u dijalogu)
  sNaziv := '';
  dStara := 0;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := DB;
    Q.SQL.Text := 'SELECT Naziv, Cena FROM USLUGA WHERE Sifra_usluge = :id';
    Q.ParamByName('id').AsInteger := idUsluga;
    Q.Open;
    if Q.IsEmpty then Exit;
    sNaziv := Q.FieldByName('Naziv').AsString;
    dStara := Q.FieldByName('Cena').AsFloat;
  finally
    Q.Free;
  end;

  TDialogService.InputQuery(
    'Izmena cene: ' + sNaziv,
    ['Nova cena (RSD)'],
    [FormatFloat('0.##', dStara)],
    procedure(const AResult: TModalResult; const AValues: array of string)
    var
      sNova: string;
      dNova: Double;
      Q2: TFDQuery;
    begin
      if AResult <> mrOk then Exit;
      if Length(AValues) = 0 then Exit;

      sNova := StringReplace(Trim(AValues[0]), ',', '.', [rfReplaceAll]);
      if not TryStrToFloat(sNova, dNova, TFormatSettings.Invariant) then
      begin
        ShowMessage('Neispravna cena! Unesite broj (npr. 750).');
        Exit;
      end;
      if dNova < 0 then
      begin
        ShowMessage('Cena ne moze biti negativna.');
        Exit;
      end;

      Q2 := TFDQuery.Create(nil);
      try
        Q2.Connection := DB;
        Q2.SQL.Text := 'UPDATE USLUGA SET Cena = :c WHERE Sifra_usluge = :id';
        Q2.ParamByName('c').AsFloat   := dNova;
        Q2.ParamByName('id').AsInteger := idUsluga;
        Q2.ExecSQL;
      finally
        Q2.Free;
      end;

      UcitajCenovnik;
    end);
end;

procedure TFrameAdmin.lbCenovnikClick(Sender: TObject);
var
  idx: Integer;
begin
  idx := lbCenovnik.ItemIndex;
  if (idx < 0) or (idx >= FUslugaCount) then Exit;
  IzmeniCenuUsluge(FUslugaIDs[idx]);
end;

// -------------------------------------------------------
//  Dopuna magacina (RESURS) - admin dodaje kolicinu na stanje
// -------------------------------------------------------
procedure TFrameAdmin.DopuniResurs(idResurs: Integer);
var
  sNaziv: string;
  dStanje: Double;
  Q: TFDQuery;
begin
  sNaziv  := '';
  dStanje := 0;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := DB;
    Q.SQL.Text :=
      'SELECT Tip_Resursa, Trenutno_u_Magacinu FROM RESURS ' +
      'WHERE Sifra_resursa = :id';
    Q.ParamByName('id').AsInteger := idResurs;
    Q.Open;
    if Q.IsEmpty then Exit;
    sNaziv  := Q.FieldByName('Tip_Resursa').AsString;
    dStanje := Q.FieldByName('Trenutno_u_Magacinu').AsFloat;
  finally
    Q.Free;
  end;

  TDialogService.InputQuery(
    'Dopuna: ' + sNaziv + '  (na stanju: ' + FormatFloat('0.##', dStanje) + ')',
    ['Kolicina za dodavanje'],
    [''],
    procedure(const AResult: TModalResult; const AValues: array of string)
    var
      sKol: string;
      dKol: Double;
      Q2: TFDQuery;
    begin
      if AResult <> mrOk then Exit;
      if Length(AValues) = 0 then Exit;

      sKol := StringReplace(Trim(AValues[0]), ',', '.', [rfReplaceAll]);
      if not TryStrToFloat(sKol, dKol, TFormatSettings.Invariant) then
      begin
        ShowMessage('Neispravna kolicina! Unesite broj (npr. 1000).');
        Exit;
      end;
      if dKol <= 0 then
      begin
        ShowMessage('Kolicina mora biti veca od nule.');
        Exit;
      end;

      Q2 := TFDQuery.Create(nil);
      try
        Q2.Connection := DB;
        Q2.SQL.Text :=
          'UPDATE RESURS SET Trenutno_u_Magacinu = Trenutno_u_Magacinu + :k ' +
          'WHERE Sifra_resursa = :id';
        Q2.ParamByName('k').AsFloat    := dKol;
        Q2.ParamByName('id').AsInteger := idResurs;
        Q2.ExecSQL;
      finally
        Q2.Free;
      end;

      UcitajMagacin;
    end);
end;

procedure TFrameAdmin.rectDopuniClick(Sender: TObject);
var
  idx: Integer;
begin
  idx := lbMagacin.ItemIndex;
  if (idx < 0) or (idx >= FMagCount) then
  begin
    ShowMessage('Izaberite zalihu iz liste pa kliknite "Dopuni".');
    Exit;
  end;
  DopuniResurs(FMagIDs[idx]);
end;

procedure TFrameAdmin.rectIzmeniCenuClick(Sender: TObject);
var
  idx: Integer;
begin
  idx := lbCenovnik.ItemIndex;
  if (idx < 0) or (idx >= FUslugaCount) then
  begin
    ShowMessage('Izaberite uslugu iz liste pa kliknite "Izmeni cenu".');
    Exit;
  end;
  IzmeniCenuUsluge(FUslugaIDs[idx]);
end;

// -------------------------------------------------------
//  Klik na unos radnika -> popup sa detaljima
// -------------------------------------------------------
procedure TFrameAdmin.lbUnosiClick(Sender: TObject);
var
  idx: Integer;
begin
  idx := lbUnosi.ItemIndex;
  if (idx < 0) or (idx > High(FUnosDetalji)) then Exit;
  if FUnosDetalji[idx] = '' then Exit;

  lblPopupNaslov.Text  := lbUnosi.ListItems[idx].Text;
  lblPopupDetalji.Text := FUnosDetalji[idx];
  rectPopup.Visible    := True;
  rectPopup.BringToFront;
end;

procedure TFrameAdmin.rectPopupClick(Sender: TObject);
begin
  rectPopup.Visible := False;
end;

procedure TFrameAdmin.rectPopupZatvoriClick(Sender: TObject);
begin
  rectPopup.Visible := False;
end;

procedure TFrameAdmin.rectOdjavaClick(Sender: TObject);
begin
  LoggedInUserID     := 0;
  LoggedInRole       := '';
  LoggedInUsername   := '';
  LoggedInImePrezime := '';
  SelectedPetID      := 0;
  TNavFrames.GoLogin;
end;

// =======================================================
//  UPRAVLJANJE: zaposleni, usluge, resursi, ljubimci
// =======================================================

procedure TFrameAdmin.lblImeAdminClick(Sender: TObject);
begin
  PromeniLozinkuZaposlenog(LoggedInUserID);
end;

// Korisnicko ime mora da bude jedinstveno u obe tabele naloga
function TFrameAdmin.KorisnickoImeZauzeto(const AKorIme: string): Boolean;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := DB;
    Q.SQL.Text :=
      'SELECT (SELECT COUNT(*) FROM ZAPOSLENI WHERE lower(KorisnickoIme) = lower(:u)) + ' +
      '       (SELECT COUNT(*) FROM MUSTERIJA WHERE lower(KorisnickoIme) = lower(:u2))';
    Q.ParamByName('u').AsString  := AKorIme;
    Q.ParamByName('u2').AsString := AKorIme;
    Q.Open;
    Result := Q.Fields[0].AsInteger > 0;
  finally
    Q.Free;
  end;
end;

// -------------------------------------------------------
//  Novi zaposleni
// -------------------------------------------------------
procedure TFrameAdmin.rectDodajZaposlenogClick(Sender: TObject);
begin
  TDialogService.InputQuery('Novi zaposleni',
    ['Ime', 'Prezime', 'Uloga (npr. Negovatelj)', 'Korisnicko ime',
     #1'Lozinka (bar 6 znakova)'],
    ['', '', 'Negovatelj', '', ''],
    procedure(const AResult: TModalResult; const AValues: array of string)
    var
      Q: TFDQuery;
      sIme, sPrezime, sUloga, sKorIme, sLozinka: string;
    begin
      if (AResult <> mrOk) or (Length(AValues) < 5) then Exit;
      sIme     := Trim(AValues[0]);
      sPrezime := Trim(AValues[1]);
      sUloga   := Trim(AValues[2]);
      sKorIme  := Trim(AValues[3]);
      sLozinka := Trim(AValues[4]);

      if (sIme = '') or (sPrezime = '') or (sKorIme = '') then
      begin
        ShowMessage('Ime, prezime i korisnicko ime su obavezni.');
        Exit;
      end;
      if sUloga = '' then
        sUloga := 'Negovatelj';
      // Novi admin se ne pravi iz aplikacije, a 'Neaktivan' je rezervisana uloga
      if SameText(sUloga, 'Admin') or SameText(sUloga, 'Neaktivan') then
      begin
        ShowMessage('Uloga ne moze biti "Admin" ni "Neaktivan".');
        Exit;
      end;
      if Length(sLozinka) < 6 then
      begin
        ShowMessage('Lozinka mora imati bar 6 znakova.');
        Exit;
      end;
      if KorisnickoImeZauzeto(sKorIme) then
      begin
        ShowMessage('Korisnicko ime "' + sKorIme + '" je vec zauzeto.');
        Exit;
      end;

      Q := TFDQuery.Create(nil);
      try
        Q.Connection := DB;
        Q.SQL.Text :=
          'INSERT INTO ZAPOSLENI (Ime, Prezime, Uloga, KorisnickoIme, Lozinka, Dostupan) ' +
          'VALUES (:ime, :prez, :uloga, :kor, :loz, 1)';
        Q.ParamByName('ime').AsString   := sIme;
        Q.ParamByName('prez').AsString  := sPrezime;
        Q.ParamByName('uloga').AsString := sUloga;
        Q.ParamByName('kor').AsString   := sKorIme;
        Q.ParamByName('loz').AsString   := HesLozinke(sLozinka);
        Q.ExecSQL;
      finally
        Q.Free;
      end;

      UcitajZaposlene;
      ShowMessage('Zaposleni je dodat. Prijava: ' + sKorIme);
    end);
end;

// -------------------------------------------------------
//  Uklanjanje zaposlenog: bez unosa se brise, sa unosima se
//  deaktivira (ne moze da se prijavi, a istorija ostaje).
// -------------------------------------------------------
procedure TFrameAdmin.rectUkloniZaposlenogClick(Sender: TObject);
var
  Q: TFDQuery;
  idx, idZap, nUnosa: Integer;
  sIme, sPoruka: string;
begin
  idx := lbZaposleni.ItemIndex;
  if (idx < 0) or (idx >= FZapCount) then
  begin
    ShowMessage('Izaberite zaposlenog iz liste.');
    Exit;
  end;
  idZap := FZapIDs[idx];

  if JeZauzet(idZap) then
  begin
    ShowMessage('Zaposleni ima aktivnost u toku. Neka je prvo zavrsi.');
    Exit;
  end;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := DB;
    Q.SQL.Text :=
      'SELECT Ime, Prezime, Uloga, ' +
      '  (SELECT COUNT(*) FROM DNEVNA_AKTIVNOST WHERE Sifra_zaposlenog = :z2) AS Unosa ' +
      'FROM ZAPOSLENI WHERE Sifra_zaposlenog = :z';
    Q.ParamByName('z').AsInteger  := idZap;
    Q.ParamByName('z2').AsInteger := idZap;
    Q.Open;
    if Q.IsEmpty then Exit;
    if SameText(Q.FieldByName('Uloga').AsString, 'Neaktivan') then
    begin
      ShowMessage('Ovaj nalog je vec deaktiviran.');
      Exit;
    end;
    sIme   := Q.FieldByName('Ime').AsString + ' ' + Q.FieldByName('Prezime').AsString;
    nUnosa := Q.FieldByName('Unosa').AsInteger;
  finally
    Q.Free;
  end;

  if nUnosa = 0 then
    sPoruka := 'Obrisati zaposlenog ' + sIme + '?'
  else
    sPoruka := sIme + ' ima ' + IntToStr(nUnosa) + ' unosa.' + #13#10 +
      'Nalog ce biti deaktiviran: vise ne moze da se prijavi, a istorija ostaje.' +
      #13#10 + 'Nastaviti?';

  TDialogService.MessageDialog(sPoruka, TMsgDlgType.mtConfirmation,
    [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo, 0,
    procedure(const AResult: TModalResult)
    var
      Q2: TFDQuery;
    begin
      if AResult <> mrYes then Exit;
      Q2 := TFDQuery.Create(nil);
      try
        Q2.Connection := DB;
        if nUnosa = 0 then
          Q2.SQL.Text := 'DELETE FROM ZAPOSLENI WHERE Sifra_zaposlenog = :z'
        else
          // Lozinka NULL = prijava vise nije moguca
          Q2.SQL.Text :=
            'UPDATE ZAPOSLENI SET Uloga = ''Neaktivan'', Lozinka = NULL, Dostupan = 0 ' +
            'WHERE Sifra_zaposlenog = :z';
        Q2.ParamByName('z').AsInteger := idZap;
        Q2.ExecSQL;
      finally
        Q2.Free;
      end;
      UcitajZaposlene;
      if FZapCount > 0 then
      begin
        lbZaposleni.ItemIndex := 0;
        PrikaziRadnika(FZapIDs[0]);
      end;
    end);
end;

// -------------------------------------------------------
//  Nova usluga u cenovniku
// -------------------------------------------------------
procedure TFrameAdmin.rectDodajUsluguClick(Sender: TObject);
begin
  TDialogService.InputQuery('Nova usluga',
    ['Naziv usluge', 'Cena (RSD)'],
    ['', ''],
    procedure(const AResult: TModalResult; const AValues: array of string)
    var
      Q: TFDQuery;
      sNaziv: string;
      dCena: Double;
    begin
      if (AResult <> mrOk) or (Length(AValues) < 2) then Exit;
      sNaziv := Trim(AValues[0]);
      if sNaziv = '' then
      begin
        ShowMessage('Unesite naziv usluge.');
        Exit;
      end;
      if not TryStrToFloat(StringReplace(Trim(AValues[1]), ',', '.', [rfReplaceAll]),
                           dCena, TFormatSettings.Invariant) or (dCena < 0) then
      begin
        ShowMessage('Neispravna cena! Unesite broj (npr. 750).');
        Exit;
      end;

      Q := TFDQuery.Create(nil);
      try
        Q.Connection := DB;
        Q.SQL.Text := 'SELECT COUNT(*) FROM USLUGA WHERE lower(Naziv) = lower(:n)';
        Q.ParamByName('n').AsString := sNaziv;
        Q.Open;
        if Q.Fields[0].AsInteger > 0 then
        begin
          ShowMessage('Usluga "' + sNaziv + '" vec postoji.');
          Exit;
        end;
        Q.Close;

        Q.SQL.Text := 'INSERT INTO USLUGA (Naziv, Cena) VALUES (:n, :c)';
        Q.ParamByName('n').AsString := sNaziv;
        Q.ParamByName('c').AsFloat  := dCena;
        Q.ExecSQL;
      finally
        Q.Free;
      end;
      UcitajCenovnik;
    end);
end;

// -------------------------------------------------------
//  Novi resurs u magacinu
// -------------------------------------------------------
procedure TFrameAdmin.rectDodajResursClick(Sender: TObject);
begin
  TDialogService.InputQuery('Novi resurs u magacinu',
    ['Naziv i jedinica, npr. Grickalice (g)', 'Pocetno stanje', 'Minimalni nivo'],
    ['', '0', '0'],
    procedure(const AResult: TModalResult; const AValues: array of string)
    var
      Q: TFDQuery;
      sNaziv: string;
      dStanje, dMin: Double;
    begin
      if (AResult <> mrOk) or (Length(AValues) < 3) then Exit;
      sNaziv := Trim(AValues[0]);
      if sNaziv = '' then
      begin
        ShowMessage('Unesite naziv resursa.');
        Exit;
      end;
      // Jedinica u zagradi je obavezna - po njoj se pretvaraju kolicine (kg -> g...)
      if JedinicaResursa(sNaziv) = '' then
      begin
        ShowMessage('Dodajte jedinicu u zagradi na kraju naziva: (g), (ml) ili (kom).');
        Exit;
      end;
      if not TryStrToFloat(StringReplace(Trim(AValues[1]), ',', '.', [rfReplaceAll]),
                           dStanje, TFormatSettings.Invariant) or (dStanje < 0) or
         not TryStrToFloat(StringReplace(Trim(AValues[2]), ',', '.', [rfReplaceAll]),
                           dMin, TFormatSettings.Invariant) or (dMin < 0) then
      begin
        ShowMessage('Stanje i minimalni nivo moraju biti brojevi (0 ili vise).');
        Exit;
      end;

      Q := TFDQuery.Create(nil);
      try
        Q.Connection := DB;
        Q.SQL.Text := 'SELECT COUNT(*) FROM RESURS WHERE lower(Tip_Resursa) = lower(:t)';
        Q.ParamByName('t').AsString := sNaziv;
        Q.Open;
        if Q.Fields[0].AsInteger > 0 then
        begin
          ShowMessage('Resurs "' + sNaziv + '" vec postoji. Za vecu kolicinu koristite "Dopuni".');
          Exit;
        end;
        Q.Close;

        Q.SQL.Text :=
          'INSERT INTO RESURS (Tip_Resursa, Trenutno_u_Magacinu, Kolicina_Nivo) ' +
          'VALUES (:t, :s, :m)';
        Q.ParamByName('t').AsString := sNaziv;
        Q.ParamByName('s').AsFloat  := dStanje;
        Q.ParamByName('m').AsFloat  := dMin;
        Q.ExecSQL;
      finally
        Q.Free;
      end;
      UcitajMagacin;
      ShowMessage('Resurs je dodat.' + #13#10 +
        'Ako naziv sadrzi rec "hrana", pojavice se kod unosa hrane, a ostali kod "Ostalo".');
    end);
end;

// -------------------------------------------------------
//  Ljubimci u pansionu (aktivni prvo, pa odjavljeni)
// -------------------------------------------------------
procedure TFrameAdmin.UcitajLjubimceAdmin;
var
  Q: TFDQuery;
  Item: TListBoxItem;
  n: Integer;
  sStatus, sVlasnik: string;
begin
  lbLjubimciAdmin.BeginUpdate;
  try
    lbLjubimciAdmin.Clear;
    FLjubIDs := nil;
    n := 0;
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := DB;
      Q.SQL.Text :=
        'SELECT p.id, p.name, p.species, p.Lokacija, ' +
        '       COALESCE(p.Status, ''Aktivan'') AS StatusLj, m.Ime, m.Prezime ' +
        'FROM pets p ' +
        'LEFT JOIN MUSTERIJA m ON m.Sifra_musterije = p.Sifra_musterije ' +
        'ORDER BY CASE WHEN COALESCE(p.Status, ''Aktivan'') = ''Odjavljen'' THEN 1 ELSE 0 END, ' +
        '         p.name';
      Q.Open;
      while not Q.Eof do
      begin
        SetLength(FLjubIDs, n + 1);
        FLjubIDs[n] := Q.FieldByName('id').AsInteger;

        sStatus  := Q.FieldByName('StatusLj').AsString;
        sVlasnik := Trim(Q.FieldByName('Ime').AsString + ' ' + Q.FieldByName('Prezime').AsString);
        if sVlasnik = '' then
          sVlasnik := '(nepoznat vlasnik)';

        Item := TListBoxItem.Create(lbLjubimciAdmin);
        Item.Text := Q.FieldByName('name').AsString + ' (' +
          Q.FieldByName('species').AsString + ')   ·   ' + sStatus;
        Item.ItemData.Detail := 'Vlasnik: ' + sVlasnik;
        if Trim(Q.FieldByName('Lokacija').AsString) <> '' then
          Item.ItemData.Detail := Item.ItemData.Detail + '  ·  ' +
            Q.FieldByName('Lokacija').AsString;
        lbLjubimciAdmin.AddObject(Item);

        Inc(n);
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    lbLjubimciAdmin.EndUpdate;
  end;
end;

// -------------------------------------------------------
//  Prijem ljubimca: vlasnik mora da ima nalog, boks mora da bude slobodan
// -------------------------------------------------------
procedure TFrameAdmin.rectPrimiLjubimcaClick(Sender: TObject);
begin
  TDialogService.InputQuery('Prijem ljubimca',
    ['Ime ljubimca', 'Vrsta (Pas, Macka...)', 'Rasa', 'Starost (npr. 2 godine)',
     'Alergije', 'Boks (npr. A3)', 'Korisnicko ime ili email vlasnika'],
    ['', 'Pas', '', '', 'Nema poznatih', '', ''],
    procedure(const AResult: TModalResult; const AValues: array of string)
    var
      Q: TFDQuery;
      sIme, sVrsta, sRasa, sStarost, sAlergije, sBoks, sVlasnik: string;
      idVlasnika: Integer;
    begin
      if (AResult <> mrOk) or (Length(AValues) < 7) then Exit;
      sIme      := Trim(AValues[0]);
      sVrsta    := Trim(AValues[1]);
      sRasa     := Trim(AValues[2]);
      sStarost  := Trim(AValues[3]);
      sAlergije := Trim(AValues[4]);
      sBoks     := Trim(AValues[5]);
      sVlasnik  := Trim(AValues[6]);

      if (sIme = '') or (sVrsta = '') or (sBoks = '') or (sVlasnik = '') then
      begin
        ShowMessage('Ime, vrsta, boks i vlasnik su obavezni.');
        Exit;
      end;
      if not StartsText('Boks', sBoks) then
        sBoks := 'Boks ' + sBoks;
      if sAlergije = '' then
        sAlergije := 'Nema poznatih';

      Q := TFDQuery.Create(nil);
      try
        Q.Connection := DB;

        // Vlasnik mora vec da ima nalog (registracija)
        Q.SQL.Text :=
          'SELECT Sifra_musterije FROM MUSTERIJA ' +
          'WHERE lower(KorisnickoIme) = lower(:v) OR lower(COALESCE(Email, '''')) = lower(:v2)';
        Q.ParamByName('v').AsString  := sVlasnik;
        Q.ParamByName('v2').AsString := sVlasnik;
        Q.Open;
        if Q.IsEmpty then
        begin
          ShowMessage('Vlasnik "' + sVlasnik + '" ne postoji.' + #13#10 +
                      'Vlasnik prvo treba da se registruje u aplikaciji.');
          Exit;
        end;
        idVlasnika := Q.Fields[0].AsInteger;
        Q.Close;

        // Boks ne sme da bude zauzet drugim ljubimcem koji je jos u pansionu
        Q.SQL.Text :=
          'SELECT name FROM pets WHERE lower(Lokacija) = lower(:b) ' +
          'AND COALESCE(Status, ''Aktivan'') <> ''Odjavljen''';
        Q.ParamByName('b').AsString := sBoks;
        Q.Open;
        if not Q.IsEmpty then
        begin
          ShowMessage(sBoks + ' je zauzet (' + Q.Fields[0].AsString + ').');
          Exit;
        end;
        Q.Close;

        Q.SQL.Text :=
          'INSERT INTO pets (name, species, breed, age, Status, Sifra_musterije, ' +
          '  Lokacija, Alergije, DatumPrijema) ' +
          'VALUES (:ime, :vrsta, :rasa, :starost, ''Aktivan'', :mid, :lok, :alerg, :dp)';
        Q.ParamByName('ime').AsString     := sIme;
        Q.ParamByName('vrsta').AsString   := sVrsta;
        Q.ParamByName('rasa').AsString    := sRasa;
        Q.ParamByName('starost').AsString := sStarost;
        Q.ParamByName('mid').AsInteger    := idVlasnika;
        Q.ParamByName('lok').AsString     := sBoks;
        Q.ParamByName('alerg').AsString   := sAlergije;
        Q.ParamByName('dp').AsDateTime    := Now;
        Q.ExecSQL;
      finally
        Q.Free;
      end;

      UcitajLjubimceAdmin;
      ShowMessage(sIme + ' je primljen u pansion (' + sBoks + ').');
    end);
end;

// -------------------------------------------------------
//  Odjava ljubimca + racun po cenovniku
// -------------------------------------------------------
procedure TFrameAdmin.rectOdjaviLjubimcaClick(Sender: TObject);
var
  Q: TFDQuery;
  idx, idPet: Integer;
  sIme, sRacun: string;
  dUkupno: Double;
begin
  idx := lbLjubimciAdmin.ItemIndex;
  if (idx < 0) or (idx > High(FLjubIDs)) then
  begin
    ShowMessage('Izaberite ljubimca iz liste "Ljubimci u pansionu".');
    Exit;
  end;
  idPet := FLjubIDs[idx];

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := DB;
    Q.SQL.Text :=
      'SELECT name, COALESCE(Status, ''Aktivan'') AS StatusLj, ' +
      '  (SELECT COUNT(*) FROM DNEVNA_AKTIVNOST ' +
      '    WHERE Sifra_ljubimca = :p2 AND StatusAktivnosti = ''U toku'') AS UToku ' +
      'FROM pets WHERE id = :p';
    Q.ParamByName('p').AsInteger  := idPet;
    Q.ParamByName('p2').AsInteger := idPet;
    Q.Open;
    if Q.IsEmpty then Exit;
    sIme := Q.FieldByName('name').AsString;
    if Q.FieldByName('StatusLj').AsString = 'Odjavljen' then
    begin
      Q.Close;
      // Vec odjavljen - samo prikazi racun
      sRacun := ObracunBoravka(idPet, dUkupno);
      lblPopupNaslov.Text  := 'Racun: ' + sIme + ' (odjavljen)';
      lblPopupDetalji.Text := sRacun;
      rectPopup.Visible    := True;
      rectPopup.BringToFront;
      Exit;
    end;
    if Q.FieldByName('UToku').AsInteger > 0 then
    begin
      ShowMessage(sIme + ' ima aktivnost u toku. Odjava je moguca kad se zavrsi.');
      Exit;
    end;
  finally
    Q.Free;
  end;

  sRacun := ObracunBoravka(idPet, dUkupno);

  TDialogService.MessageDialog(
    'Odjava: ' + sIme + #13#10#13#10 + sRacun + #13#10#13#10 + 'Odjaviti ljubimca?',
    TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo, 0,
    procedure(const AResult: TModalResult)
    var
      Q2: TFDQuery;
    begin
      if AResult <> mrYes then Exit;
      Q2 := TFDQuery.Create(nil);
      try
        Q2.Connection := DB;
        // Boks se oslobadja, a ljubimac ostaje u bazi radi istorije i racuna
        Q2.SQL.Text :=
          'UPDATE pets SET Status = ''Odjavljen'', DatumOdjave = :d, Lokacija = '''' ' +
          'WHERE id = :p';
        Q2.ParamByName('d').AsDateTime := Now;
        Q2.ParamByName('p').AsInteger  := idPet;
        Q2.ExecSQL;
      finally
        Q2.Free;
      end;
      UcitajLjubimceAdmin;
      lblPopupNaslov.Text  := 'Racun: ' + sIme;
      lblPopupDetalji.Text := sRacun;
      rectPopup.Visible    := True;
      rectPopup.BringToFront;
    end);
end;

end.
