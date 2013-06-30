{
  Classes to represent resource data.
}
unit PE.Resources;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.SysUtils,

  gRBTree,

  PE.Common,
  PE.Types.Resources;

type
  { Nodes }

  TResourceTreeNode = class;
  TResourceTreeBranchNode = class;

  // Return False to stop traversing or True to continue.
  TResourceTraverseMethod = function(Node: TResourceTreeNode): boolean of object;

  // Base node.
  TResourceTreeNode = class
  private
    // Either ID or Name.
    FId: uint32;
    FName: UnicodeString;
    procedure SetId(const Value: uint32);
    procedure SetName(const Value: UnicodeString);
  public
    Parent: TResourceTreeBranchNode;

    procedure Traverse(TraverseMethod: TResourceTraverseMethod); inline;

    // Check if node is named. Otherwise it's ID.
    function IsNamed: boolean; inline;

    function IsBranch: boolean; inline;
    function IsLeaf: boolean; inline;

    // Find resource by Name or Id.
    function FindByName(const Name: string): TResourceTreeNode; inline;
    function FindByID(Id: uint32): TResourceTreeNode; inline;
    // By Name/Id.
    function FindNode(Node: TResourceTreeNode): TResourceTreeNode;
    // Find either by name or by id.
    function FindByNameOrId(const Name: string; Id: uint32): TResourceTreeNode;

    function GetPath: string;

    property Id: uint32 read FId write SetId;
    property Name: UnicodeString read FName write SetName;
  end;

  // Node list.
  TResourceTreeNodes = TRBTree<TResourceTreeNode>;

  // Leaf node (data).
  TResourceTreeLeafNode = class(TResourceTreeNode)
  private
    FDataRVA: TRVA; // RVA of data in original image.
    FCodepage: uint32;
    FData: TMemoryStream;
    function GetDataSize: uint32;
  public
    constructor Create;
    constructor CreateFromRVA(PE: TPEImageObject; DataRVA: TRVA; DataSize: uint32; CodePage: uint32);
    constructor CreateFromEntry(PE: TPEImageObject; const Entry: TResourceDataEntry);
    constructor CreateFromStream(Stream: TStream; Pos: UInt64 = 0; Size: UInt64 = 0);

    destructor Destroy; override;

    procedure UpdateData(Buffer: PByte; Size: uint32);

    property Data: TMemoryStream read FData;
    property DataRVA: TRVA read FDataRVA;
    property DataSize: uint32 read GetDataSize;
    property CodePage: uint32 read FCodepage write FCodepage;
  end;

  // Branch node.
  TResourceTreeBranchNode = class(TResourceTreeNode)
  private
    // 5.9.2. Resource Directory Entries
    // ...
    // All the Name entries precede all the ID entries for the table.
    // All entries for the table are sorted in ascending order:
    // Name entries by case-insensitive string and the ID entries by numeric value.
    FChildren: TResourceTreeNodes;

    procedure ChildrenNotify(Sender: TObject; const Item: TResourceTreeNode;
      Action: TCollectionNotification);

    // Make sure node will be placed in right order.
    // To allow Id/Name be changed dynamically we need to call KeepNodeOrder_Begin
    // before changing (it will remove current node without destroying it) and
    // call KeepNodeOrder_End when change done (to add changed node). It is done
    // internally in SetId and SetName (TResourceTreeNode).
    // The benefit is nodes are always sorted dynamically.
    // If KeepNodeOrder_Begin/end not called, RBTree structure will
    // be corrupted during change of Name/Id.
    procedure KeepNodeOrder_Begin(Node: TResourceTreeNode); inline;
    procedure KeepNodeOrder_End(Node: TResourceTreeNode); inline;
  public
    Characteristics: uint32;
    TimeDateStamp: uint32;
    MajorVersion: uint16;
    MinorVersion: uint16;

    constructor Create();
    destructor Destroy; override;

    // Get either Name or Id as string.
    function GetSafeName: string;

    // Add node to children. Result is added node.
    function Add(Node: TResourceTreeNode): TResourceTreeNode;
    function AddNewBranch: TResourceTreeBranchNode;
    function AddNewLeaf: TResourceTreeLeafNode;

    // Remove node. Result is True if node was found and removed.
    function Remove(Node: TResourceTreeNode;
      RemoveSelfIfNoChildren: boolean = False): boolean;

    property Children: TResourceTreeNodes read FChildren;
  end;

  { Tree }

  TResourceTree = class
  protected
    FRoot: TResourceTreeBranchNode;
    procedure CreateDummyRoot;
  public
    constructor Create;
    destructor Destroy; override;

    // Clear all nodes.
    procedure Clear;

    property Root: TResourceTreeBranchNode read FRoot;
  end;

