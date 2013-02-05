unit PE.Resources;

interface

uses
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

    function IsBranch: boolean; inline;
    function IsLeaf: boolean; inline;
  end;

  // Node list.
  TResourceTreeNodes = TList<TResourceTreeNode>;

  // Leaf node (data).
  TResourceTreeLeafNode = class(TResourceTreeNode)
  public
    DataRVA: TRVA;
    DataSize: uint32;
    Codepage: uint32;
  end;

  // Branch node.
  TResourceTreeBranchNode = class(TResourceTreeNode)
  public
    Characteristics: uint32;
    TimeDateStamp: uint32;
    MajorVersion: uint16;
    MinorVersion: uint16;

    // Either ID or Name.
    Id: uint32;
    Name: String;

    Children: TResourceTreeNodes;

    constructor Create;
    destructor Destroy; override;

    // Add child node.
    function AddChild(Node: TResourceTreeNode): TResourceTreeNode;

    // Get either Name or Id as string.
    function GetSafeName: string;

  end;

  // Return False to stop traversing.
  TResourceTreeNodeTraverseProc = function(Node: TResourceTreeNode; ud: pointer)
    : boolean of object;

  { Tree }

  TResourceTree = class
  protected
    FRoot: TResourceTreeBranchNode;
    procedure CreateDummyRoot;
    procedure TraverseNode(Node: TResourceTreeNode;
      TraverseProc: TResourceTreeNodeTraverseProc; UserData: pointer);
  public

    constructor Create;
    destructor Destroy; override;

    // Add child node.
    function AddChild(Node: TResourceTreeNode; Parent: TResourceTreeBranchNode)
      : TResourceTreeNode; inline;

    // Traverse from root.
    procedure Traverse(TraverseProc: TResourceTreeNodeTraverseProc;
      UserData: pointer = nil); inline;

    // Clear all nodes.
    procedure Clear;

    property Root: TResourceTreeBranchNode read FRoot;
  end;

implementation

{ TResourceTreeNode }

function TResourceTreeBranchNode.AddChild(Node: TResourceTreeNode)
  : TResourceTreeNode;
begin
  Result := Node;
  if Assigned(Node) then
  begin
    Node.Parent := self;
    Children.Add(Node);
  end;
end;

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
  Parent: TResourceTreeBranchNode): TResourceTreeNode;
begin
  Result := Parent.AddChild(Node);
end;

procedure TResourceTree.Clear;
begin
  FRoot.Free; // To destroy all children.
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

procedure TResourceTree.Traverse(TraverseProc: TResourceTreeNodeTraverseProc;
  UserData: pointer);
begin
  TraverseNode(FRoot, TraverseProc, UserData);
end;

procedure TResourceTree.TraverseNode(Node: TResourceTreeNode;
  TraverseProc: TResourceTreeNodeTraverseProc; UserData: pointer);
const
  WANT_MORE_NODES = True;
var
  n: TResourceTreeNode;
begin
  if Assigned(TraverseProc) and (Assigned(Node)) then
  begin
    // Visit node.
    if TraverseProc(Node, UserData) = WANT_MORE_NODES then
    begin
      if Node is TResourceTreeBranchNode then
        // Visit children.
        for n in TResourceTreeBranchNode(Node).Children do
          TraverseNode(n, TraverseProc, UserData)
    end;
  end;
end;

end.
