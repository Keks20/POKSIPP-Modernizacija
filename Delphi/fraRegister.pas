unit fraRegister;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, 
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Layouts,uNavFrames, FMX.Objects, FMX.Edit,
  FireDAC.Comp.Client,uUserStore;

type
  TFrame4 = class(TFrame)
    Layout1: TLayout;
    Layout3: TLayout;
    lblTitle: TLabel;
    rectCard: TRectangle;
    edtUsername: TEdit;
    edtPassword: TEdit;
    edtNumber: TEdit;
    edtEmail: TEdit;
    edtIme: TEdit;
    edtPrezime: TEdit;
    btnRegister: TRectangle;
    Label1: TLabel;
    lblLogin: TLabel;
    lbHaveAcc: TLabel;
    procedure lblLoginClick(Sender: TObject);
    procedure btnRegisterClick(Sender: TObject);

  private
    { Private declarations }
  public
    { Public declarations }
  end;

implementation

{$R *.fmx}



procedure TFrame4.btnRegisterClick(Sender: TObject);
begin
  if Trim(edtUsername.Text) = '' then
  begin
    ShowMessage('Unesite korisničko ime');
    Exit;
  end;

  if Trim(edtEmail.Text) = '' then
  begin
    ShowMessage('Unesite email');
    Exit;
  end;

  if Trim(edtNumber.Text) = '' then
  begin
    ShowMessage('Unesite broj telefona');
    Exit;
  end;

  if Trim(edtPassword.Text) = '' then
  begin
    ShowMessage('Unesite lozinku');
    Exit;
  end;

  if Trim(edtIme.Text) = '' then
  begin
    ShowMessage('Unesite ime');
    Exit;
  end;

  if Trim(edtPrezime.Text) = '' then
  begin
    ShowMessage('Unesite prezime');
    Exit;
  end;

  try
    with TFDQuery.Create(nil) do
    begin
      try
        Connection := DB;

        // Proveri da li je korisničko ime zauzeto - i kod musterija i kod zaposlenih.
        // Ranije se proveravala samo MUSTERIJA, pa je musterija mogla da uzme
        // korisnicko ime 'admin' ili 'osoblje'.
        SQL.Text :=
          'SELECT (SELECT COUNT(*) FROM MUSTERIJA WHERE lower(KorisnickoIme) = lower(:u)) + ' +
          '       (SELECT COUNT(*) FROM ZAPOSLENI WHERE lower(KorisnickoIme) = lower(:u2))';
        ParamByName('u').AsString  := Trim(edtUsername.Text);
        ParamByName('u2').AsString := Trim(edtUsername.Text);
        Open;
        if Fields[0].AsInteger > 0 then
        begin
          Close;
          ShowMessage('Korisničko ime je već zauzeto!');
          Exit;
        end;
        Close;

        // Email mora da bude jedinstven (koristi se za prijavu i promenu lozinke)
        SQL.Text :=
          'SELECT COUNT(*) FROM MUSTERIJA WHERE lower(COALESCE(Email, '''')) = lower(:e)';
        ParamByName('e').AsString := Trim(edtEmail.Text);
        Open;
        if Fields[0].AsInteger > 0 then
        begin
          Close;
          ShowMessage('Nalog sa ovim emailom već postoji!');
          Exit;
        end;
        Close;

        SQL.Text :=
          'INSERT INTO MUSTERIJA ' +
          '  (KorisnickoIme, Lozinka, Telefon_Hitno, Email, Ime, Prezime, Nalog) ' +
          'VALUES (:kor, :loz, :tel, :email, :ime, :prez, :nalog)';

        ParamByName('kor').AsString   := Trim(edtUsername.Text);
        ParamByName('loz').AsString   := HesLozinke(Trim(edtPassword.Text));
        ParamByName('tel').AsString   := Trim(edtNumber.Text);
        ParamByName('email').AsString := Trim(edtEmail.Text);
        ParamByName('ime').AsString   := Trim(edtIme.Text);
        ParamByName('prez').AsString  := Trim(edtPrezime.Text);
        ParamByName('nalog').AsString := 'Standard';

        ExecSQL;
      finally
        Free;
      end;
    end;

    ShowMessage('Uspešna registracija! Možete se prijaviti.');
    TNavFrames.Back;

  except
    on E: Exception do
      ShowMessage('Greška: ' + E.Message);
  end;
end;

procedure TFrame4.lblLoginClick(Sender: TObject);
begin

  TNavFrames.Back;
end;

end.
