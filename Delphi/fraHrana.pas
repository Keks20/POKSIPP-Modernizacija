unit fraHrana;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Variants,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs,
  FMX.StdCtrls, FMX.Controls.Presentation, FMX.Layouts, FMX.Objects,
  FMX.Edit, FMX.Memo, FMX.Memo.Types, FMX.ScrollBox, FMX.ListBox,
  FireDAC.Comp.Client, uUserStore, uNavFrames;

type
  TFrameHrana = class(TFrame)


    layHeader: TLayout;
    lblNaslov: TLabel;
    rectNazad: TRectangle;


    rectForma: TRectangle;

    lblVrsta: TLabel;
    cbVrsta: TComboBox;       // izbor vrste hrane iz magacina (RESURS)

    lblVremeObroka: TLabel;
    edtVremeObroka: TEdit;    // npr. "08:30"

    lblKolicina: TLabel;
    edtKolicina: TEdit;       // npr. "280g"

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
    procedure SacuvajHranu;
  end;

implementation

{$R *.fmx}

procedure TFrameHrana.Loaded;
begin
  inherited;
  lblNaslov.Text      := 'Hrana';
  edtVremeObroka.Text := FormatDateTime('hh:nn', Now);
  UcitajResurse;
end;

// Napuni padajuci meni vrstama hrane iz magacina (RESURS)
procedure TFrameHrana.UcitajResurse;
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
        'WHERE lower(Tip_Resursa) LIKE ''%hrana%'' ' +
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
//  ParsujVreme - prihvata hh:nn bez StrToDateTime
// -------------------------------------------------------
function TFrameHrana.ParsujVreme(const AVreme: string;
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


procedure TFrameHrana.SacuvajHranu;
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
    ShowMessage('Izaberite vrstu hrane iz padajuceg menija!');
    Exit;
  end;

  if Trim(edtVremeObroka.Text) = '' then
  begin
    ShowMessage('Unesite vreme obroka!');
    edtVremeObroka.SetFocus;
    Exit;
  end;

  if not ParsujVreme(edtVremeObroka.Text, dtVreme) then
  begin
    ShowMessage('Pogresno vreme obroka!' + #13#10 +
                'Koristite format: hh:nn (npr. 08:30)');
    edtVremeObroka.SetFocus;
    Exit;
  end;

  if Trim(edtKolicina.Text) = '' then
  begin
    ShowMessage('Unesite kolicinu hrane (npr. 280g)!');
    edtKolicina.SetFocus;
    Exit;
  end;

  // --- Vrsta hrane i resurs dolaze direktno iz izbora u meniju (RESURS) ---
  sVrsta   := cbVrsta.Items[cbVrsta.ItemIndex];
  idResurs := FResIDs[cbVrsta.ItemIndex];

  // Kolicina se pretvara u jedinicu resursa: '1,5kg' -> 1500 za 'Suva hrana (g)'.
  // Ranije se uzimao samo prvi ceo broj, pa je '1,5 kg' skidalo 1 g sa zaliha.
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

      idUsluga := 0;
      Q.SQL.Text := 'SELECT Sifra_usluge FROM USLUGA WHERE Naziv = ''Hranjenje'' LIMIT 1';
      Q.Open;
      if not Q.IsEmpty then idUsluga := Q.Fields[0].AsInteger;
      Q.Close;

      // Upis obroka/stavke i umanjenje zaliha idu zajedno: ili oba, ili nijedno.
      DB.StartTransaction;
      try
        // Zalihe se skidaju pre upisa - ako ih nema dovoljno, ne upisuje se nista.
        if not SkiniSaZaliha(idResurs, dUtrosak, sGreska) then
        begin
          DB.Rollback;
          ShowMessage(sGreska);
          Exit;
        end;

        Q.SQL.Text :=
          'INSERT INTO DNEVNA_AKTIVNOST ' +
          '  (Kategorija, Vrsta_aktivnosti, VremeOd, VremeDo, ' +
          '   DuzinaTrajanja, StatusAktivnosti, ' +
          '   VremeObroka, Kolicina, Komentar, ' +
          '   Sifra_usluge, Sifra_resursa, Kolicina_Utroska, ' +
          '   Sifra_zaposlenog, Sifra_ljubimca) ' +
          'VALUES ' +
          '  (:kat, :vrsta, :od, :od, ' +
          '   :traj, :status, ' +
          '   :vobroka, :kol, :kom, ' +
          '   NULLIF(:usl, 0), :res, :utr, ' +  // bez usluge = NULL, ne 0
          '   :zap, :pet)';

        Q.ParamByName('kat').AsString     := 'Hrana';
        Q.ParamByName('vrsta').AsString   := sVrsta;
        Q.ParamByName('od').AsDateTime    := dtVreme;
        Q.ParamByName('traj').AsString    := '0 min';
        Q.ParamByName('status').AsString  := 'Zavrseno';
        Q.ParamByName('vobroka').AsString := Trim(edtVremeObroka.Text);
        Q.ParamByName('kol').AsString     := Trim(edtKolicina.Text);
        Q.ParamByName('kom').AsString     := Trim(memoKomentar.Text);
        Q.ParamByName('usl').AsInteger    := idUsluga;
        Q.ParamByName('res').AsInteger    := idResurs;
        Q.ParamByName('utr').AsFloat      := dUtrosak;
        Q.ParamByName('zap').AsInteger    := LoggedInUserID;
        Q.ParamByName('pet').AsInteger    := SelectedPetID;
        Q.ExecSQL;

        DB.Commit;
      except
        if DB.InTransaction then
          DB.Rollback;
        raise;
      end;

      ShowMessage('Obrok je uspesno zabelezen!');
      TNavFrames.Back;

    except
      on E: Exception do
        ShowMessage('Greska: ' + E.Message);
    end;
  finally
    Q.Free;
  end;
end;

procedure TFrameHrana.rectPotvrdiClick(Sender: TObject);
begin
  SacuvajHranu;
end;

procedure TFrameHrana.rectNazadClick(Sender: TObject);
begin
  TNavFrames.Back;
end;

end.
