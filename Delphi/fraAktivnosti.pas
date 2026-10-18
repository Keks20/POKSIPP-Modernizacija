unit fraAktivnosti;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Variants, System.DateUtils,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs,
  FMX.StdCtrls, FMX.Controls.Presentation, FMX.Layouts, FMX.Objects,
  FMX.Edit, FMX.ListBox,
  FireDAC.Comp.Client, uUserStore, uNavFrames;

type
  TFrameAktivnosti = class(TFrame)
    layHeader: TLayout;
    lblNaslov: TLabel;
    rectNazad: TRectangle;

    scrollForm: TScrollBox;
    rectForma: TRectangle;

    lblVrsta: TLabel;
    cbUsluga: TComboBox;      // usluga iz cenovnika (USLUGA) - od nje zavisi racun

    lblOpis: TLabel;
    edtOpis: TEdit;           // npr. "jutarnja, oko parka" (obavezno samo za "Druga aktivnost")

    lblVremeOd: TLabel;
    edtVremeOd: TEdit;

    lblVremeDo: TLabel;
    edtVremeDo: TEdit;

    lblTrajanje: TLabel;
    lblTrajanjeVal: TLabel;

    lblNapomena: TLabel;

    rectZapocni: TRectangle;
    lblZapocni: TLabel;

    procedure Loaded; override;
    procedure rectZapocniClick(Sender: TObject);
    procedure rectNazadClick(Sender: TObject);
    procedure edtVremeDoExit(Sender: TObject);
    procedure edtVremeOdExit(Sender: TObject);
    procedure cbUslugaChange(Sender: TObject);

  private
    FFS: TFormatSettings;
    FUslugaIDs: TArray<Integer>;  // Sifra_usluge za svaku stavku menija; 0 = druga aktivnost
    procedure UcitajUsluge;
    procedure ZapocniAktivnost;
    procedure IzracunajTrajanje;
    function ParsujVreme(const AVreme: string; out ADT: TDateTime): Boolean;
  end;

implementation

{$R *.fmx}

const
  // Aktivnost koje nema u cenovniku (npr. trening poslusnosti): upisuje se bez usluge,
  // pa se ne naplacuje. Opis je tada obavezan, jer je on jedini naziv aktivnosti.
  DRUGA_AKTIVNOST = 'Druga aktivnost (bez naplate)';

procedure TFrameAktivnosti.Loaded;
begin
  inherited;
  FFS := TFormatSettings.Create;
  FFS.TimeSeparator := ':';
  FFS.ShortTimeFormat := 'hh:nn';
  FFS.LongTimeFormat  := 'hh:nn';

  lblNaslov.Text      := 'Aktivnosti';
  edtVremeOd.Text     := FormatDateTime('hh:nn', Now);
  edtVremeDo.Text     := FormatDateTime('hh:nn', Now);
  lblTrajanjeVal.Text := '0 min';
  UcitajUsluge;
end;

// Napuni padajuci meni uslugama iz cenovnika (USLUGA).
// Ranije se vrsta kucala rukom, a usluga se pogadjala iz teksta: "setnja" bez
// kvacice ili "jutarnja setnja" mogli su da promase uslugu, pa se nije naplacivala.
// Hranjenje se ne nudi - ono se upisuje preko ekrana Hrana.
procedure TFrameAktivnosti.UcitajUsluge;
var
  Q: TFDQuery;
  n: Integer;
begin
  cbUsluga.Items.BeginUpdate;
  try
    cbUsluga.Items.Clear;
    FUslugaIDs := nil;
    n := 0;
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := DB;
      Q.SQL.Text :=
        'SELECT Sifra_usluge, Naziv FROM USLUGA ' +
        'WHERE Naziv <> ''Hranjenje'' ' +
        'ORDER BY Naziv';
      Q.Open;
      while not Q.Eof do
      begin
        SetLength(FUslugaIDs, n + 1);
        FUslugaIDs[n] := Q.FieldByName('Sifra_usluge').AsInteger;
        cbUsluga.Items.Add(Q.FieldByName('Naziv').AsString);
        Inc(n);
        Q.Next;
      end;
    finally
      Q.Free;
    end;

    // Poslednja stavka: aktivnost van cenovnika
    SetLength(FUslugaIDs, n + 1);
    FUslugaIDs[n] := 0;
    cbUsluga.Items.Add(DRUGA_AKTIVNOST);
  finally
    cbUsluga.Items.EndUpdate;
  end;
  cbUsluga.ItemIndex := 0;
  cbUslugaChange(nil);
