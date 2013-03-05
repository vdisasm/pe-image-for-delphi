{
  Classes to represent resource data.

  Adding or removing children must be done from TResourceTree to maintain
  right total count.
}
unit PE.Resources;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.SysUtils,

  PE.Common,
  PE.Types.Resources;

type
  { Nodes }

  // Base node.
  TResourceTreeNode = class
  public
    Parent: TResourceTreeNode;

    // Either ID or Name.
    Id: uint32;
    Name: UnicodeString;

    function IsBranch: boolean; inline;
    function IsLeaf: boolean; inline;

    function GetPath: string;
  end;

  // Node list.
  TResourceTreeNodes = TList<TResourceTreeNode>;

  // Leaf node (data).
  TResourceTreeLeafNode = class(TResourceTreeNode)
  private
    FDataRVA: TRVA; // RVA of data in original image.
    FCodepage: uint32;
    FData: TMemoryStream;
    function GetDataSize: uint32;
    function GetCodePage: uint32;
  public
    constructor Create(PE: TPEImageObject; DataRVA: TRVA; DataSize: uint32; CodePage: uint32);
    constructor CreateFromEntry(PE: TPEImageObject; const Entry: TResourceDataEntry);
    destructor Destroy; override;
    property Data: TMemoryStream read FData;
    property DataRVA: TRVA read FDataRVA;
    property DataSize: uint32 read GetDataSize;
    property CodePage: uint32 read GetCodePage;
  end;

  // Branch node.
  TResourceTreeBranchNode = class(TResourceTreeNode)
  public
    Characteristics: uint32;
    TimeDateStamp: uint32;
    MajorVersion: uint16;
    MinorVersion: uint16;

    Children: TResourceTreeNodes;

    constructor Create;
    destructor Destroy; override;

    // Get either Name or Id as string.
    function GetSafeName: string;
  end;

  // Return False to stop traversing or True to continue.
  TResourceTraverseMethod = function(Node: TResourceTreeNode): boolean of object;

  { Tree }

  TResourceTree = class
  private
    FTotalNodes: integer;
  protected
    FRoot: TResourceTreeBranchNode;
    procedure CreateDummyRoot;
  public

    constructor Create;
    destructor Destroy; override;

    // Add child node.
    function AddChild(Node: TResourceTreeNode; ParentNode: TResourceTreeBranchNode)
      : TResourceTreeNode; // inline;

    // Traverse from node.
    procedure TraverseNode(Node: TResourceTreeNode;
      TraverseMethod: TResourceTraverseMethod);

    // Traverse from root.
    procedure Traverse(TraverseMethod: TResourceTraverseMethod;
      UserData: pointer = nil); inline;

    // Clear all nodes.
    procedure Clear;

    property Root: TResourceTreeBranchNode read FRoot;
    property TotalNodes: integer read FTotalNodes;
  end;

implementation

uses
  PE.Image;

{ TResourceTreeNode }

constructor TResourceTreeBranchNode.Create;
begin
  inherited;
  Children := TResourceTreeNodes.Create;
end;

destructor TResourceTreeBranchNode.Destroy;
var
  n: TResourceTreeNode;
begin
  for n in Children do
    n.Free;
  Children.Free;
  inherited;
end;

function TResourceTreeBranchNode.GetSafeName: string;
begin
  if name <> '' then
    Result := name
  else
    Result := Format('#%d', [Id])
end;

{ TResourceTreeNode }

function TResourceTreeNode.GetPath: string;
var
  Cur: TResourceTreeNode;
  Separator: string;
begin
  Cur := self;

  if Cur.IsLeaf then
  begin
    Result := Format('(%d)', [TResourceTreeLeafNode(Cur).FCodepage]);
  end;

  // All parent nodes are branches.
  // Go up excluding root node.
  while (Cur.Parent <> nil) and (Cur.Parent.Parent <> nil) do
  begin
    // Leaf node don't need PathDelim.
    if Cur = self then
      Separator := ''
    else
      Separator := PathDelim;
    Result := Format('%s%s%s', [TResourceTreeBranchNode(Cur.Parent).GetSafeName,
      Separator, Result]);
    Cur := Cur.Parent;
  end;
end;

function TResourceTreeNode.IsBranch: boolean;
begin
  Result := (self is TResourceTreeBranchNode);
end;

function TResourceTreeNode.IsLeaf: boolean;
begin
  Result := (self is TResourceTreeLeafNode);
end;

{ TResourceTree }

function TResourceTree.AddChild(Node: TResourceTreeNode;
  ParentNode: TResourceTreeBranchNode): TResourceTreeNode;
begin
  Result := Node;
  if Assigned(Node) then
  begin
    Node.Parent := ParentNode;
    ParentNode.Children.Add(Node);
    Inc(FTotalNodes);
  end;
end;

procedure TResourceTree.Clear;
begin
  FRoot.Free; // To destroy all children.
  FTotalNodes := 0;
  CreateDummyRoot;
end;

constructor TResourceTree.Create;
begin
  inherited;
  CreateDummyRoot;
end;

procedure TResourceTree.CreateDummyRoot;
begin
  FRoot := TResourceTreeBranchNode.Create;
end;

destructor TResourceTree.Destroy;
begin
  FRoot.Free;
  inherited;
end;

procedure TResourceTree.Traverse(TraverseMethod: TResourceTraverseMethod;
  UserData: pointer);
begin
  TraverseNode(FRoot, TraverseMethod);
end;

procedure TResourceTree.TraverseNode(Node: TResourceTreeNode;
  TraverseMethod: TResourceTraverseMethod);
const
  WANT_MORE_NODES = True;
var
  n: TResourceTreeNode;
begin
  if Assigned(TraverseMethod) and (Assigned(Node)) then
  begin
    // Visit node.
    if TraverseMethod(Node) = WANT_MORE_NODES then
    begin
      // If branch, visit children.
      if Node.IsBranch then
        for n in TResourceTreeBranchNode(Node).Children do
          TraverseNode(n, TraverseMethod)
    end;
  end;
end;

{ TResourceTreeLeafNode }

constructor TResourceTreeLeafNode.Create(PE: TPEImageObject; DataRVA: TRVA;
  DataSize: uint32; CodePage: uint32);
begin
  FDataRVA := DataRVA;
  FCodepage := CodePage;
  // Create stream and copy data from image.
  FData := TMemoryStream.Create;
  if DataSize <> 0 then
  begin
    FData.Size := DataSize;
    TPEImage(PE).DumpRegionToStream(FData, DataRVA, DataSize);
  end;
end;

constructor TResourceTreeLeafNode.CreateFromEntry(PE: TPEImageObject;
  const Entry: TResourceDataEntry);
begin
  Create(PE, Entry.DataRVA, Entry.Size, Entry.CodePage);
end;

destructor TResourceTreeLeafNode.Destroy;
begin
  FData.Free;
  inherited;
end;

function TResourceTreeLeafNode.GetCodePage: uint32;
begin
  Result := FCodepage;
end;

function TResourceTreeLeafNode.GetDataSize: uint32;
begin
  Result := FData.Size;
end;

end.
