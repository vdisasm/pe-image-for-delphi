{
  Example of creating image with resources from scratch.
}
program ResourceBuild;

uses
  PE.Common,
  PE.Image,
  PE.Build,
  PE.Resources.Windows,
  PE.Resources;

procedure CreateResources;
var
  Img: TPEImage;
  lf: TResourceTreeLeafNode;
  r: TWindowsResourceTree;
  data1, data2, data3, data4, data5: uint32;
begin
  Img := TPEImage.Create;
  try
    // Create Windows resource tree to handle generic resources in Windows way.
    r := TWindowsResourceTree.Create(Img.ResourceTree);
    try
      // Setup data.
      data1 := $C0DE0001;
      data2 := $C0DE0002;
      data3 := $C0DE0003;
      data4 := $C0DE0004;
      data5 := $C0DE0005;

      // UpdateResource will update existing resource or create new reource
      // if it doesn't exist.
      
      // Named entries.
      r.UpdateResource(PChar(RT_RCDATA), 'abc', 1234, @data1, 4);
      r.UpdateResource(PChar(RT_RCDATA), 'def', 2345, @data2, 4);
      r.UpdateResource(PChar(RT_RCDATA), 'cde', 3456, @data3, 4);
      // Non-english name.
      r.UpdateResource(PChar(RT_RCDATA), 'Новый ресурс', 3456, @data4, 4);
      // ID entries.
      r.UpdateResource(PChar(RT_RCDATA), PChar(432), 4567, @data5, 4);
      r.UpdateResource(PChar(RT_RCDATA), PChar(123), 4567, @data5, 4);

      lf := r.FindResource(PChar(RT_RCDATA), 'cde', 3456);
      lf.Data.LoadFromFile('dummy.txt');
    finally
      r.Free;
    end;
    // Rebuild resources
    ReBuildDirData(Img, DDIR_RESOURCE, True);
    Img.SaveToFile('tmp\new_resources_from_scratch.dll');
  finally
    Img.Free;
  end;
end;

begin
  CreateResources;

end.
