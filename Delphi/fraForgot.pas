unit fraForgot;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Layouts,uNavFrames, FMX.Edit, FMX.Objects,
  uUserStore,FireDAC.Comp.Client, FMX.DialogService;

type
  TFrame3 = class(TFrame)
    Layout1: TLayout;
    rectCard: TRectangle;
    edtUsername: TEdit;
    edtPassword: TEdit;
    rectChange: TRectangle;
    Label1: TLabel;
    edtAgain: TEdit;
    Label2: TLabel;
    lbHaveAcc: TLabel;
    lblLogin: TLabel;
    procedure lblLoginClick(Sender: TObject);
    procedure rectChangeClick(Sender: TObject);

  private
    { Private declarations }
  public
    { Public declarations }
  end;

implementation

{$R *.fmx}


procedure TFrame3.lblLoginClick(Sender: TObject);
begin
TNavFrames.Back;
end;



procedure TFrame3.rectChangeClick(Sender: TObject);
var
  identifier, sNova: string;
  Q: TFDQuery;
  idMusterije: Integer;
  sKorIme, sEmail, sTelefon, sPitanje: string;
  bUnetTelefon: Boolean;
begin
  identifier := Trim(edtUsername.Text);

  if identifier = '' then
  begin
    ShowMessage('Unesite korisničko ime, email ili broj telefona');
    Exit;
  end;

  if Trim(edtPassword.Text) = '' then
  begin
    ShowMessage('Unesite novu lozinku');
    Exit;
  end;

  if Trim(edtAgain.Text) = '' then
  begin
    ShowMessage('Ponovite lozinku');
    Exit;
  end;

  if Trim(edtPassword.Text) <> Trim(edtAgain.Text) then
  begin
    ShowMessage('Lozinke se ne poklapaju');
    Exit;
  end;

  sNova := Trim(edtPassword.Text);

  Q := TFDQuery.Create(nil);
  try
    // Proveri u MUSTERIJA tabeli (po korisničkom imenu, emailu ili telefonu)
    Q.Connection := DB;
    Q.SQL.Text :=
      'SELECT Sifra_musterije, KorisnickoIme, COALESCE(Email, '''') AS Email, ' +
      '       COALESCE(Telefon_Hitno, '''') AS Telefon ' +
      'FROM MUSTERIJA ' +
      'WHERE lower(KorisnickoIme) = lower(:x) ' +
      '   OR lower(COALESCE(Email, '''')) = lower(:x) ' +
      '   OR Telefon_Hitno = :x';
    Q.ParamByName('x').AsString := identifier;
    Q.Open;

    if Q.IsEmpty then
    begin
      ShowMessage('Ne postoji korisnik sa tim podacima.' + #13#10 +
                  'Unesite korisničko ime, email ili telefon.');
      Exit;
    end;

    // Vise naloga moze da ima isti telefon - tada ne menjamo nista.
    Q.FetchAll;
    if Q.RecordCount > 1 then
    begin
      ShowMessage('Pronađeno je više naloga sa tim podatkom.' + #13#10 +
                  'Unesite korisničko ime ili email.');
      Exit;
    end;

    idMusterije := Q.FieldByName('Sifra_musterije').AsInteger;
    sKorIme     := Q.FieldByName('KorisnickoIme').AsString;
    sEmail      := Q.FieldByName('Email').AsString;
    sTelefon    := Q.FieldByName('Telefon').AsString;
  finally
    Q.Free;
  end;

  // Druga provera identiteta: ranije je bilo dovoljno znati nečije korisničko
  // ime da mu se promeni lozinka. Sada se traži i drugi podatak sa naloga.
  bUnetTelefon := (sTelefon <> '') and (identifier = sTelefon);
  if bUnetTelefon then
    sPitanje := 'Korisničko ime ili email sa naloga'
  else
    sPitanje := 'Broj telefona sa naloga';

  TDialogService.InputQuery('Potvrda identiteta', [sPitanje], [''],
    procedure(const AResult: TModalResult; const AValues: array of string)
    var
      sOdgovor: string;
      bTacno: Boolean;
      Q2: TFDQuery;
    begin
      if (AResult <> mrOk) or (Length(AValues) < 1) then Exit;
      sOdgovor := Trim(AValues[0]);

      if bUnetTelefon then
        bTacno := (sOdgovor <> '') and
          (SameText(sOdgovor, sKorIme) or ((sEmail <> '') and SameText(sOdgovor, sEmail)))
      else
        bTacno := (sTelefon <> '') and (sOdgovor = sTelefon);

      if not bTacno then
      begin
        ShowMessage('Podaci se ne poklapaju sa nalogom. Lozinka nije promenjena.');
        Exit;
      end;

      Q2 := TFDQuery.Create(nil);
      try
        Q2.Connection := DB;
        Q2.SQL.Text :=
          'UPDATE MUSTERIJA SET Lozinka = :p WHERE Sifra_musterije = :id';
        Q2.ParamByName('p').AsString   := HesLozinke(sNova);
        Q2.ParamByName('id').AsInteger := idMusterije;
        Q2.ExecSQL;
      finally
        Q2.Free;
      end;

      ShowMessage('Lozinka je uspešno promenjena!');
      TNavFrames.Back;
    end);
end;

end.
