unit fraOsoblje;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.DateUtils,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Layouts, FMX.Objects, FMX.ListBox, FMX.Edit,
  FMX.Memo, FMX.Memo.Types, FMX.ScrollBox,
  FireDAC.Comp.Client, uUserStore, uNavFrames;

type
  TFrameOsoblje = class(TFrame, IFrameRefresh)
    // --- ZAGLAVLJE ---
    layHeader: TLayout;
    lblNaslov: TLabel;
    lblImeZaposlenog: TLabel;
    rectOdjava: TRectangle;
    lblDostupnost: TLabel;

    // --- LJUBIMCI ---
    lbLjubimci: TListBox;

    // --- AKTIVNOST U TOKU ---
    rectUToku: TRectangle;
    lblUToku: TLabel;

    // --- POPUP U TOKU ---
    rectPopupUToku: TRectangle;
    lblPopupAktNaslov: TLabel;
    lblPopupAktVreme: TLabel;
    lblPopupAktStatus: TLabel;
    edtVremeZavrsetka: TEdit;
    // Komentar i procena se unose tek po zavrsetku aktivnosti
    lblKomentarZavrsetka: TLabel;
    memoKomentarZavrsetka: TMemo;
    lblProcenaZavrsetka: TLabel;
    edtProcenaZavrsetka: TEdit;

    // --- PLAN ---
    lblPlanTitle: TLabel;

    rectAktivnosti: TRectangle;
    lblAktivnosti: TLabel;
    lblAktivnostiSub: TLabel;
    rectAktivnostiBtn: TRectangle;
    rectPregledAktBtn: TRectangle;
    lblPregledAkt: TLabel;

    rectHrana: TRectangle;
    lblHrana: TLabel;
    lblHranaSub: TLabel;
    rectHranaBtn: TRectangle;
    rectPregledHranaBtn: TRectangle;
    lblPregledHrana: TLabel;

    rectOstalo: TRectangle;
    lblOstalo: TLabel;
    lblOstaloSub: TLabel;
    rectOstaloBtn: TRectangle;
    rectPregledOstaloBtn: TRectangle;
    lblPregledOstalo: TLabel;

    procedure Loaded; override;
    procedure Show; override;
    procedure rectUTokuClick(Sender: TObject);
    procedure rectZavrsiBtnClick(Sender: TObject);
    procedure rectPopupUTokuZatvoriClick(Sender: TObject);
    procedure rectOdjavaClick(Sender: TObject);
    procedure rectAktivnostiBtnClick(Sender: TObject);
    procedure rectPregledAktBtnClick(Sender: TObject);
    procedure rectHranaBtnClick(Sender: TObject);
    procedure rectPregledHranaBtnClick(Sender: TObject);
    procedure rectOstaloBtnClick(Sender: TObject);
    procedure rectPregledOstaloBtnClick(Sender: TObject);
    procedure lbLjubimciClick(Sender: TObject);
    procedure lblImeZaposlenogClick(Sender: TObject);

  private
    FPetIDs: TArray<Integer>;  // ranije array[0..19] - 21. ljubimac je pisao van niza
    FPetCount: Integer;
    FCurrentActivityID: Integer;
    procedure UcitajLjubimce;
    procedure AzurirajBrojeve;
  public
    procedure RefreshView;  // IFrameRefresh - poziva navigacija pri povratku
  end;

implementation

{$R *.fmx}
uses fraAktivnosti, fraHrana, fraOstaloUnos, fraDnevnikMusterije;

procedure TFrameOsoblje.UcitajLjubimce;
var
  Q: TFDQuery;
  Item: TListBoxItem;
  blobBytes: TBytes;
  Stream: TMemoryStream;
  imgPet: TImage;
  layText: TLayout;
  lblName, lblSpecies, lblOwner: TLabel;
  bImaSliku: Boolean;
  rectBezSlike: TRectangle;
  lblSlovo: TLabel;
