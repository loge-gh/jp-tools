﻿unit YarxiKanji;
{
Kanji
  Nomer      Номер. В точности соответствует номеру записи, можно игнорировать.
  RusNick    Имя кандзи на русском, иногда несколько. См. ParseKanjiRusNick
  OnYomi     Оны, см. ParseKanjiOnYomi
  KunYomi    Транскрипции чтений кандзи, см. ParseKanjiKunYomi
              - кунные чтения
              - онные смыслы и их чтения
              - чтения в именах
  Russian    Значения, см. ParseKanjiRussian
              - значения в кунных чтениях
              - значения в онных смыслах
  Compounds  Примеры употреблений в сочетаниях, см. ParseKanjiCompounds
  Str
  Utility
  Uncd       Код символа в UCS2/UTF16 (число).
  Bushu
  Dicts
  Layout
  Concise
  Yo
}

interface
uses SysUtils, Classes, UniStrUtils, FastArray, WcExceptions;

{
 Русское название кандзи.
 Может быть несколько, некоторые могут быть альтернативными вариантами предыдущих,
 но мы такие сейчас выкидываем.
}

type
  TRusNicks = TArray<string>;

function ParseKanjiRusNick(const inp: string): TRusNicks;


{
 Онные чтения.
}

type
  TOnYomiEntry = record
    kana: string; //если пустое => кокудзи
    rare: boolean;
  end;
  POnYomiEntry = ^TOnYomiEntry;
  TOnYomiEntries = array of TOnYomiEntry; //пустой => кокудзи

function ParseKanjiOnYomi(const inp: string): TOnYomiEntries;



{
 Readings: Чтения в словах.
}

type
  TCharLinkPosition = (
    lpDefault = 0, //по-моему, LastLine
    lpFirstLine,
    lpAllClauses,
    lpOneClause,
    lpFromTo,
    lpNewline,
    lpKanji
  );
  TCharLink = record
    _type: char;
    pos: TCharLinkPosition;
    posfrom: byte;
    posto: byte;
    text: string;
    wordref: integer; //весь набор целиком ссылается на слово. Обычно ноль
  end;
  PCharLink = ^TCharLink;

  TKunReadingFlag = (
    krSpaces,       //было окружено пробелами - хз, что это
    krHidden,       //не показывать, но учитывать при поиске
    krUnchecked     //не отредактировано. Если элемент первый, применяется и к переводу
  );
  TKunReadingFlags = set of TKunReadingFlag;
  TKunReading = record
   { Транскрипция, как она встречается в базе + в нужных местах вставлено тире
    и после букв, где в русской версии должно стоять "и", вставлены "´" }
    romaji: string;
    kana: string;
    flags: TKunReadingFlags;
   { Мы модифицируем text, вставляя спец. символы. Функция переводит номер буквы
    в номер в модифицированном тексте. }
    function roma_getPos(APos: integer): integer;
    function roma_getLen: integer;
    function roma_getNthI(APos: integer): integer;
    function roma_getIcount: integer;
  end;
  PKunReading = ^TKunReading;
  TUsuallyIn = (
    uiNormal = 0,
    uiHiragana,
    uiKatakana,
    uiKana
  );
  TKunReadingSetFlag = (
    ksTranscriptionUnderWord
  );
  TKunReadingSetFlags = set of TKunReadingSetFlag;
  TKunReadingSet = record
    items: array of TKunReading; //варианты чтения
    kanji: string; //запись кандзи - одна на все варианты
    refs: TArray<TCharLink>;
    flags: TKunReadingSetFlags;
    latin_tail: string; //дополнительный хвост вида ~суру
    usually_in: TUsuallyIn;
    tl_usually_in: TArray<TUsuallyIn>; //если даны метки для конкретных подпунктов
    procedure roma_getNthI(APos: integer; out AItem: integer; out ACharIdx: integer);
  end;
  PKunReadingSet = ^TKunReadingSet;
  TKunReadings = array of TKunReadingSet;

function ParseKanjiKunReadings(const kanji: string; inp: string): TKunReadings;
function ParseCharLink(var pc: PChar): TCharLink;
function ParseAdditionalKanjiChain(var pc: PChar): string;



{
  Readings: Чтения в сочетаниях.
}
type
  TCompoundReadingType = (ctCommon, ctRare);
  TCompoundReading = record
    _type: TCompoundReadingType;
    text: string;
  end;
  PCompoundReading = ^TCompoundReading;

  TCompoundReadingSet = array of TCompoundReading;
  PCompoundReadingSet = ^TCompoundReadingSet;

  TCompoundReadings = array of TCompoundReadingSet;

function ParseKanjiCompoundReadings(inp: string): TCompoundReadings;
function DumpKanjiCompoundReadings(const AReadings: TCompoundReadings): string;
function DumpKanjiCompoundReadingSet(const AReadingSet: TCompoundReadingSet): string;
function DumpKanjiCompoundReading(const AReading: TCompoundReading): string;



{
  Readings: Чтения в именах.
}
type
  TNameReadingType = (
    ntCommon,       //обычные чтения
    ntOccasional,   //"также"
    ntRare,         //"реже"
    ntHidden        //скрытые, только для поиска
  );
  TNameReading = record
    _type: TNameReadingType;
    text: string;
  end;
  PNameReading = ^TNameReading;
  TNameReadings = array of TNameReading;

function ParseKanjiNameReadings(const inp: string): TNameReadings;
function DumpKanjiNameReadings(const AReadings: TNameReadings): string;
function DumpKanjiNameReading(const AReading: TNameReading): string;



{
  Кандзи: Kanji.Kunyomi
}
type
  TKanjiReadings = record
    show_kuns: byte; //показывать по умолчанию до куна n значения m включительно
    show_tango: byte; //последовательность ![цифра]? -- значение неясно
    kun: TKunReadings;
    compound: TCompoundReadings;
    name: TNameReadings;
  end;
  PKanjiReadings = ^TKanjiReadings;

function ParseKanjiKunYomi(const kanji: string; inp: string): TKanjiReadings;
function DumpKanjiKunYomi(const AReadings: TKanjiReadings): string;


{
  Кандзи: Kanji.Russian.
}
type
  TKunyomiKanjiLink = record
    _type: char;
    text: string;
  end;
  PKunyomiKanjiLink = ^TKunyomiKanjiLink;

 {
  Значения разделены на:
  1. Блоки/block (по чтениям)
  2. Пункты/clause (внутри блока, по номерам)
  3. Суффиксы/suffixedEntry (обычно внутри пункта, разные наклонения слова в нём)
 }

 { Часть пункта значения, объединённая одним суффиксом, например, ~suru,
  ~ni naru или пустым. }
  TKunyomiMeaningSuffixedEntry = record
    suffix: string; //суффикс - см. match_suffix
    text: string;
  end;
  PKunyomiMeaningSuffixedEntry = ^TKunyomiMeaningSuffixedEntry;

 { Пункт значения }
  TKunyomiMeaningClause = record
    index: integer; //номер - ноль для "номера по умолчанию" (до первого буллета)
    entries: TArray<TKunyomiMeaningSuffixedEntry>;
    common_clause: boolean; //общее вступление для последующих пунктов
  end;
  PKunyomiMeaningClause = ^TKunyomiMeaningClause;

 { Блок значения }
  TKunyomiMeaningBlock = record
    isNominal: boolean;
    links: TArray<TKunyomiKanjiLink>;
    clauses: TArray<TKunyomiMeaningClause>;
  end;
  PKunyomiMeaningBlock = ^TKunyomiMeaningBlock;

  TKunyomiMeanings = TArray<TKunyomiMeaningBlock>;

  TCompoundMeaning = record
  end;
  TCompoundMeanings = TArray<TCompoundMeaning>;

  TRelatedKanjiPos = (
    rpBigGray,            //большое серое справа
    rpUnderKanji,         //прямо под кандзи
    rpUnderNickname       //прямо под именем кандзи
  );
  TRelatedKanjiLink = record
    pos: TRelatedKanjiPos;
    _type: char;
    text: string;
  end;
  PRelatedKanjiLink = ^TRelatedKanjiLink;

  TFeldmanKonradFlag = (
    fkNone,
    fkMissing,
    fkDeprecated,
    fkOriginal,
    fkSimplified
  );

  TRussianMeanings = record
    kunyomi: TKunyomiMeanings;
    compound: TCompoundMeanings;
    related_kanji: TArray<TRelatedKanjiLink>;
    fk_flag: TFeldmanKonradFlag;
  end;

function ParseKanjiRussian(inp: string): TRussianMeanings;
function ParseKanjiKunyomiMeanings(inp: string): TKunyomiMeanings;
function ParseKanjiCompoundMeanings(inp: string): TCompoundMeanings;


{
  Кандзи: Kanji.Compounds. Работает в сочетании с KunYomi и Russian.
}
type
  TCompoundFlag = (cfIrregularReading, cfIrregularMeaning, cfSingular, cfHashtag);
  TCompoundFlags = set of TCompoundFlag;
  TCompoundEntry = record
    block: integer; //special purpose blocks are negative
    wordref: integer;
    msgref: integer;
    flags: TCompoundFlags;
  end;
  PCompoundEntry = ^TCompoundEntry;
  TCompoundEntries = array of TCompoundEntry;

const //special purpose blocks
  BLOCK_NAMES = -1;

function ParseKanjiCompounds(inp: string): TCompoundEntries;
function DumpKanjiCompounds(const ACompounds: TCompoundEntries): string;
function DumpKanjiCompound(const ACompound: TCompoundEntry): string;


implementation
uses StrUtils, JWBKanaConv, YarxiStrings, YarxiCore, YarxiRefs,
  YarxiReadingCommon;

{
Поле Kanji.RusNick:
Формат:  человеколюбие*косточка*вишнёвая берёза
*#* - альтернативные записи (ставятся ко всему набору):
  дешёвый*#*дешевый*
  лёгкий*обмен*#*легкий*обмен**  --- две звёздочки в конце
*_* - там, где стоит, строка не переносится:
  речь*_*различать*_*лепесток*косичка*_*управление*
Ударения:
  замок*!2  --- ударение на 2-й букве
  ах!  --- просто восклицательный знак
Курсив? (для названий радикалов):
  ''капля''
  ''лёд''*#*''лед''  --- совместно с альтернативой
  императорское ''мы''  --- просто кавычки

Ещё встречается:
  -ха-  --- ничего не значит, отображается, как есть
}

