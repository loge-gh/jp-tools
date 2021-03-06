﻿program AnkiToEdict;
{
Parses a tab-separated Anki export, strips HTML tags according to a set of rules
and converts to EDICT-compatible dictionary.

Note that while compatible, this does not give you the full extent of EDICT
features (grammar markers etc).
}

{$APPTYPE CONSOLE}

{$R *.res}

uses
  SysUtils, Classes, Generics.Collections, Generics.Defaults, ConsoleToolbox,
  JWBIO, StrUtils, UniStrUtils, FilenameUtils, EdictWriter, RegularExpressions,
  RegExUtils, FastArray, ExprMatching;

type
  TExpressionCard = record
    base: string;
    deriv: string;
    procedure Reset;
  end;

  TAnkiToEdict = class(TCommandLineApp)
  protected
    Files: TFilenameArray;
    ExprColumn: integer;
    ReadColumn: integer;
    MeaningColumn: integer;
  protected
    OutputFile: string;
    Output: TStreamEncoder;
    Words: TDictionary<string, TExpressionCard>;
    edict1, edict2, jmdict: TArticleWriter;
    procedure Init; override;
    function HandleSwitch(const s: string; var i: integer): boolean; override;
    function HandleParam(const s: string; var i: integer): boolean; override;
    function OnHtmlEntity(const Match: TMatch): string;
  public
    procedure ShowUsage; override;
    procedure Run; override;
    procedure ParseFile(const AFilename: string);
  end;

var
  regex: TRegexLib;

procedure TAnkiToEdict.ShowUsage;
begin
  writeln('Parses a tab-separated Anki export, strips HTML tags according to a '
    +'set of rules and converts to EDICT-compatible dictionary.');
  writeln('Usage: '+ProgramName+' <file1> [file2] ... [-flags]');
  writeln('Flags:');
  writeln('');
  writeln('Input:');
  writeln('  -te <column>      zero-based. Take expressions from this column (default is 0)');
  writeln('  -tr <column>      Take readings from this column (default is 1, if none available set to -1)');
  writeln('  -tm <column>      Take meanings (content) from this column (default is 2, if none available set to -1)');
  writeln('  -es <text>        Expression separator. If specified, multiple ways of writing an expression can be listed.');
  writeln('  -rs <text>        Reading separator. By default expression separator is used.');
  writeln('  -er regex         use this regex (PCRE) to match expressions (return "expr" and "read").');
  writeln('  -rr regex         use this regex (PCRE) to match readings (return "read").');
  writeln('');
  writeln('Output:');
  writeln('  -o output.file    specify output file (otherwise console, EDICT2 only)');
end;

procedure TAnkiToEdict.Init;
begin
  ExprColumn := 0;
  ReadColumn := 1;
  MeaningColumn := 2;
end;

function TAnkiToEdict.HandleSwitch(const s: string; var i: integer): boolean;
begin
  if s='-te' then begin
    if i>=ParamCount then BadUsage('-te needs column number');
    Inc(i);
    ExprColumn := StrToInt(ParamStr(i));
    Result := true
  end else
  if s='-tr' then begin
    if i>=ParamCount then BadUsage('-tr needs column number');
    Inc(i);
    ReadColumn := StrToInt(ParamStr(i));
    Result := true
  end else
  if s='-tm' then begin
    if i>=ParamCount then BadUsage('-tm needs column number');
    Inc(i);
    MeaningColumn := StrToInt(ParamStr(i));
    Result := true
  end else

  if s='-es' then begin
    if i>=ParamCount then BadUsage('-es needs separator value');
    Inc(i);
    SetExpressionSeparator(ParamStr(i)[1]);
    Result := true
  end else
  if s='-rs' then begin
    if i>=ParamCount then BadUsage('-rs needs separator value');
    Inc(i);
    SetReadingSeparator(ParamStr(i)[1]);
    Result := true
  end else
  if s='-er' then begin
    if i>=ParamCount then BadUsage('-er needs regex');
    Inc(i);
    SetExpressionPattern(ParamStr(i));
    Result := true
  end else
  if s='-rr' then begin
    if i>=ParamCount then BadUsage('-rr needs regex');
    Inc(i);
    SetReadingPattern(ParamStr(i));
    Result := true
  end else

  if s='-o' then begin
    if i>=ParamCount then BadUsage('-o requires file name');
    Inc(i);
    OutputFile := ParamStr(i);
    Result := true;
  end else
    Result := inherited;
end;

function TAnkiToEdict.HandleParam(const s: string; var i: integer): boolean;
begin
  AddFile(Files, s);
  Result := true;
end;


procedure TExpressionCard.Reset;
begin
  Self.base := '';
  Self.deriv := '';
end;

function _compareString(const Left, Right: string): Boolean;
begin
  Result := CompareStr(Left, Right)=0;
end;

function _hashString(const Value: string): Integer;
begin
  if Value='' then
    Result := 0
  else
    Result := BobJenkinsHash(Value[1], Length(Value)*SizeOf(Value[1]), 1234567);