implementation

uses
  PE.Image;

function TreeNodeCompareLess(const A, B: TResourceTreeNode): boolean;
var
  NamedA, NamedB: boolean;
  n1, n2: string;
begin
  NamedA := A.IsNamed;
  NamedB := B.IsNamed;
  if NamedA and NamedB then // Compare named.
  begin
    n1 := UpperCase(A.Name);
    n2 := UpperCase(B.Name);
    exit(CompareStr(n1, n2) < 0);
  end;
  if (not NamedA) and (not NamedB) then // Compare by ID.
    Result := A.Id < B.Id
  else // Compare Named vs ID (named must go first).
    Result := NamedA and (not NamedB);
end;

{ TResourceTreeNode }

function TResourceTreeBranchNode.Add(Node: TResourceTreeNode): TResourceTreeNode;
begin
  Result := Node;
  if Assigned(Node) then
  begin
    Node.Parent := Self;
    FChildren.Add(Node);
  end;
end;

function TResourceTreeBranchNode.AddNewBranch: TResourceTreeBranchNode;
begin
  Result := TResourceTreeBranchNode.Create;
  Add(Result);
end;

function TResourceTreeBranchNode.AddNewLeaf: TResourceTreeLeafNode;
begin
  Result := TResourceTreeLeafNode.Create;
  Add(Result);
end;

procedure TResourceTreeBranchNode.ChildrenNotify(Sender: TObject;
  const Item: TResourceTreeNode; Action: TCollectionNotification);
begin
  case Action of
    cnRemoved:
      Item.Free;
  end;
end;

constructor TResourceTreeBranchNode.Create();
begin
  inherited;
  FChildren := TResourceTreeNodes.Create(TreeNodeCompareLess);
  FChildren.OnNotify := ChildrenNotify;
end;

function TResourceTreeBranchNode.Remove(Node: TResourceTreeNode;
  RemoveSelfIfNoChildren: boolean): boolean;
begin
  Result := FChildren.Remove(Node);
  if RemoveSelfIfNoChildren and (Self.FChildren.Count = 0) and (Parent <> nil) then
    Self.Parent.Remove(Self, True);
end;

destructor TResourceTreeBranchNode.Destroy;
begin
  FChildren.Free;
  inherited;
end;

function TResourceTreeBranchNode.GetSafeName: string;
begin
  if IsNamed then
    Result := name
  else
    Result := Format('#%d', [Id])
end;

procedure TResourceTreeBranchNode.KeepNodeOrder_Begin(Node: TResourceTreeNode);
begin
  if Assigned(Self) then
    FChildren.Remove(Node, False);
end;

procedure TResourceTreeBranchNode.KeepNodeOrder_End(Node: TResourceTreeNode);
begin
  if Assigned(Self) then
    FChildren.Add(Node, False);
end;

{ TResourceTreeNode }

function TResourceTreeNode.FindByName(const Name: string): TResourceTreeNode;
begin
  Result := FindByNameOrId(Name, 0);
end;

function TResourceTreeNode.FindByID(Id: uint32): TResourceTreeNode;
begin
  Result := FindByNameOrId('', Id);
end;

function TResourceTreeNode.FindByNameOrId(const Name: string;
  Id: uint32): TResourceTreeNode;
var
  tmp: TResourceTreeNode;
  p: TResourceTreeNodes.TRBNodePtr;
