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
    constructor Create(ProcessID: DWORD; ModuleBase: NativeUInt);
    destructor Destroy; override;

    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    function Read(var Buffer; Count: Longint): Longint; override;
  end;

implementation

{ TProcessModuleStream }

constructor TProcessModuleStream.Create(ProcessID: DWORD;
  ModuleBase: NativeUInt);
begin
  inherited Create;

  FProcessHandle := OpenProcess(
    PROCESS_QUERY_INFORMATION or // for GetModuleInformation
    PROCESS_VM_READ,             // to read memory
    False,
    ProcessID);

  if FProcessHandle = 0 then
    RaiseLastOSError;

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
  result := done;
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
  result := FCurrentRVA;
end;

end.
