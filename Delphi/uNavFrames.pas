unit uNavFrames;

interface

uses
  System.Generics.Collections,System.SysUtils,System.Classes,
  FMX.Controls, FMX.Forms, FMX.Layouts,FMX.Types,Winapi.Windows;

type
  // Frejmovi koji treba da se osveze kad postanu vidljivi kroz navigaciju
  // (npr. ekran osoblja koji racuna brojeve i status "U toku") implementiraju ovo.
  IFrameRefresh = interface
    ['{4E7A1C90-3B2D-4F18-9A6E-7C5D0F1B2A33}']
    procedure RefreshView;
  end;

  TNavFrames = class
  private
    class var FStack: TStack<TFrame>;
    class var FHost: TLayout;
    class var FCurrent: TFrame;
    class var FCache: TDictionary<TClass, TFrame>;
    class procedure ClearHost;
    class procedure RefreshCurrent;
    class procedure OslobodiKasnije(F: TFrame);
  public
    class constructor Create;
    class destructor Destroy;

    class procedure GoCached(AFrameClass: TClass; AOwner: TComponent);
    class procedure Init(AHost: TLayout);
    class procedure Go(ANext: TFrame);
    class procedure Back;
    class procedure GoLogin;
  end;


implementation
uses fraLogin;
class procedure TNavFrames.GoLogin;
var
  F: TFrame;
begin
  // Posle odjave praznimo istoriju ekrana: ekrani prethodnog korisnika
  // ne ostaju u memoriji i stek ne raste sa svakom prijavom.
  while FStack.Count > 0 do
  begin
    F := FStack.Pop;
    if not FCache.ContainsValue(F) then
      F.Free;
  end;

  if FCurrent <> nil then
  begin
    FCurrent.Visible := False;
    FCurrent.Parent := nil;
    OslobodiKasnije(FCurrent);
    FCurrent := nil;
  end;

  Go(TFrame2.Create(nil));
end;

// Ekran se oslobadja tek kad se zavrsi klik koji je pokrenuo navigaciju
// (ne smemo da unistimo objekat dok se izvrsava njegov dogadjaj).
class procedure TNavFrames.OslobodiKasnije(F: TFrame);
begin
  if (F = nil) or FCache.ContainsValue(F) then Exit;
  TThread.ForceQueue(nil,
    procedure
    begin
      F.Free;
    end);
end;
type
  TFrameClass = class of TFrame;
class constructor TNavFrames.Create;
begin
  FStack := TStack<TFrame>.Create;
  FCache := TDictionary<TClass, TFrame>.Create;
end;

class destructor TNavFrames.Destroy;
var
  P: TPair<TClass, TFrame>;
begin
  for P in FCache do
  begin
    P.Value.Parent := nil;
    P.Value.Free;
  end;

  FCache.Free;
  FStack.Free;
end;

class procedure TNavFrames.Init(AHost: TLayout);
begin
  FHost := AHost;
end;

class procedure TNavFrames.Go(ANext: TFrame);
begin
  if (FHost = nil) or (ANext = nil) then Exit;


  if FCurrent <> nil then
  begin
    FCurrent.Visible := False;
    FCurrent.Parent := nil;
    if (FCurrent <> nil) and (FCurrent <> ANext) then
    begin
    FCurrent.Visible := False;
    FStack.Push(FCurrent);
    end;
    OutputDebugString(PChar('Stack=' + FStack.Count.ToString));
  end;


  FCurrent := ANext;
  ClearHost;
  FCurrent.Parent := FHost;
  FCurrent.Align := TAlignLayout.Client;
  FCurrent.Visible := True;
  FCurrent.BringToFront;
  RefreshCurrent;
end;

// Pozovi RefreshView na trenutnom frejmu ako ga podrzava (npr. ekran osoblja).
// Tako se brojevi i status "U toku" osveze pri svakom povratku na ekran.
class procedure TNavFrames.RefreshCurrent;
var
  R: IFrameRefresh;
begin
  if (FCurrent <> nil) and Supports(FCurrent, IFrameRefresh, R) then
    R.RefreshView;
end;

class procedure TNavFrames.ClearHost;
var
  i: Integer;
begin
  if FHost = nil then Exit;

  // Gasi samo frejmove; pozadina (bgRect) i ostali fiksni elementi ostaju vidljivi
  for i := 0 to FHost.ControlsCount - 1 do
    if FHost.Controls[i] is TFrame then
      FHost.Controls[i].Visible := False;
end;

class procedure TNavFrames.GoCached(AFrameClass: TClass; AOwner: TComponent);
var
  F: TFrame;
begin
  if (FHost = nil) or (AFrameClass = nil) then Exit;

  if not FCache.TryGetValue(AFrameClass, F) then
  begin
    F := TFrameClass(AFrameClass).Create(nil);
    F.Name := 'fr_' + AFrameClass.ClassName;
    FCache.Add(AFrameClass, F);
  end;

  Go(F);
end;

class procedure TNavFrames.Back;
var
  Prev: TFrame;
begin
  if (FHost = nil) or (FStack.Count = 0) then Exit;


  if FCurrent <> nil then
  begin
    FCurrent.Visible := False;
    FCurrent.Parent := nil;
    // Ekran sa kog se vracamo vise ne treba - ranije je ostajao u memoriji zauvek.
    OslobodiKasnije(FCurrent);
  end;


  Prev := FStack.Pop;
  FCurrent := Prev;
  ClearHost;
  FCurrent.Parent := FHost;
  FCurrent.Align := TAlignLayout.Client;
  FCurrent.Visible := True;
  FCurrent.BringToFront;
  RefreshCurrent;
end;

end.
