unit PE.MemoryStream;

interface

uses
  System.Classes,
  System.SysUtils;

type
  TPEMemoryStream = class(TCustomMemoryStream)
  private
    FModuleToUnload: HMODULE;
    FModuleFileName: string;
    FModuleSize: uint32;
  public
    constructor Create(const ModuleName: string; ForceLoadingModule: boolean = False);

    destructor Destroy; override;

    class function GetModuleImageSize(ModulePtr: PByte): uint32; static;
  end;

implementation

uses
  WinApi.Windows,

  PE.Types.DosHeader,
  PE.Types.NTHeaders;

{ TDLLStream }

constructor TPEMemoryStream.Create(const ModuleName: string;
  ForceLoadingModule: boolean);
var
  FModulePtr: pointer;
begin
  inherited Create;
  FModuleFileName := ModuleName;

  FModulePtr := pointer(GetModuleHandle(PChar(ModuleName)));
  FModuleToUnload := 0;

  if (FModulePtr = nil) and (ForceLoadingModule) then
  begin
    FModuleToUnload := LoadLibrary(PChar(ModuleName));
    FModulePtr := pointer(FModuleToUnload);
  end;

  if FModulePtr = nil then
    raise Exception.CreateFmt('Module "%s" not found in address space',
      [ModuleName]);

  FModuleSize := TPEMemoryStream.GetModuleImageSize(FModulePtr);

  SetPointer(FModulePtr, FModuleSize);

end;

destructor TPEMemoryStream.Destroy;
begin
  if FModuleToUnload <> 0 then
    FreeLibrary(FModuleToUnload);
  inherited;
end;

class function TPEMemoryStream.GetModuleImageSize(ModulePtr: PByte): uint32;
var
  dos: PImageDOSHeader;
  nt: PImageNTHeaders;
begin
  dos := PImageDOSHeader(ModulePtr);

  if dos.e_magic <> MZ_SIGNATURE then
    raise Exception.Create('Not PE image');

  nt := PImageNTHeaders(ModulePtr + dos^.e_lfanew);

  if nt.Signature <> PE00_SIGNATURE then
    raise Exception.Create('Not PE image');

  Result := nt^.OptionalHeader.pe32.SizeOfImage;
end;

end.
