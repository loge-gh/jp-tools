﻿program WarodaiConvert;
{$APPTYPE CONSOLE}
{
Зависимости:
  libiconv2.dll
  TPerlRegEx
}

//Look into english EDICT for markers to known words. Slow.
{$DEFINE ENMARKERS}

//Считаем число ссылок <a href=>, и различные виды слов, им предшествующий
//{$DEFINE COUNT_HREFS}

uses
  SysUtils,
  Classes,
  Windows,
  UniStrUtils,
  StreamUtils,
  iconv,
  Warodai in 'Warodai.pas',
  WakanDic in 'WakanDic.pas',
  WarodaiMarkers in 'WarodaiMarkers.pas',
  WarodaiHeader in 'WarodaiHeader.pas',
  WarodaiBody in 'WarodaiBody.pas',
  WarodaiTemplates in 'WarodaiTemplates.pas',
  EdictWriter in 'EdictWriter.pas',
  WcUtils in 'WcUtils.pas',
  WcExceptions in 'WcExceptions.pas',
  EdictConverter in 'EdictConverter.pas',
  PerlRegExUtils in 'PerlRegExUtils.pas',
  WarodaiXrefs in 'WarodaiXrefs.pas';

{
Заметки по реализации.
1. Каны в полях "перевод" быть не должно. Из описания EDICT:
 > As the format restricts Japanese characters to the kanji and kana fields,
 > any cross-reference data and other informational fields are omitted.
 Значит, её надо переводить в ромадзи (опционально киридзи).

2. Первая "общая" строчка. Встречаются такие:
 > <i>неперех.</i>
 > (<i>англ.</i> advantage)
 Общие флаги и общий языковой источник

 > 1.
 Просто удалить

 > <i>уст.</i> 嗚呼
 > <i>уст.</i> 穴賢, 穴畏, 恐惶
 > : ～する
 > (<i>редко</i> 明く)
 > (…に, …と)
 > (を)

}

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
  writeln('  '+ExtractFileName(paramstr(0))+' <ewarodai.txt> <output file> [flags]');
  writeln('Flags:');
  writeln('  --with-tags <tag-dict> --- copies grammar tags from <tag-dict> where possible.');
end;

var
  InputFile: UnicodeString; //source Warodai file
  OutputFile: UnicodeString; //output EDICT file
  TagDictFile: UnicodeString; //reference dictionary file with tags (Wakan format)
  ExamplesFile: UnicodeString;

procedure ParseCommandLine;
var i: integer;
 s: string;
begin
  InputFile := '';
  OutputFile := '';
  TagDictFile := '';
  ExamplesFile := '';

  i := 1;
  while i<=ParamCount() do begin
    s := Trim(ParamStr(i));
    if Length(s)<=0 then begin
      Inc(i);
      continue;
    end;

    if s='--with-tags' then begin
      Inc(i);
      if i>ParamCount() then
        BadUsage('--with-tags requires tag-dict filename');
      TagDictFile := ParamStr(i);
    end else
    if s='--examples' then begin
      Inc(i);
      if i>ParamCount() then
        BadUsage('--examples requires output filename');
      ExamplesFile := ParamStr(i);
    end else
    if InputFile='' then
      InputFile := s
    else
    if OutputFile='' then
      OutputFile := s
    else
      BadUsage('Unknown parameter: "'+s+'"');

    Inc(i);
  end;

 //Check configuration
  if InputFile='' then
    BadUsage('Input file required.');
  if OutputFile='' then
    BadUsage('Output file required');
end;


var
  inp: TWarodaiReader;
  edict1: TArticleWriter;
  edict2: TArticleWriter;
  jmdict: TArticleWriter;
  examples: TCharWriter;
  stats: record
    artcnt: integer;
    badcnt: integer;
    TlLines: integer;
    VarLines: integer;
    KanaLines: integer;
    KanjiLines: integer;

    SeveralTlLines: integer; //block has several basic translation lines. Not a normal case.
    MixedTlLines: integer; //block has several lines + they are intermixed with other types of lines
    ex_cnt: integer;
  end;


procedure ReadHeader;
var s: string;
begin
  while inp.ReadLine(s) and (s<>'') do begin end;
end;

procedure SetLineTypes(block: PEntryBlock);
var i,ev: integer;
  tl_lines: integer;
  last_tl: boolean;
  mixed_tl: boolean;
