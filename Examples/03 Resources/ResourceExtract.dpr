program ResourceExtract;

uses
  System.SysUtils,

  PE.Image,
  PE.Resources;

type
  TMyImg = class(TPEImage)
    function MyTraverse(Node: TResourceTreeNode; ud: pointer): boolean;
  end;

var
  img: TMyImg;

  { TMyImg }

function TMyImg.MyTraverse(Node: TResourceTreeNode; ud: pointer): boolean;
var
  Leaf: TResourceTreeLeafNode;
  FileName, ParentName: string;
  Written: uint32;
begin
  // Need only leaf nodes (data).
  if Node.IsLeaf then
  begin
    Leaf := Node as TResourceTreeLeafNode;

    // Leaf should always have parent (branch), though it's just example.
    if (Leaf.Parent <> nil) then
      ParentName := (Leaf.Parent as TResourceTreeBranchNode).GetSafeName
    else
      ParentName := '';

    // Make file name.
    FileName := Format('tmp\rsrc_%s_%x_%x_%x',
      [ParentName, Leaf.DataRVA, Leaf.DataSize, Leaf.Codepage]);

    // Dump raw resource.
    Written := self.DumpRegionToFile(FileName, Leaf.DataRVA, Leaf.DataSize);
  end;
  Result := True; // continue
end;

begin
  img := TMyImg.Create;
  try
    if img.LoadFromFile('SampleLib.dll') then
    begin
      // Traverse and dump all resources.
      img.ResourceTree.Traverse(img.MyTraverse);
    end;
  finally
    img.Free;
  end;

end.
