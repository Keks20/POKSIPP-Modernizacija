unit fraDnevnikMusterije;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Layouts, FMX.Objects, FMX.ListBox,
  FireDAC.Comp.Client, uUserStore, uNavFrames, uPetModel;

type
  TFrameDnevnikMusterije = class(TFrame)
    // --- ZAGLAVLJE ---
    layHeader: TLayout;
    lblNaslov: TLabel;
    lblPozdrav: TLabel;
    rectNazad: TRectangle;

    // --- ODABIR LJUBIMCA ---
    rectOdabir: TRectangle;
    lblOdabirTitle: TLabel;
    cbLjubimci: TComboBox;
    lblBoravak: TLabel;       // boravak i racun do sada (klik = ceo racun)

    // --- GLAVNI SCROLL ---
    scrollContent: TScrollBox;

    // ---- SEKCIJA: AKTIVNOSTI ----
    rectSekAkt: TRectangle;
    lblSekAkt: TLabel;
    lblBrojAkt: TLabel;
    lbAktivnosti: TListBox;

    // ---- SEKCIJA: HRANA ----
    rectSekHrana: TRectangle;
    lblSekHrana: TLabel;
    lblBrojHrana: TLabel;
    lbHrana: TListBox;

    // ---- SEKCIJA: OSTALO ----
    rectSekOstalo: TRectangle;
    lblSekOstalo: TLabel;
    lblBrojOstalo: TLabel;
    lbOstalo: TListBox;

    // ---- SEKCIJA: POPUP ----
    rectPopup: TRectangle;
    rectPopupCard: TRectangle;
    lblPopupNaslov: TLabel;
    lblPopupDetalji: TLabel;
    rectPopupZatvori: TRectangle;
    lblPopupX: TLabel;


    procedure Loaded; override;
    procedure rectNazadClick(Sender: TObject);
    procedure cbLjubimciChange(Sender: TObject);
    procedure lbAktivnostiClick(Sender: TObject);
    procedure lbHranaClick(Sender: TObject);
    procedure lbOstaloClick(Sender: TObject);
    procedure rectPopupZatvoriClick(Sender: TObject);
    procedure rectPopupClick(Sender: TObject);
    procedure lblBoravakClick(Sender: TObject);

  private
    // Dinamicki nizovi - ranije array[0..19] i [0..49]: 21. ljubimac je pisao
    // van niza, a detalji posle 50. zapisa se nisu otvarali.
    FPetIDs: TArray<Integer>;
    FPetCount: Integer;

    // Cuva detalje za svaki item
    FAktDetalji: TArray<string>;
    FHranaDetalji: TArray<string>;
    FOstaloDetalji: TArray<string>;

    procedure UcitajMojeLjubimce;
    procedure UcitajSve;
    procedure UcitajAktivnosti;
    procedure UcitajHranu;
    procedure UcitajOstalo;
    procedure PrikaziPopup(const ANaslov, ADetalji: string);
    procedure PrikaziBoravak;
  end;

implementation

{$R *.fmx}

procedure TFrameDnevnikMusterije.Loaded;
var
  i, nIdx: Integer;
begin
  inherited;
  lblPozdrav.Text := 'Zdravo, ' + LoggedInImePrezime + '!';

  // Popup je na pocetku skriven
  rectPopup.Visible := False;

  UcitajMojeLjubimce;

  if FPetCount = 0 then
  begin
    // Bez ljubimaca: prazne liste sa porukom, i nista tudje se ne prikazuje.
    SelectedPetID := 0;
    UcitajSve;
    lbAktivnosti.Clear;
    var ItemPrazno := TListBoxItem.Create(lbAktivnosti);
    ItemPrazno.Text := 'Nemate ljubimce u pansionu.';
    lbAktivnosti.AddObject(ItemPrazno);
    lblBrojAkt.Text := '';
    lblBrojHrana.Text := '';
    lblBrojOstalo.Text := '';
  end
  else if cbLjubimci.Count > 0 then
  begin
    // Zadrzi vec selektovanog ljubimca (kad osoblje dodje preko "Pregled")
    nIdx := 0;
    for i := 0 to FPetCount - 1 do
      if FPetIDs[i] = SelectedPetID then
      begin
        nIdx := i;
        Break;
      end;
    cbLjubimci.ItemIndex := nIdx;
    SelectedPetID := FPetIDs[nIdx];
    UcitajSve;
  end;
