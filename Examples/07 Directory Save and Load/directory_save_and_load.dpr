{
  * This example shows how block of data specified in data directory can be
  * saved from image and loaded into image.
  *
  * Though this is not recommended way to export directory data unless you
  * know what you do.
  *
  * Normally you need to export parsed data (such as imports, exports and other)
  * and save it in your custom file format.
  *
  * Note that image directory size can be less than actual data. So real size
  * can be calcualted only by parsing directory. That's why avoid saving/loading
  * directory data directly. Use parsed data instead.
}
program directory_save_and_load;

{$APPTYPE CONSOLE}

{$R *.res}


uses
  System.SysUtils,

  PE.Common,
  PE.Image;

procedure main;
var
  img: TPEImage;
begin
  img := TPEImage.Create;
  try
    if img.LoadFromFile('SampleLib.dll', []) then
    begin
      img.DataDirectories.SaveToFile(DDIR_EXPORT, 'export_dir');
      img.DataDirectories.LoadFromFile(DDIR_EXPORT, 'export_dir', 0);
    end;
  finally
    img.Free;
  end;
end;

begin
  try
    main;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
