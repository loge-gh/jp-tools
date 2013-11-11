program YarxiConvert;
{$APPTYPE CONSOLE}
{ Reads Yarxi database format and generates various things out of it.
 Requires sqlite3.dll in the same folder.
 Requires sqlite/sqlite3ds to compile }

uses
  SysUtils,
  UniStrUtils,
  ConsoleToolbox,
  JWBIO,
  Yarxi in 'Yarxi.pas';

type
  TYarxiConvert = class(TCommandLineApp)
  protected
    Command: string;
    Yarxi: TYarxiDB;
    Output: TStreamEncoder;
    function HandleSwitch(const s: string; var i: integer): boolean; override;
    function HandleParam(const s: string; var i: integer): boolean; override;
  public
    procedure ShowUsage; override;
    procedure Run; override;
    procedure RunKanji;
    procedure RunTango;
  end;

procedure TYarxiConvert.ShowUsage;
begin
  writeln('Usage: '+ProgramName);
end;

function TYarxiConvert.HandleSwitch(const s: string; var i: integer): boolean;
begin
  Result := inherited;
end;

function TYarxiConvert.HandleParam(const s: string; var i: integer): boolean;
begin
  Command := s;
  Result := true;
end;

procedure TYarxiConvert.Run;
begin
  Yarxi := TYarxiDB.Create('yarxi.db');
  Yarxi.KanaTran.LoadFromFile('yarxi.kcs');

  Output := ConsoleWriter();

  if Command='kanji' then
    RunKanji
  else
  if (Command='words') or (Command='tango') then
    RunTango
  else
    BadUsage('Invalid command: '+Command);

  FreeAndNil(Output);
  FreeAndNil(Yarxi);
end;

procedure TYarxiConvert.RunKanji;
var k: TKanjiRecord;
begin
  Yarxi.ParseKanji;
  writeln(ErrOutput, IntToStr(Length(Yarxi.Kanji))+' kanji read.');

  for k in Yarxi.Kanji do
    Output.WriteLn(
      SepJoin(k.RusNicks, '/') + #09
        + k.JoinOns + #09 + Yarxi.KanaTran.RomajiToKana('K'+k.JoinOns(' '), []) + #09
        + k.KunYomi + #09 + Yarxi.KanaTran.RomajiToKana('H'+k.KunYomi, []) + #09
        + k.Russian
    );
end;

procedure TYarxiConvert.RunTango;
var k: TTangoRecord;
begin
  Yarxi.ParseTango;
  writeln(ErrOutput, IntToStr(Length(Yarxi.Tango))+' tango read.');

  for k in Yarxi.Tango do
    Output.WriteLn(k.Kana + #09 + k.Reading + #09 + k.Russian);
end;

begin
  RunApp(TYarxiConvert);
end.