end;

procedure TFrameDnevnikMusterije.UcitajMojeLjubimce;
var
  Q: TFDQuery;
begin
  cbLjubimci.Items.Clear;
  FPetCount := 0;
  FPetIDs := nil;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := DB;

    // Musterija vidi SAMO svoje ljubimce. Osoblje i admin (dolaze preko "Pregled")
    // vide sve. Ranije je musterija bez ljubimaca videla ljubimce svih vlasnika,
    // a osoblje je trazeno po Sifra_musterije = sifra zaposlenog (pogresna tabela).
    if LoggedInRole = 'MUSTERIJA' then
    begin
      Q.SQL.Text :=
        'SELECT id, name, breed, species ' +
        'FROM pets WHERE Sifra_musterije = :mid ORDER BY name';
      Q.ParamByName('mid').AsInteger := LoggedInUserID;
    end
    else
      Q.SQL.Text := 'SELECT id, name, breed, species FROM pets ORDER BY name';
    Q.Open;

    while not Q.Eof do
    begin
      SetLength(FPetIDs, FPetCount + 1);
      FPetIDs[FPetCount] := Q.FieldByName('id').AsInteger;
      cbLjubimci.Items.Add(
        Q.FieldByName('name').AsString + '  (' +
        Q.FieldByName('species').AsString + ' · ' +
        Q.FieldByName('breed').AsString + ')'
      );
      Inc(FPetCount);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

procedure TFrameDnevnikMusterije.cbLjubimciChange(Sender: TObject);
begin
  if (cbLjubimci.ItemIndex < 0) or
     (cbLjubimci.ItemIndex >= FPetCount) then Exit;
  SelectedPetID := FPetIDs[cbLjubimci.ItemIndex];
  UcitajSve;
end;

procedure TFrameDnevnikMusterije.UcitajSve;
begin
  PrikaziBoravak;
  UcitajAktivnosti;
  UcitajHranu;
  UcitajOstalo;
end;

// -------------------------------------------------------
//  Prikazi popup sa detaljima
// -------------------------------------------------------
procedure TFrameDnevnikMusterije.PrikaziPopup(
  const ANaslov, ADetalji: string);
begin
  lblPopupNaslov.Text  := ANaslov;
  lblPopupDetalji.Text := ADetalji;
  rectPopup.Visible    := True;
  rectPopup.BringToFront;
end;

// -------------------------------------------------------
//  Klik na aktivnost → prikazi detalje
// -------------------------------------------------------
procedure TFrameDnevnikMusterije.lbAktivnostiClick(Sender: TObject);
var
  idx: Integer;
begin
  idx := lbAktivnosti.ItemIndex;
  if (idx < 0) or (idx > High(FAktDetalji)) then Exit;
  if FAktDetalji[idx] = '' then Exit;

  PrikaziPopup(
    lbAktivnosti.Items[idx],
    FAktDetalji[idx]
  );
end;

procedure TFrameDnevnikMusterije.lbHranaClick(Sender: TObject);
var
  idx: Integer;
begin
  idx := lbHrana.ItemIndex;
  if (idx < 0) or (idx > High(FHranaDetalji)) then Exit;
  if FHranaDetalji[idx] = '' then Exit;

  PrikaziPopup(
    lbHrana.Items[idx],
    FHranaDetalji[idx]
  );
end;

procedure TFrameDnevnikMusterije.lbOstaloClick(Sender: TObject);
var
  idx: Integer;
begin
  idx := lbOstalo.ItemIndex;
  if (idx < 0) or (idx > High(FOstaloDetalji)) then Exit;
  if FOstaloDetalji[idx] = '' then Exit;

  PrikaziPopup(
    lbOstalo.Items[idx],
    FOstaloDetalji[idx]
  );
end;

// Zatvori popup klikom na X ili na pozadinu
procedure TFrameDnevnikMusterije.rectPopupZatvoriClick(Sender: TObject);
begin
  rectPopup.Visible := False;
end;

procedure TFrameDnevnikMusterije.rectPopupClick(Sender: TObject);
begin
  rectPopup.Visible := False;
end;

// -------------------------------------------------------
//  AKTIVNOSTI
// -------------------------------------------------------
procedure TFrameDnevnikMusterije.UcitajAktivnosti;
var
  Q: TFDQuery;
  Item: TListBoxItem;
  sDetalj: string;
  i: Integer;
