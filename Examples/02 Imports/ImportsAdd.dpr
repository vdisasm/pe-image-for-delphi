program ImportsAdd;

{$APPTYPE CONSOLE}


uses
  PE.Common,
  PE.Image,
  PE.Imports,
  PE.Imports.Func,
  PE.Build;

var
  img: TPEImage;

begin
  img := TPEImage.Create;
  try
    img.LoadFromFile('SampleLib.dll');

    // Import some func from some.dll at rva $1000
    img.Imports.AddNew($1000, 'some.dll', 'somefunc');

    if ReBuildDirData(img, DDIR_IMPORT, true) <> nil then
      img.SaveToFile('tmp\new_import.dll')
    else
      writeln('Failed to rebuild image');
  finally
    img.Free;
  end;

end.
