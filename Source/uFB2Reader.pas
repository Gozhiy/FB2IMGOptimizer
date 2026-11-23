
unit uFB2Reader;

interface

uses
  Classes, SysUtils, Vcl.Graphics;

type
  TFB2Image = class
  public
    ID: string;
    ContentType: string;
    Bitmap: TBitmap;
    DataSize: Int64;
    ErrorMessage: string;

    constructor Create;
    destructor Destroy; override;

    function IsLoaded: Boolean;
    function Width: Integer;
    function Height: Integer;
  end;

  TFB2Reader = class
  private
    FImages: TList;
    FSourceText: string;
    FEncodingCodePage: Integer;
    FBOM: TBytes;

    function ReadTextFile(const FileName: string): string;
    function GetEncodingCodePage(const S: string): Integer;
    function FindTagEnd(const S: string; StartPos: Integer): Integer;
    function GetAttribute(const TagText, AttrName: string): string;
    function GetTagName(const TagText: string): string;

    procedure ReadBinaryNodes(const S: string);
    procedure LoadBinaryImage(const ID, MIMEType,
      Base64Text: string);

    function RewriteImageTag(
      const TagText: string;
      Replacements: TStrings): string;

    function FindReplacement(
      const OldID: string;
      Replacements: TStrings;
      out NewID: string): Boolean;

  public
    constructor Create;
    destructor Destroy; override;

    procedure LoadFromFile(const FileName: string);

    procedure ReplaceImageReferences(Replacements: TStrings);
    procedure SaveToFile(const FileName: string);

    function Count: Integer;
    function Image(Index: Integer): TFB2Image;

    property Images: TList read FImages;
  end;

implementation

uses
  System.StrUtils,
  EncdDecd,
  Vcl.Imaging.jpeg,
  Vcl.Imaging.pngimage;

{ TFB2Image }

constructor TFB2Image.Create;
begin
  inherited Create;
  Bitmap := TBitmap.Create;
  DataSize := 0;
  ErrorMessage := '';
end;

destructor TFB2Image.Destroy;
begin
  Bitmap.Free;
  inherited Destroy;
end;

function TFB2Image.IsLoaded: Boolean;
begin
  Result := (ErrorMessage = '') and
            (Bitmap.Width > 0) and
            (Bitmap.Height > 0);
end;

function TFB2Image.Width: Integer;
begin
  Result := Bitmap.Width;
end;

function TFB2Image.Height: Integer;
begin
  Result := Bitmap.Height;
end;

{ TFB2Reader }

constructor TFB2Reader.Create;
begin
  inherited Create;
  FImages := TList.Create;
  FSourceText := '';
  FEncodingCodePage := 65001;
  SetLength(FBOM, 0);
end;

destructor TFB2Reader.Destroy;
var
  I: Integer;
begin
  for I := 0 to FImages.Count - 1 do
    TFB2Image(FImages[I]).Free;

  FImages.Free;
  inherited Destroy;
end;

function TFB2Reader.Count: Integer;
begin
  Result := FImages.Count;
end;

function TFB2Reader.Image(Index: Integer): TFB2Image;
begin
  Result := TFB2Image(FImages[Index]);
end;

function TFB2Reader.GetEncodingCodePage(
  const S: string): Integer;
var
  P, Q: Integer;
  Enc: string;
