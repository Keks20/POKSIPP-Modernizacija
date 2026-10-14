program poksi;





{$R *.dres}

uses
  System.StartUpCopy,
  FMX.Forms,
  uUserStore in 'uUserStore.pas',
  frmMain in 'frmMain.pas' {Form5},
  fraWelcome in 'fraWelcome.pas' {Frame1: TFrame},
  fraLogin in 'fraLogin.pas' {Frame2: TFrame},
  fraForgot in 'fraForgot.pas' {Frame3: TFrame},
  fraRegister in 'fraRegister.pas' {Frame4: TFrame},
  uNavFrames in 'uNavFrames.pas',
  uPetModel in 'uPetModel.pas',
  fraOsoblje in 'fraOsoblje.pas' {FrameOsoblje: TFrame},
  fraDnevnikMusterije in 'fraDnevnikMusterije.pas' {FrameDnevnikMusterije: TFrame},
  fraAktivnosti in 'fraAktivnosti.pas' {FrameAktivnosti: TFrame},
  fraHrana in 'fraHrana.pas' {FrameHrana: TFrame},
  fraOstaloUnos in 'fraOstaloUnos.pas' {FrameOstaloUnos: TFrame},
  fraAdmin in 'fraAdmin.pas' {FrameAdmin: TFrame};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm5, Form5);
  Application.Run;
end.
