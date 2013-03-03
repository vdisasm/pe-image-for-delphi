{
  Classes to represent resource data.

  Adding or removing children must be done though helper functions, not directly
  to maintatin right total count. Total count needed during resource table
  building.
}
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

    // Get either Name or Id as string.
    function GetSafeName: string;
  end;

  // Return False to stop traversing.
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

end.
