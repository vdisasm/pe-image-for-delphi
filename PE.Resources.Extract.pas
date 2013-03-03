unit PE.Resources.Extract;

interface

uses
  PE.Common,
  PE.Resources;

// Extract raw resource data from Root node and save it to Dir folder.
// If Root is nil, the main root is taken.
// Result is number of resources extracted.
function ExtractRawResources(Img: TPEImageObject; const Dir: string;
  Root: TResourceTreeNode = nil): integer;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  PE.Image;

type

  { TExtractor }

  TExtractor = class
  private
    FImg: TPEImage;
    FDir: string;
    FCount: integer;
    function Callback(Node: TResourceTreeNode): boolean;
  public
    function Extract(Img: TPEImage; const Dir: string; Root: TResourceTreeNode): integer;
  end;

function TExtractor.Callback(Node: TResourceTreeNode): boolean;
var
  Leaf: TResourceTreeLeafNode;
  FileName, ParentName: string;
  Written: uint32;
begin
  if Node.IsLeaf then
  begin
    Leaf := Node as TResourceTreeLeafNode;

    if (Leaf.Parent <> nil) then
      ParentName := (Leaf.Parent as TResourceTreeBranchNode).GetSafeName
    else
      ParentName := '';

    // Make file name.
    FileName := Format('%s\rsrc_%s_%x_%x_%x',
      [FDir, ParentName, Leaf.DataRVA, Leaf.DataSize, Leaf.Codepage]);

    // Dump raw resource.
    Written := FImg.DumpRegionToFile(FileName, Leaf.DataRVA, Leaf.DataSize);

    inc(FCount);
  end;
  Result := True; // continue
end;

function ExtractRawResources(Img: TPEImageObject; const Dir: string; Root: TResourceTreeNode = nil): integer;
var
  Extractor: TExtractor;
begin
  Extractor := TExtractor.Create;
  try
    Result := Extractor.Extract(Img as TPEImage,
      ExcludeTrailingPathDelimiter(Dir), Root);
  finally
    Extractor.Free;
  end;
end;

function TExtractor.Extract(Img: TPEImage; const Dir: string;
  Root: TResourceTreeNode): integer;
begin
  FImg := Img;
  FDir := Dir;
  FCount := 0;
  if Root = nil then
    Root := Img.ResourceTree.Root;
  if Root = nil then
    Exit(0);
  TDirectory.CreateDirectory(Dir);
  Img.ResourceTree.TraverseNode(Root, Callback);
  Exit(FCount);
end;

end.
