{
  List image resources sorted by size.
}
program ResourceStats;

{$apptype console}


uses
  System.Generics.Collections,
  System.Generics.Defaults,
  System.SysUtils,

  PE.Common,
  PE.Image,
  PE.Resources;

type
  TSizePair = TPair<string, uint32>; // name, size pair
  TSizeList = TList<TSizePair>;

  TMyImg = class(TPEImage)
  public
    List: TSizeList;
    constructor Create;
    destructor Destroy; override;

    function MyTraverse(Node: TResourceTreeNode): boolean;
  end;

var
  img: TMyImg;
  pair: TSizePair;

  { TMyImg }

constructor TMyImg.Create;
begin
  inherited Create;
  List := TSizeList.Create;
end;

destructor TMyImg.Destroy;
begin
  List.Free;
  inherited;
end;

function TMyImg.MyTraverse(Node: TResourceTreeNode): boolean;
var
  Leaf: TResourceTreeLeafNode;
begin
  if Node.IsLeaf then
  begin
    Leaf := Node as TResourceTreeLeafNode;
    List.Add(TSizePair.Create(Leaf.GetPath, Leaf.Data.Size));
  end;
  result := True; // continue
end;

begin
  img := TMyImg.Create;
  try
    if ParamStr(1) <> '' then
      if img.LoadFromFile(ParamStr(1), [PF_RESOURCES]) then
      begin
        img.ResourceTree.Root.Traverse(img.MyTraverse);

        img.List.Sort(TComparer<TSizePair>.Construct(
          function(const a, b: TSizePair): integer
          begin
            if a.Value > b.Value then
              exit(1)
            else if a.Value < b.Value then
              exit(-1);
            exit(0);
          end
          ));

        for pair in img.List do
          writeln(format('%-16d %s', [pair.Value, pair.Key]));

      end;
  finally
    img.Free;
  end;

  readln;

end.
