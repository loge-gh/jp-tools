﻿program JRDic;
{$APPTYPE CONSOLE}
{
Утилиты для работы с JRDic/web.
}

{$DEFINE NOWAKAN}
{ Отключить функции программы, требующие при компиляции модулей из Вакана }

{$IF Defined(DCC) and Defined(MSWINDOWS)}
  {$DEFINE DB_ADO}
{$ELSE}
  //FreePascal's SQLdb
  {$DEFINE DB_SQLDB}
{$IFEND}

{$IFDEF FPC}
  {$DEFINE NOWAKAN}
{$ENDIF}

uses
 {$IFDEF UNIX}cwstring,{$ENDIF} //Enables FreePascal string assignment-conversion
  SysUtils,
  Classes,
  Variants,
  Db,
  {$IFDEF DB_ADO}ActiveX, AdoDb,{$ENDIF}
  {$IFDEF DB_SQLDB}sqldb, mysql55conn,{$ENDIF}
  {$IFNDEF NOWAKAN}
  JWBStrings,
  JWBDic,
  {$ENDIF}
  EdictWriter,
  StreamUtils;

type
  EBadUsage = class(Exception)
  end;

procedure BadUsage(msg: UnicodeString);
begin
  raise EBadUsage.Create(msg);
end;

procedure PrintUsage;
begin
  writeln('Usage: ');
  writeln('  '+ExtractFileName(paramstr(0))+'<command>');
  writeln('Supported commands:');
  writeln('  export <filename> = export dictionary to EDICT formats');
 {$IFNDEF NOWAKAN}
  writeln('  autoread <EDICT> = automatically add readings from this EDICT dictionary');
 {$ENDIF}
 {$IFDEF DEBUG}
  writeln('Debug commands:');
  writeln('  export-test <filename> = export some test records in EDICT formats');
 {$ENDIF}
end;

var
  Command: UnicodeString;
  NeedDb: boolean;
  Verbose: boolean;

  ExportParams: record
    Filename: string;
  end;

 {$IFNDEF NOWAKAN}
  AutoreadParams: record
    DictFilename: string;
  end;
 {$ENDIF}

procedure ParseCommandLine;
var i: integer;
  s: string;
begin
  Command := '';
  NeedDb := false;
  Verbose := false;

 //Parse
  i := 1;
  while i<=ParamCount() do begin
    s := ParamStr(i);
    if Length(s)<=0 then continue;

   //Param
    if s[1]='-' then begin
      s := AnsiLowerCase(s);
      if s='-verbose' then
        Verbose := true
      else
        BadUsage('Invalid param: "'+s+'"');

    end else

   //Command
    if Command='' then begin
      Command := AnsiLowerCase(s);

      if (Command='export')
      {$IFDEF DEBUG}or (Command='export-test'){$ENDIF}
      then begin
        FillChar(ExportParams, sizeof(ExportParams), 0);
        NeedDb := Command<>'export-test';
      end else
     {$IFNDEF NOWAKAN}
      if Command='autoread' then begin
        FillChar(AutoreadParams, sizeof(AutoreadParams), 0);
      end else
     {$ENDIF}
        BadUsage('Invalid command: "'+s+'"');

    end else

   //Non-command non-option params (filename list etc)
    begin
      if (Command='export')
     {$IFDEF DEBUG}or (Command='export-test'){$ENDIF}
      then begin
        if ExportParams.Filename='' then
          ExportParams.Filename := ParamStr(i)
        else
          BadUsage('Invalid export param: "'+s+'"');
      end else
     {$IFNDEF NOWAKAN}
      if Command='autoread' then begin
        if AutoreadParams.DictFilename='' then
          AutoreadParams.DictFilename := ParamStr(i)
        else
          BadUsage('Invalid autoread param: "'+s+'"');
      end else
     {$ENDIF}
        BadUsage('Invalid param: "'+s+'"');

    end;

    Inc(i);
  end; //of ParamStr enumeration

 //Check that post-parsing conditions are met (non-conflicting options etc)
  if Command='' then
    BadUsage('You have to specify a command');
  if (Command='export')
  {$IFDEF DEBUG}or (Command='export-test'){$ENDIF}
  then begin
    if ExportParams.Filename='' then
      BadUsage('export requires output filename');
  end;
 {$IFNDEF NOWAKAN}
  if Command='autoread' then begin
    if AutoreadParams.DictFilename='' then
      BadUsage('autoread requires input dictionary');
  end;
 {$ENDIF}
