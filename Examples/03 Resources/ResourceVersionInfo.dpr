{
  Parse version info resource (RT_VERSION)
}
program ResourceVersionInfo;

{$APPTYPE CONSOLE}

{$R *.res}


uses
  System.SysUtils,

  PE.Image,
  PE.Resources,
  PE.Resources.Windows,
  PE.Resources.VersionInfo;

procedure DumpRtVersionNode(node: TResourceTreeLeafNode);
var
  inf: TPEVersionInfo;
begin
  writeln(format('  lang: %d', [node.id]));

  inf := TPEVersionInfo.Create;
  try
    inf.LoadFromStream(node.Data);
    inf.PrintTree(
      procedure(const Text: string)
      begin
        writeln(Text);
      end);
  finally
    inf.Free;
  end;
end;

procedure DumpRtVersionBranch(branch: TResourceTreeBranchNode);
var
  n, leaf: TResourceTreeNode;
  n_br: TResourceTreeBranchNode;
  name: string;
begin
  for n in branch.Children do
  begin
    if not n.IsBranch then
      raise Exception.Create('Expected branch node (ID)');

    name := n.GetNameOrId;
    writeln(name);

    n_br := TResourceTreeBranchNode(n);
    if n_br.Children.Count = 0 then
    begin
      writeln('  no sub-nodes');
      exit;
    end;

    for leaf in n_br.Children do
      if leaf.IsLeaf then
        DumpRtVersionNode(TResourceTreeLeafNode(leaf))
      else
        raise Exception.Create('Expected leaf node');
  end;
end;

procedure Parse(const FileName: string);
var
  img: TPEImage;
  rt: TWindowsResourceTree;
  branch_rt_version: TResourceTreeBranchNode;
begin
  img := TPEImage.Create;
  try
    if not img.LoadFromFile(FileName) then
    begin
      writeln('Failed to load image');
      exit;
    end;

    // Find RT_VERSION branch.
    rt := TWindowsResourceTree.Create(img.ResourceTree);
    try
      branch_rt_version := rt.FindResource(PChar(RT_VERSION));
    finally
      rt.Free;
    end;

    if branch_rt_version = nil then
    begin
      writeln('no RT_VERSION branch found');
      exit;
    end;

    DumpRtVersionBranch(branch_rt_version);
  finally
    img.Free;
  end;
end;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    // verinfo1.dll doesn't exist
    // You have to create it first.
    Parse('verinfo1.dll');
    readln;
  except
    on E: Exception do
      writeln(E.ClassName, ': ', E.Message);
  end;

end.
