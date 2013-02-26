program DLLLoader;

uses
  PE.Image,
  PE.DLLLoader;

var
  Img: TPEImage;
  DLL: TDLL;

begin
  Img := TPEImage.Create;
  DLL := TDLL.Create(Img);
  try
    if Img.LoadFromFile('SampleLib.dll') then
    begin
      if DLL.Load() <> msOK then
          ; // error
    end;
  finally
    DLL.Free; // free it before Img.
    Img.Free;
  end;

end.