end;


var
  Config: TStringList;

  Db: TCustomConnection;
 {$IFDEF DB_SQLDB}
  DbTransaction: TSQLTransaction; //SQLdb requires this
 {$ENDIF}

  tblPrefix: string;
 //Database table names, escaped if needed
  tbl_Words: string;
  tbl_Tls: string;

procedure SetupDb;
var
 {$IFDEF DB_ADO}
  AdoDb: TAdoConnection;
 {$ENDIF}
 {$IFDEF DB_SQLDB}
  MysqlDb: TMySQL55Connection;
 {$ENDIF}
begin
  if not NeedDb then exit;

  writeln('Connecting to DB...');
 {$IFDEF DB_ADO}
  AdoDb := TAdoConnection.Create(nil);
  AdoDb.ConnectionString := Config.Values['ConnectionString'];
  if AdoDb.ConnectionString='' then
  AdoDb.ConnectionString := Format('Provider=MSDASQL;Driver=%s;Server=%s;'
    +'Database=%s;User=%s;Password=%s;Option=3;',
    [Config.Values['OdbcDriver'],
     Config.Values['Hostname'],
     Config.Values['DatabaseName'],
     Config.Values['Username'],
     Config.Values['Password']]);
  Db := AdoDb;
 {$ENDIF}
 {$IFDEF DB_SQLDB}
  MysqlDb := TMysql55Connection.Create(nil);
  MysqlDb.HostName := Config.Values['Hostname'];
  MysqlDb.DatabaseName := Config.Values['DatabaseName'];
  MysqlDb.UserName := Config.Values['Username'];
  MysqlDb.Password := Config.Values['Password'];
  Db := MysqlDb;
 {$ENDIF}
  Db.Open();
  writeln('Connection succeeded.');
 {$IFDEF DB_SQLDB}
  DbTransaction := TSQLTransaction.Create(nil);
  DbTransaction.Database := TDatabase(Db);
  DbTransaction.StartTransaction;
  writeln('Transaction started.');
  MysqlDb.ExecuteDirect('SET CHARACTER SET `utf8`');
  MysqlDb.ExecuteDirect('SET NAMES `utf8`');
 {$ENDIF}

  tblPrefix := Config.Values['TablePrefix'];
  tbl_Words := '`'+tblPrefix+'words`';
  tbl_Tls := '`'+tblPrefix+'tls`';
end;

procedure FreeDb;
begin
  FreeAndNil(Db);
end;

{ Some DB backends require us to wrap everything in transaction,
 so call this after you make changes to the DB. }
procedure CommitDb;
begin
 {$IFDEF DB_SQLDB}
  writeln('Commiting...');
  DbTransaction.Commit;
  DbTransaction.StartTransaction; //new one
 {$ENDIF}
 //ADO does not need this as we don't use transactions at this time
end;

procedure repl(var s:UnicodeString;const sub,rep:UnicodeString);
var i_pos: integer;
begin
  i_pos := pos(sub,s);
  while i_pos>0 do begin
    s:=copy(s,1,i_pos-1)+rep+copy(s,i_pos+length(sub),length(s)-i_pos+1-length(sub));
    i_pos := pos(sub,s);
  end;
end;

