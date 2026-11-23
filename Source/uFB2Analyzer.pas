
unit uFB2Analyzer;

interface

uses
  Classes, SysUtils, uFB2Reader;

type
  TFB2Analyzer = class
  private
    FReader: TFB2Reader;
    FThreshold: Integer;
    FMaxAreaDifference: Integer;
  public
    constructor Create(AReader: TFB2Reader);

    procedure Analyze(
      const ReportFileName: string;
      Threshold: Integer = 16;
      MaxAreaDifference: Integer = 50
    );

    property Threshold: Integer read FThreshold;
    property MaxAreaDifference: Integer read FMaxAreaDifference;
  end;

implementation

uses
  uPerceptualHash;

type
  TImageInfo = record
    Image: TFB2Image;
    Hash: UInt64;
    Area: Int64;
  end;

  TImageInfoArray = array of TImageInfo;
  TIntMatrix = array of array of Integer;
  TBooleanArray = array of Boolean;
  TIntegerArray = array of Integer;

  TGroupInfo = record
    Members: TIntegerArray;
    MemberCount: Integer;
    PairCount: Integer;
    MainIndex: Integer;
  end;

  TGroupArray = array of TGroupInfo;

constructor TFB2Analyzer.Create(AReader: TFB2Reader);
begin
  inherited Create;
  FReader := AReader;
  FThreshold := 16;
  FMaxAreaDifference := 50;
end;

procedure TFB2Analyzer.Analyze(
  const ReportFileName: string;
  Threshold: Integer;
  MaxAreaDifference: Integer
);
var
  Images: TImageInfoArray;
  Distances: TIntMatrix;
  Assigned: TBooleanArray;
  Groups: TGroupArray;
  Report: TStringList;
  Replacements: TStringList;

  N: Integer;
  I, J, G: Integer;

  ProcessedCount: Integer;
  ErrorCount: Integer;
  PairsChecked: Int64;
  PairsSkipped: Int64;
  SimilarPairs: Int64;

  MainGroupCount: Integer;
  SmallGroupCount: Integer;
  MainGroupImages: Integer;
  SmallGroupImages: Integer;

  AreaMin, AreaMax: Int64;
  AreaDifference: Double;

  BestIndex: Integer;
  BestDegree: Integer;

  function IsSimilar(A, B: Integer): Boolean;
  begin
    Result :=
      (Distances[A][B] >= 0) and
      (Distances[A][B] <= FThreshold);
  end;

  function FindBestRepresentative: Integer;
  var
    X, Y: Integer;
    CurrentDegree: Integer;
  begin
    Result := -1;
    BestDegree := 0;

    for X := 0 to N - 1 do
    begin
      if Assigned[X] or not Images[X].Image.IsLoaded then
        Continue;

      CurrentDegree := 0;

      for Y := 0 to N - 1 do
      begin
        if (X = Y) or Assigned[Y] then
          Continue;

        if IsSimilar(X, Y) then
          Inc(CurrentDegree);
      end;

      if CurrentDegree = 0 then
        Continue;

      if (CurrentDegree > BestDegree) or
         ((CurrentDegree = BestDegree) and
          ((Result < 0) or
           (Images[X].Area > Images[Result].Area))) then
      begin
        Result := X;
        BestDegree := CurrentDegree;
      end;
    end;
  end;

  function CountGroupPairs(const Group: TGroupInfo): Integer;
  var
    X, Y: Integer;
  begin
    Result := 0;

    for X := 0 to Group.MemberCount - 2 do
      for Y := X + 1 to Group.MemberCount - 1 do
        if IsSimilar(
          Group.Members[X],
          Group.Members[Y]
        ) then
          Inc(Result);
  end;

  procedure WriteImageInfo(Index: Integer);
  begin
    Report.Add(
      Format('%s  %dx%d  Area: %d',
        [
          Images[Index].Image.ID,
          Images[Index].Image.Width,
          Images[Index].Image.Height,
          Images[Index].Area
        ])
    );
  end;

  procedure WriteGroup(const Group: TGroupInfo; GroupNumber: Integer);
  var
    X, Y: Integer;
  begin
    Report.Add(
      Format('GROUP %d (%d images, %d pairs)',
        [
          GroupNumber,
          Group.MemberCount,
          Group.PairCount
        ])
    );

    Report.Add('--------------------');
    Report.Add('Main image:');
    WriteImageInfo(Group.MainIndex);

    Report.Add('');
    Report.Add('Group members:');

    for X := 0 to Group.MemberCount - 1 do
      if Group.Members[X] <> Group.MainIndex then
        WriteImageInfo(Group.Members[X]);

    Report.Add('');
    Report.Add('Similar pairs:');

    for X := 0 to Group.MemberCount - 2 do
      for Y := X + 1 to Group.MemberCount - 1 do
        if IsSimilar(
          Group.Members[X],
          Group.Members[Y]
        ) then
        begin
          Report.Add(
            Format('%s <-> %s  Distance: %d',
              [
                Images[Group.Members[X]].Image.ID,
                Images[Group.Members[Y]].Image.ID,
                Distances[
                  Group.Members[X]
                ][
                  Group.Members[Y]
                ]
              ])
          );
        end;

    Report.Add('');
  end;

