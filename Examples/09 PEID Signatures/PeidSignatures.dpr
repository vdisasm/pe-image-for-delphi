program PeidSignatures;

{$APPTYPE CONSOLE}

{$R *.res}


uses
  System.Classes,
  System.Diagnostics,
  System.SysUtils,

  PE.ID,
  PE.Image;

procedure main;
var
  sig: TPEIDSignatures;
  img: TPEImage;
  FoundSigs: TStringList;
  s: string;
  sw: TStopwatch;
begin
  // Try to load signatures.
  sig := PeidLoadSignatures('UserDB.txt');
  try
    if assigned(sig) then
    begin
      img := TPEImage.Create;
      FoundSigs := TStringList.Create;
      try
        if img.LoadFromFile('SampleLib.dll', []) then
        begin
          sw := TStopwatch.StartNew;
          PeidScan(img, sig, FoundSigs);
          sw.Stop;
          writeln('Elapsed ', string(sw.Elapsed));

          if FoundSigs.Count <> 0 then
          begin
            for s in FoundSigs do
              writeln(s);
          end
          else
          begin
            writeln('Nothing detected');
          end;

        end;
      finally
        img.Free;
        FoundSigs.Free;
      end;
    end;
  finally
    sig.Free;
  end;
end;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    main;
    readln;
  except
    on E: Exception do
      writeln(E.ClassName, ': ', E.Message);
  end;

end.
