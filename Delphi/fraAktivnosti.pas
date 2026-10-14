unit fraAktivnosti;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Variants, System.DateUtils,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs,
  FMX.StdCtrls, FMX.Controls.Presentation, FMX.Layouts, FMX.Objects,
  FMX.Edit, FMX.Memo, FMX.Memo.Types, FMX.ScrollBox,
  FireDAC.Comp.Client, uUserStore, uNavFrames;

type
  TFrameAktivnosti = class(TFrame)
    layHeader: TLayout;
    lblNaslov: TLabel;
    rectNazad: TRectangle;

    scrollForm: TScrollBox;
    rectForma: TRectangle;

    lblVrsta: TLabel;
    edtVrsta: TEdit;

    lblVremeOd: TLabel;
    edtVremeOd: TEdit;

    lblVremeDo: TLabel;
    edtVremeDo: TEdit;

    lblTrajanje: TLabel;
    lblTrajanjeVal: TLabel;

    lblKomentar: TLabel;
    memoKomentar: TMemo;

    lblProcena: TLabel;
    edtProcena: TEdit;

    rectZapocni: TRectangle;
    lblZapocni: TLabel;

    procedure Loaded; override;
    procedure rectZapocniClick(Sender: TObject);
    procedure rectNazadClick(Sender: TObject);
    procedure edtVremeDoExit(Sender: TObject);
    procedure edtVremeOdExit(Sender: TObject);

  private
    FFS: TFormatSettings;
    procedure ZapocniAktivnost;
    procedure IzracunajTrajanje;
    function ParsujVreme(const AVreme: string; out ADT: TDateTime): Boolean;
  end;

implementation

{$R *.fmx}

// Nadji uslugu iz kataloga ciji se naziv pojavljuje u vrsti aktivnosti (OBUHVATA)
function NadjiUslugu(const AVrsta: string): Integer;
var
  Q: TFDQuery;
begin
  Result := 0;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := DB;
    Q.SQL.Text :=
      'SELECT Sifra_usluge FROM USLUGA ' +
      'WHERE instr(lower(:v), lower(Naziv)) > 0 LIMIT 1';
    Q.ParamByName('v').AsString := AVrsta;
    Q.Open;
    if not Q.IsEmpty then Result := Q.Fields[0].AsInteger;
    Q.Close;
  finally
    Q.Free;
  end;
end;

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

// Zapocni aktivnost — cuvaj sa statusom 'U toku', odmah se vrati
procedure TFrameAktivnosti.ZapocniAktivnost;
var
  Q: TFDQuery;
  dtOd, dtDo: TDateTime;
begin
  if Trim(edtVrsta.Text) = '' then
  begin
    ShowMessage('Unesite vrstu aktivnosti!');
    edtVrsta.SetFocus;
    Exit;
  end;

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
        ' DuzinaTrajanja, StatusAktivnosti, ' +
        ' ProcenaPonasanja, Komentar, Sifra_usluge, ' +
        ' Sifra_zaposlenog, Sifra_ljubimca) ' +
        'VALUES ' +
        '(:kat, :vrsta, :od, :vdo, ' +
        ' :traj, :status, :procena, :kom, NULLIF(:usl, 0), :zap, :pet)';  // bez usluge = NULL, ne 0 (strani kljuc u MySQL-u)

      Q.ParamByName('kat').AsString     := 'Aktivnosti';
      Q.ParamByName('vrsta').AsString   := Trim(edtVrsta.Text);
      Q.ParamByName('od').AsDateTime    := dtOd;
      Q.ParamByName('vdo').AsDateTime   := dtDo;
      Q.ParamByName('traj').AsString    := 'U toku';
      Q.ParamByName('status').AsString  := 'U toku';
      Q.ParamByName('procena').AsString := Trim(edtProcena.Text);
      Q.ParamByName('kom').AsString     := Trim(memoKomentar.Text);
      Q.ParamByName('usl').AsInteger    := NadjiUslugu(Trim(edtVrsta.Text));
      Q.ParamByName('zap').AsInteger    := LoggedInUserID;
      Q.ParamByName('pet').AsInteger    := SelectedPetID;
      Q.ExecSQL;

      ShowMessage('Aktivnost je zapoceta! Pracena je na pocetnoj strani.');
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