begin
  lbAktivnosti.BeginUpdate;
  try
    lbAktivnosti.Clear;
    FAktDetalji := nil;
    if SelectedPetID <= 0 then Exit;

    Q := TFDQuery.Create(nil);
    try
      Q.Connection := DB;
      Q.SQL.Text :=
        'SELECT da.Vrsta_aktivnosti, da.VremeOd, da.VremeDo, ' +
        '       da.DuzinaTrajanja, da.ProcenaPonasanja, da.Komentar, ' +
        '       da.StatusAktivnosti, z.Ime, z.Prezime ' +
        'FROM DNEVNA_AKTIVNOST da ' +
        'LEFT JOIN ZAPOSLENI z ON z.Sifra_zaposlenog = da.Sifra_zaposlenog ' +
        'WHERE da.Sifra_ljubimca = :pid AND da.Kategorija = ''Aktivnosti'' ' +
        'ORDER BY da.VremeOd DESC';
      Q.ParamByName('pid').AsInteger := SelectedPetID;
      Q.Open;

      Q.FetchAll; // RecordCount broji samo ucitane redove (prvih 50) bez ovoga
      lblBrojAkt.Text := '(' + IntToStr(Q.RecordCount) + ' zapisa)';

      if Q.IsEmpty then
      begin
        Item := TListBoxItem.Create(lbAktivnosti);
        Item.Text := 'Nema zabelezenih aktivnosti';
        lbAktivnosti.AddObject(Item);
      end
      else
      begin
        i := 0;
        while not Q.Eof do
        begin
          Item := TListBoxItem.Create(lbAktivnosti);
          Item.Text := Q.FieldByName('Vrsta_aktivnosti').AsString;
          // Datum je dodat jer lista obuhvata vise dana
          Item.ItemData.Detail :=
            FormatDateTime('dd.mm. hh:nn', Q.FieldByName('VremeOd').AsDateTime) +
            ' - ' +
            FormatDateTime('hh:nn', Q.FieldByName('VremeDo').AsDateTime) +
            '  (' + Q.FieldByName('DuzinaTrajanja').AsString + ')';
          lbAktivnosti.AddObject(Item);

          // Sacuvaj pune detalje za popup
          if Q.FieldByName('StatusAktivnosti').AsString = 'U toku' then
          begin
            sDetalj :=
              'Vrsta: ' + Q.FieldByName('Vrsta_aktivnosti').AsString + #13#10 +
              'Pocelo: ' +
              FormatDateTime('hh:nn', Q.FieldByName('VremeOd').AsDateTime) + #13#10 +
              'Predvidjeno zavrsetka: ' +
              FormatDateTime('hh:nn', Q.FieldByName('VremeDo').AsDateTime) + #13#10 +
              'Status: U toku';
          end
          else
          begin
            sDetalj :=
              'Vrsta: ' + Q.FieldByName('Vrsta_aktivnosti').AsString + #13#10 +
              'Od: ' + FormatDateTime('hh:nn', Q.FieldByName('VremeOd').AsDateTime) +
              '  Do: ' + FormatDateTime('hh:nn', Q.FieldByName('VremeDo').AsDateTime) + #13#10 +
              'Trajanje: ' + Q.FieldByName('DuzinaTrajanja').AsString + #13#10 +
              'Status: Zavrseno';

            if Q.FieldByName('ProcenaPonasanja').AsString <> '' then
              sDetalj := sDetalj + #13#10 +
                'Procena: ' + Q.FieldByName('ProcenaPonasanja').AsString;

            if Q.FieldByName('Komentar').AsString <> '' then
              sDetalj := sDetalj + #13#10 +
                'Komentar: ' + Q.FieldByName('Komentar').AsString;
          end;

          sDetalj := sDetalj + #13#10 +
            'Zaposleni: ' + Q.FieldByName('Ime').AsString +
            ' ' + Q.FieldByName('Prezime').AsString;

          SetLength(FAktDetalji, i + 1);
          FAktDetalji[i] := sDetalj;

          Inc(i);
          Q.Next;
        end;
      end;
    finally
      Q.Free;
    end;
  finally
    lbAktivnosti.EndUpdate;
  end;
end;

// -------------------------------------------------------
//  HRANA
// -------------------------------------------------------
procedure TFrameDnevnikMusterije.UcitajHranu;
var
  Q: TFDQuery;
  Item: TListBoxItem;
  sDetalj: string;
  i: Integer;
