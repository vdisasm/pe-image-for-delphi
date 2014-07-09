unit PE.Parser.ImportDelayed;

interface

uses
  System.Generics.Collections,
  System.SysUtils,

  PE.Common,
  PE.Types,
  PE.Types.Directories,
  PE.Types.FileHeader, // expand TPEImage.Is32bit
  PE.Types.Imports,
  PE.Types.ImportsDelayed,
  PE.Utils;

type
  TPEImportDelayedParser = class(TPEParser)
  public
    function Parse: TParserResult; override;
  end;

implementation

uses
  PE.Image,
  PE.Imports.Func;

type
  TFuncs = TList<TPEImportFunctionDelayed>;

procedure ParseTable(
  const PE: TPEImage;
  const Table: TDelayLoadDirectoryTable;
  const Funcs: TFuncs);
var
  DllName: string;
  FnName: string;
  Fn: TPEImportFunctionDelayed;
  HintNameRva: TRVA;
  Ilt: TImportLookupTable;
  iFunc: integer;
  wordSize: integer;
var
  Ordinal: UInt16;
  Hint: UInt16 absolute Ordinal;
  Iat: TRVA;
  SubValue: UInt32;
begin
  if Table.UsesVA then
    SubValue := PE.ImageBase
  else
    SubValue := 0;

  PE.SeekRVA(Table.Name - SubValue);
  DllName := PE.ReadANSIString;

  wordSize := PE.ImageWordSize;
  iFunc := 0;
  Iat := Table.DelayImportAddressTable - SubValue;

  while PE.SeekRVA(Table.DelayImportNameTable - SubValue + iFunc * wordSize) do
  begin
    HintNameRva := PE.ReadWord();
    if HintNameRva = 0 then
      break;

    Ilt.Create(HintNameRva, PE.Is32bit);

    Ordinal := 0;
    FnName := '';

    if Ilt.IsImportByOrdinal then
    begin
      // Import by ordinal only. No hint/name.
      Ordinal := Ilt.OrdinalNumber;
    end
    else
    begin
      // Import by name. Get hint/name
      if not PE.SeekRVA(HintNameRva - SubValue) then
        raise Exception.Create('Error reading delayed import hint/name.');
      Hint := PE.ReadWord(2);
      FnName := PE.ReadANSIString;
    end;

    Fn := TPEImportFunctionDelayed.Create(Iat, FnName, Ordinal);
    PE.ImportsDelayed.AddNew(Iat, DllName, Fn);

    inc(Iat, wordSize);
    inc(iFunc);
  end;
end;

function TPEImportDelayedParser.Parse: TParserResult;
var
  PE: TPEImage;
  ddir: TImageDataDirectory;
  ofs: integer;
  Table: TDelayLoadDirectoryTable;
  Tables: TList<TDelayLoadDirectoryTable>;
  Funcs: TFuncs;
  TablesUseRVA: boolean;
begin
  PE := TPEImage(FPE);

  Result := PR_ERROR;

  // If no imports, it's ok.
  if not PE.DataDirectories.Get(DDIR_DELAYIMPORT, @ddir) then
    Exit(PR_OK);
  if ddir.IsEmpty then
    Exit(PR_OK);

  // Seek import dir.
  if not PE.SeekRVA(ddir.VirtualAddress) then
    Exit;

  Tables := TList<TDelayLoadDirectoryTable>.Create;
  try

    // Delay-load dir. tables.
    ofs := 0;
    TablesUseRVA := True; // default, compiler-friendly
    while True do
    begin
      if ofs > ddir.Size then
        Exit(PR_ERROR);

      if not PE.ReadEx(Table, SizeOf(Table)) then
        break;

      if Table.Empty then
        break;

      // Attribute:
      // 0: addresses are VA (old VC6 binaries)
      // 1: addresses are RVA

      if (ofs = 0) then
      begin
        TablesUseRVA := Table.UsesRVA; // initialize once
      end
      else if TablesUseRVA <> Table.UsesRVA then
      begin
        // Normally all tables must use either VA or RVA. No mix allowed.
        // If mix found it must be not real table.
        // For example, Delphi (some versions for sure) use(d) such optimization.
        break;
      end;

      Tables.Add(Table);
      inc(ofs, SizeOf(Table));
    end;

    // Parse tables.
    if Tables.Count = 0 then
      Exit(PR_OK);

    Funcs := TFuncs.Create;
    try
      for Table in Tables do
        ParseTable(PE, Table, Funcs);
    finally
      Funcs.Free;
    end;

    Result := PR_OK;
  finally
    Tables.Free;
  end;
end;

end.
