unit fraOstaloUnos;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Variants,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs,
  FMX.StdCtrls, FMX.Controls.Presentation, FMX.Layouts, FMX.Objects,
  FMX.Edit, FMX.Memo, FMX.Memo.Types, FMX.ScrollBox, FMX.ListBox,
  FireDAC.Comp.Client, uUserStore, uNavFrames;

type
  TFrameOstaloUnos = class(TFrame)

    layHeader: TLayout;
    lblNaslov: TLabel;
    rectNazad: TRectangle;


    rectForma: TRectangle;

    lblVrsta: TLabel;
    cbVrsta: TComboBox;       // izbor vrste iz magacina (RESURS)

    lblVreme: TLabel;
    edtVreme: TEdit;          // npr. "14:00"

    lblStatus: TLabel;
    edtStatus: TEdit;         // npr. "Dlaka ociscena, nokti sredjeni"

    lblKolicina: TLabel;
    edtKolicina: TEdit;       // npr. "50" (sampon ml) ili "5" (maramice kom)

    lblKomentar: TLabel;
    memoKomentar: TMemo;

    rectPotvrdi: TRectangle;
    lblPotvrdi: TLabel;

    procedure Loaded; override;
    procedure rectPotvrdiClick(Sender: TObject);
    procedure rectNazadClick(Sender: TObject);

  private
    FResIDs: TArray<Integer>;  // Sifra_resursa za svaku stavku menija (bez ogranicenja broja)
    FResCount: Integer;
    function ParsujVreme(const AVreme: string;
      out ADT: TDateTime): Boolean;
    procedure UcitajResurse;
    procedure SacuvajOstalo;
  end;

implementation

{$R *.fmx}

procedure TFrameOstaloUnos.Loaded;
begin
  inherited;
  lblNaslov.Text := 'Ostalo';
  edtVreme.Text  := FormatDateTime('hh:nn', Now);
  UcitajResurse;
end;

// Napuni padajuci meni vrstama iz magacina (RESURS) - sve sem hrane
procedure TFrameOstaloUnos.UcitajResurse;
var
  Q: TFDQuery;
begin
  cbVrsta.Items.BeginUpdate;
  try
    cbVrsta.Items.Clear;
    FResCount := 0;
    FResIDs := nil;
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := DB;
      Q.SQL.Text :=
        'SELECT Sifra_resursa, Tip_Resursa FROM RESURS ' +
        'WHERE lower(Tip_Resursa) NOT LIKE ''%hrana%'' ' +
        'ORDER BY Tip_Resursa';
      Q.Open;
      while not Q.Eof do
      begin
        SetLength(FResIDs, FResCount + 1);
        FResIDs[FResCount] := Q.FieldByName('Sifra_resursa').AsInteger;
        cbVrsta.Items.Add(Q.FieldByName('Tip_Resursa').AsString);
        Inc(FResCount);
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    cbVrsta.Items.EndUpdate;
  end;
  if cbVrsta.Items.Count > 0 then
    cbVrsta.ItemIndex := 0;
end;

// -------------------------------------------------------
//  Isti ParsujVreme kao u fraAktivnosti
//  Prihvata format hh:nn bez StrToDateTime
// -------------------------------------------------------
function TFrameOstaloUnos.ParsujVreme(const AVreme: string;
  out ADT: TDateTime): Boolean;
var
  parts: TArray<string>;
  nH, nM: Integer;
begin
  Result := False;
  parts  := Trim(AVreme).Split([':']);

  if Length(parts) < 2 then Exit;
  if not TryStrToInt(Trim(parts[0]), nH) then Exit;
  if not TryStrToInt(Trim(parts[1]), nM) then Exit;
  if (nH < 0) or (nH > 23) then Exit;
  if (nM < 0) or (nM > 59) then Exit;

  ADT    := Trunc(Now) + EncodeTime(nH, nM, 0, 0);
  Result := True;
end;


procedure TFrameOstaloUnos.SacuvajOstalo;
var
  Q: TFDQuery;
  dtVreme: TDateTime;
  idUsluga, idResurs: Integer;
  dUtrosak: Double;
  sVrsta, sGreska: string;
