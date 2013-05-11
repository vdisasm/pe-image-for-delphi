program ModuleLoader;

uses
  PE.Image,
  PE.ExecutableLoader;

var
  Img: TPEImage;
  Module: TExecutableModule;

begin
  Img := TPEImage.Create;
  Module := TExecutableModule.Create(Img);
  try
    if Img.LoadFromFile('SampleLib.dll') then
    begin
      if Module.Load() <> msOK then
          ; // error
    end;
  finally
    Module.Free; // free it before Img.
    Img.Free;
  end;

end.