end;

procedure TFrameAktivnosti.cbUslugaChange(Sender: TObject);
begin
  if (cbUsluga.ItemIndex >= 0) and (cbUsluga.ItemIndex < Length(FUslugaIDs)) and
     (FUslugaIDs[cbUsluga.ItemIndex] = 0) then
  begin
    lblOpis.Text := 'Naziv aktivnosti (obavezno):';
    edtOpis.TextPrompt := 'npr. Trening poslusnosti';
  end
  else
  begin
    lblOpis.Text := 'Opis (nije obavezno):';
    edtOpis.TextPrompt := 'npr. jutarnja, oko parka';
  end;
end;

function TFrameAktivnosti.ParsujVreme(const AVreme: string;
  out ADT: TDateTime): Boolean;
var
  sVreme: string;
  nH, nM: Integer;
  parts: TArray<string>;
begin
  Result := False;
  sVreme := Trim(AVreme);
  parts := sVreme.Split([':']);
  if Length(parts) < 2 then Exit;
  if not TryStrToInt(Trim(parts[0]), nH) then Exit;
  if not TryStrToInt(Trim(parts[1]), nM) then Exit;
  if (nH < 0) or (nH > 23) then Exit;
  if (nM < 0) or (nM > 59) then Exit;
  ADT := Trunc(Now) + EncodeTime(nH, nM, 0, 0);
  Result := True;
end;

procedure TFrameAktivnosti.IzracunajTrajanje;
var
  dtOd, dtDo: TDateTime;
  nMinuta: Int64;
begin
  if not ParsujVreme(edtVremeOd.Text, dtOd) then
  begin
    lblTrajanjeVal.Text := '--';
    Exit;
  end;
  if not ParsujVreme(edtVremeDo.Text, dtDo) then
  begin
    lblTrajanjeVal.Text := '--';
    Exit;
  end;
  if dtDo < dtOd then
    dtDo := dtDo + 1;
  nMinuta := MinutesBetween(dtDo, dtOd);
  if nMinuta = 0 then
    lblTrajanjeVal.Text := '0 min'
  else if nMinuta < 60 then
    lblTrajanjeVal.Text := IntToStr(nMinuta) + ' min'
  else
    lblTrajanjeVal.Text :=
      IntToStr(nMinuta div 60) + 'h ' +
      IntToStr(nMinuta mod 60) + 'min';
end;

procedure TFrameAktivnosti.edtVremeOdExit(Sender: TObject);
begin
  IzracunajTrajanje;
end;

procedure TFrameAktivnosti.edtVremeDoExit(Sender: TObject);
begin
  IzracunajTrajanje;
end;

// Zapocni aktivnost - cuva se sa statusom 'U toku', odmah se vrati.
// Komentar i procena se upisuju tek kad se aktivnost zavrsi (popup na ekranu Osoblje),
// jer se tek tada zna kako je proslo.
procedure TFrameAktivnosti.ZapocniAktivnost;
var
  Q: TFDQuery;
  dtOd, dtDo: TDateTime;
  idUsluga: Integer;
  sOpis, sVrsta: string;