begin
  lbHrana.BeginUpdate;
  try
    lbHrana.Clear;
    FHranaDetalji := nil;
    if SelectedPetID <= 0 then Exit;

    Q := TFDQuery.Create(nil);
    try
      Q.Connection := DB;
      Q.SQL.Text :=
        'SELECT da.Vrsta_aktivnosti, da.VremeOd, da.VremeObroka, da.Kolicina, ' +
        '       da.Komentar, z.Ime, z.Prezime ' +
        'FROM DNEVNA_AKTIVNOST da ' +
        'LEFT JOIN ZAPOSLENI z ON z.Sifra_zaposlenog = da.Sifra_zaposlenog ' +
        'WHERE da.Sifra_ljubimca = :pid AND da.Kategorija = ''Hrana'' ' +
        'ORDER BY da.VremeOd DESC';
      Q.ParamByName('pid').AsInteger := SelectedPetID;
      Q.Open;

      Q.FetchAll; // RecordCount broji samo ucitane redove (prvih 50) bez ovoga
      lblBrojHrana.Text := '(' + IntToStr(Q.RecordCount) + ' obroka)';

      if Q.IsEmpty then
      begin
        Item := TListBoxItem.Create(lbHrana);
        Item.Text := 'Nema zabelezenih obroka';
        lbHrana.AddObject(Item);
      end
      else
      begin
        i := 0;
        while not Q.Eof do
        begin
          Item := TListBoxItem.Create(lbHrana);
          Item.Text := Q.FieldByName('Vrsta_aktivnosti').AsString;
          Item.ItemData.Detail :=
            FormatDateTime('dd.mm.', Q.FieldByName('VremeOd').AsDateTime) + ' ' +
            Q.FieldByName('VremeObroka').AsString +
            '  |  ' + Q.FieldByName('Kolicina').AsString;
          lbHrana.AddObject(Item);

          sDetalj :=
            'Vrsta hrane: ' + Q.FieldByName('Vrsta_aktivnosti').AsString + #13#10 +
            'Vreme obroka: ' + Q.FieldByName('VremeObroka').AsString + #13#10 +
            'Kolicina: ' + Q.FieldByName('Kolicina').AsString;

          if Q.FieldByName('Komentar').AsString <> '' then
            sDetalj := sDetalj + #13#10 +
              'Komentar: ' + Q.FieldByName('Komentar').AsString;

          sDetalj := sDetalj + #13#10 +
            'Zaposleni: ' + Q.FieldByName('Ime').AsString +
            ' ' + Q.FieldByName('Prezime').AsString;

          SetLength(FHranaDetalji, i + 1);
          FHranaDetalji[i] := sDetalj;

          Inc(i);
          Q.Next;
        end;
      end;
    finally
      Q.Free;
    end;
  finally
    lbHrana.EndUpdate;
  end;
end;

// -------------------------------------------------------
//  OSTALO
// -------------------------------------------------------
procedure TFrameDnevnikMusterije.UcitajOstalo;
var
  Q: TFDQuery;
  Item: TListBoxItem;
  sDetalj: string;
  i: Integer;
