{
  Load and map module into current process.
  Module MUST have relocations or be RIP-addressed to be loaded normally.
}
unit PE.ExecutableLoader;

interface

uses
  System.Generics.Collections,
  WinApi.Windows,
  PE.Image;

type
  TMapStatus = (
    msOK,
    msImageAlreadyMapped,
    msError,
    msImageSizeError,
    msMapSectionsError,
    msSectionAllocError,
    msProtectSectionsError,
    msImportLibraryNotFound,
    msImportNameNotFound,
    msImportOrdinalNotFound,
    msEntryPointFailure
    );

type
  TEXEEntry = procedure(); stdcall;
  TDLLEntry = function(hInstDLL: HINST; fdwReason: DWORD; lpvReserved: LPVOID): BOOL; stdcall;

  TLoadedModules = TDictionary<string, HMODULE>;

  TExecutableModule = class
  private
    FPE: TPEImage;
    FInstance: NativeUInt;
    FEntry: Pointer;
    FSizeOfImage: UInt32;
    FLoadedImports: TLoadedModules;
    function Check(const Desc: string; var rslt: TMapStatus; ms: TMapStatus): boolean;

    function MapSections(PrefferedVa: UInt64): TMapStatus;
    function ProtectSections: TMapStatus;
    function Relocate: TMapStatus;
    function LoadImports: TMapStatus;

    procedure UnloadImports;
  public
    constructor Create(PE: TPEImage);
    destructor Destroy; override;

    function IsImageMapped: boolean; inline;

    function Load(PrefferedVa: UInt64 = 0): TMapStatus;
    function Unload: boolean;
  end;

implementation

uses
  // Expand
  PE.Types.FileHeader,
  PE.Utils,
  PE.Sections,

  System.SysUtils,

  PE.Imports,
  PE.Section,
  PE.Types.Relocations;

function HasBits(value, mask: DWORD): boolean; inline;
begin
  Result := (value and mask) <> 0;
end;

function CharacteristicsToProtect(CH: DWORD): DWORD;
var
  X, R, W, C: boolean;
begin
  Result := 0;

  X := HasBits(CH, IMAGE_SCN_MEM_EXECUTE);
  R := HasBits(CH, IMAGE_SCN_MEM_READ);
  W := HasBits(CH, IMAGE_SCN_MEM_WRITE);
  C := HasBits(CH, IMAGE_SCN_MEM_NOT_CACHED);

  if X then
  begin
    if R then
    begin
      if W then
        Result := Result or PAGE_EXECUTE_READWRITE
      else
        Result := Result or PAGE_EXECUTE_READ;
    end
    else if W then
      Result := Result or PAGE_EXECUTE_WRITECOPY
    else
      Result := Result or PAGE_EXECUTE;
  end
  else if R then
  begin
    if W then
      Result := Result or PAGE_READWRITE
    else
      Result := Result or PAGE_READONLY;
  end
  else if W then
    Result := Result or PAGE_WRITECOPY
  else
  begin
    Result := Result or PAGE_NOACCESS;
  end;

  if C then
    Result := Result or PAGE_NOCACHE;
end;

function min(d1, d2: DWORD): DWORD;
begin
  if d1 < d2 then
    Result := d1
  else
    Result := d2;
end;

{ TDLL }

function TExecutableModule.Check(const Desc: string; var rslt: TMapStatus;
  ms: TMapStatus): boolean;
begin
  rslt := ms;
  Result := ms = msOK;

  if Result then
    FPE.Msg.Write(Desc + ' .. OK.')
  else
    FPE.Msg.Write(Desc + ' .. failed.')
end;

constructor TExecutableModule.Create(PE: TPEImage);
begin
  FPE := PE;
  FLoadedImports := TLoadedModules.Create;
end;

destructor TExecutableModule.Destroy;
begin
  Unload;
  FLoadedImports.Free;
  inherited;
end;

function TExecutableModule.IsImageMapped: boolean;
begin
  Result := FInstance <> 0;
end;

function TExecutableModule.MapSections(PrefferedVa: UInt64): TMapStatus;
var
  i: integer;
  sec: TPESection;
  size: DWORD;
  va: pbyte;
  dw: DWORD;
begin
  Result := msMapSectionsError;

  FSizeOfImage := FPE.CalcSizeOfImage;

  if FSizeOfImage = 0 then
    exit(msImageSizeError);

  // Reserve and commit memory for image.
  FInstance := NativeUInt(VirtualAlloc(Pointer(PrefferedVa), FSizeOfImage,
    MEM_RESERVE or MEM_COMMIT, PAGE_READWRITE));

  if FInstance = 0 then
    exit(msSectionAllocError);

  // copy sections and header
  // todo: header

  for i := 0 to FPE.Sections.Count - 1 do
  begin
    sec := FPE.Sections[i];
    if sec.VirtualSize <> 0 then
    begin
      va := pbyte(FInstance) + sec.RVA;
      size := min(sec.VirtualSize, sec.RawSize);
      if not FPE.SeekRVA(sec.RVA) then
        exit;
      FPE.Read(va, size);
    end;
  end;

  Result := msOK;
end;

function TExecutableModule.LoadImports: TMapStatus;
var
  ImpLib: TPEImportLibrary;
  ImpLibName, ImpFnName: AnsiString;
  s: string;
  hmod: HMODULE;
  proc: Pointer;
  i, iFn: integer;
  va: UInt64;
  ModuleMustBeFreed: boolean;