begin
  FThreshold := Threshold;
  FMaxAreaDifference := MaxAreaDifference;

  N := FReader.Count;

  SetLength(Images, N);
  SetLength(Distances, N);
  SetLength(Assigned, N);

  for I := 0 to N - 1 do
    SetLength(Distances[I], N);

  Report := TStringList.Create;
  Replacements := TStringList.Create;
  try
    ProcessedCount := 0;
    ErrorCount := 0;
    PairsChecked := 0;
    PairsSkipped := 0;
    SimilarPairs := 0;

    MainGroupCount := 0;
    SmallGroupCount := 0;
    MainGroupImages := 0;
    SmallGroupImages := 0;

    Report.Add('FB2 IMAGE ANALYSIS');
    Report.Add('------------------');
    Report.Add('Threshold: ' + IntToStr(FThreshold));
    Report.Add('Maximum area difference: ' +
      IntToStr(FMaxAreaDifference) + '%');
    Report.Add('');

    { Load images and calculate hashes }

    Report.Add('IMAGE HASHES');
    Report.Add('------------');

    for I := 0 to N - 1 do
    begin
      Images[I].Image := FReader.Image(I);
      Images[I].Hash := 0;
      Images[I].Area := 0;

      if Images[I].Image.IsLoaded then
      begin
        Images[I].Area :=
          Int64(Images[I].Image.Width) *
          Int64(Images[I].Image.Height);

        Images[I].Hash :=
          CalcPHash(Images[I].Image.Bitmap);

        Inc(ProcessedCount);

        Report.Add(
          Format('%s  %dx%d  Hash calculated',
            [
              Images[I].Image.ID,
              Images[I].Image.Width,
              Images[I].Image.Height
            ])
        );
      end
      else
      begin
        Inc(ErrorCount);

        Report.Add(
          Images[I].Image.ID + '  ERROR: ' +
          Images[I].Image.ErrorMessage
        );
      end;
    end;

    Report.Add('');

    { Initialize distance matrix }

    for I := 0 to N - 1 do
      for J := 0 to N - 1 do
        Distances[I][J] := -1;

    { Compare image pairs }

    for I := 0 to N - 2 do
    begin
      if not Images[I].Image.IsLoaded then
        Continue;

      for J := I + 1 to N - 1 do
      begin
        if not Images[J].Image.IsLoaded then
          Continue;

        AreaMin := Images[I].Area;
        AreaMax := Images[J].Area;

        if AreaMin > AreaMax then
        begin
          AreaMin := Images[J].Area;
          AreaMax := Images[I].Area;
        end;

        if AreaMax > 0 then
        begin
          AreaDifference :=
            (AreaMax - AreaMin) * 100.0 / AreaMax;

          if AreaDifference > FMaxAreaDifference then
          begin
            Inc(PairsSkipped);
            Continue;
          end;
        end;

        Inc(PairsChecked);

        Distances[I][J] :=
          ComparePHash(Images[I].Hash, Images[J].Hash);

        Distances[J][I] := Distances[I][J];

        if Distances[I][J] <= FThreshold then
          Inc(SimilarPairs);
      end;
    end;

    { Build groups }

    SetLength(Groups, 0);

    while True do
    begin
      BestIndex := FindBestRepresentative;

      if BestIndex < 0 then
        Break;

      G := Length(Groups);
      SetLength(Groups, G + 1);

      Groups[G].MainIndex := BestIndex;
      Groups[G].MemberCount := 0;
      Groups[G].PairCount := 0;
      SetLength(Groups[G].Members, N);

      Groups[G].Members[Groups[G].MemberCount] := BestIndex;
      Inc(Groups[G].MemberCount);

      Assigned[BestIndex] := True;

      for J := 0 to N - 1 do
      begin
        if (J = BestIndex) or Assigned[J] then
          Continue;

        if IsSimilar(BestIndex, J) then
        begin
          Groups[G].Members[Groups[G].MemberCount] := J;
          Inc(Groups[G].MemberCount);
          Assigned[J] := True;
        end;
      end;

      Groups[G].PairCount := CountGroupPairs(Groups[G]);
    end;

    { Main groups: 5 or more pairs }

    Report.Add('MAIN GROUPS');
    Report.Add('===========');
    Report.Add('');

    for G := 0 to High(Groups) do
    begin
      if Groups[G].PairCount >= 5 then
      begin
        Inc(MainGroupCount);
        Inc(MainGroupImages, Groups[G].MemberCount);

        WriteGroup(Groups[G], MainGroupCount);

        { Create replacement rules }

        for I := 0 to Groups[G].MemberCount - 1 do
        begin
          if Groups[G].Members[I] <> Groups[G].MainIndex then
          begin
            Replacements.Add(
              Images[Groups[G].Members[I]].Image.ID + '=' +
              Images[Groups[G].MainIndex].Image.ID
            );
          end;
        end;
      end;
    end;

    if MainGroupCount = 0 then
      Report.Add('No main groups found.');

    { Replace image references }

    if Replacements.Count > 0 then
      FReader.ReplaceImageReferences(Replacements);

    { Small groups: 1 to 4 pairs }

    Report.Add('');
    Report.Add('SMALL GROUPS - MANUAL REVIEW');
    Report.Add('============================');
    Report.Add('');

    for G := 0 to High(Groups) do
    begin
      if (Groups[G].PairCount >= 1) and
         (Groups[G].PairCount < 5) then
      begin
        Inc(SmallGroupCount);
        Inc(SmallGroupImages, Groups[G].MemberCount);
        WriteGroup(Groups[G], SmallGroupCount);
      end;
    end;

    if SmallGroupCount = 0 then
      Report.Add('No small groups found.');

    { Summary }

    Report.Add('');
    Report.Add('SUMMARY');
    Report.Add('-------');
    Report.Add('Images found: ' + IntToStr(N));
    Report.Add('Images processed: ' + IntToStr(ProcessedCount));
    Report.Add('Images with errors: ' + IntToStr(ErrorCount));
    Report.Add('Pairs checked: ' + IntToStr(PairsChecked));
    Report.Add('Pairs skipped by area: ' + IntToStr(PairsSkipped));
    Report.Add('Similar pairs: ' + IntToStr(SimilarPairs));
    Report.Add('Main groups: ' + IntToStr(MainGroupCount));
    Report.Add('Small groups: ' + IntToStr(SmallGroupCount));
    Report.Add('Images in main groups: ' + IntToStr(MainGroupImages));
    Report.Add('Images in small groups: ' + IntToStr(SmallGroupImages));
    Report.Add('Replacement rules created: ' +
      IntToStr(Replacements.Count));
    writeln('Save to report file '+ReportFileName);
    Report.SaveToFile(ReportFileName);
     writeln('Save to report file -ok');
  finally
    Replacements.Free;
    Report.Free;
  end;
end;

end.

