program ResourceBuild;

uses
  PE.Common,
  PE.Image,
  PE.Build,
  PE.Build.Resource in '..\..\PE.Build.Resource.pas';

const
  src = 'SampleLib.dll';

var
  Img: TPEImage;

begin
  ReportMemoryLeaksOnShutdown := True;
  Img := TPEImage.Create;
  try
    // Parse resources only.
    if Img.LoadFromFile(src, [PF_RESOURCES]) then
    begin
      ReBuildDirData(Img, DDIR_RESOURCE, True);
      Img.SaveToFile('tmp\new_resources.dll');
    end;
  finally
    Img.Free;
  end;

end.
