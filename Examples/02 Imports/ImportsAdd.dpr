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

    // Adding dll and func in one line.
    // To add few funcs, lib must be stored to temp. variable.
    img.Imports.NewLib('some.dll').NewFunction('somefunc');

    if ReBuildDirData(img, DDIR_IMPORT, true) <> nil then
      img.SaveToFile('tmp\new_import.dll')
    else
      writeln('Failed to rebuild image');
  finally
    img.Free;
  end;

end.