begin
  lbLjubimci.BeginUpdate;
  try
    lbLjubimci.Clear;
    FPetCount := 0;
    FPetIDs := nil;

    Q := TFDQuery.Create(nil);
    try
      Q.Connection := DB;
      Q.SQL.Text :=
        'SELECT p.id, p.name, p.breed, p.species, p.age, p.image_blob, ' +
        '       p.Lokacija, p.Alergije, m.Ime, m.Prezime ' +
        'FROM pets p ' +
        'LEFT JOIN MUSTERIJA m ON m.Sifra_musterije = p.Sifra_musterije ' +
        // Odjavljeni ljubimci nisu vise u pansionu - za njih se nista ne unosi
        'WHERE COALESCE(p.Status, ''Aktivan'') <> ''Odjavljen'' ' +
        'ORDER BY p.name';
      Q.Open;

      while not Q.Eof do
      begin
        SetLength(FPetIDs, FPetCount + 1);
        FPetIDs[FPetCount] := Q.FieldByName('id').AsInteger;

        Item := TListBoxItem.Create(lbLjubimci);
        Item.Text := ''; // sprecava crtanje teksta iza custom kontrola

        // --- Slika (levo, 68px) ---
        imgPet := TImage.Create(Item);
        imgPet.Parent := Item;
        imgPet.Align := TAlignLayout.Left;
        imgPet.Margins.Left   := 6;
        imgPet.Margins.Top    := 6;
        imgPet.Margins.Bottom := 6;
        imgPet.Margins.Right  := 6;
        imgPet.Size.Width := 68;
        imgPet.WrapMode   := TImageWrapMode.Fit;
        imgPet.HitTest    := False;

        // Slika iz baze (vlasnik je postavlja preko web stranice). Ako je nema,
        // prikazuje se sivo polje sa prvim slovom imena - isto kao na sajtu.
        bImaSliku := False;
        blobBytes := Q.FieldByName('image_blob').AsBytes;
        if Length(blobBytes) > 0 then
        begin
          Stream := TMemoryStream.Create;
          try
            try
              Stream.WriteBuffer(blobBytes[0], Length(blobBytes));
              Stream.Position := 0;
              imgPet.Bitmap.LoadFromStream(Stream);
              bImaSliku := True;
            except
              bImaSliku := False; // ostecena slika ne sme da obori listu
            end;
          finally
            Stream.Free;
          end;
        end;

        if not bImaSliku then
        begin
          rectBezSlike := TRectangle.Create(imgPet);
          rectBezSlike.Parent := imgPet;
          rectBezSlike.Align := TAlignLayout.Client;
          rectBezSlike.Fill.Color := $FFE7E2D6;   // ista boja kao na sajtu
          rectBezSlike.Stroke.Kind := TBrushKind.None;
          rectBezSlike.XRadius := 8;
          rectBezSlike.YRadius := 8;
          rectBezSlike.HitTest := False;

          lblSlovo := TLabel.Create(rectBezSlike);
          lblSlovo.Parent := rectBezSlike;
          lblSlovo.Align := TAlignLayout.Client;
          lblSlovo.StyledSettings := [];          // inace stil prepise font i boju
          lblSlovo.TextSettings.Font.Size := 28;
          lblSlovo.TextSettings.Font.Style := [TFontStyle.fsBold];
          lblSlovo.TextSettings.FontColor := $FFA39C8B;
          lblSlovo.TextSettings.HorzAlign := TTextAlign.Center;
          lblSlovo.TextSettings.VertAlign := TTextAlign.Center;
          lblSlovo.Text := AnsiUpperCase(Copy(Trim(Q.FieldByName('name').AsString), 1, 1));
          lblSlovo.HitTest := False;
        end;

        // --- Layout za tekst (desno) ---
        layText := TLayout.Create(Item);
        layText.Parent := Item;
        layText.Align := TAlignLayout.Client;
        layText.Padding.Left   := 4;
        layText.Padding.Top    := 8;
        layText.Padding.Bottom := 6;
        layText.HitTest := False;

        // Ime ljubimca (vece, bold)
        lblName := TLabel.Create(Item);
        lblName.Parent := layText;
        lblName.Align  := TAlignLayout.Top;
        lblName.Height := 22;
        lblName.Text   := Q.FieldByName('name').AsString;
        lblName.StyledSettings := [];
        lblName.TextSettings.Font.Size  := 14;
        lblName.TextSettings.Font.Style := [TFontStyle.fsBold];
        lblName.HitTest := False;

        // Vrsta · Rasa · Starost
        lblSpecies := TLabel.Create(Item);
        lblSpecies.Parent := layText;
        lblSpecies.Align  := TAlignLayout.Top;
        lblSpecies.Height := 19;
        lblSpecies.Text   :=
          Q.FieldByName('species').AsString + '  ·  ' +
          Q.FieldByName('breed').AsString   + '  ·  ' +
          Q.FieldByName('age').AsString;
        lblSpecies.StyledSettings := [];
        lblSpecies.TextSettings.Font.Size := 11;
        lblSpecies.HitTest := False;

        // Vlasnik · Boks
        lblOwner := TLabel.Create(Item);
        lblOwner.Parent := layText;
        lblOwner.Align  := TAlignLayout.Top;
        lblOwner.Height := 17;
        lblOwner.Text   :=
          Q.FieldByName('Ime').AsString + ' ' +
          Q.FieldByName('Prezime').AsString + '  ·  Boks: ' +
          Q.FieldByName('Lokacija').AsString;
        if Trim(Q.FieldByName('Alergije').AsString) <> '' then
          lblOwner.Text := lblOwner.Text + '  ·  Alergije: ' +
            Q.FieldByName('Alergije').AsString;
        lblOwner.StyledSettings := [];
        lblOwner.TextSettings.Font.Size := 10;
        lblOwner.HitTest := False;

        lbLjubimci.AddObject(Item);
        Inc(FPetCount);
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    lbLjubimci.EndUpdate;
  end;

  if lbLjubimci.Count > 0 then
  begin
    lbLjubimci.ItemIndex := 0;
    ActivePetIndex := 0;
    SelectedPetID  := FPetIDs[0];
  end;
