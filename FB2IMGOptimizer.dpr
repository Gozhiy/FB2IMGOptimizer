program FB2IMGOptimizer;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  uFB2Reader in 'Source\uFB2Reader.pas',
  uFB2Analyzer in 'Source\uFB2Analyzer.pas',
  uPerceptualHash in 'Source\uPerceptualHash.pas';

var
  Reader: TFB2Reader;
  Analyzer: TFB2Analyzer;
  I: Integer;
  Img: TFB2Image;
  fileIn: string;
  FileOut: string;
  FileRep: string;
  Distantion: integer;
  PercArea: integer;
const
  help =
  'The program replaces groups of images containing identical graphics with a single instance—the one that best matches the majority. ' +#13#10 +
  'example of execution: FB2IMGCheck.exe -fi <FileFB2> -fo <FileFB2^> -fr <FileReport> -D <distantion> -p <PercArea>' +#13#10 +
  '-FI - fileInput' +#13#10 +
  '-FO - FileOutput  default - "fileInput^.fb2"' +#13#10 +
  '-FR - FileReport  default - "Report.txt"'+#13#10 +
  '-D  - Distantion  default - 14 (distance between file hashes)'+#13#10 +
  '-p  - PercArea    default - 40 (Percentage of file area difference)';
   procedure GetParams;
   var
     s,s1:string;
   begin
      s:= ParamStr(1);
      if (AnsiUppercase(s)<>'-FI') and
         (AnsiUppercase(s)<>'-FO') and
         (AnsiUppercase(s)<>'-FR') and
         (AnsiUppercase(s)<>'-D') and
         (AnsiUppercase(s)<>'-P')
      then
      begin
        fileIn:= s;


      end;


      for i := 1 to ParamCount do
      begin
       s:= ParamStr(i);
       if(AnsiUppercase(s)<>'-FI') and (i+1<=ParamCount) then
        fileIn:= ParamStr(i+1);
       if(AnsiUppercase(s)<>'-FO') and (i+1<=ParamCount) then
        fileOut:= ParamStr(i+1);
       if(AnsiUppercase(s)<>'-FR') and (i+1<=ParamCount) then
        FileRep:= ParamStr(i+1);
       if(AnsiUppercase(s)<>'-D') and (i+1<=ParamCount) then
        Distantion:= strtointdef(ParamStr(i+1),14);
       if(AnsiUppercase(s)<>'-P') and (i+1<=ParamCount) then
        PercArea:= strtointdef(ParamStr(i+1),40);

      end;
      if fileOut='' then
      begin
       fileOut:= fileIn;
       fileOut:= copy(filein,1,length(filein)-4);
       fileOut:= fileOut +'^.fb2';
      end;
      if FileRep='' then
      begin
        s:= fileIn;
        s:= ExtractFileDir(s);
        FileRep:= IncludeTrailingPathDelimiter(s)+'Report.txt';
      end;
       if Distantion=0 then Distantion:= 14;
       if PercArea=0   then PercArea:=40;
   end;

begin
  if ParamCount=0 then
  begin
   writeln(help);
  end
  else
  begin
    GetParams;
    Reader := TFB2Reader.Create;
     try
       writeln('Load '+FileIn);
      Reader.LoadFromFile(FileIn);
      writeln('Load - ok.');
       Analyzer := TFB2Analyzer.Create(Reader);
      try
       writeln('Analize and replace file');
        Analyzer.Analyze(Filerep, Distantion, PercArea);
        writeln('Analize and replace - ok.');
        writeln('Save to file '+FileOut);
        Reader.SaveToFile(FileOut);
        writeln('Save to file - ok.');
      finally
        Analyzer.Free;
      end;
    finally
      Reader.Free;
    end;
  end;
end.