begin
  for i := 0 to FPE.Imports.Count - 1 do
  begin
    // Get next import library.
    ImpLib := FPE.Imports[i];
    ImpLibName := ImpLib.Name;

    FPE.Msg.Write('Processing import module: "%s"', [ImpLibName]);

    // Check if module already in address space.
    hmod := GetModuleHandleA(PAnsiChar(ImpLibName));
    ModuleMustBeFreed := hmod = 0;

    // Try make system load lib from default paths.
    if hmod = 0 then
      hmod := LoadLibraryA(PAnsiChar(ImpLibName));
    // Try load from dir, where image located.
    if (hmod = 0) and (FPE.FileName <> '') then
    begin
      s := ExtractFilePath(FPE.FileName) + ImpLibName;
      hmod := LoadLibrary(PChar(s));
    end;
    // If lib not found, raise.
    if hmod = 0 then
    begin
      FPE.Msg.Write('Imported module "%s" not loaded.', [ImpLibName]);
      // It's either not found, or its dependencies not found.
      exit(msImportLibraryNotFound);
    end;

    // Module found.
    if ModuleMustBeFreed then
      FLoadedImports.Add(ImpLibName, hmod);

    // Process import functions.
    for iFn := 0 to ImpLib.Functions.Count - 1 do
    begin
      // Find imported function.

      // By Name.
      if ImpLib.Functions[iFn].Name <> '' then
      begin
        ImpFnName := ImpLib.Functions[iFn].Name;
        proc := GetProcAddress(hmod, PAnsiChar(ImpFnName));
        if proc = nil then
        begin
          FPE.Msg.Write('Imported name "%s" not found.', [ImpFnName]);
          exit(msImportNameNotFound);
        end;
      end
      else
      // By Ordinal.
      begin
        proc := GetProcAddress(hmod, PAnsiChar(ImpLib.Functions[iFn].Ordinal));
        if proc = nil then
        begin
          FPE.Msg.Write('Imported ordinal "%d" not found.', [ImpLib.Functions[iFn].Ordinal]);
          exit(msImportOrdinalNotFound);
        end;
      end;

      // Patch.
      va := FInstance + ImpLib.Functions[iFn].RVA;
      if FPE.Is32bit then
        PUINT(va)^ := UInt32(proc)
      else if FPE.Is64bit then
        PUInt64(va)^ := UInt64(proc);
    end;
  end;
  Result := msOK;
end;

function TExecutableModule.ProtectSections: TMapStatus;
var
  i: integer;
  sec: TPESection;
  prot: cardinal;
  va: pbyte;
  dw: DWORD;
begin
  for i := 0 to FPE.Sections.Count - 1 do
  begin
    Result := msProtectSectionsError;
    sec := FPE.Sections[i];
    if sec.VirtualSize <> 0 then
    begin
      va := Pointer(FInstance);
      inc(va, sec.RVA);
      prot := CharacteristicsToProtect(sec.Flags);
      if not VirtualProtect(va, sec.VirtualSize, prot, dw) then
        exit;
    end;
  end;
  Result := msOK;
end;

function TExecutableModule.Relocate: TMapStatus;
var
  Reloc: TReloc;
  Delta: UInt32;
  pDst: PCardinal;
begin
  Delta := FInstance - FPE.ImageBase;

  if Delta = 0 then
    exit(msOK); // no relocation needed

  for Reloc in FPE.Relocs.Items do
  begin
    case Reloc.&Type of
      IMAGE_REL_BASED_HIGHLOW:
        begin
          pDst := PCardinal(FInstance + Reloc.RVA);
          inc(pDst^, Delta);
        end;
      else
        raise Exception.CreateFmt('Unsupported relocation type: %d', [Reloc.&Type]);
    end;
  end;
  Result := msOK;
end;

function TExecutableModule.Load(PrefferedVa: UInt64): TMapStatus;
var
  EntryOK: boolean;
begin
  if IsImageMapped then
    exit(msImageAlreadyMapped);

  Result := msError;

  if
    Check('Map Sections', Result, MapSections(PrefferedVa)) and
    Check('Fix Relocation', Result, Relocate()) and
    Check('Fix Imports', Result, LoadImports) and
    Check('Protect Sections', Result, ProtectSections()) then
  begin
    FEntry := Pointer(FInstance + FPE.EntryPointRVA);

    // Call Entry Point.
    if FPE.IsDLL then
    begin
      FPE.Msg.Write('Calling DLL Entry with DLL_PROCESS_ATTACH.');
      EntryOK := TDLLEntry(FEntry)(FInstance, DLL_PROCESS_ATTACH, nil);
      if not EntryOK then
        FPE.Msg.Write('DLL returned FALSE.');
    end
    else
    begin
      FPE.Msg.Write('Calling EXE Entry.');
      TEXEEntry(FEntry)();
      EntryOK := True;
    end;

    if EntryOK then
      exit(msOK)
    else
      Result := msEntryPointFailure;
  end;

  // If something failed.
  Unload;
end;

function TExecutableModule.Unload: boolean;
begin
  if not IsImageMapped then
    exit(True);

  // DLL finalization.
  if @FEntry <> nil then
    if FPE.IsDLL then
    begin
      FPE.Msg.Write('Calling DLL Entry with DLL_PROCESS_DETACH.');
      TDLLEntry(FEntry)(FInstance, DLL_PROCESS_DETACH, nil);
    end;

  // Unload imported libraries.
  UnloadImports;

  // Free image memory
  VirtualFree(Pointer(FInstance), FSizeOfImage, MEM_RELEASE);
  FInstance := 0;

  Result := True;
end;

procedure TExecutableModule.UnloadImports;
var
  Pair: TPair<string, HMODULE>;
begin
  for Pair in FLoadedImports do
  begin
    FPE.Msg.Write('Unloading import "%s"', [Pair.Key]);
    FreeLibrary(Pair.value);
  end;
  FLoadedImports.Clear;
end;

end.