end;

procedure TFrameOsoblje.Loaded;
begin
  inherited;
  lblImeZaposlenog.Text := LoggedInImePrezime + '  ·  promeni lozinku';
  lblImeZaposlenog.Width := 215;
  UcitajLjubimce;
  AzurirajBrojeve;
end;

procedure TFrameOsoblje.AzurirajBrojeve;
var
  Q: TFDQuery;
  nAkt, nHrana, nOst: Integer;
  sAktivnost: string;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := DB;

    // --- Brojevi unesenih po kategoriji danas (samo ako je ljubimac izabran) ---
    if SelectedPetID > 0 then
    begin
      Q.SQL.Text :=
        'SELECT COUNT(*) FROM DNEVNA_AKTIVNOST ' +
        'WHERE Sifra_ljubimca = :pid AND Kategorija = :kat ' +
        'AND VremeOd >= :d0 AND VremeOd < :d1';
      Q.ParamByName('pid').AsInteger := SelectedPetID;
      Q.ParamByName('d0').AsDateTime := Trunc(Now);
      Q.ParamByName('d1').AsDateTime := Trunc(Now) + 1;

      Q.ParamByName('kat').AsString := 'Aktivnosti';
      Q.Open; nAkt   := Q.Fields[0].AsInteger; Q.Close;

      Q.ParamByName('kat').AsString := 'Hrana';
      Q.Open; nHrana := Q.Fields[0].AsInteger; Q.Close;

      Q.ParamByName('kat').AsString := 'Ostalo';
      Q.Open; nOst   := Q.Fields[0].AsInteger; Q.Close;

      lblAktivnostiSub.Text := 'Uneseno danas: ' + IntToStr(nAkt);
      lblHranaSub.Text      := 'Uneseno danas: ' + IntToStr(nHrana);
      lblOstaloSub.Text     := 'Uneseno danas: ' + IntToStr(nOst);
    end;

    // --- Status zaposlenog: zauzet ako ima aktivnost 'U toku' ---
    // Zavisi od zaposlenog, NE od izabranog ljubimca, pa se uvek racuna.
    // Bez COUNT(*) - dohvati poslednju 'U toku' aktivnost i proveri IsEmpty.
    Q.SQL.Text :=
      'SELECT Vrsta_aktivnosti, VremeOd ' +
      'FROM DNEVNA_AKTIVNOST ' +
      'WHERE Sifra_zaposlenog = :zap ' +
      'AND StatusAktivnosti = ''U toku'' ' +
      'ORDER BY VremeOd DESC LIMIT 1';
    Q.ParamByName('zap').AsInteger := LoggedInUserID;
    Q.Open;

    if not Q.IsEmpty then
    begin
      sAktivnost := Q.FieldByName('Vrsta_aktivnosti').AsString;
      lblUToku.Text := 'U toku: ' + sAktivnost + '  (od ' +
        FormatDateTime('hh:nn', Q.FieldByName('VremeOd').AsDateTime) + ')';
      rectUToku.Visible := True;

      lblDostupnost.Text := #$25CF' Zauzet';
      lblDostupnost.TextSettings.FontColor := TAlphaColors.Red;
    end
    else
    begin
      rectUToku.Visible := False;
      lblDostupnost.Text := #$25CF' Dostupan';
      lblDostupnost.TextSettings.FontColor := TAlphaColors.Green;
    end;
    Q.Close;

  finally
    Q.Free;
  end;
