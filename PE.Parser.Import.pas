unit PE.Parser.Import;

interface

uses
  System.Generics.Collections,
  System.SysUtils,

  PE.Common,
  PE.Types,
  PE.Types.Imports,
  PE.Types.FileHeader,
  PE.Imports,
  PE.Imports.Func,
  PE.Imports.Lib,
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

function ReadGoodILTItem(PE: TPEImage; var dq: uint64): boolean; inline;
begin
  dq := PE.ReadWord;
  Result := dq <> 0;
end;

function TPEImportParser.Parse: TParserResult;
type
  TImpDirs = TList<TImportDirectoryTable>;
  TILTs = TList<TImportLookupTable>;
var
  dir: TImageDataDirectory;
  bIs32: boolean;
  dq: uint64;
  sizet: byte;
  IDir: TImportDirectoryTable;
  IATRVA: uint64;
  PATCHRVA: uint64; // place where loader will put new address
  IDirs: TImpDirs;
  ILT: TImportLookupTable;
  ILTs: TILTs;
  ImpFn: TPEImportFunction;
  Lib: TPEImportLibrary;
  PE: TPEImage;
  LibraryName: string;
  dwLeft: uint32;
  bEmptyLastDirFound: boolean;
  IDirNumber: integer;
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
    if not PE.DataDirectories.Get(DDIR_IMPORT, @dir) then
      exit(PR_OK);
    if dir.IsEmpty then
      exit(PR_OK);

    // Seek import dir.
    if not PE.SeekRVA(dir.VirtualAddress) then
      exit;

    // Read import descriptors.
    dwLeft := dir.Size;
    bEmptyLastDirFound := False;
    while dwLeft >= sizeof(IDir) do
    begin
      // Read IDir.
      if not PE.ReadEx(@IDir, sizeof(IDir)) then
        exit;

      if IDir.IsEmpty then // it's last dir
      begin
        bEmptyLastDirFound := true;
        break;
      end;

      // Check RVA.
      if not(PE.RVAExists(IDir.NameRVA)) then
      begin
        PE.Msg.Write(SCategoryImports, 'Bad RVAs in directory. Imports are incorrect.');
        exit;
      end;

      IDirs.Add(IDir); // add read dir

      dec(dwLeft, sizeof(IDir));
    end;

    if IDirs.Count = 0 then
    begin
      PE.Msg.Write(SCategoryImports, 'No directories found.');
      exit;
    end;

    if not bEmptyLastDirFound then
    begin
      PE.Msg.Write(SCategoryImports, 'No last (empty) directory found.');
    end;

    // Parse import descriptors.
    IDirNumber := -1;
    for IDir in IDirs do
    begin
      inc(IDirNumber);

      ILTs.Clear;

      // Read library name.
      if (not PE.SeekRVA(IDir.NameRVA)) then
      begin
        PE.Msg.Write(SCategoryImports, 'Library name RVA not found (0x%x) for dir # %d.', [IDir.NameRVA, IDirNumber]);
        Continue;
      end;

      LibraryName := PE.ReadAnsiString;

      if LibraryName.IsEmpty then
      begin
        PE.Msg.Write(SCategoryImports, 'Library # %d has empty name.', [IDirNumber]);
        Continue;
      end;

      Lib := TPEImportLibrary.Create(LibraryName, IDir.IsBound);
      PE.Imports.Add(Lib);

      Lib.TimeDateStamp := IDir.TimeDateStamp;

      // Skip bad dll name.
      if Lib.Name.IsEmpty then
      begin
        PE.Msg.Write(SCategoryImports, 'Bad library name (# %d)', [IDirNumber]);
        Continue;
      end;

      PATCHRVA := IDir.FirstThunk;
      if PATCHRVA = 0 then
      begin
        PE.Msg.Write(SCategoryImports, 'Library # %d (%s) has NULL patch RVA.', [IDirNumber, Lib.Name]);
        break;
      end;

      if IDir.OriginalFirstThunk <> 0 then
        IATRVA := IDir.OriginalFirstThunk
      else
        IATRVA := IDir.FirstThunk;

      if IATRVA = 0 then
      begin
        PE.Msg.Write(SCategoryImports, 'Library # %d (%s) has NULL IAT RVA.', [IDirNumber, Lib.Name]);
        break;
      end;

      Lib.IATRVA := IATRVA;

      // Read IAT elements.
      while PE.SeekRVA(IATRVA) and ReadGoodILTItem(PE, dq) do
      begin
        // Process only unique functions (by RVA).
        ILT.Create(dq, bIs32);

        ImpFn := TPEImportFunction.CreateEmpty;

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
          ImpFn.Name := PE.ReadAnsiString;
        end;

        Lib.Functions.Add(ImpFn);

        inc(IATRVA, sizet); // next item
        inc(PATCHRVA, sizet);
      end;
    end;

    Result := PR_OK;

  finally
    IDirs.Free;
    ILTs.Free;
  end;
end;

end.
