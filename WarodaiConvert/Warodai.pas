﻿unit Warodai;

interface
uses SysUtils, UniStrUtils, StreamUtils, WcUtils;
{$INCLUDE 'Warodai.inc'}

var
 //Общая статистика для всех Warodai-модулей
  WarodaiStats: record
    LinesRead: integer;
    LinesTooShort: integer; //article lines shorter than 2 characters --- skipped
    Comments: integer;
    DataLines: integer; //translations, variations and examples

    ArticleCount: integer;

    GroupCommon: integer; //число общих для групп частей
    BlockCommon: integer; //число общих для блоков частей
    Multitemplates: integer; //число шаблонов, которые содержат несколько вариантов на одной строке

   //Всё последующее - это "# статей, которые..."
    GroupNumberFixed: integer; //первый блок смешался с переводом, но мы починили
    GroupNumberGuessed: integer; //номер первого блока вообще потерян
    GroupNumberMissing: integer; //номер какого-то блока потерян, но не первого
    BlockNumberFixed: integer;
    BlockNumberGuessed: integer;
    BlockNumberMissing: integer;

  end;

type
  EParsingException = class(Exception);
   //Explicit common group blocks: явные блоки в общей группе, затем появление явной группы
  ESilentParsingException = class(EParsingException);

 { Некоторые типы ошибок можно делать Silent, если мы в принципе такое не поддерживаем }

  EMultilineCommon = class(ESilentParsingException); { Общий кусок больше одной строки в длину }
    //Multiline Group Common: несколько строк в общей части 1+ групп
    //Multiline Block Common: несколько строк в общей части 1+ блоков
  EColonAfterTl = class(ESilentParsingException); { Перевод завершается двоеточием - это неполный перевод }
    //translation lines which end with colon ':'. Suspicious.
  EAlternativeIds = class(ESilentParsingException); { Идентификаторы третьего уровня - а) б) в) }
    //статья с 3-м уровнем разбиения ("а)", "б)", и т.п)
  EKanjiKanaLeft = class(ESilentParsingException); { В статье остались кандзи или кана после извлечения шаблона. Обычно это ссылки, но возможно всякое }
    //Kanji or kana left in string after doing ExtractTemplate
    //Kanji or kana left in string after doing ExtractExample
  ESeveralProperTranslations = class(ESilentParsingException); { Обычно все добавочные строки - это "ср." и "см. также" }
    //статей, где блок содержит несколько строк простого перевода

  EBracketsMismatch = class(ESilentParsingException);
   { Серьёзная ошибка: либо сам перевод содержит непарные/неверно парные скобки,
     либо такие образуются в результате его разбиения на глоссы.
     Без разбиения на глоссы перевод добавить нельзя. }

  EIllegalXrefChar = class(ESilentParsingException);
   { Недопустимый или неподдерживаемый символ в ссылке на запись }

  ETemplateParsingException = class(ESilentParsingException); { Шаблон или пример не удалось разобрать или какие-то части его не поддерживаются. }
  EOpenTemplate = class(ESilentParsingException); { В статье встречается открытый шаблон (см. шаблоны) - не поддерживаем }
  EInsideTemplate = class(ESilentParsingException); { Шаблоны внутри строки (не в начале) }


type
  TWarodaiReader = class(TCharReader)
  protected
    FArticleLines: array[0..99] of string;
    FArticleLineCount: integer;
  public
    function NextArticle(out ln: string): boolean;
    function ReadLine(out ln: string): boolean; reintroduce;
    procedure SkipArticle;
    function ArticleText: string;
  end;

const
  EV_NORMAL = 0;
  EV_KANA = 1;
  EV_KANJI = 2;

{ Возвращает KANJI, если в строке есть и кандзи, KANA, если только кана, и NORMAL, если ничего нет }
function EvalChars(const s: string): integer;

{
Регистрация ошибок.
Ошибки собираются на протяжении всего разбора, а выводятся один раз, в конце.
}

var
  err: TList<string>;

procedure DumpMsg(const msg: string); overload;
procedure DumpMsg(const msg, line: string); overload;


implementation

{ Пропускает пустые строки и читает первую непустую.
 Обычно это заголовочная строка. }
function TWarodaiReader.NextArticle(out ln: string): boolean;
begin
  FArticleLineCount := 0;
  while ReadLine(ln) and (ln='') do begin end;
  if ln='' then begin //couldn't read another line then
    Result := false;
    exit;
  end;
  Inc(WarodaiStats.ArticleCount);
  Result := true;
end;


function TWarodaiReader.ReadLine(out ln: string): boolean;
begin
  Result := inherited ReadLine(ln);
  if not Result then exit;

 //От беспорядочно расставленных тегов <i> больше беды, чем пользы.
 //Выкидываем их все, как если бы их и не было!
  ln := repl(ln,'<i>','');
  ln := repl(ln,'</i>','');
  Inc(WarodaiStats.LinesRead);
  if FArticleLineCount<Length(FArticleLines) then begin
    Inc(FArticleLineCount);
    FArticleLines[FArticleLineCount-1] := ln;
   //Иначе просто не добавляем строку - в дампах статья получится обрезанной
  end;
end;

//Проматываем текущую запись до конца
procedure TWarodaiReader.SkipArticle;
var s: string;
begin
  while ReadLine(s) and (s<>'') do begin end;
end;

function TWarodaiReader.ArticleText: string;
var i: integer;
begin
  if FArticleLineCount<=0 then begin
    Result := '';
    exit;
  end;

  Result := FArticleLines[0];
  for i := 1 to FArticleLineCount - 1 do
    Result := Result + #13#10 + FArticleLines[i];
end;

function EvalChars(const s: string): integer;
var i: integer;
begin
  Result := EV_NORMAL;
  for i := 1 to Length(s) do
    if IsKanji(s[i]) then begin
      Result := EV_KANJI;
      break;
    end else
    if IsKana(s[i]) then
      Result := EV_KANA;
end;

procedure DumpMsg(const msg: string);
begin
  err.Add(msg);
end;

procedure DumpMsg(const msg, line: string);
begin
  err.Add(msg+#13#10+line);
end;

initialization
  FillChar(WarodaiStats, sizeof(WarodaiStats), 0);

end.