end;

procedure TAnkiToEdict.Run;
var i: integer;
begin
  if ParamCount<1 then BadUsage();
  if Length(Files)<1 then BadUsage('Input files not specified');

  regex := TRegexLib.Create;

  if OutputFile<>'' then begin
    edict1 := TEdict1Writer.Create(OutputFile+'.edict1');
    edict2 := TEdict2Writer.Create(OutputFile+'.edict2');
    jmdict := TJmDictWriter.Create(OutputFile+'.jmdict');
  end else begin
    edict1 := nil;
    edict2 := TEdict2Writer.Create(ConsoleWriter);
    jmdict := nil;
  end;

  Files := ExpandFileMasks(Files, true);
  for i := 0 to Length(Files)-1 do
    ParseFile(Files[i]);

  FreeAndNil(edict1);
  FreeAndNil(edict2);
  FreeAndNil(jmdict);
  FreeAndNil(Output);
  FreeAndNil(regex);
end;

{
Deck entry text parsing.
Supports:
  <div>Multiple</div>
  <div>~suru entries</div>
  Even; ~suru inline
  'various' "quotes"
  (brackets)
  [square brackets]
  or combinations thereof
}

type
  TSense = record
    glosses: TArray<string>;
    procedure Reset;
  end;
  PSense = ^TSense;
  TEntry = record
    pat_expr, pat_read: string;
    senses: TArray<TSense>;
    procedure Reset;
  end;
  PEntry = ^TEntry;

procedure TSense.Reset;
begin
  glosses.Reset;
end;

procedure TEntry.Reset;
begin
  pat_expr := '';
  pat_read := '';
  senses.Reset;
end;

//Matches patterns of type: ～権 [～けん]
//True if this was a pattern (basically all CJK + had ~ anywhere) + moves
//pointer to the end of it

function TryEatBasicPattern(var ps: PChar; out pattern: string): boolean;
var pc: PChar;
begin
  Result := false;
  pc := ps;
  while pc^<>#00 do begin
    if not (IsKana(pc^) or IsKanji(pc^) or IsCJKSymbolOrPunctuation(pc^)
      or IsFullWidthCharacter(pc^)) then break;
    if pc^='～' then Result := true;
    Inc(pc);
  end;

  if Result=true then begin
    pattern := StrSub(ps, pc);
    ps := pc;
  end;
end;

function TryEatPattern(var ps: PChar; out expr, read: string): boolean;
var pc: PChar;
begin
  pc := ps;
  Result := TryEatBasicPattern(pc, expr);
  if not Result then exit;

  ps := pc;
  read := '';
  if pc^=#00 then exit; //with true
  if pc^<>' ' then exit(false); //unsupported char in pattern

  Inc(pc);
  if pc^<>'[' then exit; //again, not a continuation of pattern
  if not TryEatBasicPattern(pc, read) then exit;
  if (pc^<>']') then begin
    read := '';
    exit;
  end;
  ps := pc;
end;

//Apply separately to expr and reading
function ApplyPattern(const pattern: string; const data: string): string;
begin
  if pattern='' then
    Result := data
  else
    Result := pattern.Replace('～', data);
end;

//All HTML tags need to be removed/replaced with linear markup before calling,
//htmlentities decoded.
function SplitMeaning(ln: string): TArray<TEntry>;
var ps, pc, pt: PChar;
  entry: PEntry;
  sense: PSense;
  quotes: string; //stack of quotes
  lastQuote: char;
  pat_expr, pat_read: string;

  procedure PushQuote(const c: char);
  begin
    quotes := quotes + c;
    lastQuote := c;
  end;

  procedure PopQuote;
  begin
    delete(quotes, Length(quotes), 1);
    if quotes='' then
      lastQuote := #00
    else
      lastQuote := quotes[Length(quotes)];
  end;

  procedure CommitGloss;
  var text: string;
  begin
    text := Trim(StrSub(ps, pc));
    if text='' then begin
      ps := pc;
      exit;
    end;
    if entry=nil then begin
      entry := PEntry(Result.AddNew);
      entry.Reset;
    end;
    if sense=nil then begin
      sense := PSense(entry.senses.AddNew);
      sense.Reset;
    end;
    sense.glosses.Add(text);
    ps := pc;
  end;

  procedure CommitSense;
  begin
    CommitGloss;
    sense := nil;
  end;

  procedure CommitEntry;
  begin
    CommitSense;
    entry := nil;
  end;

  procedure NewEntry(const pat_expr, pat_read: string);
  begin
    CommitEntry;
    entry := PEntry(Result.AddNew);
    entry.senses.Reset;
    entry.pat_expr := pat_expr;
    entry.pat_read := pat_read;
  end;

