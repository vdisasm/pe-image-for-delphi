unit PE.Parser.Resources;

interface

uses
  PE.Common,
  PE.Types,
  PE.Types.Resources,
  PE.Resources;

type
  TPEResourcesParser = class(TPEParser)
  protected type
    TEntryKind = (EK_ID, EK_NAME);
  protected
    FBaseRVA: TRVA; // RVA of RSRC section base
    FTree: TResourceTree;
    function ReadEntry(
      ParentNode: TResourceTreeBranchNode;
      RVA: TRVA;
      Index: integer;
      EntyKind: TEntryKind;
      RDT: PResourceDirectoryTable): TResourceTreeNode;
    function ReadNode(
      ParentNode: TResourceTreeBranchNode;
      RVA: TRVA): TParserResult;
  public
    function Parse: TParserResult; override;
  end;

implementation

uses
  PE.Image,
  PE.Types.Directories;

{ TPEResourcesParser }

function TPEResourcesParser.Parse: TParserResult;
var
  Img: TPEImage;
  dir: TImageDataDirectory;
begin
  Img := FPE as TPEImage;

  // Check if directory present.
  if not Img.DataDirectories.Get(DDIR_RESOURCE, @dir) then
    exit(PR_OK);
  if dir.IsEmpty then
    exit(PR_OK);

  // Store base RVA.
  FBaseRVA := dir.VirtualAddress;

  // Try to seek resource dir.
  if not Img.SeekRVA(FBaseRVA) then
    exit(PR_ERROR);

  // Read root and children.
  FTree := Img.ResourceTree;
  ReadNode(FTree.Root, FBaseRVA);
  exit(PR_OK);
end;

function TPEResourcesParser.ReadEntry(
  ParentNode: TResourceTreeBranchNode;
  RVA: TRVA;
  Index: integer;
  EntyKind: TEntryKind;
  RDT: PResourceDirectoryTable): TResourceTreeNode;
var
  Img: TPEImage;
  Entry: TResourceDirectoryEntry;
  DataEntry: TResourceDataEntry;
  SubRVA, DataRVA, NameRVA: TRVA;
  LeafNode: TResourceTreeLeafNode;
  BranchNode: TResourceTreeBranchNode;
  TmpNode: TResourceTreeNode;
begin
  Result := nil;
  Img := FPE as TPEImage;

  // Try to read entry.
  if not(Img.SeekRVA(RVA + Index * SizeOf(Entry)) and
    Img.ReadEx(@Entry, SizeOf(Entry))) then
  begin
    Img.Msg.Write('Bad resource entry.');
    exit;
  end;

  // Handle Leaf or Branch.
  if Entry.IsDataEntryRVA then
  begin
    { Leaf node }
    DataRVA := Entry.DataEntryRVA + FBaseRVA;
    if not(Img.SeekRVA(DataRVA) and Img.ReadEx(@DataEntry, SizeOf(DataEntry))) then
    begin
      Img.Msg.Write('Bad resource leaf node.');
      exit;
    end;
    LeafNode := TResourceTreeLeafNode.CreateFromEntry(FPE, DataEntry);
    Result := LeafNode;
  end
  else
  begin
    { Branch Node. }
    RVA := Img.PositionRVA; // Store RVA.
    // Alloc and fill node.
    BranchNode := TResourceTreeBranchNode.Create;
    if RDT <> nil then
    begin
      BranchNode.Characteristics := RDT^.Characteristics;
      BranchNode.TimeDateStamp := RDT^.TimeDateStamp;
      BranchNode.MajorVersion := RDT^.MajorVersion;
      BranchNode.MinorVersion := RDT^.MinorVersion;
    end;
    // Get sub-level RVA.
    SubRVA := Entry.SubdirectoryRVA + FBaseRVA;
    // Read children.
    ReadNode(BranchNode, SubRVA);
    Result := BranchNode;
  end;

  // Get Id or Name.
  if Result <> nil then
  begin
    // Assigning Id or Name at this stage won't trigger sort, as Parent isn't
    // assigned yet.
    case EntyKind of
      EK_ID:
        begin
          Result.Id := Entry.IntegerID;
        end;
      EK_NAME:
        begin
          NameRVA := Entry.NameRVA + FBaseRVA;
          if not Img.SeekRVA(NameRVA) then
          begin
            Img.Msg.Write('Failed to read resource name.');
            exit(nil);
          end;
          Result.Name := Img.ReadUnicodeString;
        end;
    end;

    // When Result node is finished we can add it to parent.
    TmpNode := ParentNode.FindNode(Result);
    if TmpNode <> nil then
    begin
      Result.Free;
      exit(TmpNode);
    end;
    ParentNode.Add(Result);
  end;
end;

function TPEResourcesParser.ReadNode(
  ParentNode: TResourceTreeBranchNode;
  RVA: TRVA): TParserResult;
var
  Img: TPEImage;
  RDT: TResourceDirectoryTable;
  i: integer;
begin
  Img := FPE as TPEImage;

  // Read Directory Table.
  if not(Img.SeekRVA(RVA) and Img.ReadEx(@RDT, SizeOf(RDT))) then
  begin
    Img.Msg.Write('Failed to read resource directory table.');
    exit(PR_ERROR);
  end;

  inc(RVA, SizeOf(RDT));

  // Read named entries.
  for i := 0 to RDT.NumberOfNameEntries - 1 do
    ReadEntry(ParentNode, RVA, i, EK_NAME, @RDT);

  // Read Id entries.
  for i := 0 to RDT.NumberOfIDEntries - 1 do
    ReadEntry(ParentNode, RVA, i, EK_ID, @RDT);

  exit(PR_OK);
end;

end.