begin
  last_tl := true;
  mixed_tl := false;
  tl_lines := 0;
  for i := 0 to block.line_cnt - 1 do begin
   {$IFDEF COUNT_HREFS}
    MatchHrefs(block.lines[i]);
   {$ENDIF}
    block.lines[i] := RemoveFormatting(block.lines[i]);

    ev := EvalChars(block.lines[i]);
    if ev=EV_KANA then begin
      Inc(stats.KanaLines);
      last_tl := false;
    end else
    if ev=EV_KANJI then begin
      Inc(stats.KanjiLines);
      last_tl := false;
    end else begin
      Inc(stats.TlLines);
      Inc(tl_lines);
      if not last_tl then
        mixed_tl := true;
      last_tl := false;
    end;

    if pos('～', block.lines[i])>0 then begin
      Inc(stats.VarLines);
      last_tl := false;
    end;

    if block.lines[i][Length(block.lines[i])]=':' then
      raise EColonAfterTl.Create('Colon after TL');
  end;

  if tl_lines>1 then
    Inc(stats.SeveralTlLines);
  if mixed_tl then
    Inc(stats.MixedTlLines);
end;


var
  com: TCharWriter; //common meaning cases
 //Для ускорения храним по одной копии,
 //чтобы не создавать-удалять каждый раз.
  hdr: TEntryHeader;
  body: TEntryBody;
  mg: TTemplateMgr;
  ex_list: TExampleList;

function ReadArticle: boolean;
var ln: string;
  i, j: integer;
 {$IFDEF ENMARKERS}
  mark: TEntryMarkers;
 {$ENDIF}
  body_read: boolean;
begin
  Result := inp.NextArticle(ln);
  if not Result then exit;

  err.Reset;

  body_read := false;
  Inc(stats.artcnt);
  try
    try
      DecodeEntryHeader(ln, @hdr);
      ReadBody(inp, @body);
      body_read := true;

     //Clean up a bit
      for i := 0 to hdr.words_used - 1 do begin
        DropVariantIndicator(hdr.words[i].s_reading);
        for j := 0 to hdr.words[i].s_kanji_used-1 do
          DropVariantIndicator(hdr.words[i].s_kanji[j]);
      end;

      for i := 0 to body.group_cnt - 1 do
        for j := 0 to body.groups[i].block_cnt - 1 do
          SetLineTypes(@body.groups[i].blocks[j]);

     {$IFDEF ENMARKERS}
     //Query markers from english edict
      FillMarkers(hdr, mark);
     {$ENDIF}

     //Add to edict
      ex_list.Reset;
      ProcessEntry(@hdr, @body, @mg, @ex_list);
      for i := 0 to mg.version_cnt - 1 do begin
        edict1.Print(@mg.versions[i].art);
        edict2.Print(@mg.versions[i].art);
        jmdict.Print(@mg.versions[i].art);
      end;
      if examples<>nil then begin
        for i := 0 to ex_list.Count - 1 do
          examples.WriteLine(ex_list.items[i]);
        Inc(stats.ex_cnt, ex_list.Count);
      end;

    except
      on E: EParsingException do begin
        ExceptionStats.RegisterException(E);
        DumpMsg(E.Message);
        Inc(stats.badcnt);
        if not body_read then
          inp.SkipArticle;
        if not (E is ESilentParsingException) then
          writeln('Line '+IntToStr(WarodaiStats.LinesRead)
            + ' article '+IntToStr(stats.artcnt)+': '
            +E.Message);
      end;
    end;

  finally
    if com<>nil then
      for i := 0 to err.Count - 1 do
      begin
        com.WriteLine('Line '+IntToStr(WarodaiStats.LinesRead)
            + ' article '+IntToStr(stats.artcnt)+': '
            +err.items[i]);
        com.WriteLine(inp.ArticleText);
        com.WriteLine('');
      end;
  end;

  Result := true;
end;


procedure Run;
const loc: AnsiString='English_United States.1252';
var tm: cardinal;
 {$IFDEF COUNT_HREFS}
  i: integer;
  outp: TCharWriter;
 {$ENDIF}
