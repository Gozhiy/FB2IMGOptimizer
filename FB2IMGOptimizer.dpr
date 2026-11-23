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
  'FB2IMGOptimizer.exe [InputFile] [-fi <InputFile>] [-fo <OutputFile>] [-fr <ReportFile>] [-D <Distance>] [-p <PercArea>]' +#13#10#13#10 +
  ' InputFile  Input FB2 file. Can be specified as the first argument without the -fi switch.' + #13#10 +
  '-fi  Explicitly specifies the input FB2 file' +#13#10 +
  '-fo  Output FB2 file (Default: input filename with "_optimized" suffix)  ' +#13#10 +
  '-fr  Report file (default: Report.txt) ' +#13#10 +
  '-D   Maximum distance between image hashes (default: 14)  ' +#13#10 +
  '-p   Maximum percentage difference in image area (default: 40)' ;

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
       fileOut:= fileOut +'_optimized.fb2';
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