{
В запросах можно использовать некоторые спец. слова (см. ниже) - они будут заменены
на имена таблиц.
}
function Query(const cmd: UnicodeString; readonly: boolean = true): TDataSet;
var tmp: UnicodeString;
 {$IFDEF DB_ADO}
  Query: TADOQuery;
 {$ENDIF}
 {$IFDEF DB_SQLDB}
  Query: TSQLQuery;
 {$ENDIF}
begin
  tmp := cmd;
  repl(tmp, '{$words}', tbl_Words);
  repl(tmp, '{$tls}', tbl_Tls);
 {$IFDEF DEBUG}
  if Verbose then
    writeln('Query: '+cmd);
 {$ENDIF}

 {$IFDEF DB_ADO}
  Query := TAdoQuery.Create(nil);
  Query.Connection := TAdoConnection(Db);
  Query.CursorLocation := clUseServer;
  Query.CursorType := ctOpenForwardOnly;
  if readonly then
    Query.LockType := ltReadOnly
  else
    Query.LockType := ltUnspecified;
 {$ENDIF}
 {$IFDEF DB_SQLDB}
  Query := TSQLQuery.Create(nil);
  Query.Database := TDatabase(Db);
  Query.Transaction := DbTransaction;
 {$ENDIF}
  Query.SQL.Text := tmp;
  Query.Open;
  Result := Query;
end;

{$IFDEF DEBUG}
procedure Run_ExportTest(const OutputFile: string);
var art: TEdictArticle;
  wri_jm: TJmDictWriter;
  wri_2: TEdict2Writer;
  wri_1: TEdict1Writer;

  procedure AddRec(kanji: array of string; kana: array of string; senses: array of string);
  var i: integer;
  begin
    art.Reset;
    for i := Low(kanji) to High(kanji) do
      art.AddKanji^.k := kanji[i];
    for i := Low(kana) to High(kana) do
      with art.AddKana^ do begin
        k := kana[i];
        AllKanji := true;
      end;
    for i := Low(senses) to High(senses) do
      art.AddSense^.AddGloss(senses[i]);
    wri_1.Print(@art);
    wri_2.Print(@art);
    wri_jm.Print(@art);
  end;

begin
  wri_jm := TJmDictWriter.Create(OutputFile+'.jmdict');
  wri_2 := TEdict2Writer.Create(OutputFile+'.edict2');
  wri_1 := TEdict1Writer.Create(OutputFile+'.edict1');

  writeln('Writing some test records to '+OutputFile+'...');
  AddRec(['latin'], ['LATIN'], ['latin word']);
  AddRec(['kyrillic'], ['KYRILLIC'], ['русский текст']);
  AddRec(['どう見ても'], [], ['как ни посмотри', 'с какой стороны ни глянь']);
  AddRec(['気のせい'], ['きのせい'], ['померещилось', 'показалось']);
  AddRec(['電波'], ['でんぱ'], ['электромагнитная волна', 'чокнутый']);
  AddRec(['先が思いやられる'], ['さきがおもいやられる'], ['о дальнейшем и думать не хочется',
    'что будет дальше - подумать страшно', 'страшно себе представить, что будет дальше']);

  FreeAndNil(wri_1);
  FreeAndNil(wri_2);
  FreeAndNil(wri_jm);
end;
{$ENDIF}

procedure Run_Export(const OutputFile: string);
var r: TDataset;
  art: TEdictArticle;
  wri_jm: TJmDictWriter;
  wri_2: TEdict2Writer;
  wri_1: TEdict1Writer;
  LastId, Id: integer;
  TotalLines: integer;
