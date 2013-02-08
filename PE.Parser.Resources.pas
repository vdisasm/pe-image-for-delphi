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

const
  // Windows uses three levels.
  RESOURCE_LEVEL_TYPE = 0;
  RESOURCE_LEVEL_NAME = 1;
  RESOURCE_LEVEL_LANG = 2;

  { TPEResourcesParser }

function TPEResourcesParser.Parse: TParserResult;
var
  dir: TImageDataDirectory;
begin
  // Check if empty.
  if not TPEImage(FPE).DataDirectories.Get(DDIR_RESOURCE, @dir) then
    exit(PR_OK);
  if dir.IsEmpty then
    exit(PR_OK);

  // Store base RVA.
  FBaseRVA := dir.VirtualAddress;

  // Try to seek resource dir.
  if not TPEImage(FPE).SeekRVA(FBaseRVA) then
    exit(PR_ERROR);

  // Read root and children.
  FTree := TPEImage(FPE).ResourceTree;
  ReadNode(FBaseRVA, FTree.Root);
  exit(PR_OK);
end;

function TPEResourcesParser.ReadEntry;
var
  Entry: TResourceDirectoryEntry;
  DataEntry: TResourceDataEntry;
  SubRVA, DataRVA, NameRVA: TRVA;
  LeafNode: TResourceTreeLeafNode;
  BranchNode: TResourceTreeBranchNode;
begin
  Result := nil;

  with TPEImage(FPE) do
  begin
    if SeekRVA(RVA) then
      if ReadEx(@Entry, SizeOf(Entry)) then
      begin
        if Entry.IsDataEntryRVA then
        // Leaf node.
        begin
          DataRVA := Entry.DataEntryRVA + FBaseRVA;
          if SeekRVA(DataRVA) then
            if ReadEx(@DataEntry, SizeOf(DataEntry)) then
            begin
              LeafNode := TResourceTreeLeafNode.Create;
              LeafNode.DataRVA := DataEntry.DataRVA;
              LeafNode.DataSize := DataEntry.Size;
              LeafNode.Codepage := DataEntry.Codepage;
              exit(LeafNode);
            end;
          exit(nil);
        end
        else
        // Branch Node.
        begin
          // Store RVA.
          RVA := PositionRVA;

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
          if EntyKind = EK_ID then
            BranchNode.ID := Entry.IntegerID
          else
          begin
            NameRVA := Entry.NameRVA + FBaseRVA;
            if not SeekRVA(NameRVA) then
              exit(nil);
            BranchNode.Name := ReadUnicodeString;
          end;

          // Get sub-level RVA.
          SubRVA := Entry.SubdirectoryRVA + FBaseRVA;

          // Read children.
          ReadNode(SubRVA, BranchNode);

        end;

        exit(BranchNode);
      end;
  end;
end;

function TPEResourcesParser.ReadNode;
var
  RDT: TResourceDirectoryTable;
  i: integer;
begin
  with TPEImage(FPE) do
  begin
    // Read Directory Table.
    if SeekRVA(RVA) then
      if ReadEx(@RDT, SizeOf(RDT)) then
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
  end;
  exit(PR_ERROR);
end;

end.
