program directory_save_and_load;

{$APPTYPE CONSOLE}

{$R *.res}


uses
  System.SysUtils,

  PE.Image;

procedure main;
var
  img: TPEImage;
begin
  img := TPEImage.Create;
  try
    if img.LoadFromFile('SampleLib.dll', []) then
    begin
      img.DataDirectories.SaveToFile(0, 'export_dir');
      img.DataDirectories.LoadFromFile(0, 'export_dir', 0);
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