begin
  Result.Reset;
  if ln='' then exit;

  entry := nil;
  sense := nil;

  quotes := '';
  lastQuote := #00;

  pc := @ln[1];
  ps := pc;
  while pc^<>#00 do begin
    pt := pc;
    if ((lastQuote='"') and (pc^='"'))
    or ((lastQuote='''') and (pc^=''''))
    or ((lastQuote='(') and (pc^=')'))
    or ((lastQuote='[') and (pc^=']')) then
      PopQuote()
    else
    if (pc^='"') or (pc^='''') or (pc^='(') or (pc^='[') then
      PushQuote(pc^)
    else
    if (lastQuote<>#00) then begin
     //Do nothing
    end else
    if pc^=',' then begin
      CommitGloss;
      Inc(ps);
    end else
    if pc^=';' then begin
      CommitSense;
      Inc(ps);
    end else
    if TryEatPattern(pt, pat_expr, pat_read) then begin
      CommitSense; //with old value of pc
      NewEntry(pat_expr, pat_read);
      pc := pt; //after pattern
      ps := pt;
    end else
    begin
     //Normal char
    end;

    Inc(pc);
  end;

  CommitEntry;
end;



function TAnkiToEdict.OnHtmlEntity(const Match: TMatch): string;
var ent: string;
begin
  if Match.Groups.Count<2 then begin
    Result := Match.Value;
    exit;
  end;
  ent := Match.Groups[1].Value;
  if ent='lt' then Result := '<' else
  if ent='gt' then Result := '>' else
  if ent='amp' then Result := '&' else
  if ent='quot' then Result := '"' else
  if ent='nbsp' then Result := ' ' else
  Result := Match.Value; //not handled
 //Decode more entities here as needed.
end;

//Regex patterns
const
  pHtmlTags = '<[^>]*>';
  pBr = '<br\s*(/?)\s*>';
  pDivContents = '<div>([^<>]*)</div>';
  pHtmlEntity = '&([^;]*);';

procedure TAnkiToEdict.ParseFile(const AFilename: string);
var inp: TStreamDecoder;
  ln, s_expr, s_read, mean: string;
  parts: TStringArray;
  p_expr: TExpressions;
  p_read: TReadings;
  p_mean: TArray<TEntry>;
  ed: TEdictArticle;
  sense: PEdictSenseEntry;
  expr: TExpression;
  read: TReading;
  i, j, k: integer;
begin
  inp := OpenTextFile(AFilename);
  try
    while inp.ReadLn(ln) do begin
      parts := StrSplit(PWideChar(Trim(ln)),#09);
      if Length(parts)<=0 then continue;

      parts := StrSplit(PWideChar(ln),#09);
      if ExprColumn>=Length(parts) then
        continue;
      s_expr := Trim(parts[ExprColumn]);
      if (ReadColumn<0) or (ReadColumn=ExprColumn) or (ReadColumn>=Length(parts)) then
        s_read := ''
      else
        s_read := Trim(parts[ReadColumn]);

      if MeaningColumn>=Length(parts) then
        continue;
      mean := parts[MeaningColumn];
      if mean='' then continue; //sometimes there's no meaning and the card
        //is present for some other reason

      p_expr := ParseExpressions(s_expr, s_read);
      p_read := ExpressionsToReadings(p_expr);

      regex.Replace2(mean, pDivContents, '\1; ');       //  <div>a</div><div>b</div> --> a; b
      regex.Replace2(mean, ';\s*'+pBr+'\*', '; ');      //  a; <br>b -->  a; b
      regex.Replace2(mean, '\s*'+pBr+'\*', '; ');       //  a <br>b -->  a; b
      regex.Replace2(mean, pHtmlEntity, OnHtmlEntity);
      regex.Replace2(mean, pHtmlTags, '');              //  remove all remaining tags

      p_mean := SplitMeaning(mean);
      for i := 0 to p_mean.Count-1 do begin
        ed.Reset;

        for expr in p_expr do
          ed.AddKanji^.k := ApplyPattern(p_mean[i].pat_expr, expr.expr);

        for read in p_read do
          with ed.AddKana^ do begin
            if p_mean[i].pat_read<>'' then
              k := ApplyPattern(p_mean[i].pat_read, read.read)
            else
              k := ApplyPattern(p_mean[i].pat_expr, read.read); //perhaps empty
            AllKanji := Length(read.expressions)=0;
            if not AllKanji then
              for j := 0 to Length(read.expressions)-1 do
                AddKanjiRef(read.expressions[j]);
        end;

        for j := 0 to p_mean[i].Senses.Count-1 do begin
          sense := ed.AddSense;
          for k := 0 to p_mean[i].senses[j].glosses.Count-1 do
            sense.AddGloss(p_mean[i].senses[j].glosses[k]);
        end;

        if edict1<>nil then
          edict1.Print(@ed);
        if edict2<>nil then
          edict2.Print(@ed);
        if jmdict<>nil then
          jmdict.Print(@ed);
      end;
    end;

  finally
    FreeAndNil(inp);
  end;
end;


begin
  RunApp(TAnkiToEdict);
end.