begin
  Result := 65001;

  P := Pos('encoding', LowerCase(S));
  if P = 0 then
    Exit;

  P := PosEx('=', S, P);
  if P = 0 then
    Exit;

  Inc(P);

  while (P <= Length(S)) and (S[P] <= ' ') do
    Inc(P);

  if P > Length(S) then
    Exit;

  if not (S[P] in ['''', '"']) then
    Exit;

  Q := P;
  Inc(Q);

  while (Q <= Length(S)) and (S[Q] <> S[P]) do
    Inc(Q);

  if Q > Length(S) then
    Exit;

  Enc := LowerCase(Copy(S, P + 1, Q - P - 1));

  if Enc = 'utf-8' then
    Result := 65001
  else if Enc = 'utf-16' then
    Result := 1200
  else if Enc = 'utf-16le' then
    Result := 1200
  else if Enc = 'utf-16be' then
    Result := 1201
  else if Enc = 'windows-1251' then
    Result := 1251
  else if Enc = 'windows-1252' then
    Result := 1252
  else if Enc = 'windows-1250' then
    Result := 1250
  else if Enc = 'koi8-r' then
    Result := 20866
  else if Enc = 'iso-8859-1' then
    Result := 28591
  else if Enc = 'iso-8859-5' then
    Result := 28595;
end;

function TFB2Reader.ReadTextFile(
  const FileName: string): string;
var
  FS: TFileStream;
  Bytes: TBytes;
  Encoding: TEncoding;
  CodePage: Integer;
  StartPos: Integer;
  CountBytes: Integer;
  Header: string;
begin
  Result := '';

  SetLength(FBOM, 0);

  FS := TFileStream.Create(FileName,
    fmOpenRead or fmShareDenyNone);
  try
    SetLength(Bytes, FS.Size);

    if FS.Size > 0 then
      FS.ReadBuffer(Bytes[0], FS.Size);

  finally
    FS.Free;
  end;

  if Length(Bytes) = 0 then
  begin
    FEncodingCodePage := 65001;
    Exit;
  end;

  StartPos := 0;
  CountBytes := Length(Bytes);

  { Визначаємо BOM }

  if (CountBytes >= 3) and
     (Bytes[0] = $EF) and
     (Bytes[1] = $BB) and
     (Bytes[2] = $BF) then
  begin
    StartPos := 3;
    CodePage := 65001;

    SetLength(FBOM, 3);
    FBOM[0] := $EF;
    FBOM[1] := $BB;
    FBOM[2] := $BF;
  end
  else if (CountBytes >= 2) and
          (Bytes[0] = $FF) and
          (Bytes[1] = $FE) then
  begin
    StartPos := 2;
    CodePage := 1200;

    SetLength(FBOM, 2);
    FBOM[0] := $FF;
    FBOM[1] := $FE;
  end
  else if (CountBytes >= 2) and
          (Bytes[0] = $FE) and
          (Bytes[1] = $FF) then
  begin
    StartPos := 2;
    CodePage := 1201;

    SetLength(FBOM, 2);
    FBOM[0] := $FE;
    FBOM[1] := $FF;
  end
  else
  begin
    { Без BOM орієнтуємося на XML-декларацію }

    Header := '';

    if CountBytes > 200 then
      CountBytes := 200;

    SetLength(Header, CountBytes);

    Move(Bytes[0], Header[1], CountBytes);

    CodePage := GetEncodingCodePage(Header);
    StartPos := 0;
  end;

  FEncodingCodePage := CodePage;

  CountBytes := Length(Bytes) - StartPos;

  if CountBytes <= 0 then
    Exit;

  Encoding := TEncoding.GetEncoding(CodePage);
  try
    Result := Encoding.GetString(
      Bytes, StartPos, CountBytes);
  finally
    Encoding.Free;
  end;
end;

function TFB2Reader.FindTagEnd(
  const S: string; StartPos: Integer): Integer;
var
  I: Integer;
  Quote: Char;
begin
  Result := 0;
  Quote := #0;

  for I := StartPos to Length(S) do
  begin
    if Quote <> #0 then
    begin
      if S[I] = Quote then
        Quote := #0;
    end
    else
    begin
      if (S[I] = '''') or (S[I] = '"') then
        Quote := S[I]
      else if S[I] = '>' then
      begin
        Result := I;
        Exit;
      end;
    end;
  end;
end;

function TFB2Reader.GetTagName(
  const TagText: string): string;
var
  I: Integer;
begin
  Result := '';

  I := 1;

  if (I <= Length(TagText)) and (TagText[I] = '<') then
    Inc(I);

  if (I <= Length(TagText)) and (TagText[I] = '/') then
    Inc(I);

  while (I <= Length(TagText)) and
        (TagText[I] <= ' ') do
    Inc(I);

  while (I <= Length(TagText)) and
        not (TagText[I] in [' ', #9, #10, #13, '>', '/']) do
  begin
    Result := Result + TagText[I];
    Inc(I);
  end;
end;

function TFB2Reader.GetAttribute(
  const TagText, AttrName: string): string;
var
  I, J: Integer;
  Name: string;
  Quote: Char;
begin
  Result := '';
  I := 1;

  while I <= Length(TagText) do
  begin
    while (I <= Length(TagText)) and
          (TagText[I] <= ' ') do
      Inc(I);

    if I > Length(TagText) then
      Exit;

    if TagText[I] in ['<', '/', '>'] then
    begin
      Inc(I);
      Continue;
    end;

    J := I;

    while (I <= Length(TagText)) and
          not (TagText[I] in [' ', '=', #9, #10, #13, '>', '/']) do
      Inc(I);

    Name := Copy(TagText, J, I - J);

    while (I <= Length(TagText)) and
          (TagText[I] <= ' ') do
      Inc(I);

    if (I > Length(TagText)) or (TagText[I] <> '=') then
      Continue;

    Inc(I);

    while (I <= Length(TagText)) and
          (TagText[I] <= ' ') do
      Inc(I);

    if I > Length(TagText) then
      Exit;

    Quote := TagText[I];

    if not (Quote in ['''', '"']) then
      Exit;

    Inc(I);
    J := I;

    while (I <= Length(TagText)) and
          (TagText[I] <> Quote) do
      Inc(I);

    if SameText(Name, AttrName) then
    begin
      Result := Copy(TagText, J, I - J);
      Exit;
    end;

    Inc(I);
  end;
end;

function TFB2Reader.FindReplacement(
  const OldID: string;
  Replacements: TStrings;
  out NewID: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  NewID := '';

  if Replacements = nil then
    Exit;

  for I := 0 to Replacements.Count - 1 do
  begin
    if Replacements.Names[I] = OldID then
    begin
      NewID := Replacements.ValueFromIndex[I];
      Result := True;
      Exit;
    end;
  end;
end;

function TFB2Reader.RewriteImageTag(
  const TagText: string;
  Replacements: TStrings): string;
var
  I, J, K: Integer;
  AttrName: string;
  LocalName: string;
  Quote: Char;
  OldID, NewID: string;
  NewHref: string;
begin
  Result := TagText;

  I := 1;

  { Пропускаємо ім'я тегу }

  if (I <= Length(TagText)) and (TagText[I] = '<') then
    Inc(I);

  while (I <= Length(TagText)) and
        not (TagText[I] in [' ', #9, #10, #13, '>', '/']) do
    Inc(I);

  { Переглядаємо атрибути }

  while I <= Length(TagText) do
  begin
    while (I <= Length(TagText)) and
          (TagText[I] <= ' ') do
      Inc(I);

    if (I > Length(TagText)) or
       (TagText[I] in ['>', '/']) then
      Break;

    J := I;

    while (I <= Length(TagText)) and
          not (TagText[I] in [' ', '=', #9, #10, #13, '>', '/']) do
      Inc(I);

    AttrName := Copy(TagText, J, I - J);

    K := LastDelimiter(':', AttrName);
    if K > 0 then
      LocalName := Copy(AttrName, K + 1, MaxInt)
    else
      LocalName := AttrName;

    while (I <= Length(TagText)) and
          (TagText[I] <= ' ') do
      Inc(I);

    if (I > Length(TagText)) or (TagText[I] <> '=') then
      Continue;

    Inc(I);

    while (I <= Length(TagText)) and
          (TagText[I] <= ' ') do
      Inc(I);

    if I > Length(TagText) then
      Break;

    Quote := TagText[I];

    if not (Quote in ['''', '"']) then
      Break;

    Inc(I);
    J := I;

    while (I <= Length(TagText)) and
          (TagText[I] <> Quote) do
      Inc(I);

    if SameText(LocalName, 'href') then
    begin
      OldID := Copy(TagText, J, I - J);

      { Цікавлять лише внутрішні посилання #ID }

      if (Length(OldID) > 1) and (OldID[1] = '#') then
      begin
        Delete(OldID, 1, 1);

        if FindReplacement(OldID, Replacements, NewID) then
        begin
          NewHref := '#' + NewID;

          Result :=
            Copy(TagText, 1, J - 1) +
            NewHref +
            Copy(TagText, I, MaxInt);

          Exit;
        end;
      end;
    end;

    Inc(I);
  end;
end;

procedure TFB2Reader.ReplaceImageReferences(
  Replacements: TStrings);
var
  S: string;
  TagText: string;
  TagName: string;
  LocalName: string;
  NewTag: string;
  P, TagEnd, LastPos, K: Integer;
begin
  if Replacements = nil then
    Exit;

  S := FSourceText;
  S := '';
  LastPos := 1;
  P := 1;

  while P <= Length(FSourceText) do
  begin
    P := PosEx('<', FSourceText, P);

    if P = 0 then
      Break;

    { Коментар }

    if Copy(FSourceText, P, 4) = '<!--' then
    begin
      P := PosEx('-->', FSourceText, P + 4);
      if P = 0 then
        Break;

      Inc(P, 3);
      Continue;
    end;

    { CDATA }

    if Copy(FSourceText, P, 9) = '<![CDATA[' then
    begin
      P := PosEx(']]>', FSourceText, P + 9);
      if P = 0 then
        Break;

      Inc(P, 3);
      Continue;
    end;

    { XML-інструкції }

    if Copy(FSourceText, P, 2) = '<?' then
    begin
      P := PosEx('?>', FSourceText, P + 2);
      if P = 0 then
        Break;

      Inc(P, 2);
      Continue;
    end;

    { Декларації }

    if Copy(FSourceText, P, 2) = '<!' then
    begin
      TagEnd := FindTagEnd(FSourceText, P + 2);
      if TagEnd = 0 then
        Break;

      P := TagEnd + 1;
      Continue;
    end;

    { Закривальні теги }

    if Copy(FSourceText, P, 2) = '</' then
    begin
      TagEnd := FindTagEnd(FSourceText, P + 2);
      if TagEnd = 0 then
        Break;

      P := TagEnd + 1;
      Continue;
    end;

    TagEnd := FindTagEnd(FSourceText, P + 1);

    if TagEnd = 0 then
      Break;

    TagText := Copy(
      FSourceText, P, TagEnd - P + 1);

    TagName := GetTagName(TagText);

    K := LastDelimiter(':', TagName);
    if K > 0 then
      LocalName := Copy(TagName, K + 1, MaxInt)
    else
      LocalName := TagName;

    if SameText(LocalName, 'image') then
    begin
      NewTag := RewriteImageTag(TagText, Replacements);

      if NewTag <> TagText then
      begin
        S := S + Copy(FSourceText, LastPos, P - LastPos);
        S := S + NewTag;
        LastPos := TagEnd + 1;
      end;
    end;

    P := TagEnd + 1;
  end;

  if LastPos > 1 then
    S := S + Copy(FSourceText, LastPos, MaxInt)
  else
    S := FSourceText;

  FSourceText := S;
end;

procedure TFB2Reader.SaveToFile(const FileName: string);
var
  FS: TFileStream;
  Encoding: TEncoding;
  Bytes: TBytes;
begin
  Encoding := TEncoding.GetEncoding(FEncodingCodePage);
  try
    Bytes := Encoding.GetBytes(FSourceText);
  finally
    Encoding.Free;
  end;

  FS := TFileStream.Create(
    FileName, fmCreate);
  try
    { Спочатку записуємо початковий BOM }

    if Length(FBOM) > 0 then
      FS.WriteBuffer(FBOM[0], Length(FBOM));

    if Length(Bytes) > 0 then
      FS.WriteBuffer(Bytes[0], Length(Bytes));

  finally
    FS.Free;
  end;
end;

procedure TFB2Reader.LoadBinaryImage(
  const ID, MIMEType, Base64Text: string);
var
  Img: TFB2Image;
  Graphic: TGraphic;
  InputStream: TMemoryStream;
  DecodedStream: TMemoryStream;
  Base64Bytes: AnsiString;
  CleanBase64: string;
  I: Integer;
  MT: string;
begin
  Img := TFB2Image.Create;
  FImages.Add(Img);

  Img.ID := ID;
  Img.ContentType := MIMEType;

  try
    MT := LowerCase(Trim(MIMEType));

    I := Pos(';', MT);
    if I > 0 then
      MT := Trim(Copy(MT, 1, I - 1));

    Graphic := nil;

    if MT = 'image/jpeg' then
      Graphic := TJPEGImage.Create
    else if MT = 'image/png' then
      Graphic := TPngImage.Create
    else if (MT = 'image/bmp') or
            (MT = 'image/x-ms-bmp') then
      Graphic := TBitmap.Create
    else
    begin
      Img.ErrorMessage := 'Unsupported content-type: ' + MT;
      Exit;
    end;

    try
      CleanBase64 := '';

      for I := 1 to Length(Base64Text) do
        if not (Base64Text[I] in [#9, #10, #13, ' ']) then
          CleanBase64 := CleanBase64 + Base64Text[I];

      Base64Bytes := AnsiString(CleanBase64);

      InputStream := TMemoryStream.Create;
      DecodedStream := TMemoryStream.Create;

      try
        if Length(Base64Bytes) > 0 then
          InputStream.WriteBuffer(
            Base64Bytes[1], Length(Base64Bytes));

        InputStream.Position := 0;

        DecodeStream(InputStream, DecodedStream);

        Img.DataSize := DecodedStream.Size;

        DecodedStream.Position := 0;

        Graphic.LoadFromStream(DecodedStream);
        Img.Bitmap.Assign(Graphic);

      finally
        DecodedStream.Free;
        InputStream.Free;
      end;

    finally
      Graphic.Free;
    end;

  except
    on E: Exception do
      Img.ErrorMessage := E.Message;
  end;
end;

procedure TFB2Reader.ReadBinaryNodes(const S: string);
var
  P, TagEnd, ClosePos, CloseEnd: Integer;
  TagText, TagName, CloseName: string;
  ID, MIMEType, Base64Text: string;
  SearchText: string;
begin
  P := 1;

  while P <= Length(S) do
  begin
    P := PosEx('<', S, P);

    if P = 0 then
      Break;

    if Copy(S, P, 4) = '<!--' then
    begin
      P := PosEx('-->', S, P + 4);
      if P = 0 then
        Break;
      Inc(P, 3);
      Continue;
    end;

    if Copy(S, P, 9) = '<![CDATA[' then
    begin
      P := PosEx(']]>', S, P + 9);
      if P = 0 then
        Break;
      Inc(P, 3);
      Continue;
    end;

    if Copy(S, P, 2) = '<?' then
    begin
      P := PosEx('?>', S, P + 2);
      if P = 0 then
        Break;
      Inc(P, 2);
      Continue;
    end;

    if Copy(S, P, 2) = '<!' then
    begin
      TagEnd := FindTagEnd(S, P + 2);
      if TagEnd = 0 then
        Break;
      P := TagEnd + 1;
      Continue;
    end;

    if Copy(S, P, 2) = '</' then
    begin
      TagEnd := FindTagEnd(S, P + 2);
      if TagEnd = 0 then
        Break;
      P := TagEnd + 1;
      Continue;
    end;

    TagEnd := FindTagEnd(S, P + 1);

    if TagEnd = 0 then
      Break;

    TagText := Copy(S, P, TagEnd - P + 1);
    TagName := GetTagName(TagText);

    if SameText(Copy(TagName,
       LastDelimiter(':', TagName) + 1, MaxInt), 'binary') then
    begin
      if (TagEnd > P) and (S[TagEnd - 1] = '/') then
      begin
        ID := GetAttribute(TagText, 'id');
        MIMEType := GetAttribute(TagText, 'content-type');

        LoadBinaryImage(ID, MIMEType, '');
        P := TagEnd + 1;
        Continue;
      end;

      SearchText := '</' + TagName;
      ClosePos := PosEx(SearchText, S, TagEnd + 1);

      if ClosePos = 0 then
      begin
        P := TagEnd + 1;
        Continue;
      end;

      CloseEnd := FindTagEnd(S, ClosePos + 2);

      if CloseEnd = 0 then
        Break;

      CloseName := GetTagName(
        Copy(S, ClosePos, CloseEnd - ClosePos + 1));

      if not SameText(CloseName, TagName) then
      begin
        P := TagEnd + 1;
        Continue;
      end;

      ID := GetAttribute(TagText, 'id');
      MIMEType := GetAttribute(TagText, 'content-type');

      Base64Text := Copy(S, TagEnd + 1,
        ClosePos - TagEnd - 1);

      LoadBinaryImage(ID, MIMEType, Base64Text);

      P := CloseEnd + 1;
    end
    else
      P := TagEnd + 1;
  end;
end;

procedure TFB2Reader.LoadFromFile(const FileName: string);
var
  I: Integer;
begin
  for I := FImages.Count - 1 downto 0 do
  begin
    TFB2Image(FImages[I]).Free;
    FImages.Delete(I);
  end;

  FSourceText := ReadTextFile(FileName);

  ReadBinaryNodes(FSourceText);
end;

end.

