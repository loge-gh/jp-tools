﻿unit EdictConverter;

interface
uses Warodai, WarodaiHeader, WarodaiBody, EdictWriter, WcUtils;

{
Собираем несколько версий статьи, по числу разных шаблонов.
"Просто статья" - это пустой шаблон
}

//TODO: Когда буду парсить указания:
// Любые указания типа (поэт.) относятся ко всему sense, не к отдельным глоссам.
// Нужно проверять, что они идут перед первым глоссом.
// Но бывает так: (поэт.) красивая девушка; (непоэт.) курица
// Что делать? Разбивать на два sense?

type
  TTemplateVersion = record
    templ: string;
    art: TEdictArticle;
    procedure Reset;
  end;
  PTemplateVersion = ^TTemplateVersion;
  TTemplateMgr = record
    versions: array[0..8] of TTemplateVersion;
    version_cnt: integer;
    procedure Reset;
    function Get(_templ: string): PEdictArticle;
  end;
  PTemplateMgr = ^TTemplateMgr;

  TExampleList = TList<string>;
  PExampleList = ^TExampleList;

//Пока что возвращаем один article -- позже нужно заполнять TemplateMgr
procedure ProcessEntry(hdr: PEntryHeader; body: PEntryBody; mg: PTemplateMgr; examples: PExampleList);

{
Ссылки:
  см.
  связ.
  связ.:

Форма ссылки:
  あわ【泡】 (в едикте через точку)
}

implementation
uses SysUtils, UniStrUtils, WarodaiMarkers, WarodaiTemplates;

procedure TTemplateVersion.Reset;
begin
  templ := '';
  art.Reset;
end;

procedure TTemplateMgr.Reset;
begin
  version_cnt := 0;
end;

function TTemplateMgr.Get(_templ: string): PEdictArticle;
var i: integer;
  pt: PTemplateVersion;
begin
  for i := 0 to version_cnt - 1 do
    if versions[i].templ=_templ then begin
      Result := @versions[i].art;
      exit;
    end;
 //добавляем новую
  Inc(version_cnt);
  if version_cnt>=Length(versions) then
    raise EParsingException.Create('TemplateMgr: Cannot add one more article version.');
  pt := @versions[version_cnt-1];
  pt.Reset;
  pt.templ := _templ;
  Result := @pt.art;
end;



function CompareStr(const a,b: string): integer;
begin
  Result := UniCompareStr(a,b);
end;

{ Возвращает список всех объявленных в заголовке статьи кандзи.
KanaIfNone: если у каны нет ни одной записи кандзи, добавить её саму как запись кандзи. }
function GetUniqueKanji(hdr: PEntryHeader; KanaIfNone: boolean): TList<string>;
var i, j: integer;
begin
  Result.Comparison := CompareStr;
  Result.Reset;
  for i := 0 to hdr.words_used - 1 do
    if hdr.words[i].s_kanji_used<=0 then begin
      if KanaIfNone then
       //Если кандзей ноль, то само выражение - своя запись
        Result.AddUnique(hdr.words[i].s_reading);
    end else
    for j := 0 to hdr.words[i].s_kanji_used-1 do
      Result.AddUnique(hdr.words[i].s_kanji[j]);
end;

{ Находит кандзи среди возможных записей слова, или возвращает -1. }
function FindKanjiForWord(word: PEntryWord; const kanji: string): integer;
var i: integer;
begin
  Result := -1;
  for i := 0 to word.s_kanji_used - 1 do
    if word.s_kanji[i]=kanji then begin
      Result := i;
      break;
    end;
end;

type
  TWordFlagSet = array[0..MaxWords-1] of boolean;

{ Заполняет массив флагов, выставляя true, если все доступные записи поддерживаются соотв. словом }
function GetAllKanjiUsed(hdr: PEntryHeader; const AllKanji: TList<string>): TWordFlagSet;
var i, j: integer;
begin
  for i := 0 to hdr.words_used - 1 do begin
    Result[i] := true; //for starters
    for j := 0 to AllKanji.Count - 1 do
      if FindKanjiForWord(@hdr.words[i], AllKanji.items[j])<0 then begin
        Result[i] := false;
        break;
      end;
  end;
end;




var
  AllKanji: TList<string>;
  AllKanjiUsed: TWordFlagSet;