{ Убирает ''кавычки'' по сторонам RusNick }
function KillQuotes(const inp: string): string;
begin
  if (Length(inp)<4) or (inp[1]<>'''') or (inp[2]<>'''')
  or (inp[Length(inp)-1]<>'''') or (inp[Length(inp)]<>'''') then
    Result := inp
  else
    Result := copy(inp, 3, Length(inp)-4);
end;

{ Разбирает строку и составляет список всех названий кандзи.
 Альтернативы выбрасывает. Флаги непереноса строки выбрасывает. Акценты выбрасывает.
 Можно было бы разобрать, но НААААФИИИГ. }
function ParseKanjiRusNick(const inp: string): TRusNicks;
var tmp: string;
  i_pos: integer;
  i, i_start: integer;
begin
  PushComplainContext(inp);
  try
    Result.Clear;
    tmp := inp;

   //Альтернативы нафиг
    i_pos := pos('*#*',tmp);
    if i_pos>0 then
      delete(tmp,i_pos,MaxInt);

   //Сложные случаи сводим к простым
    tmp := repl(tmp, '*_*', '*');
    tmp := repl(tmp, '**', '*');

   //Звёздочки в конце
    while (Length(tmp)>0) and (tmp[Length(tmp)]='*') do
      SetLength(tmp, Length(tmp)-1);

    if tmp='' then exit;

    i := 1;
    i_start := 1;
    while i<=Length(tmp) do begin
      if tmp[i]='*' then begin
        if (i_start<i)
        and (tmp[i_start]<>'!') then //это было ударение - нафиг
          Result.Add(KillQuotes(copy(tmp, i_start, i-i_start)));
        i_start := i+1;
      end;
      Inc(i);
    end;

    if (i>i_start)
    and (tmp[i_start]<>'!') then
      Result.Add(KillQuotes(copy(tmp, i_start, i-i_start)))
  finally
    PopComplainContext;
  end;
end;


{
Поле Kanji.OnYomi:
Формат: *kana*;*kana**;*kana*
Могут использоваться ";" и ",".
Флаги:
 *kana**   чтение малоупотребимое
 -         кокудзи (в т.ч. как один из вариантов)
Всё поле пустое => кокудзи.
Встречается такое (сейчас не обрабатывается):
  *cho:*(*ten**)*
  *ryu:*(*ryo:**)*
  *setsu*(*sai**)* #3814
  -*do:*
}
function ParseKanjiOnYomi(const inp: string): TOnYomiEntries;
var i_beg, i_pos, cnt: integer;

  procedure PostWord;
  var i_end: integer;
  begin
    if (i_pos-i_beg<=0) or ((i_pos-i_beg=1) and (inp[i_beg]='-')) then begin
      Result[cnt].kana := ''; //kokuji
      Result[cnt].rare := false;
    end else
   { Вообще говоря, судя по формату, каждое он-ёми должно быть обёрнуто в
    *звёздочки*, и исключений быть не может.
    Но они есть. Так что будем очень терпимы. }
    begin
      i_end := i_pos;
      Result[cnt].rare := false;
      if inp[i_beg]='*' then
        Inc(i_beg);
      if inp[i_end-1]='*' then
        Dec(i_end);
      if (i_end-1>=i_beg) and (inp[i_end-1]='*') then begin
        Result[cnt].rare := true;
        Dec(i_end);
      end;
      Result[cnt].kana := copy(inp, i_beg, i_end-i_beg);
    end;
  end;

begin
  PushComplainContext(inp);
  try
    if (inp='') or (inp='-') then begin
      SetLength(Result, 0);
      exit;
    end;

   //Считаем число ;,
    cnt := 0;
    for i_pos := 1 to Length(inp) do
      if (inp[i_pos]=';') or (inp[i_pos]=',') then
        Inc(cnt);
    SetLength(Result, cnt+1);

    cnt := 0;
    i_beg := 1;
    i_pos := 1;
    while i_pos<=Length(inp) do begin
      if (inp[i_pos]=';') or (inp[i_pos]=',') then begin
        PostWord;
        i_beg := i_pos+1;
        Inc(cnt);
      end;
      Inc(i_pos);
    end;
    PostWord;
  finally
    PopComplainContext;
  end;
end;

{
Поле: Kanji.KunYomi. Работает в сочетании с Russian и Compounds.
Формат: [префиксы][куны]|[чтения в сочетаниях]|[чтения в именах|c|палками]
Префиксы:
  !2!   изменить высоту блока кунов так, что по умолчанию видны первые 2 чтения
        целиком.
  !25!  --//-- по умолчанию видны 2 чтения, второе - до 5-го значения
        включительно. Указывать последнее из значений нельзя - делайте !20!
  !20!  то же, что !2!
  !2?   функция неясна
Любые блоки могут отсутствовать, однако появляются последовательно. Блок может
быть пуст.
}
function ParseKanjiKunYomi(const kanji: string; inp: string): TKanjiReadings;
var block: string;
  i: integer;
begin
  PushComplainContext(inp);
  try
    Result.show_kuns := 0;
    Result.show_tango := 0;

   { Вынимаем из начала строки флаги вида !2!, !2?. Несколько флагов подряд мы
    пока не встречали и не поддерживаем. }
    if (Length(inp)>0) and (inp[1]='!') then begin
      i := 2;
      while (i<=Length(inp)) and (inp[i]<>'!') and (inp[i]<>'?') do
        Inc(i);
      if i>Length(inp) then
        raise Exception.Create('ParseKanjiKunYomi: Unterminated leading flag.');
      if inp[i]='!' then
        Result.show_kuns := StrToInt(copy(inp,2,i-2))
      else
        Result.show_tango := StrToInt(copy(inp,2,i-2));
      delete(inp, 1, i);
    end;

    block := pop(inp, '|');
    Result.kun := ParseKanjiKunReadings(kanji, block);
    block := pop(inp, '|');
    Result.compound := ParseKanjiCompoundReadings(block);
   //Остальное - имена
    Result.name := ParseKanjiNameReadings(inp);
  finally
    PopComplainContext;
  end;
end;

function DumpKanjiKunYomi(const AReadings: TKanjiReadings): string;
begin
  Result := 'Compounds: '+ DumpKanjiCompoundReadings(AReadings.compound) + '; '
    +'Names: '+DumpKanjiNameReadings(AReadings.name);
end;


{ Возвращает положение в модифицированной (расширенной) строке по положению для
 исходной }
function TKunReading.roma_getPos(APos: integer): integer;
begin
  Result := 0;
  while APos>0 do begin
    Inc(Result);
    if Result>Length(romaji) then break;
    if (romaji[Result]<>'-') and (romaji[Result]<>'´')
    and (romaji[Result]<>'[') and (romaji[Result]<>']') then
      Dec(APos);
  end;
end;

function TKunReading.roma_getLen: integer;
begin
  Result := roma_GetPos(MaxInt)-1;
end;

{ Возвращает n-тое вхождение буквы i в строке - нужно для некоторых кодов }
function TKunReading.roma_getNthI(APos: integer): integer;
begin
  Result := 0;
  while APos>0 do begin
    Inc(Result);
    if Result>Length(romaji) then break;
    if (romaji[Result]='i') or (romaji[Result]='I') then
      Dec(APos);
  end;
end;

function TKunReading.roma_getIcount: integer;
var i: integer;
begin
  Result := 0;
  for i := 1 to Length(romaji) do
    if romaji[i]='i' then Inc(Result);
end;

{ То же, но для всего ReadingSet }
procedure TKunReadingSet.roma_getNthI(APos: integer; out AItem: integer; out ACharIdx: integer);
begin
  AItem := 0;
  while AItem<Length(items) do begin
    ACharIdx := items[AItem].roma_getNthI(APos);
    if ACharIdx<=Length(items[AItem].romaji) then
      break;
    Dec(APos, items[AItem].roma_getIcount);
    Inc(AItem);
  end;
end;

{
Поле: Kanji.KunYomi, блок KunReadings.
Формат: 334*aware*awareppoi*kanashii
Набор цифр определяет, сколько букв покрывает кандзи в соотв. чтении:
  AWAre*AWAreppoi*KANAshii
0 означает "покрывает всё слово".
^ означает "10 + следующая цифра" (т.к. просто 10 читалось бы как позиции 1 и 0)

Дальше, разделённые *, идут наборы вариантов чтения кунёми. Обычно в наборе одно
чтение, если несколько - разделяются "*/*":
  034*jiji*/*jijii*/*jii*aware*kanashii
Последняя * не ставится.

чтение*Qn*     "и" вместо "й" в русской транскрипции в n-й букве i, считая от
               начала ReadingSet
ЧТЕНИЕ         онное чтение в яп. слове - напр. АИрасии. Отображается синим.
чтеНИЕ         часть слова бывает большими буквами без причины.
* чтение *     пробелы вокруг => не искать по этому чтению (вероятно?)
*/*чтение      следующий вариант чтения в одном вхождении
*&*чтение      не показывать, но учитывать при поиске (иногда &слитно).
*=*чтение      разновидность предыдущего чтения (arui ha/arui wa), использовать
               предыдущее как кану, а это - как транскрипцию.
               Максимум одно на чтение. Используется исключительно для ha/wa,
               и Яркси болезненно реагирует на попытки заменить что-то ещё.
**чтение       не отредактировано (чтение бледным цветом). Если стоит у первого
               чтения, то касается и перевода.
набор*!!*      транскрипция помещается ПОД словом, кол-во транскрипций может быть
               больше одной (#1196)
набор*!R*      то же, что !!, но только для русского словаря
чтение*-n*     вставить тире в n-ю позицию чтения. Похоже, только для красоты.
               Номера букв и длина чтения логически не меняются.
набор*#хвост*  латинский хвост к набору (~суру). Иногда пробел *#в конце *
               На длину чтения и его кандзи-отображение не влияет.

Пометки:
набор*^^*      чаще хираганой (иногда слитно^^)
набор*^!^*     то же, разместить текст под кандзи
набор*^@*      чаще катаканой
набор*^#*      чаще каной
набор*^01129*  стандартная ссылка -- см. ParseCharLink (иногда слитно:
               *hiroi^50859* или *ateru*^12060^11250*)
 К сожалению, существует некоторая проблема, следующие вещи все верны:
   ^40000      ссылка на 0000
   ^_240000    ссылка со 2-го пункта на 0000 (см. формат ссылок)
   ^^          чаще хираганой
   ^_2^^       чаще хираганой для 2-го пункта (#124)
   ^_2^#       чаще каной
 Ну и как это, блин, разбирать?

Отображение в кандзи:
набор*+6*      добавить курикаэси (種々) перед хвостом каны. Число задаёт, после
               какой буквы чтения вставить кури.
*набор*$1[..]* вставить с указанной позиции кандзи-позиции (в итоговом тексте):
  [1084]       кандзи в скобках
  1084         кандзи по номеру
  ''кана''     кана
  $25445+      вторичный курикаэси, вставляется после вхождения. Допускается
               не больше одного.
См. комментарии к FinalizeKunReadingSet по подробной трактовке этих параметров
и их комбинаций.

набор*~n*      n символов от начала чтения вынести перед кандзи (для гонорификов)
набор*[3]5*    часть чтения с 4-й буквы по 5-ю опциональна (кв. скобки)
набор*[4[6]6]8 две опциональных части, (4..6] и (6..8]
Опциональные части могут быть только в хвосте (>= длины корня), т.е. после любых
кури и доп. кандзи.

Игнорируем:
набор*VI*
набор*VT*      неизвестно что, с виду не влияет
набор*L1*      неизвестно, что

После каждого флага тоже ставится *, последняя * не ставится (однако ставится
закрывающая для набора, если требуется).

Для скрытых чтений информация о покрытии отсутствует (напр. #13):
!2!041133* AKU *warui*ashi*ashikarazu*akutareru*^!^*akutare*^^*&*nikui*|AKU,WARU/O/-NIKUI
}
type
 //Временная информация по KunReadingSet, при закрытии сета формирующая финальную
  TAdditionalKanji = record
    pos: integer; //точка вставки доп. цепочки кандзи, в кандзи!
    text: string;
    kuri: boolean; //в конце цепочки курикаэси
  end;
  PAdditionalKanji = ^TAdditionalKanji;
  TOptionalSpan = record
    op: byte; //начинается после ...
    ed: byte; //кончается после ...; 0 = до конца транскрипции
  end;
  POptionalSpan = ^TOptionalSpan;
  TRawKunReadingSet = record
    prefix_chars: byte; //число символов префикса (до кандзи)
    main_chars: byte; //префикс + число символов, заменяемых кандзи
    kuri_chars: byte; //число символов, указанных до основного курикаэси
    optional_spans: TArray<TOptionalSpan>; //опциональные блоки
    additional_kanji: TArray<TAdditionalKanji>;
    with_kurikaeshi: boolean;
    procedure Reset;
  end;

procedure FinalizeKunReadingSet(const kanji: string; rset: PKunReadingSet;
  const raw: TRawKunReadingSet); forward;
function match_targeted_kana_flag(pc: PChar): boolean; forward;

//True, если символ - буква, которая может встречаться в транскрипциях
function IsTranscriptionChar(const ch: char): boolean;
begin
  Result := IsLatin(ch) or (ch=':'){долгота в транскрипциях}
    or (ch=''''){после буквы n}
    or (ch='-')
    or (ch=' ');
end;

//Читает транскрипцию начиная с текущей буквы
function EatTranscription(var pc: PChar): string;
var ps: PChar;
begin
  ps := pc;
  while IsTranscriptionChar(pc^) do
    Inc(pc);
  Result := spancopy(ps,pc);
end;

function ParseKanjiKunReadings(const kanji: string; inp: string): TKunReadings;
var lead: string;
  rset: PKunReadingSet;
  rd: PKunReading;
  ps, pc: PChar;
  flag_next_hidden: boolean;
  flag_next_unchecked: boolean;
  flag_slash: boolean;
  req_sep: boolean; //require * or EOF as the next char
  i, j: integer;
  raw: TRawKunReadingSet;
  tmp_str: string;

  procedure CloseReading;
  begin
    rd := nil;
  end;

  procedure CloseSet;
  begin
    CloseReading();
    if rset<>nil then
      FinalizeKunReadingSet(kanji, rset, raw);
    rset := nil;
    raw.Reset;
  end;

  procedure NewSet;
  begin
    CloseSet();
    SetLength(Result, Length(Result)+1);
    rset := @Result[Length(Result)-1];
    FillChar(rset^, SizeOf(rset^), 0);
  end;

  procedure NewReading;
  begin
    CloseReading;
    Check(rset<>nil);
    SetLength(rset.items, Length(rset.items)+1);
    rd := @rset.items[Length(rset.items)-1];
    FillChar(rd^, SizeOf(rd^), 0);
  end;

begin
  FillChar(Result, SizeOf(Result), 0);
  if Length(inp)<=0 then exit;

  flag_next_hidden := false;
  flag_next_unchecked := false;
  flag_slash := false;
  req_sep := false;

  lead := pop(inp,'*');
  rset := nil;
  rd := nil;
  raw.Reset;

  pc := PChar(inp);
  while pc^<>#00 do begin

    if req_sep then begin
      Check(pc^='*', '* required and missing: '+pc);
      req_sep := false
    end;

   //Двойная звёздочка
    if eat(pc,'**') then begin
      flag_next_unchecked := true;
    end else

   //Одиночная звёздочка
    if pc^='*' then begin
      Inc(pc);
     //просто ничего не делаем
    end else

    if pc^='!' then begin
      Check(eat(pc, ['!!','!R ', '!R', '!$'])>=0);
      req_sep := true;
      Check(rset<>nil, 'No open reading set');
      Check(not (ksTranscriptionUnderWord in rset.flags), 'Duplicate !-sequence' );
      rset.flags := rset.flags + [ksTranscriptionUnderWord];
    end else

    if pc^='Q' then begin
      Inc(pc);
      Check(rd<>nil, 'No open reading'); //должно быть, хоть обращаемся и не напрямую
      Check(rset<>nil, 'No open reading set');
      j := EatNumber(pc);
     //#2708: если вариантов чтения несколько, индексация букв i идёт сквозь все
      rset.roma_getNthI(j, i, j);
      Check((i>=0) and (i<Length(rset.items)));
      Check((j>=0) and (j<=Length(rset.items[i].romaji)));
      Insert('´', rset.items[i].romaji, j+1); //insert counts from 1
      req_sep := true;
    end else

    if pc^='V' then begin
     //Непонятные флаги. Просто удаляем
      Check(eat(pc, ['VI','VT','V2'])>=0);
      req_sep := true;
    end else

    if pc^='L' then begin
     //Непонятные флаги
      Check(eat(pc, ['L1'])>=0);
      req_sep := true;
    end else

   //также бывает нормальное тире: *-ni itatte wa. #1108
    if (pc^='-') and IsDigit((pc+1)^) then begin
      Inc(pc);
      Check(rd<>nil, 'No open reading set');
      j := EatNumber(pc);
      i := rd.roma_getPos(j);
      Check((i>=0) and (i<=Length(rd.romaji)));
      Insert('-', rd.romaji, i+1); //insert counts from 1
     //req_sep := true;  //#217
    end else

    if pc^='~' then begin
      Inc(pc);
      Check(rset<>nil, 'No open reading set');
      Check(raw.prefix_chars<=0, 'Duplicate prefix char declaration');
      raw.prefix_chars := EatNumber(pc);
     //req_sep := true;  //Nope: #94
    end else

    if pc^='[' then begin
      Inc(pc);
      Check(rset<>nil, 'No open reading set');
      Check(raw.optional_spans.Length=0, 'Duplicate optional_pos declaration');
      with raw.optional_spans.AddNew^ do begin
        op := EatNumber(pc);
        if pc^='[' then begin
          Inc(pc);
         //доп. блок - такой же
          with raw.optional_spans.AddNew^ do begin
            op := EatNumber(pc);
            Check(pc^=']');
            Inc(pc);
            ed := EatNumber(pc); //во внутр. блоке Яркси требует 2-й части, потребуем и мы
          end;
        end;
        Check(pc^=']');
        Inc(pc);
        if IsDigit(pc^) then //что-то осталось
          ed := EatNumber(pc)
        else
          ed := 0;
      end;
     // req_sep := true; //Nope: #837
    end else

    if pc^='=' then begin
    { Альтернативное написание - поддерживается только ва/ха, как в Яркси }
      Check(rd<>nil, 'Нельзя дать альтернативное чтение без главного');
      Inc(pc);
      Check(pc^='*'); //можно ослабить и сделать if pc^=='*' then Inc(pc);
      Inc(pc);
      tmp_str := EatTranscription(pc);
      Check(tmp_str<>'');
      rd.romaji := CombineAlternativeReading(rd.romaji, tmp_str);

      req_sep := true;
    end else

    if pc^='&' then begin
     { Иногда скрытые чтения присоединяются к совсем непохожим (#13). Может
      показаться, что имелся в виду новый блок. Так ли это - надо подумать...
      Во всяком случае, перевода для скрытого варианта нет (Яркси ошибочно
      лезет за ним в другую часть вообще) }
      Inc(pc);
      Check(not flag_next_hidden, 'Duplicate flag_hidden.');
      flag_next_hidden := true;
      flag_slash := true;
     //req_sep := true;  //Nope, может слипаться с последующими
    end else

    if pc^='/' then begin
      Inc(pc);
      CloseReading();
      flag_slash := true;
      req_sep := true;
    end else

    if pc^='^' then begin
      Check(rset<>nil, 'No open reading set');

      if eat(pc,['^^','^!^'])>=0 then begin
        Check(rset.usually_in=uiNormal, 'Duplicate ^^ flag');
        rset.usually_in := uiHiragana;
      end else

      if eat(pc,'^@') then begin
        Check(rset.usually_in=uiNormal, 'Duplicate ^@ flag');
        rset.usually_in := uiKatakana;
      end else

      if eat(pc,['^#','^!#'])>=0 then begin
        Check(rset.usually_in=uiNormal, 'Duplicate ^# flag');
        rset.usually_in := uiKana;
      end else

     //К сожалению, придётся заниматься проституцией
      if match_targeted_kana_flag(pc) then begin
        Inc(pc,2); //^_
        j := EatNumber(pc);
        if rset.tl_usually_in.Length<j then
          rset.tl_usually_in.SetLength(j+1);
        Check(rset.tl_usually_in[j] = uiNormal);
        if eat(pc,['^^','^!^'])>=0 then begin
          rset.tl_usually_in[j] := uiHiragana;
        end else
        if eat(pc,'^@') then begin
          rset.tl_usually_in[j] := uiKatakana;
        end else
        if eat(pc,'^#') then begin
          rset.tl_usually_in[j] := uiKana;
        end else
          Die('This is goddamn horrible.')
      end else
        rset.refs.Add(ParseCharLink(pc));

     //req_sep := true;  //Nope, бывают цепочки
    end else

    if pc^='#' then begin
      Inc(pc);
      Check(rset<>nil, 'No open reading set');
      ps := pc;
      while IsLatin(pc^) or (pc^='[') or (pc^=']') {#340} do
        Inc(pc);
      Check(pc>ps);
      rset.latin_tail := spancopy(ps, pc);
      while pc^=' ' do Inc(pc); //#34
      req_sep := true;
    end else

    if pc^='+' then begin
      Inc(pc);
      Check(rset<>nil, 'No open reading set');
      Check(not raw.with_kurikaeshi, 'Duplicate +kurikaeshi');
      raw.kuri_chars := EatNumber(pc);
      raw.with_kurikaeshi := true;
      req_sep := true;
    end else

    if pc^='$' then begin
      Check(rset<>nil, 'No open reading set');
      Inc(pc);
      Check(IsDigit(pc^), 'invalid additional_kanji_pos');
      with raw.additional_kanji.AddNew^ do begin
        pos := Ord(pc^)-Ord('0');
        Inc(pc);
        text := ParseAdditionalKanjiChain(pc);
        if pc^='+' then begin
          Inc(pc);
          kuri := true;
          for i := 0 to raw.additional_kanji.Length-2 do
            Assert(not raw.additional_kanji[i].kuri); //допуск.-ся только один доп. кури
        end;
      end;
     //req_sep := true;  //Nope, бывают цепочки
    end else

   //Просто транскрипция
    begin
      tmp_str := EatTranscription(pc);
      //Мы обязаны хоть что-то прочесть, т.к. все флаги мы уже исключили
      Check(tmp_str<>'', 'Cannot parse this part: '+pc);

      if not flag_slash then begin
        NewSet();

       //Съедаем одну позицию из lead
        if lead='' then begin
          Complain('No char coverage data for another reading block');
          raw.main_chars := 0;
        end else begin
         //Расширенная позиция: ^7 == 17
          if lead[1]='^' then begin
            raw.main_chars := 10;
            delete(lead,1,1);
            Check(lead<>'', 'Incomplete char coverage ^expansion');
          end else
            raw.main_chars := 0;

          if lead[1]='_' then begin //похоже, это как ноль
            Complain('lead[i]==_, correcting to 0');
            lead[1]:='0';
          end;

         //Остаток позиции
          Check((lead[1]>='0') and (lead[1]<='9'), 'Invalid char coverage position: '+lead[1]+' (digit expected)');
          raw.main_chars := raw.main_chars + Ord(lead[1])-Ord('0');
          delete(lead,1,1);
        end;
      end else
        flag_slash := false; //слеш работает на одно чтение вперёд

      NewReading();

      if flag_next_hidden then
        rd.flags := rd.flags + [krHidden];
      flag_next_hidden := false;

      if flag_next_unchecked then
        rd.flags := rd.flags + [krUnchecked];
      flag_next_unchecked := false;

      rd.romaji := tmp_str;

     //пробелы
      if (rd.romaji[1]=' ') or (rd.romaji[Length(rd.romaji)]=' ') then begin
        rd.romaji := Trim(rd.romaji);
        rd.flags := rd.flags + [krSpaces];
      end;

     //большие буквы
      rd.romaji := LowerCase(rd.romaji);

     //req_sep := true;  //Nope, возможно, что-то осталось
    end;
  end;

  CloseSet(); //если был

 //Контроль
  if lead<>'' then
    Complain('Остались неразобранные позиции числа символов.');
end;

function match_targeted_kana_flag(pc: PChar): boolean;
begin
  Result := false;
  if pc^<>'^' then exit;
  Inc(pc);
  if pc^<>'_' then exit;
  Inc(pc);
  if not IsDigit(pc^) then exit;
  Inc(pc); //пока допускаем макс. одну цифру
 { Более свободно:
    while IsNumeric(pc^) do Inc(pc);
  Однако так рискуем матчнуть ^_210000^1111. Сейчас не матчнем, т.к. у нас
  дальше требуется ^, @ или #, но если это требование ослабнет... }
  if pc^<>'^' then exit;
  Inc(pc);
  Result := (pc^='^') or (pc^='@') or (pc^='#');
end;

procedure TRawKunReadingSet.Reset;
begin
  Self.prefix_chars := 0;
  Self.main_chars := 0;
  Self.kuri_chars := 0;
  Self.optional_spans.Reset;
  Self.additional_kanji.Reset;
  Self.with_kurikaeshi := false;
end;

{ Преобразует временную сырую информацию о наборе чтений в финальную.
1. Базовый курикаэси (種々). Число kuri_chars задаёт, после какой буквы чтения
вставить кури. Если оно не равно длине корня (явной или неявной), то весь хвост
отбрасывается:
  4*abcdef     = 種ef
  4*abcdef*+4* = 種々ef
  4*abcdef*+6* = 種々
На это код братски закладывается, добавляя недостающий хвост как latin_tail.
Хочется взять и уверстать.

2. Сколько бы ни было $доп.кандзи, от стандартного чтения по-прежнему
добавляется хвост после всего. Если был кури, он добавляется перед хвостом.

3. Вхождений $доп.кандзи может быть несколько. Кандзи-позиций перед хвостом
выделяется столько, какой макс. номер вхождения + длина. Вхождения могут
оставлять дыры ($1..$3..) или перекрываться ($1''sou''$2''u'' - u в кане
накрываются).

4. Вторичный кури допускается только один. После него обрезаются остальные
вхождения, в т.ч. последующие вторичные кури.
Если присутствует вторичный кури, любой канахвост переносится после первого
кандзи:
  К1_канахвост_К2_К3_вторкури
Первичный кури вторичному не обязателен. Цифры после + не требуются и
игнорируются. }
procedure FinalizeKunReadingSet(const kanji: string; rset: PKunReadingSet;
  const raw: TRawKunReadingSet);
var i, main_chars: integer;
  rd: PKunReading;
  ak: PAdditionalKanji;
  prefix: string;
  kana_tail: string;
  add_kanji_tail: string;
  had_secondary_kuri: boolean;
begin
  Check(Length(rset.items)>0); //иначе странно

 { Если вариантов несколько, по факту Яркси просто использует для вычислений
  первый, а остальные просто пишет каной. Хотелось бы что-то проверить (длину,
  совпадение хвоста), но к сожалению, они могут различаться практически во всём. }
  rd := @rset.items[0];

  if raw.main_chars>0 then
    main_chars := raw.main_chars
  else
    main_chars := rd.roma_getLen;

 { Непонятно, как опциональные части должны взаимодействовать с каной.
  Требуем, чтобы все были в хвосте }
  for i := 0 to raw.optional_spans.Length-1 do begin
    Check(raw.optional_spans[i].op>=main_chars);
    Check(raw.optional_spans[i].ed>=main_chars);
  end;

  if raw.prefix_chars>0 then begin
    prefix := RomajiToKana(clearMarks(
      copy(rd.romaji, 1, rd.roma_getPos(raw.prefix_chars))
    ));
  end else
    prefix := '';

 //Доп. символы -- не сразу в rset.kanji, их может потребоваться пристроить
 //в разные места
  add_kanji_tail := '';
  had_secondary_kuri := false;
  for i := 0 to raw.additional_kanji.Length-1 do begin
    ak := PAdditionalKanji(raw.additional_kanji.GetPointer(i));
    while ak.pos-1>Length(add_kanji_tail) do
      add_kanji_tail := add_kanji_tail + ' ';
    add_kanji_tail :=
      copy(add_kanji_tail, 1, ak.pos-2)
      +clearMarks(ak.text)
      +copy(add_kanji_tail, ak.pos-1+Length(ak.text)-1, MaxInt);
  end;

  rset.kanji := kanji;
  if not had_secondary_kuri then
    rset.kanji := rset.kanji + add_kanji_tail;

 //Главный курикаэси - перед хвостом
  if raw.with_kurikaeshi then
    rset.kanji := rset.kanji + '々';

 { Вставляем кв. скобки. Вообще говоря, Яркси вставляет их только в кандзи-версию,
  а все варианты каны оставляет без них. Однако нумеруются они именно в кане.
  Логично вставлять их и туда, но версий каны может быть несколько, и к другим
  они уже не подойдут (длина другая, корень другой, окончание другое).

  Однако наблюдается, что Яркси как раз это и использует: если часть кандзи
  опциональна, в записи есть соотв. число вариантов каны.
  TODO: Определять такие варианты и объединять. }
  for i := 0 to raw.optional_spans.Length-1 do begin
    Insert('[', rd.romaji, rd.roma_getPos(raw.optional_spans[i].op+1));
    Insert(']', rd.romaji, rd.roma_getPos(raw.optional_spans[i].ed+1));
  end;

 //Хвост
  if raw.with_kurikaeshi and (raw.kuri_chars<>main_chars) then begin
   //Хвост не показывается. Так в Яркси, и он даже на это рассчитывает.
    kana_tail := '';
  end else begin
   //Обычный хвост
    kana_tail := RomajiToKana(clearMarks(
        copy(rd.romaji, main_chars+1, MaxInt)
      ));
  end;
  rset.kanji := rset.kanji + kana_tail;

 //Дополняем хвостом ссылки, которым это нужно
  for i := 0 to rset.refs.Length-1 do begin
   { Дополняются ссылки из единственного кандзи, также ссылки вида 因/由 #45 }
   // if Length(rset.refs[i].text)=1 then //один-единственный кандзи.. я надеюсь
    rset.refs.GetPointer(i).text := rset.refs.GetPointer(i).text+kana_tail;
  //А префикс не нужно ли? Курикаэси?
  end;


  if had_secondary_kuri then //если был вторичный кури, то доп. кандзи после хвоста
    rset.kanji := rset.kanji + add_kanji_tail;

 //Префикс
  rset.kanji := prefix + rset.kanji;

 //Остальным просто кану
  for i := 0 to Length(rset.items)-1 do
    rset.items[i].kana := RomajiToKana(clearMarks(rset.items[i].romaji));
end;

{
Формат ссылок на кандзи: ^[цифра][номер]-''текст''-[номер]=[номер слова]
Все части, кроме ^[цифра][номер] опциональны.
Цифра:
  0 = см.
  1 = ср.
  2 = ?????
  3 = реже
  4 = иначе
  5 = чаще
  6 = синоним
  7 = антоним
  8 = не путать с
  9 = ранее
  r = ранее так же
  t = теперь
  i = иногда так же
  z = как замена
  m = ошибочно вместо
  всё остальное = ??????
^[цифра][номер]-[номер] === несколько кандзи подряд
^[цифра][номер]-''[текст]'' === доп. текст хираганой
^<блок>=[номер слова] === сделать весь блок ссылкой на указанное слово
По умолчанию ссылка присоединяется к последнему варианту перевода
^_[цифра]<блок> === присоединить ссылку к n-му варианту перевода из нескольких
^:<блок> === присоединить ссылку ко всем вариантам перевода
^::[2 цифры]<блок> === присоединить ссылку к n-му и m-му вариантам перевода
  /  палка между кандзи (1172/8654)
^!<блок> === поставить ссылку слева от вариантов перевода (под словом)
^- === присоединить ссылку к первой строчке перевода. Немного отличается от
  ^_цифра, т.к. вариант перевода может быть всего один, нулевой, а строчек
  несколько.
^+ === только для блоков 2+: начать с новой строки, а не продолжать старую.
Также бывает:
  ^4''текст''номер
Тогда в чём смысл тире? Неизвестно, но без тире Яркси с длинными цепочками не
справляется (>2 эл-тов).

Похоже, если у кандзи нет доп. хвоста (?), присоединяется стандартный хвост из
соотв. чтения главного кандзи.
Нужно разобраться и подставлять в конце.
}
function ParseCharLink(var pc: PChar): TCharLink;
var i, tmp_int: integer;
  ps: PChar;
begin
  FillChar(Result, SizeOf(Result), 0);
  Check(pc^='^', 'Invalid start mark');
  Inc(pc);

  if pc^='+' then begin
    Inc(pc);
    Result.pos := lpNewline;
  end else
  if pc^='-' then begin
    Inc(pc);
    Result.pos := lpFirstLine;
  end else
  if pc^='_' then begin
    Inc(pc);
    Check((pc^>='0') and (pc^<='9'), 'Invalid tl-variant index');
    Result.pos := lpOneClause;
    Result.posfrom := Ord(pc^)-Ord('0');
    Inc(pc);
  end else
  if pc^=':' then begin
    Inc(pc);
    if pc^=':' then begin
      Result.pos := lpFromTo;
      Inc(pc);
      Check((pc^>='0') and (pc^<='9'), 'Invalid tl-variant index');
      Result.posfrom := Ord(pc^)-Ord('0');
      Inc(pc);
      Check((pc^>='0') and (pc^<='9'), 'Invalid tl-variant index');
      Result.posto := Ord(pc^)-Ord('0');
      Inc(pc);
    end else
      Result.pos := lpAllClauses;
  end else
  if pc^='!' then begin //#356
    Inc(pc);
    Result.pos := lpKanji;
  end else
    Result.pos := lpDefault;

  if ((pc^>='0') and (pc^<='9')) or (pc^='r') or (pc^='t') or (pc^='i')
  or (pc^='z') or (pc^='m') then
    Result._type := pc^
  else
    Die('Invalid type: '+pc^);
  Inc(pc);

  Result.text := '';
  while pc^<>#00 do begin
    if pc^='''' then begin
      Check((pc+1)^='''', 'invalid singular '' mark');
      pc := pc+2;
      ps := pc;
      while (pc^<>#00) and (pc^<>'''') do
        Inc(pc);
      Check(pc^<>#00, 'invalid unclosed text element');
      Check((pc+1)^='''', 'invalid singular '' mark');
      Result.text := Result.text + spancopy(ps,pc);
      pc := pc+2;
    end else
   //Допустимые печатные символы
    if (pc^='/') then begin
      Result.text := Result.text + pc^;
      Inc(pc);
    end else
   //Разделитель. Необязателен, но обычно присутствует. С длинными цепочками
   //без разделителя Яркси не справляется.
    if pc^='-' then begin
     //просто пропускаем
      Inc(pc);
    end else
   //Число
    if IsDigit(pc^) then begin
      tmp_int := 0;
      for i := 1 to 4 do begin
        Check((pc^>='0') and (pc^<='9'), 'invalid charref');
        tmp_int := tmp_int * 10 + Ord(pc^)-Ord('0');
        Inc(pc);
      end;
      Result.text := Result.text + getKanji(tmp_int);
    end else
   //Что-то другое => конец цепочки
      break;
  end;

 //Последняя часть
  Result.wordref := 0;
  if pc^='=' then begin
    Inc(pc);
    while (pc^>='0') and (pc^<='9') do begin
      Inc(pc);
      Result.wordref := Result.wordref * 10 + Ord(pc^)-Ord('0');
    end;
  end;
end;

{ Цепочка вида номер''текст''[номер]номер, встречающаяся в KunYomi при вставке
 дополнительных кандзи }
function ParseAdditionalKanjiChain(var pc: PChar): string;
var ps: PChar;
begin
 {
  Вообще говоря, цепочка может быть любой, но Яркси поступает по разному в
  зав-ти от того, начинается она с кандзи или текста.
  Если с кандзи то корень слова вышибает в начало канахвоста:
    __К1_текст_К0_канахвост
  Если с текста, то оставляет на месте:
    K0_текст_K1_канахвост
 }
  Result := '';
  while pc^<>#00 do begin

   //Текст каной
    if pc^='''' then begin
      Inc(pc);
      Check(pc^='''');
      Inc(pc);
      ps := pc;
      while (pc^<>#00) and (pc^<>'''') do
        Inc(pc);
      Check(pc^<>#00);
      Result := Result + KanaTran.RomajiToKana(spancopy(ps,pc), []);
      Check(pc^='''');
      Inc(pc);
      Check(pc^='''');
      Inc(pc);
    end else
   //Допустимые символы
    if (pc^='[') or (pc^=']') then begin
      Result := Result + pc^;
      Inc(pc);
    end else
   //Число (номер кандзи)
    if IsDigit(pc^) then begin
      Result := Result + getKanji(EatNumber(pc)); //надеюсь, два подряд не бывает..
    end else
      break; //неизвестный символ => выходим
  end;
end;


{
Поле: Kanji.KunYomi, блок CompoundReadings.
Формат:
  AISO_AISOX/AISO2,ASIO2X_AISO2Y-AISO2Z/AISO3
  => aiso, реже aisox;
     aiso2, aiso2x, реже aiso2y, aiso2z;
     aiso3
  U,HA,HANE
Разделители:
  /   следующий набор
  ,   следующее чтение
  _   следующее редкое чтение
  -   ничего не значит, обычный символ
}
function ParseKanjiCompoundReadings(inp: string): TCompoundReadings;
var ps, pc: PChar;
  rset: PCompoundReadingSet;
  next_type: TCompoundReadingType;

  procedure CommitReading;
  begin
    if pc<=ps then exit;
    if rset=nil then begin
      SetLength(Result, Length(Result)+1);
      rset := @Result[Length(Result)-1];
      SetLength(rset^, 1);
    end else
      SetLength(rset^, Length(rset^)+1);
    rset^[Length(rset^)-1]._type := next_type;
    rset^[Length(rset^)-1].text := spancopy(ps, pc);
  end;

begin
  SetLength(Result, 0);
  if inp='' then exit;

  rset := nil;
  next_type := ctCommon;

  pc := PChar(inp);
  ps := pc;
  while pc^<>#00 do begin

    if pc^='/' then begin
      CommitReading;
      rset := nil;
      next_type := ctCommon;
      ps := pc+1;
    end else

    if pc^=',' then begin
      CommitReading;
      ps := pc+1;
    end else

    if pc^='_' then begin
      CommitReading;
      next_type := ctRare;
      ps := pc+1;
    end else

    begin
      //nothing
    end;

    Inc(pc);
  end;

  CommitReading;
end;

function DumpKanjiCompoundReadings(const AReadings: TCompoundReadings): string;
var i: integer;
begin
  if Length(AReadings)<=0 then begin
    Result := '';
    exit;
  end;
  Result := DumpKanjiCompoundReadingSet(AReadings[0]);
  for i := 1 to Length(AReadings)-1 do
    Result := Result + '; ' + DumpKanjiCompoundReadingSet(AReadings[i]);
end;

function DumpKanjiCompoundReadingSet(const AReadingSet: TCompoundReadingSet): string;
var i: integer;
begin
  if Length(AReadingSet)<=0 then begin
    Result := '';
    exit;
  end;
  Result := DumpKanjiCompoundReading(AReadingSet[0]);
  for i := 1 to Length(AReadingSet)-1 do
    Result := Result + ', ' + DumpKanjiCompoundReading(AReadingSet[i]);
end;

function DumpKanjiCompoundReading(const AReading: TCompoundReading): string;
begin
  case AReading._type of
    ctCommon: Result := 'C:';
    ctRare: Result := 'R:';
  else
    raise Exception.Create('DumpKanjiCompoundReading: Unexpected name reading type');
  end;
  Result := Result + AReading.text;
end;



{
Поле: Kanji.KunYomi, блок NameReadings.
Формат: [в именах]|[также]|[реже]-[скрыто]
Любые блоки могут отсутствовать, но появляются последовательно:
  [в именах]||[реже]
Исключение: || в начале - то же, что |           (#4)
Исключение: -[скрыто] обрывает цепочку.
  [в именах]-[скрыто]|[всё равно скрыто]
  [в именах]-[скрыто]-[скрыто]
Формат блока: $чтение$чтение$
В мягком режиме:
  - деление запятой $чтение,чтение$ (яркси это терпит)
  - отсутствие $рамок$
}
function ParseKanjiNameReadings(const inp: string): TNameReadings;
var blockType: TNameReadingType;
  pc, ps: PChar;
  readingSetOpen: boolean; //видели $ после прошлого | или -

 //ps должен стоять на начальном символе $, pc на конечном.
  procedure CommitReading;
  begin
    if ps>=pc then exit;
    if (ps+1=pc) and (ps^=' ') then
      exit; //Яркси любит такие пустые пробельные позиции, но по сути не нужны
    SetLength(Result, Length(Result)+1);
    Result[Length(Result)-1]._type := blockType;
    Result[Length(Result)-1].text := spancopy(ps,pc);
  end;

begin
  SetLength(Result, 0);
  if inp='' then exit;

  blockType := ntCommon;
  readingSetOpen := false;
  pc := PChar(inp);
  if pc^='|' then Inc(pc); // иногда лишний | в начале, см. формат
  ps := pc;
  while pc^<>#00 do begin
    if pc^='|' then begin
     {$IFDEF FORGIVING}
      CommitReading;
     {$ELSE}
      if ps<pc then
        raise Exception.Create('ParseKanjiNameReadings: No closing tag for a reading');
     {$ENDIF}
      case blockType of
        ntCommon: blockType := ntOccasional;
        ntOccasional: blockType := ntRare;
      else //rare or hidden
        raise Exception.Create('ParseKanjiNameReadings: additional | not allowed.');
      end;
      ps := pc+1;
      readingSetOpen := false;
    end else

   //note: могут быть и как часть текста: $asd$-bsd$  $asd-$bsd$
    if (pc^='-') and ((pc+1)^='$') and (ps>=pc) then begin
     {$IFDEF FORGIVING}
      CommitReading;
     {$ELSE}
      if ps<pc then
        raise Exception.Create('ParseKanjiNameReadings: No closing tag for a reading');
     {$ENDIF}
      blockType := ntHidden;
      ps := pc+1;
      readingSetOpen := false;
    end else

    if pc^='$' then begin
      CommitReading; //если это переключатель
      readingSetOpen := true;
      ps := pc+1;
    end else

    begin
     {$IFNDEF FORGIVING}
      if not ReadingSetOpen then
        raise Exception.Create('ParseKanjiNameReadings: No opening tag for a reading');
     {$ENDIF}
    end;

    Inc(pc);
  end;

  CommitReading;
end;

function DumpKanjiNameReadings(const AReadings: TNameReadings): string;
var i: integer;
begin
  if Length(AReadings)<=0 then begin
    Result := '';
    exit;
  end;
  Result := DumpKanjiNameReading(AReadings[0]);
  for i := 1 to Length(AReadings)-1 do
    Result := Result + ', ' + DumpKanjiNameReading(AReadings[i]);
end;

function DumpKanjiNameReading(const AReading: TNameReading): string;
begin
  case AReading._type of
    ntCommon: Result := 'C:';
    ntOccasional: Result := 'O:';
    ntRare: Result := 'R:';
    ntHidden: Result := 'H:';
  else
    raise Exception.Create('DumpKanjiNameReading: Unexpected name reading type');
  end;
  Result := Result + AReading.text;
end;

{
Ссылки на связанные кандзи. Присутствуют в заголовке Kanji.Russian, может быть
несколько (даже одного типа).
 *[буква][номер] - большая теневая ссылка справа
 $[буква][номер] - маленькая ссылка возле знака
 ^[буква][номер] - маленькая ссылка под названием кандзи
Кодировка буквами во всех случаях разная, но пока общей вводить мы не будем.
}
function match_related_kanji(var pc: PChar; out link: TRelatedKanjiLink): boolean;
begin
  if pc^='*' then
    link.pos := rpBigGray
  else
  if pc^='$' then
    link.pos := rpUnderKanji
  else
  if pc^='^' then
    link.pos := rpUnderNickname
  else begin
    Result := false;
    exit;
  end;
  Inc(pc);

 //Допустимые буквы
  case link.pos of
    rpBigGray: Check(IsDigit(pc^) or (pc^='?'));
    rpUnderNickname: Check(IsDigit(pc^) or (test_char(pc^, 'oimrsStvzZ')>0));
  else Check(IsDigit(pc^));
  end;
  link._type := pc^;
  Inc(pc);

 //Номер ровно 4 цифры -- дальше могут быть другие цифры #945
  link.text := getKanji(EatNumber(pc, 4));
  Result := true;
end;


{
Поле: Kanji.Russian.
Формат: <префиксы>KunyomiMeanings|CompoundMeanings
Перед вызовом конвертируйте русские буквы и удалите из строки все "\" (мусор).

Общее:
    #курсив#
    | отделяет блок трактовок кун-ёми от блока описаний сочетаний
    / разделяет значения в блоках
    \ по-видимости, мусор, разделяющий значения, чтобы проще было делать поиск по
      одному из них

Префиксы:
 ~    Отсутствует в словаре Фельдман-Конрад
 ~~   В словаре Фельдман-Конрад представлен устаревшей формой
 ~~~  В словаре Фельдман-Конрад представлен оригинальной формой
 ~~~~ В словаре Фельдман-Конрад представлен упрощённой формой
 *[код], $[код], ^[код] - ссылки на связанные кандзи
}
function ParseKanjiRussian(inp: string): TRussianMeanings;
var pc: PChar;
  tmp_int: integer;
  rel_kanji: TRelatedKanjiLink;
begin
  FillChar(Result, SizeOf(Result), 0);
  if Length(inp)<=0 then exit;

  pc := PChar(inp);
  while pc^<>#00 do begin
   //Ссылки на связанный знак
    if (pc^='*') or (pc^='$') or (pc^='^') then begin
      Check(match_related_kanji(pc, rel_kanji));
      Result.related_kanji.Add(rel_kanji);
    end else
   //Флаг словаря Фельдман-Конрад
    if pc^='~' then begin
      Check(Result.fk_flag=fkNone); //два фк-флага нельзя
      tmp_int := 0;
      while pc^='~' do begin
        Inc(tmp_int);
        Inc(pc);
      end;
      case tmp_int of
        1: Result.fk_flag := fkMissing;
        2: Result.fk_flag := fkDeprecated;
        3: Result.fk_flag := fkOriginal;
        4: Result.fk_flag := fkSimplified;
      else Die('Неверный флаг Фельдман-Конрад');
      end;
    end else
      break;
  end;

  Result.kunyomi := ParseKanjiKunyomiMeanings(trypop(pc,'|'));
  Result.compound := ParseKanjiCompoundMeanings(inp);
end;

//Возвращает первую букву последнего слова в строке
function FindWordStartOffset(const text: string): integer;
var i: integer;
begin
  Result := 0; //не нашёл
  for i := Length(text) downto 1 do
    if not IsLatin(text[i]) and not IsCyrillic(text[i]) then begin
      Result := i;
      break;
    end;
  Inc(Result);
end;


{ Выбирает из строки суффикс в форматах ~i, ~~i, ~~~i, ~=ii, ~-i.
Возвращает его текстовое представление.
Формат:
 ~i] - то же, но в суффикс кв. скобках: ~[ni] }
function match_suffix(var pc: PChar; out postfix: string): boolean;
var tmp_int: integer;
begin
  if pc^<>'~' then begin
    Result := false;
    exit;
  end;
  Inc(pc);

  Result := true;
  case pc^ of
    '0': postfix := 'shita';
    '1': postfix := 'suru';
    '2': postfix := 'na';
    '3': postfix := 'no';
    '4': postfix := 'ni';
    '5': postfix := 'de';
    '6': postfix := 'to';
    '7': postfix := 'taru';
    '8': postfix := 'shite';
    '9': postfix := 'shite iru';
    '-': begin
      Inc(pc);
      case pc^ of
        '0': postfix := '(-wa)';
        '1': postfix := '(-kara)';
        //'2': postfix := '(-made)???????';
        '3': postfix := '(-no)';
        '4': postfix := '(-ni)';
        //'5': postfix := '(-de)????????';
        '6': postfix := '(-to)';
        '7': postfix := '(-wo)';
        '8': postfix := '(-ga)';
        '9': postfix := '(-suru)';
        '@': postfix := '(-to shite)';
        //'+': postfix := '(-shita)????????';
        //'=': postfix := '(shite iru)??????';
      else postfix := '(-demo)'; //~-something_else //TODO: Does this really work? No collisions?
      end;
    end;
    '~': begin
      Inc(pc);
      case pc^ of
        '0': postfix := 'o suru';
        '1': postfix := 'ga aru';
        '2': postfix := 'no aru';
        '3': postfix := 'no nai';
        '4': postfix := 'de aru';
        '5': postfix := 'des'; //From yarxi.pl: TODO: check #42
        '6': postfix := 'da';
        '7': postfix := 'ni suru';
        '8': postfix := 'ni naru';
        '9': postfix := 'to shite';
        '~': begin
          Inc(pc);
          case pc^ of
            '0': postfix := 'naru';
            '1': postfix := 'kara';
            '2': postfix := 'made';
            '3': postfix := 'mo';
            '4': postfix := 'wa';
            '5': postfix := 'to suru';
            '6': postfix := 'yori';
            '7': postfix := 'ga shite iru';
            '8': postfix := 'to shita';
            '9': postfix := 'to shite iru';
          else
            Dec(pc,4);
            Result := false;
          end;
        end
      else
        Dec(pc,3);
        Result := false;
      end;
    end;
    '=': begin
      Inc(pc);
     //Переводим 2 байта в число.
      if IsDigit(pc^) and IsDigit((pc+1)^) then
        tmp_int := DigitToInt(pc^)*10+DigitToInt((pc+1)^)
      else
        tmp_int := -1; //негодное
      case tmp_int of
        00: postfix := '!';
        01: postfix := 'aru';
        02: postfix := 'atte';
        03: postfix := 'ga nai';
        04: postfix := 'ga atte';
        05: postfix := 'ga shite aru';
        06: postfix := 'ga suru';
        07: postfix := 'de mo';
        08: postfix := 'de wa';
        09: postfix := 'de nai';
        10: postfix := 'de (~ni)';
        11: postfix := 'des ka?';
        12: postfix := 'deshita';
        13: postfix := 'de suru';
        14: postfix := 'ka';
        15: postfix := 'made mo';
        16: postfix := 'mo nai';
        17: postfix := '[mo] nai';
        18: postfix := 'mo naku';
        19: postfix := 'nagara';
        20: postfix := 'nai';
        21: postfix := 'na (~no)';
        22: postfix := 'narazaru';
        23: postfix := 'narazu';
        24: postfix := 'na[ru]';
        25: postfix := 'nasai';
        26: postfix := 'nashi no';
        27: postfix := 'naki';
        28: postfix := 'naku';
        29: postfix := 'ni (~wa)';
        30: postfix := 'ni (~de)';
        31: postfix := 'ni mo';
        32: postfix := 'teki';
        33: postfix := 'ni shite';
        34: postfix := 'ni [shite]';
        35: postfix := 'ni nai';
        36: postfix := 'ni natte';
        37: postfix := 'ni natte iru';
        38: postfix := 'ni aru';
        39: postfix := 'ni sareru';
        40: postfix := 'ni iru';
        41: postfix := 'ni naranai';
        42: postfix := 'sarete';
        43: postfix := '[ni] suru';
        44: postfix := 'ni yaru';
        45: postfix := '[no] aru';
        46: postfix := 'no shita';
        47: postfix := 'no shinai';
        48: postfix := 'no suru';
        49: postfix := 'wo';
        50: postfix := '[wo] suru';
        51: postfix := 'wo shite iru';
        52: postfix := 'wo shita';
        53: postfix := 'wo yaru';
        54: postfix := 'saseru';
        55: postfix := 'sareru';
        56: postfix := 'shite aru';
        57: postfix := 'su';
        58: postfix := 'shimas';
        59: postfix := 'shinai';
        60: postfix := 'sezuni';
        61: postfix := 'seru';
        62: postfix := 'to naru';
        63: postfix := 'to saseru';
        //64: postfix := '???';
        65: postfix := '[to] shita';
        66: postfix := 'to [shite]';
        67: postfix := 'to mo';
        68: postfix := '[to] mo sureba';
        69: postfix := 'to nareba';
        70: postfix := 'to [naku]';
        71: postfix := 'e';
        72: postfix := 'sarate iru';
        73: postfix := 'ga gotoshi';
        74: postfix := 'da kara';
        75: postfix := 'dake no';
        //'76: postfix := '???';
        77: postfix := 'mono';
        78: postfix := 'naru';
        79: postfix := 'naraba';
        80: postfix := 'naranu';
        81: postfix := 'narashimeru';
        82: postfix := 'ni [natte]';
        83: postfix := 'o shinai';
        84: postfix := 'wo shite';
        85: postfix := 'shinagara';
        86: postfix := 'subeki';
        87: postfix := 'sureba';
        88: postfix := 'shitemo';
        89: postfix := 'to mo shinai';
        90: postfix := 'yaru';
        91: postfix := 'to natte';
        92: postfix := 'suruna';
        93: postfix := 'ni oite';
      end;
    end;
  else
    Dec(pc, 2);
    Result := false;
  end;
  Inc(pc);

 //Что-то матчнули
  if Result and (pc^=']') then begin
    postfix := '['+postfix+']';
    Inc(pc);
  end;
end;

{
Формат квадратных скобок из Kanji.Russian/KunyomiMeanings:
[''текст'']   текст красным, в скобках     (''текст'')
[''^текст'']  => (от ''текст'')
[''=текст'']  => (= ''текст'')
[''-текст'']  простой текст без скобок:    ''текст''
[''^o:sho:]   бывает, что кавычки не закрыты, яркси закрывает
Несколько элементов:
  [''-de aru'', ''-shite aru'', ''koto-ga aru'']
  Первый ''- задаёт формат (см. выше), и отображается без тире, если нужно тире,
  ставьте их два: [[''--de aru'']]. Остальные как есть: (''-shite aru'').
}
function parse_kmeaning_sq_brackets(var pc: PChar): string;
var ps: PChar;
  flag_no_outer_brackets: boolean; //внешних скобок нет (закрывающая не нужна)
  flag_inner_brackets: boolean; //внутренние кв. скобки
begin
  Inc(pc);
  Check(pc^='''');
  while pc^='''' do Inc(pc);

  flag_no_outer_brackets := false;
  flag_inner_brackets := false;

  if pc^='-' then begin
    Result := '''''';
    flag_no_outer_brackets := true;
    Inc(pc);
  end else
  if pc^='^' then begin
    Result := '(от ''''';
    Inc(pc);
  end else
  if pc^='=' then begin {#2317}
    Result := '(= ''''';
    Inc(pc);
  end else
    Result := '(''''';

 //Вытаскиваем содержимое, оно требует спец. разбора
  ps := pc;
  while pc^<>#00 do begin
    if IsLatin(pc^) or IsDigit(pc^){#343} or (test_char(pc^, ' :-.')>0) {#343, #866}
    or (pc^='''') {#630 одиночное ' встречается в транскрипциях}{#2739: двойное ' встречается из-за списков}
    or (pc^=',') {#2739: списки через запятую}
    then
      Inc(pc)
    else
    if pc^='>' then begin //замена вложенным кв. скобкам
      if flag_inner_brackets then
        Result := Result + spancopy(ps,pc) + '['
      else
        Result := Result + spancopy(ps,pc) + '[';
      flag_inner_brackets := not flag_inner_brackets;
      Inc(pc);
      ps := pc;
    end else
    if (pc^=']') then begin
      break; //конец скобки
    end else
      Die('Недопустимый символ в кв. скобках');
  end;

  Check(not flag_inner_brackets);

 //Последние кавычки Яркси закрывает автоматически, но не прочие.
  if (Length(Result)<1) or (Result[Length(Result)]<>'''') then
    Result := Result + '''''';

  if not flag_no_outer_brackets then
    Result := Result + ')';
  Check(pc^=']');
  Inc(pc);
end;


(*
Поле: Kanji.Russian, блок KunyomiMeanings.
Формат: значение,в разных,вариантах/значение/значение
Подробности:
 _        пустой элемент (если зачем-то нужен по индексам)
 =        далее - название, наименование; если KanjiKunyomi достаточно пуст,
          номинальное значение
          ПРОБЛЕМА: непонятно, до какого места это длится. До переноса? Нового
          пункта? Запятой?
 ^1234    символ со ссылкой прямо в строке, без пояснения
 +        перенос строки в этом месте (инлайн). Мало что значит, т.к. ставится
          даже в середине фразы, если та не влезает.
 ++       перенос строки и начало новой левее кандзи, без отступа (для длинных)
 &        начало нового пункта. Текст до первого & - без номера
 @[цифра] частые выражения (напр. "и т.п.") (инлайн)
 @@       оно же (@ вместо цифры)
 ()       скобки. Текст внутри - курсив. Если внутри перенос, курсив за ним
          явно: (общее название+#нескольких декоративных растений)
 (##)     скобки без курсива (с его отменой). После переносов, соотв., тоже не восст.
 (!3)     ударение на i-й букве в предшествующем слове
 ~i и др. "при употреблении с таким суффиксом" (встречается инлайн) -
          см. match_suffix
 >        ближайший кусок текста - вступление ко всем последующим пунктам.
          Что такое кусок - точно неясно, но #италик# и @7-частое  - это куски.
          Затем должно сразу идти &, но если есть ещё текст - это обычный
          нулевой пункт.
 {текст}  текст синим ссылочным цветом, вынесен в конец строки         #127
 Поддерживает спец. префиксы:
   +      на новой строке, в центре
   +_     на новой строке, слева
   ++     через одну строку, в центре
   ++_    через одну строку, слева
   ^1234  вставка кандзи (в любом месте)

 [''кв. скобки'']  - см. match_kmeaning_sq_brackets


Ещё не реализовано:


Похоже, это в правой части:
{^^12345}    ссылка от этого значения; коды те же, что в ParseCharLink
{^^^}


*)
function ParseKanjiKunyomiMeanings(inp: string): TKunyomiMeanings;
var ps, pc: PChar;
  tmp_int: integer;
  block: PKunyomiMeaningBlock;
  clause: PKunyomiMeaningClause;
  entry: PKunyomiMeaningSuffixedEntry;
  flag_brackets: boolean;
  flag_brackets_noitalic: boolean;
  flag_curly_brackets: boolean;

 //Открывает новые block, clause или entry, если открытых нет
  procedure NeedBlock;
  begin
    if block=nil then
      block := PKunyomiMeaningBlock(Result.AddNew);
  end;

  procedure NeedClause;
  begin
    NeedBlock;
    if clause=nil then
      clause := PKunyomiMeaningClause(block.clauses.AddNew);
  end;

  procedure NeedEntry;
  begin
    NeedClause;
    if entry=nil then
      entry := PKunyomiMeaningSuffixedEntry(clause.entries.AddNew);
  end;

 //Закрывает любые открытые entry, clause или block, даже пустые.
  procedure EndEntry;
  begin
    entry := nil;
  end;

  procedure EndClause;
  begin
    EndEntry;
    clause := nil;
  end;

  procedure EndBlock;
  begin
    EndClause;
    block := nil;
  end;

 //Прибавляет выбранный непустой кусок текста к текущему block>clause>entry
 //Если их нет, открывает по необходимости.
  procedure CommitText;
  begin
    if pc<=ps then exit; //текста пока не было
    while ps^='_' do Inc(ps); //ради пустых элементов "_"
    Check(pc>=ps); //теперь уже пустой текст оставляем - нас попросили

    NeedEntry;
    entry.text := entry.text + spancopy(ps, pc);
  end;

 { Закрывает "общий clause", если он был.
   Вызывать только после элементов, которые *явно* закрывают common_clause и
   переключают на обычный нулевой clause. И только стоя на след. символе.
   Открытие ненулевого clause закрое common_clause обычным образом, и это хорошо,
   т.к. новому clause там будет выдан номер 1, а здесь следующий NeedClause
   выдаст 0 по дефолту }
  procedure EndCommonClause;
  begin
    if (clause=nil) or not clause.common_clause then exit;
    CommitText;
    EndClause;
   //По идее после окончания common_clause не должно быть текста в нулевой
   //кляузе, однако #1995
   // Check((pc^=#00) or (pc^='&') or (pc^='/'));
  end;

begin
  Result.Clear;
  if inp='' then exit;

  block := nil;
  clause := nil;
  entry := nil;

  flag_brackets := false;
  flag_brackets_noitalic := false;
  flag_curly_brackets := false;

  pc := PChar(inp);
  ps := pc;
  while pc^<>#00 do begin

   //Следующий перевод
    if pc^='/' then begin
      CommitText;
      EndBlock;
     //Наличие палки означает, что блок всё-таки должен начаться,
     //как бы там ни было с содержимым
      NeedBlock;
      Inc(pc);
      ps := pc;
    end else

   //Перенос строки
    if pc^='+' then begin
      CommitText;
      NeedEntry;
     //Перенос строки мало что значит, т.к. ставится по графическим соображениям
     //(влазит ли строка в интерфейсе Яркси). Игнорируем его. Разве что ; добавляем,
     //они не везде перед переносом.
      if (entry.text<>'') and (entry.text[Length(entry.text)]<>';')
      and (entry.text[Length(entry.text)]<>',') then
        entry.text := entry.text + ';';
      Inc(pc);
     //См. комментарий к разбору () скобок
      if flag_brackets then begin
        while pc^='+' do Inc(pc); //Иногда переносов несколько подряд #127
        if not flag_brackets_noitalic then begin
          Check(pc^='#'); //чисто из интереса - есть ли случаи, где италик забыт?
          Inc(pc); //пропускаем
        end else
          Check(pc^<>'#');
      end;
      ps := pc;
    end else

   //Следующий пункт
    if pc^='&' then begin
      CommitText;
      EndClause;
      NeedBlock; //но пока не новую кляузу
     //Следующий номер зависит от того, что уже есть. Может ничего не быть,
     //быть нулевой блок, общий нулевой блок или несколько блоков
      if block.clauses.Count=0 then
        tmp_int := 1 //Явно открытые кляузы нумеруются с единицы
      else
        tmp_int := block.clauses.LastPointer^.index+1;
     //А автоматически открытая без & кляуза будет иметь номер 0, как и надо
      NeedClause;
      clause.index := tmp_int;
      Inc(pc);
      ps := pc;
    end else

   //Новый префикс для последующего
    if pc^='~' then begin
      CommitText; //закрываем старое
      if (entry<>nil) and (entry.text<>'') then
        EndEntry;
      NeedEntry;

     //Необязательно проверки на вшивость
      Check(not flag_brackets);

     //Разбор
      Check(match_suffix(pc, entry.suffix));
      ps := pc;
    end else

   //Текст специальным ссылочным цветом
    if pc^='{' then begin
      Check(not flag_curly_brackets);
     //Содержимое пишем в тот же блок, но, пожалуй, обернём его фигурными
     //скобками, чтобы можно было потом разобраться.
      Inc(pc); //скобочку тоже записываем
      CommitText;
     //блок не сбрасываем
     //Наплевать на переносы и размещение по строкам. Блин! Кто всё это придумал.
      while pc^='+' do Inc(pc);
      if pc^='_' then Inc(pc);
      flag_curly_brackets := true;
      ps := pc;
    end else

    if pc^='}' then begin
      Check(flag_curly_brackets);
      Inc(pc); //скобочку записываем
      CommitText;
      flag_curly_brackets := false;
      ps := pc;
    end else

   //Инлайн-ссылка на перевод. Т.к. символы ещё недоступны, оставляем её в таком виде.
   //Вообще-то, кажется, случается только в {фиг. скобках}, но мы их разбираем по-общему
    if pc^='^' then begin
      Inc(pc);
      tmp_int := 0;
      while (tmp_int<4) and IsDigit(pc^) do begin
        Inc(pc);
        Inc(tmp_int);
      end;
      Check(tmp_int=4);
     //И всё, просто увеличили указатель
    end else

   //Скобки не значат ничего специального, но выделяются курсивом. Если внутри
   //скобки перенос строки, курсив повторяется: (начало+#конец).
   //Мы хотим этот лишний знак удалить, поэтому парсим скобки отдельно:
    if pc^='(' then begin
      Inc(pc);
      if pc^='!' then begin //специальный случай, ударение
        Dec(pc);
        CommitText;
        Inc(pc,2);
        tmp_int := EatNumber(pc);
        Check(pc^=')');
        Inc(pc);
        Check(entry<>nil); //иначе как-то... странно. Но можно и Need*
       //Вставляем прямо в текст, слава богу, тут индексация не важна
       //Хотя... если акцентов будет несколько...
       //Но по идее, в одном слове не должно быть двух ударений.
        tmp_int := FindWordStartOffset(entry.text)+tmp_int-1;
        entry.text := copy(entry.text,1,tmp_int)+'́'+copy(entry.text,tmp_int+1,MaxInt);
      end else begin //обычная скобка
        Check(not flag_brackets); //мало ли, вложенные
        flag_brackets := true;
        flag_brackets_noitalic := (pc^='#'); //не-италик скобки
      end;

    end else

    if pc^=')' then begin
     //В Яркси есть совершенно БРАТСКИЕ статьи с подпунктами а), б).
     //На текущем этапе мы посылаем это логическое разделение в Европу и пишем
     //его как текст. (Но это требует кода тут, в закр. скобке)
      if not flag_brackets and (test_char((pc-1)^,'абв')>0) then begin
        Inc(pc);
      end else begin
        Check(flag_brackets);
        flag_brackets := false;
        flag_brackets_noitalic := false;
        Inc(pc); //и оставляем как текст
      end;
    end else

   //Следующий кусок - общее вступление
    if pc^='>' then begin
      Check((clause=nil) or (clause.entries.Length=0) or (clause.entries.Length=1));
      Check((entry=nil) or (entry.text=''));
      Inc(pc);
      NeedClause;
      clause.common_clause := true;
      Check((pc^='#') or (pc^='@') or (pc^='~')); //проверяем, что там элементы, к-е мы встречали в common_clause -- необязательно
      ps := pc;
      if pc^='#' then
        Inc(pc); //съедаем тут, чтобы в стд. обработчике не сработал сразу EndCommonClause
    end else

   //Квадратные скобки [''текст'']. Бывают и обычные, их общим чередом.
    if (pc^='[') and ((pc+1)^='''') then begin
      CommitText;
      NeedEntry;
      entry.text := entry.text + parse_kmeaning_sq_brackets(pc);
    end else

   //Просто буква из перевода
    if IsLatin(pc^) or IsCyrillic(pc^) or IsDigit(pc^) or
    (test_char(pc^,'#:;,.!? []-''%')>0) {? #462} {% #2683}
    then begin
      if (pc^='#') and (clause<>nil) and (clause.common_clause=true) then begin
        Inc(pc);
        EndCommonClause;
        ps := pc;
      end else
        Inc(pc);
    end else

    if pc^='=' then begin
      NeedBlock;
      block.isNominal := true;
      Inc(pc);
    end else

   //Пустой элемент. Пока считываем, выкинем при копировании
    if pc^='_' then begin
      Inc(pc)
    end else

   //Стандартное выражение. Пока считываем, заменим при разборе
    if pc^='@' then begin
      Inc(pc);
      Check(IsDigit(pc^) or (pc^='@'));
      Inc(pc);
      EndCommonClause;
    end else

      Die('Неизвестный элемент: '+pc^);

  end;

  CommitText;
  Check(not flag_brackets); //так, на всякий случай
end;

function ParseKanjiCompoundMeanings(inp: string): TCompoundMeanings;
begin

end;


{
Поле: Kanji.Compounds. Работает в сочетании с KunYomi и Russian.
Формат: 1:48667,N:8502@,N:2280,N:2279,N:55637,[блок]:[слово][флаги]
Специальный блок N означает "В именах".
Флаги:
 @   по соответствующему чтению (обычно не входящему в общий список) данный
     иероглиф может читаться только в одиночку и никогда в сочетаниях с другими
     знаками (отметить значение флажком 1)
 ^   нестандартное чтение (отметить треугольничком)
 *   нестандартное значение (отметить ромбиком)
 &   нестандартное чтение и значение (отметить и ромбиком, и треугольничком,
     а также отступить немного после предыдущего слова)
 #   с виду никак не влияет, может сочетаться с другими
Фигурные скобки (в комментарии заменил на квадратные) означают одно из нескольких
заранее известных сообщений для конкретных кандзи:
  1:6590,1:6579,1:[27]
Cохраняем в msgref, wordref при этом пуст.
# Решётка в начале списка означает, что список длинный и его нужно показывать
свёрнуто (#54,#67).

Выбросы:
1. В ограниченном числе случаев встречается _!мусор_мусор_1:нормальная,2:статья.
2. Встречается и _какое-то_число_1:нормальная,2:статья.
3. Иногда: "=мусор мусор" вместо статьи (впрочем, статья пустая).
}
function ParseKanjiCompounds(inp: string): TCompoundEntries;
var parts: TStringArray;
  i: integer;
  block_id: string;
  ch: char;
begin
 //Есть ровно ограниченное число случаев, когда по какой-то причине копия KunYomi
 //вываливается в Compounds. Все они начинаются с _ и мусор заканчивается _
  if (Length(inp)>0) and (inp[1]='_') then begin
    Complain('KunYomi leak', inp);
    parts := Split(inp, '_'); //боже помоги
    if Length(parts)>0 then
      inp := parts[Length(parts)-1];
  end;

 //Изредка вместо всей статьи фигня вида "=мусор мусор"
  if (Length(inp)>0) and (inp[1]='=') then begin
    Complain('= operator leak', inp);
    inp := '';
  end;

  parts := Split(inp, ',');
  SetLength(Result, Length(parts));
  if Length(parts)<=0 then exit; //меньше проверок

 //Решётка в начале списка означает, что список длинный и его нужно показывать
 //сжато. Игнорируем.
  if (Length(parts[0])>0) and (parts[0][1]='#') then
    delete(parts[0],1,1);

  for i := 0 to Length(parts)-1 do begin
    block_id := trypop(parts[i], ':');
    if block_id='' then
      raise Exception.Create('ParseKanjiCompounds: no block_id separator.');
   //Блок может быть и двухциферным, 10+
    if block_id='N' then
      Result[i].block := BLOCK_NAMES
    else
      Result[i].block := StrToInt(block_id);

    Result[i].flags := [];
    while Length(parts[i])>0 do begin
      ch := parts[i][Length(parts[i])];
      if ch='@' then
        Result[i].flags := Result[i].flags + [cfSingular]
      else
      if ch='^' then
        Result[i].flags := Result[i].flags + [cfIrregularReading]
      else
      if ch='*' then
        Result[i].flags := Result[i].flags + [cfIrregularMeaning]
      else
      if ch='&' then
        Result[i].flags := Result[i].flags + [cfIrregularReading, cfIrregularMeaning]
      else
      if ch='#' then
        Result[i].flags := Result[i].flags + [cfHashtag]
      else
        break;
      delete(parts[i], Length(parts[i]), 1);
    end;

    if tryunquote(parts[i],'{','}') then
      Result[i].msgref := StrToInt(parts[i])
    else
      Result[i].wordref := StrToInt(parts[i]);
  end;
end;

function DumpKanjiCompounds(const ACompounds: TCompoundEntries): string;
var i: integer;
begin
  if Length(ACompounds)<=0 then begin
    Result := '';
    exit;
  end;
  Result := DumpKanjiCompound(ACompounds[0]);
  for i := 1 to Length(ACompounds)-1 do
    Result := Result + ', ' + DumpKanjiCompound(ACompounds[i]);
end;

function DumpKanjiCompound(const ACompound: TCompoundEntry): string;
begin
  Result := IntToStr(ACompound.block)+':'+IntToStr(ACompound.wordref);
  if ACompound.msgref>0 then
    Result := Result+':'+IntToStr(ACompound.msgref);
  if cfIrregularReading in ACompound.flags then
    Result := Result + '^';
  if cfIrregularMeaning in ACompound.flags then
    Result := Result + '*';
  if cfSingular in ACompound.flags then
    Result := Result + '@';
  if cfHashtag in ACompound.flags then
    Result := Result + '#';
end;

end.
