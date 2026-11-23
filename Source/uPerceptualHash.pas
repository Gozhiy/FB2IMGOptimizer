
unit uPerceptualHash;

interface

uses
  System.SysUtils,
  Vcl.Graphics,System.Types;

function CalcPHash(const Bitmap: TBitmap): UInt64;

function ComparePHash(const Hash1, Hash2: UInt64): Integer;

implementation

uses
  Winapi.Windows,
  System.Math;

const
  HASH_SIZE = 8;
  DCT_SIZE  = 32;

type
  TByteArray = array[0..MaxInt div 2] of Byte;
  PByteArray = ^TByteArray;

  TGrayArray = array[0..DCT_SIZE-1,
                     0..DCT_SIZE-1] of Double;

  TDCTArray = array[0..DCT_SIZE-1,
                    0..DCT_SIZE-1] of Double;

  TCosArray = array[0..DCT_SIZE-1,
                    0..DCT_SIZE-1] of Double;

  TPHBitmap = Vcl.Graphics.TBitmap;

// --------------------------------------------------
// Перетворення зображення у матрицю 32 x 32
// --------------------------------------------------

procedure BitmapToGray32(const Bitmap: TPHBitmap;
                         var Gray: TGrayArray);
var
  Small: TPHBitmap;
  X, Y: Integer;
  Row: PByteArray;
  R, G, B: Integer;
begin
  if //(Bitmap = nil) or
     (Bitmap.Width <= 0) or
     (Bitmap.Height <= 0) then
    raise Exception.Create('Invalid bitmap');

  Small := TPHBitmap.Create;
  try
    Small.PixelFormat := pf24bit;
    Small.SetSize(DCT_SIZE, DCT_SIZE);

    Small.Canvas.Brush.Color := clWhite;
    Small.Canvas.FillRect(Rect(0, 0, DCT_SIZE, DCT_SIZE));

    SetStretchBltMode(Small.Canvas.Handle, HALFTONE);
    SetBrushOrgEx(Small.Canvas.Handle, 0, 0, nil);

    Small.Canvas.StretchDraw(
      Rect(0, 0, DCT_SIZE, DCT_SIZE), Bitmap);

    for Y := 0 to DCT_SIZE - 1 do
    begin
      // ScanLine[0] відповідає нижньому рядку
      Row := PByteArray(
        Small.ScanLine[DCT_SIZE - 1 - Y]);

      for X := 0 to DCT_SIZE - 1 do
      begin
        B := Row[X * 3];
        G := Row[X * 3 + 1];
        R := Row[X * 3 + 2];

        // Перетворення RGB у яскравість
        Gray[Y, X] :=
          (R * 77 + G * 150 + B * 29) / 256.0;
      end;
    end;

  finally
    Small.Free;
  end;
end;


// --------------------------------------------------
// Створення таблиці косинусів
// --------------------------------------------------

procedure InitCosTable(var CosTable: TCosArray);
var
  U, X: Integer;
begin
  for U := 0 to DCT_SIZE - 1 do
    for X := 0 to DCT_SIZE - 1 do
      CosTable[U, X] :=
        Cos(Pi * (2 * X + 1) * U /
            (2 * DCT_SIZE));
end;


// --------------------------------------------------
// Двовимірне DCT
// --------------------------------------------------

procedure CalculateDCT(
  const Gray: TGrayArray;
  const CosTable: TCosArray;
  var Coeff: TDCTArray);
var
  Temp: TDCTArray;
  X, Y, U, V: Integer;
  Sum: Double;
  AU, AV: Double;
begin
  // Перше перетворення: по горизонталі

  for Y := 0 to DCT_SIZE - 1 do
    for U := 0 to DCT_SIZE - 1 do
    begin
      Sum := 0;

      for X := 0 to DCT_SIZE - 1 do
        Sum := Sum +
          Gray[Y, X] * CosTable[U, X];

      Temp[Y, U] := Sum;
    end;

  // Друге перетворення: по вертикалі

  for V := 0 to DCT_SIZE - 1 do
    for U := 0 to DCT_SIZE - 1 do
    begin
      Sum := 0;

      for Y := 0 to DCT_SIZE - 1 do
        Sum := Sum +
          Temp[Y, U] * CosTable[V, Y];

      if U = 0 then
        AU := Sqrt(1.0 / DCT_SIZE)
      else
        AU := Sqrt(2.0 / DCT_SIZE);

      if V = 0 then
        AV := Sqrt(1.0 / DCT_SIZE)
      else
        AV := Sqrt(2.0 / DCT_SIZE);

      Coeff[V, U] := Sum * AU * AV;
    end;
end;


// --------------------------------------------------
// Сортування 64 значень для пошуку медіани
// --------------------------------------------------

procedure SortValues(var A: array of Double);
var
  I, J: Integer;
  Value: Double;
begin
  for I := 1 to High(A) do
  begin
    Value := A[I];
    J := I - 1;

    while (J >= 0) and (A[J] > Value) do
    begin
      A[J + 1] := A[J];
      Dec(J);
    end;

    A[J + 1] := Value;
  end;
end;


// --------------------------------------------------
// Обчислення perceptual hash
// --------------------------------------------------

function CalcPHash(const Bitmap: TPHBitmap): UInt64;
var
  Gray: TGrayArray;
  CosTable: TCosArray;
  Coeff: TDCTArray;

  Values: array[0..63] of Double;

  I, U, V: Integer;
  Median: Double;
  BitIndex: Integer;
begin
  Result := 0;

  BitmapToGray32(Bitmap, Gray);

  InitCosTable(CosTable);

  CalculateDCT(Gray, CosTable, Coeff);

  // Беремо низькочастотну область 8 x 8

  I := 0;

  for V := 0 to HASH_SIZE - 1 do
    for U := 0 to HASH_SIZE - 1 do
    begin
      Values[I] := Coeff[V, U];
      Inc(I);
    end;

  // Знаходимо медіану

  SortValues(Values);

  Median := (Values[31] + Values[32]) / 2.0;

  // Формуємо 64-бітний хеш

  BitIndex := 0;

  for V := 0 to HASH_SIZE - 1 do
    for U := 0 to HASH_SIZE - 1 do
    begin
      if Coeff[V, U] > Median then
        Result := Result or
          (UInt64(1) shl BitIndex);

      Inc(BitIndex);
    end;
end;


// --------------------------------------------------
// Відстань Хеммінга між двома хешами
// --------------------------------------------------

function ComparePHash(
  const Hash1, Hash2: UInt64): Integer;
var
  X: UInt64;
begin
  Result := 0;

  X := Hash1 xor Hash2;

  // Підрахунок одиничних бітів

  while X <> 0 do
  begin
    X := X and (X - 1);
    Inc(Result);
  end;
end;

end.