begin
  // --- Validacija ---
  if (cbVrsta.ItemIndex < 0) or (cbVrsta.ItemIndex >= FResCount) then
  begin
    ShowMessage('Izaberite vrstu iz padajuceg menija!');
    Exit;
  end;

  if Trim(edtVreme.Text) = '' then
  begin
    ShowMessage('Unesite vreme!');
    edtVreme.SetFocus;
    Exit;
  end;

  if not ParsujVreme(edtVreme.Text, dtVreme) then
  begin
    ShowMessage('Pogresno vreme!' + #13#10 +
                'Koristite format: hh:nn (npr. 14:00)');
    edtVreme.SetFocus;
    Exit;
  end;

  if Trim(edtStatus.Text) = '' then
  begin
    ShowMessage('Unesite status (opis obavljenog)!');
    edtStatus.SetFocus;
    Exit;
  end;

  // --- Vrsta i resurs koji se trosi (TROSI) dolaze iz izbora u meniju (RESURS) ---
  sVrsta   := cbVrsta.Items[cbVrsta.ItemIndex];
  idResurs := FResIDs[cbVrsta.ItemIndex];

  // Kolicina koja se skida iz magacina, u jedinici resursa ('0,5l' -> 500 za 'Sampon (ml)').
  // Polje nije obavezno - prazno znaci da se nista ne trosi.
  dUtrosak := 0;
  if Trim(edtKolicina.Text) <> '' then
    if not PretvoriKolicinu(edtKolicina.Text, sVrsta, dUtrosak, sGreska) then
    begin
      ShowMessage(sGreska);
      edtKolicina.SetFocus;
      Exit;
    end;

  // --- Upis u bazu ---
  Q := TFDQuery.Create(nil);
  try
    try
      Q.Connection := DB;

      // Usluga (OBUHVATA) - best effort prema nazivu vrste
      idUsluga := 0;
      Q.SQL.Text := 'SELECT Sifra_usluge FROM USLUGA ' +
        'WHERE instr(lower(:v), lower(Naziv)) > 0 LIMIT 1';
      Q.ParamByName('v').AsString := sVrsta;
      Q.Open;
      if not Q.IsEmpty then idUsluga := Q.Fields[0].AsInteger;
      Q.Close;

      // Upis i umanjenje zaliha idu zajedno: ili oba, ili nijedno.
      DB.StartTransaction;
      try
        // Zalihe se skidaju pre upisa - ako ih nema dovoljno, ne upisuje se nista.
        if (dUtrosak > 0) and not SkiniSaZaliha(idResurs, dUtrosak, sGreska) then
        begin
          DB.Rollback;
          ShowMessage(sGreska);
          Exit;
        end;

        Q.SQL.Text :=
          'INSERT INTO DNEVNA_AKTIVNOST ' +
          '  (Kategorija, Vrsta_aktivnosti, VremeOd, VremeDo, ' +
          '   DuzinaTrajanja, StatusAktivnosti, ' +
          '   StatusOstalo, Komentar, Kolicina, ' +
          '   Sifra_usluge, Sifra_resursa, Kolicina_Utroska, ' +
          '   Sifra_zaposlenog, Sifra_ljubimca) ' +
          'VALUES ' +
          '  (:kat, :vrsta, :od, :od, ' +
          '   :traj, :status, ' +
          '   :stost, :kom, :kol, ' +
          '   NULLIF(:usl, 0), :res, :utr, ' +  // bez usluge = NULL, ne 0
          '   :zap, :pet)';

        Q.ParamByName('kat').AsString    := 'Ostalo';
        Q.ParamByName('vrsta').AsString  := sVrsta;
        Q.ParamByName('od').AsDateTime   := dtVreme;
        Q.ParamByName('traj').AsString   := '0 min';
        Q.ParamByName('status').AsString := 'Zavrseno';
        Q.ParamByName('stost').AsString  := Trim(edtStatus.Text);
        Q.ParamByName('kom').AsString    := Trim(memoKomentar.Text);
        Q.ParamByName('kol').AsString    := Trim(edtKolicina.Text);
        Q.ParamByName('usl').AsInteger   := idUsluga;
        Q.ParamByName('res').AsInteger   := idResurs;
        Q.ParamByName('utr').AsFloat     := dUtrosak;
        Q.ParamByName('zap').AsInteger   := LoggedInUserID;
        Q.ParamByName('pet').AsInteger   := SelectedPetID;
        Q.ExecSQL;

        DB.Commit;
      except
        if DB.InTransaction then
          DB.Rollback;
        raise;
      end;

      ShowMessage('Aktivnost je uspesno zabelezena!');
      TNavFrames.Back;

    except
      on E: Exception do
        ShowMessage('Greska: ' + E.Message);
    end;
  finally
    Q.Free;
  end;
end;

procedure TFrameOstaloUnos.rectPotvrdiClick(Sender: TObject);
begin
  SacuvajOstalo;
end;

procedure TFrameOstaloUnos.rectNazadClick(Sender: TObject);
begin
  TNavFrames.Back;
end;

end.