begin
  if (cbUsluga.ItemIndex < 0) or (cbUsluga.ItemIndex >= Length(FUslugaIDs)) then
  begin
    ShowMessage('Izaberite aktivnost iz padajuceg menija!');
    Exit;
  end;

  idUsluga := FUslugaIDs[cbUsluga.ItemIndex];
  sOpis    := Trim(edtOpis.Text);

  if idUsluga = 0 then
  begin
    if sOpis = '' then
    begin
      ShowMessage('Unesite naziv aktivnosti (npr. Trening poslusnosti)!');
      edtOpis.SetFocus;
      Exit;
    end;
    sVrsta := sOpis;
  end
  else if sOpis = '' then
    sVrsta := cbUsluga.Items[cbUsluga.ItemIndex]
  else
    sVrsta := cbUsluga.Items[cbUsluga.ItemIndex] + ' - ' + sOpis;

  // Kolona Vrsta_aktivnosti je VARCHAR(100)
  sVrsta := Copy(sVrsta, 1, 100);

  if not ParsujVreme(edtVremeOd.Text, dtOd) then
  begin
    ShowMessage('Pogresno vreme pocetka!' + #13#10 +
                'Koristite format: hh:nn (npr. 09:00)');
    edtVremeOd.SetFocus;
    Exit;
  end;

  if not ParsujVreme(edtVremeDo.Text, dtDo) then
  begin
    ShowMessage('Pogresno predvidjeno vreme zavrsetka!' + #13#10 +
                'Koristite format: hh:nn (npr. 11:30)');
    edtVremeDo.SetFocus;
    Exit;
  end;

  // Aktivnost preko ponoci (npr. 23:00 - 01:00) zavrsava se sledeceg dana.
  if dtDo < dtOd then
    dtDo := dtDo + 1;

  Q := TFDQuery.Create(nil);
  try
    try
      Q.Connection := DB;

      // Radnik moze da ima samo jednu aktivnost "U toku". Ranije je nova aktivnost
      // mogla da se zapocne pored stare, a stara je zauvek ostajala "U toku"
      // (i radnik je kod administratora stalno bio "Zauzet").
      Q.SQL.Text :=
        'SELECT Vrsta_aktivnosti FROM DNEVNA_AKTIVNOST ' +
        'WHERE Sifra_zaposlenog = :zap AND StatusAktivnosti = ''U toku'' ' +
        'ORDER BY VremeOd DESC LIMIT 1';
      Q.ParamByName('zap').AsInteger := LoggedInUserID;
      Q.Open;
      if not Q.IsEmpty then
      begin
        ShowMessage('Vec imate aktivnost u toku: ' +
          Q.FieldByName('Vrsta_aktivnosti').AsString + #13#10 +
          'Zavrsite je na pocetnoj strani (zuti baner) pa zapocnite novu.');
        Q.Close;
        Exit;
      end;
      Q.Close;

      Q.SQL.Text :=
        'INSERT INTO DNEVNA_AKTIVNOST ' +
        '(Kategorija, Vrsta_aktivnosti, VremeOd, VremeDo, ' +
        ' DuzinaTrajanja, StatusAktivnosti, Sifra_usluge, ' +
        ' Sifra_zaposlenog, Sifra_ljubimca) ' +
        'VALUES ' +
        '(:kat, :vrsta, :od, :vdo, ' +
        ' :traj, :status, NULLIF(:usl, 0), :zap, :pet)';  // bez usluge = NULL, ne 0 (strani kljuc u MySQL-u)

      Q.ParamByName('kat').AsString     := 'Aktivnosti';
      Q.ParamByName('vrsta').AsString   := sVrsta;
      Q.ParamByName('od').AsDateTime    := dtOd;
      Q.ParamByName('vdo').AsDateTime   := dtDo;
      Q.ParamByName('traj').AsString    := 'U toku';
      Q.ParamByName('status').AsString  := 'U toku';
      Q.ParamByName('usl').AsInteger    := idUsluga;
      Q.ParamByName('zap').AsInteger    := LoggedInUserID;
      Q.ParamByName('pet').AsInteger    := SelectedPetID;
      Q.ExecSQL;

      ShowMessage('Aktivnost je zapoceta! Pracena je na pocetnoj strani.' + #13#10 +
                  'Komentar i procenu upisujete kad je zavrsite.');
      TNavFrames.Back;
    except
      on E: Exception do
        ShowMessage('Greska: ' + E.Message);
    end;
  finally
    Q.Free;
  end;
end;

procedure TFrameAktivnosti.rectZapocniClick(Sender: TObject);
begin
  ZapocniAktivnost;
end;

procedure TFrameAktivnosti.rectNazadClick(Sender: TObject);
begin
  TNavFrames.Back;
end;

end.