begin
  Result := nil;
  if not IsBranch then
    exit;
  tmp := TResourceTreeNode.Create;
  try
    tmp.FName := Name;
    tmp.FId := Id;
    p := TResourceTreeBranchNode(Self).FChildren.Find(tmp);
    if p <> nil then
      Result := p^.K;
  finally
    tmp.Free;
  end;
end;

function TResourceTreeNode.FindNode(Node: TResourceTreeNode): TResourceTreeNode;
var
  p: TResourceTreeNodes.TRBNodePtr;
begin
  Result := nil;
  if IsBranch then
  begin
    p := TResourceTreeBranchNode(Self).FChildren.Find(Node);
    if p <> nil then
      Result := p^.K;
  end;
end;

function TResourceTreeNode.GetPath: string;
var
  Cur: TResourceTreeNode;
  Separator: string;
begin
  Cur := Self;

  if Cur.IsLeaf then
  begin
    Result := Format('(%d)', [TResourceTreeLeafNode(Cur).FCodepage]);
  end;

  // All parent nodes are branches.
  // Go up excluding root node.
  while (Cur.Parent <> nil) and (Cur.Parent.Parent <> nil) do
  begin
    // Leaf node don't need PathDelim.
    if Cur = Self then
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
  Result := (Self is TResourceTreeBranchNode);
end;

function TResourceTreeNode.IsLeaf: boolean;
begin
  Result := (Self is TResourceTreeLeafNode);
end;

function TResourceTreeNode.IsNamed: boolean;
begin
  Result := Name <> '';
end;

procedure TResourceTreeNode.SetId(const Value: uint32);
begin
  Parent.KeepNodeOrder_Begin(Self);
  FId := Value;
  FName := '';
  Parent.KeepNodeOrder_End(Self);
end;

procedure TResourceTreeNode.SetName(const Value: UnicodeString);
begin
  Parent.KeepNodeOrder_Begin(Self);
  FId := 0;
  FName := Value;
  Parent.KeepNodeOrder_End(Self);
end;

procedure TResourceTreeNode.Traverse(TraverseMethod: TResourceTraverseMethod);
const
  WANT_MORE_NODES = True;
var
  n: TResourceTreeNode;
begin
  if Assigned(TraverseMethod) and (Assigned(Self)) then
  begin
    // Visit node.
    if TraverseMethod(Self) = WANT_MORE_NODES then
    begin
      // If branch, visit children.
      if Self.IsBranch then
        for n in TResourceTreeBranchNode(Self).FChildren do
          n.Traverse(TraverseMethod)
    end;
  end;
end;

{ TResourceTree }

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

{ TResourceTreeLeafNode }

constructor TResourceTreeLeafNode.CreateFromRVA(PE: TPEImageObject; DataRVA: TRVA;
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

constructor TResourceTreeLeafNode.CreateFromStream(Stream: TStream; Pos,
  Size: UInt64);
begin
  FData := TMemoryStream.Create;
  Stream.Position := Pos;
  if Size = 0 then
    Size := Stream.Size - Pos;
  FData.CopyFrom(Stream, Size);
end;

constructor TResourceTreeLeafNode.Create;
begin
  FData := TMemoryStream.Create;
end;

constructor TResourceTreeLeafNode.CreateFromEntry(PE: TPEImageObject;
  const Entry: TResourceDataEntry);
begin
  CreateFromRVA(PE, Entry.DataRVA, Entry.Size, Entry.CodePage);
end;

destructor TResourceTreeLeafNode.Destroy;
begin
  FData.Free;
  inherited;
end;

function TResourceTreeLeafNode.GetDataSize: uint32;
begin
  Result := FData.Size;
end;

procedure TResourceTreeLeafNode.UpdateData(Buffer: PByte; Size: uint32);
begin
  if (Buffer = nil) or (Size = 0) then
  begin
    FData.Clear;
    exit;
  end;
  FData.Size := Size;
  Move(Buffer^, FData.Memory^, Size);
end;

end.
