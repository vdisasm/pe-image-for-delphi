unit PE.Parser.Import;

interface

uses
  System.Generics.Collections,
  PE.Common,
  PE.Types,
  PE.Types.Imports,
  PE.Types.FileHeader,
  PE.Imports,
  PE.Utils;

type
  TPEImportParser = class(TPEParser)
  public
    function Parse: TParserResult; override;
  end;

implementation

uses
  PE.Types.Directories,
  PE.Image;

{ TPEImportParser }

function ReadGoodILTItem(PE: TPEImage; var dq: uint64): boolean;
begin
  dq := 0;
  if not PE.ReadEx(@dq, PE.ImageBits div 8) then
    exit(false);
  Result := dq <> 0;
end;

function TPEImportParser.Parse: TParserResult;
type
  TImpDirs = TList<TImportDirectoryTable>;
  TILTs = TList<TImportLookupTable>;
var
  ddir: TImageDataDirectory;
  bIs32: boolean;
  dq: uint64;
  sizet: byte;
  IDir: TImportDirectoryTable;
  IATRVA: uint64;
  PATCHRVA: uint64; // place where loader will put new address
  IDirs: TImpDirs;
  ILT: TImportLookupTable;
  ILTs: TILTs;
  i: Integer;
  ImpFn: TPEImportFunction;
  Lib: TPEImportLibrary;
  PE: TPEImage;
  DllName: RawByteString;
begin
  PE := TPEImage(FPE);

  Result := PR_ERROR;
  IDirs := TImpDirs.Create;
  ILTs := TILTs.Create;
  try
    PE.Imports.Clear;

    bIs32 := PE.Is32bit;
    sizet := PE.ImageBits div 8;

    // If no imports, it's ok.
    if not PE.DataDirectories.Get(DDIR_IMPORT, @ddir) then
      exit(PR_OK);
    if ddir.IsEmpty then
      exit(PR_OK);

    // Seek import dir.
    if not PE.SeekRVA(ddir.VirtualAddress) then
      exit;

    // Read import descriptors.
    while true do
    begin
      if not PE.ReadEx(@IDir, sizeof(IDir)) then
        exit;
      if IDir.IsEmpty then // it's last dir
        break;
      IDirs.Add(IDir); // add read dir
    end;

    // Parse import descriptors.
    for i := 0 to IDirs.Count - 1 do
    begin
      IDir := IDirs[i];
      ILTs.Clear;

      // read dll name
      if not PE.SeekRVA(IDir.NameRVA) then
      begin
        PE.Msg.Write('Import library has NULL name.');
        Continue;
      end;

      // Read DLL name.
      DllName := PE.ReadANSIString;

      // Create library.
      Lib := TPEImportLibrary.Create(DllName, IDir.IsBound);

      Lib.TimeDateStamp := IDir.TimeDateStamp;

      // skip bad dll name
      if Lib.Name = '' then
      begin
        PE.Msg.Write('Bad import library name.');
        Continue;
      end;

      PATCHRVA := IDir.FirstThunk;
      if PATCHRVA = 0 then
      begin
        PE.Msg.Write('Import library %s has NULL patch RVA.', [Lib.Name]);
        break;
      end;

      if IDir.OriginalFirstThunk <> 0 then
        IATRVA := IDir.OriginalFirstThunk
      else
        IATRVA := IDir.FirstThunk;

      if IATRVA = 0 then
      begin
        PE.Msg.Write('Import library %s has NULL IAT RVA.', [Lib.Name]);
        break;
      end;

      // read IAT elements
      while PE.SeekRVA(IATRVA) and ReadGoodILTItem(TPEImage(FPE), dq) do
      begin
        ILT.Create(dq, bIs32);

        ImpFn := TPEImportFunction.CreateEmpty;
        ImpFn.RVA := PATCHRVA;

        // By ordinal.
        if ILT.IsImportByOrdinal then
        begin
          ImpFn.Ordinal := ILT.OrdinalNumber;
          ImpFn.Name := '';
        end

        // By name.
        else if PE.SeekRVA(ILT.HintNameTableRVA) then
        begin
          dq := 0;
          PE.ReadEx(@dq, 2);
          ImpFn.Name := PE.ReadANSIString;
        end;

        Lib.Functions.Add(ImpFn); // add imported function
        inc(IATRVA, sizet);       // next item
        inc(PATCHRVA, sizet);

      end;

      // add created import record
      PE.Imports.Add(Lib);

    end;

    Result := PR_OK;

  finally
    IDirs.Free;
    ILTs.Free;
  end;

end;

end.