begin
  lbOstalo.BeginUpdate;
  try
    lbOstalo.Clear;
    FOstaloDetalji := nil;
    if SelectedPetID <= 0 then Exit;

    Q := TFDQuery.Create(nil);
    try
      Q.Connection := DB;
      Q.SQL.Text :=
        'SELECT da.Vrsta_aktivnosti, da.VremeOd, da.StatusOstalo, ' +
        '       da.Komentar, z.Ime, z.Prezime ' +
        'FROM DNEVNA_AKTIVNOST da ' +
        'LEFT JOIN ZAPOSLENI z ON z.Sifra_zaposlenog = da.Sifra_zaposlenog ' +
        'WHERE da.Sifra_ljubimca = :pid AND da.Kategorija = ''Ostalo'' ' +
        'ORDER BY da.VremeOd DESC';
      Q.ParamByName('pid').AsInteger := SelectedPetID;
      Q.Open;

      Q.FetchAll; // RecordCount broji samo ucitane redove (prvih 50) bez ovoga
      lblBrojOstalo.Text := '(' + IntToStr(Q.RecordCount) + ' zapisa)';

      if Q.IsEmpty then
      begin
        Item := TListBoxItem.Create(lbOstalo);
        Item.Text := 'Nema zabelezenih aktivnosti';
        lbOstalo.AddObject(Item);
      end
      else
      begin
        i := 0;
        while not Q.Eof do
        begin
          Item := TListBoxItem.Create(lbOstalo);
          Item.Text := Q.FieldByName('Vrsta_aktivnosti').AsString;
          Item.ItemData.Detail :=
            'Vreme: ' +
            FormatDateTime('dd.mm. hh:nn', Q.FieldByName('VremeOd').AsDateTime);
          lbOstalo.AddObject(Item);

          sDetalj :=
            'Vrsta: ' + Q.FieldByName('Vrsta_aktivnosti').AsString + #13#10 +
            'Vreme: ' +
            FormatDateTime('hh:nn', Q.FieldByName('VremeOd').AsDateTime);

          if Q.FieldByName('StatusOstalo').AsString <> '' then
            sDetalj := sDetalj + #13#10 +
              'Status: ' + Q.FieldByName('StatusOstalo').AsString;

          if Q.FieldByName('Komentar').AsString <> '' then
            sDetalj := sDetalj + #13#10 +
              'Komentar: ' + Q.FieldByName('Komentar').AsString;

          sDetalj := sDetalj + #13#10 +
            'Zaposleni: ' + Q.FieldByName('Ime').AsString +
            ' ' + Q.FieldByName('Prezime').AsString;

          SetLength(FOstaloDetalji, i + 1);
          FOstaloDetalji[i] := sDetalj;

          Inc(i);
          Q.Next;
        end;
      end;
    finally
      Q.Free;
    end;
  finally
    lbOstalo.EndUpdate;
  end;
end;

// -------------------------------------------------------
//  Boravak u pansionu i racun do sada (po cenovniku)
// -------------------------------------------------------
procedure TFrameDnevnikMusterije.PrikaziBoravak;
var
  Q: TFDQuery;
  dUkupno: Double;
  sTekst: string;
begin
  lblBoravak.Text := '';
  if SelectedPetID <= 0 then Exit;

  ObracunBoravka(SelectedPetID, dUkupno);

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := DB;
    Q.SQL.Text :=
      'SELECT COALESCE(Status, ''Aktivan'') AS StatusLj, DatumPrijema, DatumOdjave ' +
      'FROM pets WHERE id = :p';
    Q.ParamByName('p').AsInteger := SelectedPetID;
    Q.Open;
    if Q.IsEmpty then Exit;

    if Q.FieldByName('StatusLj').AsString = 'Odjavljen' then
    begin
      sTekst := 'Odjavljen';
      if not Q.FieldByName('DatumOdjave').IsNull then
        sTekst := sTekst + ' ' +
          FormatDateTime('dd.mm.yyyy.', Q.FieldByName('DatumOdjave').AsDateTime);
      sTekst := sTekst + '  ·  ukupno: ';
    end
    else
    begin
      sTekst := 'U pansionu';
      if not Q.FieldByName('DatumPrijema').IsNull then
        sTekst := sTekst + ' od ' +
          FormatDateTime('dd.mm.yyyy.', Q.FieldByName('DatumPrijema').AsDateTime);
      sTekst := sTekst + '  ·  racun do sada: ';
    end;
    lblBoravak.Text := sTekst + FormatFloat('#,##0.##', dUkupno) + ' RSD';
  finally
    Q.Free;
  end;
end;

procedure TFrameDnevnikMusterije.lblBoravakClick(Sender: TObject);
var
  dUkupno: Double;
begin
  if SelectedPetID <= 0 then Exit;
  if (cbLjubimci.ItemIndex < 0) or (cbLjubimci.ItemIndex >= cbLjubimci.Count) then Exit;
  PrikaziPopup('Racun: ' + cbLjubimci.Items[cbLjubimci.ItemIndex],
    ObracunBoravka(SelectedPetID, dUkupno));
end;

procedure TFrameDnevnikMusterije.rectNazadClick(Sender: TObject);
begin
  if LoggedInRole = 'MUSTERIJA' then
  begin
    LoggedInUserID     := 0;
    LoggedInRole       := '';
    LoggedInUsername   := '';
    LoggedInImePrezime := '';
    SelectedPetID      := 0;
    TNavFrames.GoLogin;
  end
  else
    TNavFrames.Back;
end;

end.
