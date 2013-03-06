program ResourceBuild;

uses
  System.SysUtils,
  PE.Common,
  PE.Image,
  PE.Build,
  PE.Build.Resource in '..\..\PE.Build.Resource.pas',
  PE.Resources.Windows in '..\..\PE.Resources.Windows.pas',
  PE.Resources in '..\..\PE.Resources.pas';

const
  src = 'SampleLib.dll';

procedure Example1;
var
  Img: TPEImage;
begin
  Img := TPEImage.Create;
  try
    // Parse resources only.
    if Img.LoadFromFile(src, [PF_RESOURCES]) then
    begin
      // Rebuild resources
      ReBuildDirData(Img, DDIR_RESOURCE, True);
      Img.SaveToFile('tmp\new_resources.dll');
    end;
  finally
    Img.Free;
  end;
end;

procedure Example2;
var
  Img: TPEImage;
  br: TResourceTreeBranchNode;
  lf: TResourceTreeLeafNode;
begin
  Img := TPEImage.Create;
  try
    // Add 1st branch.
    br := Img.ResourceTree.Root.AddNewBranch;
    br.Name := 'my1';

    // Add sub-branch.
    br := br.AddNewBranch;
    br.Name := 'my2';

    // Add leaf.
    lf := br.AddNewLeaf;
    lf.Id := 1234;
    lf.Data.Write(TBytes.Create(1, 2, 3), 3);

    // Rebuild resources
    ReBuildDirData(Img, DDIR_RESOURCE, True);
    Img.SaveToFile('tmp\new_resources_from_scratch.dll');
  finally
    Img.Free;
  end;
end;

procedure Example3;
var
  Img: TPEImage;
  n: TResourceTreeNode;
begin
  Img := TPEImage.Create;
  try
    // Parse resources only.
    if Img.LoadFromFile('aida64u.exe', [PF_RESOURCES]) then
    begin
      n := img.ResourceTree.Root.Find(RT_RCDATA);

      // Rebuild resources
      // ReBuildDirData(Img, DDIR_RESOURCE, True);
      // Img.SaveToFile('tmp\new_resources.dll');
    end;
  finally
    Img.Free;
  end;
end;

begin
  ReportMemoryLeaksOnShutdown := True;

  Example3;

end.