procedure ProcessBlock(const body_common, group_common: string; bl: PEntryBlock;
  mg: PTemplateMgr; examples: PExampleList); forward;

procedure ProcessEntry(hdr: PEntryHeader; body: PEntryBody; mg: PTemplateMgr; examples: PExampleList);
var i, j, v: integer;
  idx: integer;
  art: PEdictArticle;
begin
  mg.Reset;

 //Собираем значения
  for i := 0 to body.group_cnt - 1 do
    for j := 0 to body.groups[i].block_cnt - 1 do
      ProcessBlock(body.common, body.groups[i].common, @body.groups[i].blocks[j], mg, examples);

 //Пишем хедеры
  AllKanji := GetUniqueKanji(hdr, {KanaIfNone=}false);
  AllKanjiUsed := GetAllKanjiUsed(hdr,AllKanji);

  for v := 0 to mg.version_cnt - 1 do begin
    art := @mg.versions[v].art;
    art.ref := hdr.s_ref+'-'+IntToStr(v);

    art.kanji_used := AllKanji.Count;
    for j := 0 to art.kanji_used - 1 do begin
      art.kanji[j].Reset;
      art.kanji[j].k := AllKanji.items[j];
      if mg.versions[v].templ<>'' then
        art.kanji[j].k := repl(mg.versions[v].templ, '～', art.kanji[j].k);
     //TODO: markers, POP
    end;

    art.kana_used := hdr.words_used;
    for i := 0 to hdr.words_used - 1 do begin
      art.kana[i].Reset;
      art.kana[i].k := hdr.words[i].s_reading;
      if mg.versions[v].templ<>'' then
        art.kana[i].k := repl(mg.versions[v].templ, '～', art.kana[i].k);
      art.kana[i].AllKanji := AllKanjiUsed[i];
      if not art.kana[i].AllKanji then
        for j := 0 to hdr.words[i].s_kanji_used - 1 do begin
          idx := AllKanji.Find(hdr.words[i].s_kanji[j]);
          Assert(idx>=0, 'Kanji not found in AllKanji');
          art.kana[i].AddKanjiRef(idx);
        end;
     //TODO: markers, POP
    end;
  end;

end;

procedure VerifyBrackets(const ln: string; const br_op, br_cl: WideChar);
var cnt, i: integer;
begin
  cnt := 0;
  for i := 1 to Length(ln) do
    if ln[i]=br_op then Inc(cnt) else
    if ln[i]=br_cl then begin
      Dec(cnt);
      if cnt<0 then
        raise EBracketsMismatch.Create('Brackets mismatch '+br_op+' and '+br_cl);
    end;
  if cnt<>0 then
    raise EBracketsMismatch.Create('Brackets mismatch '+br_op+' and '+br_cl);
end;

{ Разбивает строку на глоссы }
function SplitGlosses(const ln: string): TStringArray;
var ps, pc: PWideChar;
  b_stack: integer;
  i: integer;
begin
  SetLength(Result, 0);
  if ln='' then exit;

 { Мы ищем "," и ";", но не внутри никаких скобок.
  Пока предполагаем, что скобки в формате файла везде расположены правильно,
  и достаточно считать их число, а проверять типы нет необходимости }
  b_stack := 0;

  ps := PWideChar(ln);
  pc := ps;
  while pc^<>#00 do begin
    if (pc^='(') or (pc^='[') or (pc^='{') or (pc^='<') then
      Inc(b_stack)
    else
    if (pc^=')') or (pc^=']') or (pc^='}') or (pc^='>') then begin
      Dec(b_stack);
      if b_stack<0 then
        raise EBracketsMismatch.Create('Brackets mismatch');
    end else
    if (b_stack<=0) and ((pc^=',') or (pc^=';')) then begin
      SetLength(Result, Length(Result)+1);
      Result[Length(Result)-1] := Trim(StrSub(ps,pc));
      ps := PChar(integer(pc)+SizeOf(char));
    end;
    Inc(pc);
  end;

  if pc>=ps then begin
    SetLength(Result, Length(Result)+1);
    Result[Length(Result)-1] := Trim(StrSub(ps,pc));
  end;


  if b_stack<>0 then
    raise EBracketsMismatch.Create('Brackets mismatch');

 //Проверяем, что мы случайно не порезали внутри скобки
  for i := 0 to Length(Result) - 1 do begin
    VerifyBrackets(Result[i], '[', ']');
    VerifyBrackets(Result[i], '(', ')');
    VerifyBrackets(Result[i], '{', '}');
    VerifyBrackets(Result[i], '<', '>');
  end;
