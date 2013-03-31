{
  Load and map module into current process.
  Module MUST have relocations or be RIP-addressed to be loaded normally.
}
unit PE.ExecutableLoader;

interface

uses
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
    msEntryPointFailure
    );

type
  TEXEEntry = procedure(); stdcall;
  TDLLEntry = function(hInstDLL: HINST; fdwReason: DWORD; lpvReserver: LPVOID): BOOL; stdcall;

  TExecutableModule = class
  private
    FPE: TPEImage;
    FInstance: NativeUInt;
    FEntry: Pointer;
    FSizeOfImage: UInt32;
    function MapSections(PrefferedVa: UInt64): TMapStatus;
    function ProtectSections: TMapStatus;
    function Relocate: TMapStatus;
    // LoadImport:
    // True means load and fix imports.
    // False: unload imported libraries.
    function ProcessImports(LoadImport: boolean): TMapStatus;
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
  //
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

{$REGION 'PEB'}


type
  PPEB32 = ^TPEB32;

  TPEB32 = packed record
    tmp: UInt64;
    ImageBase: Pointer;
  end;

function GetPeb32: PPEB32;
asm
  mov eax, fs:[18h]   // teb
  mov eax, [eax+30h]  // teb.peb
end;
{$ENDREGION}

{ TDLL }

constructor TExecutableModule.Create(PE: TPEImage);
begin
  FPE := PE;
end;

destructor TExecutableModule.Destroy;
begin
  Unload;
  inherited;
end;

function TExecutableModule.IsImageMapped: boolean;
begin
  Result := FInstance <> 0;
end;

function Check(var rslt: TMapStatus; ms: TMapStatus): boolean; inline;
begin
  rslt := ms;
  Result := ms = msOK;
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

function TExecutableModule.ProcessImports(LoadImport: boolean): TMapStatus;
var
  ImpLib: TPEImportLibrary;
  ImpLibName, ImpFnName: AnsiString;
  hmod: HMODULE;
  proc: Pointer;
  i, iFn: integer;
  va: UInt64;
begin
  for i := 0 to FPE.Imports.Count - 1 do
  begin
    // Get next import library.
    ImpLib := FPE.Imports[i];
    ImpLibName := ImpLib.Name;
    // Check if module already in address space.
    hmod := GetModuleHandleA(PAnsiChar(ImpLibName));

    // On unloading.
    if (not LoadImport) and (hmod <> 0) then
    begin
      FreeLibrary(hmod);
      continue; // skip part below
    end;

    if hmod = 0 then
      hmod := LoadLibraryA(PAnsiChar(ImpLibName));
    if hmod = 0 then
      raise Exception.CreateFmt('Library %s not found.', [ImpLibName]);
    // Process import functions.
    for iFn := 0 to ImpLib.Functions.Count - 1 do
    begin
      // Find function by name.
      ImpFnName := ImpLib.Functions[iFn].Name;
      proc := GetProcAddress(hmod, PAnsiChar(ImpFnName));
      if proc = nil then
        raise Exception.CreateFmt('Functon %s not found.', [ImpFnName]);
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
    Check(Result, MapSections(PrefferedVa)) and
    Check(Result, Relocate()) and
    Check(Result, ProcessImports(True)) and
    Check(Result, ProtectSections()) then
  begin
    FEntry := Pointer(FInstance + FPE.EntryPointRVA);

    // Call Entry Point.
    if FPE.IsDLL then
      EntryOK := TDLLEntry(FEntry)(FInstance, DLL_PROCESS_ATTACH, nil)
    else
    begin
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
      TDLLEntry(FEntry)(FInstance, DLL_PROCESS_DETACH, nil);

  // Unload imported libraries.
  ProcessImports(False);

  // Free image memory
  VirtualFree(Pointer(FInstance), FSizeOfImage, MEM_DECOMMIT);
  FInstance := 0;

  Result := True;
end;

end.
