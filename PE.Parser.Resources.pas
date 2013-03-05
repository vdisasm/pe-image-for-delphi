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
    function ReadEntry(var RVA: TRVA; EntyKind: TEntryKind; RDT: PResourceDirectoryTable): TResourceTreeNode;
    function ReadNode(RVA: TRVA; ParentNode: TResourceTreeBranchNode): TParserResult;
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
  ReadNode(FBaseRVA, FTree.Root);
  exit(PR_OK);
end;

function TPEResourcesParser.ReadEntry;
var
  Img: TPEImage;
  Entry: TResourceDirectoryEntry;
  DataEntry: TResourceDataEntry;
  SubRVA, DataRVA, NameRVA: TRVA;
  LeafNode: TResourceTreeLeafNode;
  BranchNode: TResourceTreeBranchNode;
begin
  Result := nil;

  Img := FPE as TPEImage;

  if not(Img.SeekRVA(RVA) and Img.ReadEx(@Entry, SizeOf(Entry))) then
  begin
    TPEImage(FPE).Msg.Write('Bad resource entry.');
    exit;
  end;

  if Entry.IsDataEntryRVA then
  // Leaf node.
  begin
    DataRVA := Entry.DataEntryRVA + FBaseRVA;

    if not(Img.SeekRVA(DataRVA) and Img.ReadEx(@DataEntry, SizeOf(DataEntry))) then
    begin
      TPEImage(FPE).Msg.Write('Bad resource leaf node.');
      exit;
    end;

    LeafNode := TResourceTreeLeafNode.CreateFromEntry(FPE, DataEntry);
    exit(LeafNode);
  end;

  // Branch Node.
  // Store RVA.
  RVA := Img.PositionRVA;

  // Alloc and fill node.
  BranchNode := TResourceTreeBranchNode.Create;
  if RDT <> nil then
  begin
    BranchNode.Characteristics := RDT^.Characteristics;
    BranchNode.TimeDateStamp := RDT^.TimeDateStamp;
    BranchNode.MajorVersion := RDT^.MajorVersion;
    BranchNode.MinorVersion := RDT^.MinorVersion;
  end;

  // Get Id or Name.
  case EntyKind of
    EK_ID:
      BranchNode.ID := Entry.IntegerID;
    EK_NAME:
      begin
        NameRVA := Entry.NameRVA + FBaseRVA;
        if not Img.SeekRVA(NameRVA) then
        begin
          TPEImage(FPE).Msg.Write('Failed to read resource name.');
          exit(nil);
        end;
        BranchNode.Name := Img.ReadUnicodeString;
      end;
  end;

  // Get sub-level RVA.
  SubRVA := Entry.SubdirectoryRVA + FBaseRVA;

  // Read children.
  ReadNode(SubRVA, BranchNode);

  exit(BranchNode);
end;

function TPEResourcesParser.ReadNode;
var
  Img: TPEImage;
  RDT: TResourceDirectoryTable;
  i: integer;
begin
  Img := FPE as TPEImage;
  // Read Directory Table.
  if Img.SeekRVA(RVA) then
    if Img.ReadEx(@RDT, SizeOf(RDT)) then
    begin
      inc(RVA, SizeOf(RDT));

      // Read named entries.
      for i := 1 to RDT.NumberOfNameEntries do
        FTree.AddChild(ReadEntry(RVA, EK_NAME, @RDT), ParentNode);

      // Read Id entries.
      for i := 1 to RDT.NumberOfIDEntries do
        FTree.AddChild(ReadEntry(RVA, EK_ID, @RDT), ParentNode);

      exit(PR_OK);
    end;
  exit(PR_ERROR);
end;

end.