end;


procedure ProcessBlock(const body_common, group_common: string; bl: PEntryBlock;
  mg: PTemplateMgr; examples: PExampleList);
var j, k: integer;
  tmp: string;
  templ: string;
  t_p: TTemplateList;
  sn: PEdictSenseEntry;
  bl_cnt: integer;
begin
  if bl.line_cnt<0 then
    raise EParsingException.Create('Block has no lines');
  bl_cnt := 0;

  for j := 0 to bl.line_cnt - 1 do begin
    tmp := bl.lines[j];
    if ExtractTemplate(tmp, templ) then begin
      SplitTemplate(templ, t_p);
      if Length(t_p)>1 then
        Inc(WarodaiStats.MultiTemplates);
     //Добавляем все в соотв. записи
      for k := 0 to Length(t_p) - 1 do begin
        if t_p[k]='' then
          raise EParsingException.Create('Invalid empty template part.');
        sn := mg.Get(t_p[k])^.AddSense;
        for tmp in SplitGlosses(tmp) do
          sn.AddGloss(tmp); //TODO: markers, xrefs, lsources
      end;
    end else
    if ExtractExample(tmp, templ) then begin
      if examples<>nil then
        examples^.Add(templ + ' === '+ tmp);
    end else begin
      if bl_cnt > 0 then
        raise ESeveralProperTranslations.Create('Block has several proper translations');
        //мы могли бы просто добавить их, но это странная ситуация, так что не будем
      sn := mg.Get('').AddSense;
      for tmp in SplitGlosses(tmp) do
        sn.AddGloss(tmp); //TODO: markers, xrefs, lsources
      Inc(bl_cnt);
    end;
  end;

end;

{

procedure TEdict1Writer.PrintEdictGroup(const hdr: TLineHeader; const common: string; const group: PEntryGroup);
var i, j, k: integer;
  bl: PEntryBlock;
  bl_cnt: integer;
  s_base: PTemplateVersion;
  templ: string;
  tmp: string;
  t_p: TTemplateList;
begin
  verMgr.Reset;
  s_base := verMgr.Get('');

  for i := 0 to group.block_cnt - 1 do begin
    if group.blocks[i].line_cnt<0 then
      raise EParsingException.Create('Block '+IntToStr(i)+' has no lines');

    bl_cnt := 0; //block proper translation count
    bl := @group.blocks[i];


 //Печатаем все версии
  PrintVersions(hdr, common, group);
end;

procedure TEdict1Writer.PrintVersions(const hdr: TLineHeader; const common: string; const group: PEntryGroup);
var i: integer;
  s_pre, s_com, s_post: string;
  tmp_hdr: TLineHeader;
  pv: PTemplateVersion;
begin
  s_com := '';
  if common<>'' then
    s_com := s_com + common + ' ';
  if group.common<>'' then
    s_com := s_com + group.common + ' ';

  for i := 0 to verMgr.version_cnt - 1 do  begin
    pv := @verMgr.versions[i];
    if pv.templ<>'' then begin
      tmp_hdr.kanji := repl(pv.templ, '～', hdr.kanji);
      tmp_hdr.kana := repl(pv.templ, '～', hdr.kana);
      tmp_hdr.mark := hdr.mark;
    end else
      tmp_hdr := hdr;
    FormatLineHeader(tmp_hdr, s_pre, s_post);
    outp.WriteLine(s_pre + s_com + pv.art + s_post);
    Inc(FAddedRecords);
  end;
end;

procedure TEdict1Writer.FormatLineHeader(hdr: TLineHeader; out s_pre, s_post: string);
begin
  if hdr.kanji <> '' then
    s_pre := hdr.kanji + ' [' + hdr.kana + '] /'
  else
    s_pre := hdr.kana + ' /';
  if hdr.mark.markers<>'' then
    s_pre := s_pre + '(' + hdr.mark.markers + ') '
  else
    s_pre := s_pre;
  if hdr.mark.pop then
    s_post := s_post + '(P)/'
  else
    s_post := '';
end;
}




end.