end;

// IFrameRefresh - navigacija ovo poziva svaki put kad ekran osoblja
// ponovo postane vidljiv (npr. povratak sa unosa aktivnosti).
procedure TFrameOsoblje.RefreshView;
begin
  AzurirajBrojeve;
end;

procedure TFrameOsoblje.lbLjubimciClick(Sender: TObject);
begin
  if (lbLjubimci.ItemIndex < 0) or
     (lbLjubimci.ItemIndex >= FPetCount) then Exit;
  ActivePetIndex := lbLjubimci.ItemIndex;
  SelectedPetID  := FPetIDs[lbLjubimci.ItemIndex];
  AzurirajBrojeve;
end;

procedure TFrameOsoblje.rectAktivnostiBtnClick(Sender: TObject);
begin
  if SelectedPetID <= 0 then
  begin
    ShowMessage('Izaberite ljubimca sa liste!');
    Exit;
  end;
  TNavFrames.Go(TFrameAktivnosti.Create(nil));
end;

procedure TFrameOsoblje.rectPregledAktBtnClick(Sender: TObject);
begin
  if SelectedPetID <= 0 then
  begin
    ShowMessage('Izaberite ljubimca sa liste!');
    Exit;
  end;
  TNavFrames.Go(TFrameDnevnikMusterije.Create(nil));
end;

procedure TFrameOsoblje.rectHranaBtnClick(Sender: TObject);
begin
  if SelectedPetID <= 0 then
  begin
    ShowMessage('Izaberite ljubimca sa liste!');
    Exit;
  end;
  TNavFrames.Go(TFrameHrana.Create(nil));
end;

procedure TFrameOsoblje.rectPregledHranaBtnClick(Sender: TObject);
begin
  if SelectedPetID <= 0 then
  begin
    ShowMessage('Izaberite ljubimca sa liste!');
    Exit;
  end;
  TNavFrames.Go(TFrameDnevnikMusterije.Create(nil));
end;

procedure TFrameOsoblje.rectOstaloBtnClick(Sender: TObject);
begin
  if SelectedPetID <= 0 then
  begin
    ShowMessage('Izaberite ljubimca sa liste!');
    Exit;
  end;
  TNavFrames.Go(TFrameOstaloUnos.Create(nil));
end;

procedure TFrameOsoblje.rectPregledOstaloBtnClick(Sender: TObject);
begin
  if SelectedPetID <= 0 then
  begin
    ShowMessage('Izaberite ljubimca sa liste!');
    Exit;
  end;
  TNavFrames.Go(TFrameDnevnikMusterije.Create(nil));
end;

// -------------------------------------------------------
//  Klik na zuti banner "U toku" → otvori popup
// -------------------------------------------------------
procedure TFrameOsoblje.rectUTokuClick(Sender: TObject);
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := DB;
    Q.SQL.Text :=
      'SELECT Sifra_aktivnosti, Vrsta_aktivnosti, VremeOd, VremeDo ' +
      'FROM DNEVNA_AKTIVNOST ' +
      'WHERE Sifra_zaposlenog = :zap ' +
      'AND StatusAktivnosti = ''U toku'' ' +
      'ORDER BY VremeOd DESC LIMIT 1';
    Q.ParamByName('zap').AsInteger := LoggedInUserID;
    Q.Open;

    if Q.IsEmpty then
    begin
      rectUToku.Visible := False;
      Exit;
    end;

    FCurrentActivityID     := Q.FieldByName('Sifra_aktivnosti').AsInteger;
    lblPopupAktNaslov.Text := Q.FieldByName('Vrsta_aktivnosti').AsString;
    // Dva reda: pocetno i predvidjeno vreme
    lblPopupAktVreme.Text  :=
      'Pocelo: ' + FormatDateTime('hh:nn', Q.FieldByName('VremeOd').AsDateTime) +
      #13#10 +
      'Predvidjeno zavrsetka: ' +
      FormatDateTime('hh:nn', Q.FieldByName('VremeDo').AsDateTime);
    lblPopupAktStatus.Text := 'Status: U toku';
    // Polje za stvarno vreme - prepopunjeno predvidjenim
    edtVremeZavrsetka.Text := FormatDateTime('hh:nn',
      Q.FieldByName('VremeDo').AsDateTime);
    memoKomentarZavrsetka.Lines.Clear;
    edtProcenaZavrsetka.Text := '';

    rectPopupUToku.Visible := True;
    rectPopupUToku.BringToFront;
  finally
    Q.Free;
  end;