begin
  wri_jm := TJmDictWriter.Create(OutputFile+'.jmdict');
  wri_2 := TEdict2Writer.Create(OutputFile+'.edict2');
  wri_1 := TEdict1Writer.Create(OutputFile+'.edict1');

  art.Reset;
  LastId := -1;
  TotalLines := 0;

  r := Query('SELECT {$words}.id as id, {$words}.word, {$words}.reading, tl, '
    +'is_redirect FROM {$words}, {$tls} '
    +'WHERE {$tls}.word={$words}.id ORDER BY {$words}.id ASC');
  while not r.EOF do begin
    Id := r.Fields[0].Value;
    if LastId<>Id then begin
      if (LastId>0) and (art.senses_used>0) then begin
        wri_jm.Print(@art);
        wri_2.Print(@art);
        wri_1.Print(@art);
      end;
      art.Reset;
      LastId := Id;
      art.AddKanji().k := r.Fields[1].Value;
      if not VarIsNull(r.Fields[2].Value)
      and not (r.Fields[2].Value='') then
        with art.AddKana()^ do begin
          k := r.Fields[2].Value;
          AllKanji := true;
        end;
    end;

    if not boolean(r.Fields[4].Value) then begin
     //Разделения нет, так что все слова регистрируем как glosses одного sense
      if art.senses_used<1 then
        art.AddSense();
      art.senses[0].AddGloss(r.Fields[3].Value);
    end;

    Inc(TotalLines);
    r.Next;
  end;

  if (LastId>0) and (art.senses_used>0) then begin
    wri_jm.Print(@art);
    wri_2.Print(@art);
    wri_1.Print(@art);
  end;


 //Output stats
  writeln('Exported records: '+IntToStr(wri_jm.AddedRecords));
  writeln('Total lines: '+IntToStr(TotalLines));

  FreeAndNil(wri_1);
  FreeAndNil(wri_2);
  FreeAndNil(wri_jm);
end;

{$IFNDEF NOWAKAN}
procedure Run_Autoread(const DictFile: string);
var edict: TJaletDic;
  cdic: TDicLookupCursor;
  r: TDataset;
  kj: string;
begin
  edict:=TJaletDic.Create;
  edict.Offline := false;
  edict.LoadOnDemand := false;
  edict.FillInfo(DictFile);
  edict.Load;
  cdic := edict.NewLookup(mtExactMatch);
  try
    r := Query('SELECT id, word, reading FROM {$words} WHERE reading=""', {readonly=}false);
    while not r.EOF do begin
      kj := r.Fields[1].Value;
      if EvalChars(kj) * [EC_HIRAGANA, EC_KATAKANA, EC_IDG_PUNCTUATION,
        EC_LATIN_HW, EC_LATIN_FW] <> [] then
      begin
        cdic.LookupKanji(kj);
        if cdic.HaveMatch then begin
          r.Fields[2].Value := cdic.GetPhonetic;
          r.UpdateRecord;
        end;
      end;

      r.Next;
    end;
  finally
    FreeAndNil(cdic);
    FreeAndNil(edict);
  end;
end;
{$ENDIF}

//Settings have been loaded already
procedure Run;
begin
 {$IFDEF DB_ADO}
  CoInitialize(nil);
 {$ENDIF}
  Config := TStringList.Create;
  Config.LoadFromFile(ChangeFileExt(ExtractFilename(paramstr(0)), '.cfg'));
  SetupDb;
  try

    if Command = 'export' then
      Run_Export(ExportParams.Filename)
    else
   {$IFNDEF NOWAKAN}
    if Command = 'autoread' then
      Run_Autoread(AutoreadParams.DictFilename)
    else
   {$ENDIF}
   {$IFDEF DEBUG}
    if Command = 'export-test' then
      Run_ExportTest(ExportParams.Filename)
    else
   {$ENDIF}
      BadUsage('Unrecognized command: '+Command);

  finally
    FreeDb;
  end;
end;

begin
  if ParamCount=0 then begin
    PrintUsage;
    exit;
  end;

  try
    ParseCommandLine;
    Run;
  except
    on E: EBadUsage do begin
      writeln('Bad usage. ');
      writeln('  '+E.Message);
      PrintUsage;
    end;
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.