begin
  ExceptionStats.Clear;
  writeln(setlocale(LC_ALL, PAnsiChar(loc)));
  inp := TWarodaiReader.Create(TFileStream.Create(InputFile, fmOpenRead), true);
  com := TCharWriter.Create(TFileStream.Create('commng.txt', fmCreate), csUtf16LE, true);
  edict1 := TEdict1Writer.Create(OutputFile+'.edict1');
  edict2 := TEdict2Writer.Create(OutputFile+'.edict2');
  jmdict := TJmDictWriter.Create(OutputFile+'.jmdict');
  if ExamplesFile<>'' then begin
    examples := TCharWriter.Create(TFileStream.Create(ExamplesFile, fmCreate), csUtf16LE, true);
    examples.WriteBom();
  end else
    examples := nil;

  if TagDictFile <> '' then
  try
    LoadReferenceDic(TagDictFile);
  except
    on E: Exception do  begin
      E.Message := 'While loading tag dictionary "'+TagDictFile+'": '+E.Message;
      raise;
    end;
  end;
  tm := GetTickCount;
  try
    com.WriteBom;
    FillChar(stats, SizeOf(stats), 0);

    ReadHeader();
    while ReadArticle() do begin
      if stats.artcnt mod 1000 = 0 then
        writeln(IntToStr(stats.artcnt));
    end;
    com.Flush;
    if examples<>nil then
      examples.Flush;

   {$IFDEF COUNT_HREFS}
    writeln('');
    writeln('Simple hrefs: '+IntToStr(xrefStats.SimpleHref)+', Href expr: '+IntToStr(xrefStats.HrefExpr));
    writeln('Saving href types...');
    outp :=  TCharWriter.Create(TFileStream.Create('out-href-types.txt', fmCreate), csUtf16LE, true);
    outp.WriteBom;
    for i := 0 to AllHrefTypes.Count - 1 do
      outp.WriteLine(AllHrefTypes.items[i]);
    FreeAndNil(outp);
   {$ENDIF}

    writeln('');
    writeln('Done.');
    writeln('Parsing took '+IntToStr(GetTickCount()-tm)+' msec.');
    writeln('');
    writeln('Lines: '+IntToStr(WarodaiStats.LinesRead));
    writeln('Articles: '+IntToStr(stats.artcnt));
    writeln('Bad articles: '+IntToStr(stats.badcnt));
    writeln('EDICT1 articles: '+IntToStr(edict1.AddedRecords));
    writeln('EDICT2 articles: '+IntToStr(edict2.AddedRecords));
    writeln('JMDICT articles: '+IntToStr(jmdict.AddedRecords));
    writeln('Examples: '+IntToStr(stats.ex_cnt));
    writeln('');
    writeln('Comments: '+IntToStr(WarodaiStats.Comments));
    writeln('Data lines: '+IntToStr(WarodaiStats.DataLines));
    writeln('TL lines: '+IntToStr(stats.TlLines));
    writeln('Var lines: '+IntToStr(stats.VarLines));
    writeln('Kana lines: '+IntToStr(stats.KanaLines));
    writeln('Kanji lines: '+IntToStr(stats.KanjiLines));
    writeln('');
    writeln('EDICT tags -- match: '+IntToStr(refStats.edictTagsFound));
    writeln('EDICT tags -- cloned: '+IntToStr(refStats.edictTagsCloned));
    writeln('EDICT tags -- unsure: '+IntToStr(refStats.edictTagsUnsure));
    writeln('');

    writeln('Group-common cases: '+IntToStr(WarodaiStats.GroupCommon));
    writeln('Block-common cases: '+IntToStr(WarodaiStats.BlockCommon));
    writeln('Multitemplate cases: '+IntToStr(WarodaiStats.Multitemplates));
    writeln('');

    writeln('Group number fixed: '+IntToStr(WarodaiStats.GroupNumberFixed));
    writeln('WARN -- Group number roughly guessed: '+IntToStr(WarodaiStats.GroupNumberGuessed));
    writeln('BAD -- Group number missing: '+IntToStr(WarodaiStats.GroupNumberMissing));

    writeln('Block number fixed: '+IntToStr(WarodaiStats.BlockNumberFixed));
    writeln('WARN -- Block number roughly guessed: '+IntToStr(WarodaiStats.BlockNumberGuessed));
    writeln('BAD -- Block number missing: '+IntToStr(WarodaiStats.BlockNumberMissing));
    writeln('');

    writeln('WTF -- Lines too short: '+IntToStr(WarodaiStats.LinesTooShort));

    writeln('BAD -- Several TL lines: '+IntToStr(stats.SeveralTlLines));
    writeln('BAD -- Mixed TL lines: '+IntToStr(stats.MixedTlLines));
    writeln('');

    ExceptionStats.PrintStats;
    writeln('');

  finally
    FreeReferenceDic();
    FreeAndNil(examples);
    FreeAndNil(com);
    FreeAndNil(jmdict);
    FreeAndNil(edict2);
    FreeAndNil(edict1);
    FreeAndNil(inp);
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
    writeln('Done');
    readln;
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