end;

// -------------------------------------------------------
//  Klik "Zavrsi aktivnost" u popupu
// -------------------------------------------------------
procedure TFrameOsoblje.rectZavrsiBtnClick(Sender: TObject);
var
  Q: TFDQuery;
  dtOd, dtDo, tKraj: TDateTime;
  nMinuta: Int64;
  sTrajanje: string;
  parts: TArray<string>;
  nH, nM: Integer;
begin
  parts := Trim(edtVremeZavrsetka.Text).Split([':']);
  if (Length(parts) < 2) or
     not TryStrToInt(Trim(parts[0]), nH) or
     not TryStrToInt(Trim(parts[1]), nM) or
     (nH < 0) or (nH > 23) or (nM < 0) or (nM > 59) then
  begin
    ShowMessage('Pogresno vreme! Format: hh:nn (npr. 11:30)');
    Exit;
  end;
  tKraj := EncodeTime(nH, nM, 0, 0);

  Q := TFDQuery.Create(nil);
  try
    try
      Q.Connection := DB;

      // Uzmi VremeOd radi trajanja
      Q.SQL.Text :=
        'SELECT VremeOd FROM DNEVNA_AKTIVNOST WHERE Sifra_aktivnosti = :id';
      Q.ParamByName('id').AsInteger := FCurrentActivityID;
      Q.Open;
      if not Q.IsEmpty then
      begin
        dtOd := Q.FieldByName('VremeOd').AsDateTime;
        // Kraj se racuna od dana kada je aktivnost POCELA (ranije od danasnjeg dana,
        // pa je aktivnost zapoceta juce dobijala pogresno trajanje).
        dtDo := Trunc(dtOd) + tKraj;
        if dtDo < dtOd then
          dtDo := dtDo + 1;
        nMinuta := MinutesBetween(dtDo, dtOd);
        if nMinuta < 60 then
          sTrajanje := IntToStr(nMinuta) + ' min'
        else
          sTrajanje := IntToStr(nMinuta div 60) + 'h ' +
                       IntToStr(nMinuta mod 60) + 'min';
      end
      else
      begin
        dtDo := Trunc(Now) + tKraj;
        sTrajanje := '0 min';
      end;
      Q.Close;

      // Komentar i procena se upisuju sada, kad se zna kako je aktivnost prosla.
      // Prazno polje ostaje NULL u bazi.
      Q.SQL.Text :=
        'UPDATE DNEVNA_AKTIVNOST SET ' +
        '  VremeDo = :do_, ' +
        '  DuzinaTrajanja = :traj, ' +
        '  StatusAktivnosti = ''Zavrseno'', ' +
        '  Komentar = NULLIF(:kom, ''''), ' +
        '  ProcenaPonasanja = NULLIF(:proc, '''') ' +
        'WHERE Sifra_aktivnosti = :id';
      Q.ParamByName('do_').AsDateTime  := dtDo;
      Q.ParamByName('traj').AsString   := sTrajanje;
      Q.ParamByName('kom').AsString    := Trim(memoKomentarZavrsetka.Text);
      Q.ParamByName('proc').AsString   := Trim(edtProcenaZavrsetka.Text);
      Q.ParamByName('id').AsInteger    := FCurrentActivityID;
      Q.ExecSQL;

      rectPopupUToku.Visible := False;
      FCurrentActivityID := 0;
      AzurirajBrojeve;
      ShowMessage('Aktivnost zavrsena! Trajanje: ' + sTrajanje);
    except
      on E: Exception do
        ShowMessage('Greska: ' + E.Message);
    end;
  finally
    Q.Free;
  end;
end;

// -------------------------------------------------------
//  Zatvori popup (klik na pozadinu ili "Zatvori")
// -------------------------------------------------------
procedure TFrameOsoblje.rectPopupUTokuZatvoriClick(Sender: TObject);
begin
  rectPopupUToku.Visible := False;
end;

procedure TFrameOsoblje.rectOdjavaClick(Sender: TObject);
begin
  LoggedInUserID     := 0;
  LoggedInRole       := '';
  LoggedInUsername   := '';
  LoggedInImePrezime := '';
  SelectedPetID      := 0;
  TNavFrames.GoLogin;
end;

procedure TFrameOsoblje.lblImeZaposlenogClick(Sender: TObject);
begin
  PromeniLozinkuZaposlenog(LoggedInUserID);
end;

procedure TFrameOsoblje.Show;
begin
  inherited;
  AzurirajBrojeve;
end;

end.
