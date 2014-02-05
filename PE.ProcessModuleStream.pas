{
  * Class to access memory of Windows process.
  *
  * Stream begin is base of module.
  * Stream size is size of image of target module.
}
unit PE.ProcessModuleStream;

interface

uses
  System.Classes,
  System.SysUtils,

  WinApi.PsApi,
  WinApi.Windows;

type
  TProcessModuleStream = class(TStream)
  private
    FProcessHandle: THandle;
    FModuleBase: NativeUInt;
    FModuleInfo: MODULEINFO;
  private
    FCurrentRVA: UInt64;
  public
    constructor Create(ProcessID: DWORD; ModuleBase: NativeUInt;
      TryToFindModuleBase: boolean = False);
    destructor Destroy; override;

    function AddressToModuleBase(Addr: UInt64): UInt64;

    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    function Read(var Buffer; Count: Longint): Longint; override;

    property ModuleBase: NativeUInt read FModuleBase;
  end;

implementation

const
  PAGE_SIZE = $1000;

  { TProcessModuleStream }

function TProcessModuleStream.AddressToModuleBase(Addr: UInt64): UInt64;
var
  sig: array [0 .. 3] of AnsiChar;
  done: SIZE_T;
  peofs: uint32;
begin
  sig := #0#0#0#0;
  Addr := Addr and ($FFFFFFFFFFFFF000);
  // MZ
  while True do
  begin
    ReadProcessMemory(FProcessHandle, Pointer(Addr), @sig[0], 4, done);
    if (sig[0] = 'M') and (sig[1] = 'Z') then
      break;
    dec(Addr, PAGE_SIZE);
  end;

  // PE,0,0
  ReadProcessMemory(FProcessHandle, Pointer(Addr + $3C), @peofs, 4, done);
  ReadProcessMemory(FProcessHandle, Pointer(Addr + peofs), @sig[0], 4, done);
  if (sig[0] <> 'P') and (sig[1] <> 'E') and (sig[2] <> #0) and (sig[3] <> #0) then
    raise Exception.CreateFmt('Bad module at %x', [Addr]);

  Result := Addr;
end;

constructor TProcessModuleStream.Create(ProcessID: DWORD;
  ModuleBase: NativeUInt; TryToFindModuleBase: boolean);
begin
  inherited Create;

  FProcessHandle := OpenProcess(
    PROCESS_QUERY_INFORMATION or // for GetModuleInformation
    PROCESS_VM_READ,             // to read memory
    False,
    ProcessID);

  if FProcessHandle = 0 then
    RaiseLastOSError;

  if TryToFindModuleBase then
    ModuleBase := AddressToModuleBase(ModuleBase);

  FModuleBase := ModuleBase;

  if not GetModuleInformation(FProcessHandle, ModuleBase, @FModuleInfo, SizeOf(FModuleInfo)) then
    RaiseLastOSError;
end;

destructor TProcessModuleStream.Destroy;
begin
  CloseHandle(FProcessHandle);
  inherited;
end;

function TProcessModuleStream.Read(var Buffer; Count: Integer): Longint;
var
  p: pbyte;
  done: NativeUInt;
begin
  p := pbyte(FModuleInfo.lpBaseOfDll) + FCurrentRVA;
  done := 0;
  ReadProcessMemory(FProcessHandle, p, @Buffer, Count, done);
  inc(FCurrentRVA, done);
  Result := done;
end;

function TProcessModuleStream.Seek(const Offset: Int64;
  Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning:
      FCurrentRVA := Offset;
    soCurrent:
      FCurrentRVA := FCurrentRVA + Offset;
    soEnd:
      FCurrentRVA := FModuleInfo.SizeOfImage + Offset;
  end;
  Result := FCurrentRVA;
end;

end.
