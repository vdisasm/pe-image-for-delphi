unit PE.Section;

interface

uses
  System.Classes,
  System.SysUtils,

  PE.Common,
  PE.Msg,
  PE.Types,
  PE.Types.Sections,
  PE.Utils;

type
  TPESection = class
  private
    FMsg: PMsgMgr;
    FName: AnsiString; // Section name.
    FVSize: uint32; // Virtual Size.
    FRVA: TRVA; // Relative Virtual Address.
    FRawSize: uint32; // Raw size.
    FRawOffset: uint32; // Raw offset.
    FFlags: uint32; // Section flags.
    FMem: PByte; // Memory allocated for section, size = raw size
    function GetImageSectionHeader: TImageSectionHeader;
  public

    constructor Create(const ASecHdr: TImageSectionHeader; AMem: pointer;
      AMsg: PMsgMgr = nil); overload;

    destructor Destroy; override;

    // Set section values from Section Header.
    procedure SetHeader(ASecHdr: TImageSectionHeader; AMem: pointer);

    // Load Section Header from stream.
    function LoadHeaderFromStream(AStream: TStream; AId: integer): boolean;

    // Can be used to load mapped section.
    function LoadDataFromStreamEx(AStream: TStream;
      ARawOffset, ARawSize: uint32): boolean;

    // Allocate Mem and read RawSize bytes from RawOffset of AStream.
    function LoadDataFromStream(AStream: TStream): boolean;

    // Save section data to AStream.
    function SaveDataToStream(AStream: TStream): boolean;

    // Save section data to file.
    function SaveToFile(const FileName: string): boolean;

    // Deallocate section data.
    procedure ClearData;

    procedure ClearMem; inline;

    function ContainRVA(RVA: TRVA): boolean; inline;
    function GetEndRVA: TRVA; inline;
    function GetEndRawOffset: uint32; inline;

    function IsNameSafe: boolean;

    property Name: AnsiString read FName write FName;
    property VirtualSize: uint32 read FVSize;
    property RVA: TRVA read FRVA write FRVA;
    property RawSize: uint32 read FRawSize write FRawSize;
    property RawOffset: uint32 read FRawOffset write FRawOffset;
    property Flags: uint32 read FFlags write FFlags;
    property Mem: PByte read FMem;
    property ImageSectionHeader: TImageSectionHeader read GetImageSectionHeader;
  end;

  PPESection = ^TPESection;

implementation

{ TPESection }

function TPESection.ContainRVA(RVA: TRVA): boolean;
begin
  Result := (RVA >= Self.RVA) and (RVA < Self.GetEndRVA);
end;

constructor TPESection.Create(const ASecHdr: TImageSectionHeader; AMem: pointer;
  AMsg: PMsgMgr);
begin
  FMsg := AMsg;
  SetHeader(ASecHdr, AMem);
end;

destructor TPESection.Destroy;
begin
  ClearData;
  inherited;
end;

function TPESection.SaveToFile(const FileName: string): boolean;
var
  fs: TFileStream;
begin
  try
    fs := TFileStream.Create(FileName, fmCreate or fmShareDenyWrite);
    try
      fs.Write(Self.FMem^, Self.FRawSize);
      Result := true;
    finally
      FreeAndNil(fs);
    end;
  except
    Result := false;
  end;
end;

procedure TPESection.SetHeader(ASecHdr: TImageSectionHeader; AMem: pointer);
var
  SizeToAlloc: uint32;
begin
  ClearData;

  FName := ASecHdr.Name;
  FVSize := ASecHdr.Misc.VirtualSize;
  FRVA := ASecHdr.VirtualAddress;
  FRawSize := ASecHdr.SizeOfRawData;
  FRawOffset := ASecHdr.PointerToRawData;
  FFlags := ASecHdr.Characteristics;

  if FRawSize <> 0 then
    SizeToAlloc := FRawSize
  else
    SizeToAlloc := FVSize;

  if SizeToAlloc = 0 then
    raise Exception.Create('Section data size = 0.');

  // If no source mem specified, alloc empty block.
  // If got surce mem, copy it.
  if AMem = nil then
    FMem := AllocMem(SizeToAlloc)
  else
  begin
    GetMem(FMem, SizeToAlloc);
    Move(AMem^, FMem^, SizeToAlloc);
  end;

end;

procedure TPESection.ClearMem;
begin
  if FMem <> nil then
  begin
    Freemem(FMem);
    FMem := nil;
  end;
end;

procedure TPESection.ClearData;
begin
  ClearMem;
  FRawSize := 0;
  FRawOffset := 0;
end;

function TPESection.GetEndRVA: TRVA;
begin
  Result := Self.RVA + Self.VirtualSize;
end;

function TPESection.GetImageSectionHeader: TImageSectionHeader;
var
  i: integer;
begin
  FillChar(Result, sizeof(Result), 0);
  for i := 1 to Min(Length(Result.Name), Length(name)) do
    Result.Name[i - 1] := name[i];
  Result.VirtualAddress := RVA;
  Result.Misc.VirtualSize := VirtualSize;
  Result.SizeOfRawData := RawSize;
  Result.PointerToRawData := RawOffset;
  Result.Characteristics := Flags;
end;

function TPESection.GetEndRawOffset: uint32;
begin
  Result := Self.FRawOffset + Self.FRawSize;
end;

function TPESection.IsNameSafe: boolean;
begin
  Result := IsStringASCII(FName);
end;

function TPESection.LoadDataFromStream(AStream: TStream): boolean;
begin
  Result := LoadDataFromStreamEx(AStream, FRawOffset, FRawSize);
end;

function TPESection.LoadDataFromStreamEx(AStream: TStream;
  ARawOffset, ARawSize: uint32): boolean;
var
  cnt: uint32;
begin
  ClearMem;

  if (ARawOffset <> 0) and (ARawSize <> 0) then
  begin
    if not StreamSeek(AStream, ARawOffset) then
      exit(false);

    GetMem(FMem, ARawSize);

    cnt := AStream.Read(FMem^, ARawSize);
    if cnt = 0 then
    begin
      ClearData;
      if Assigned(FMsg) then
        FMsg.Write('Section %s has no raw data.', [FName]);
    end
    else if (cnt <> ARawSize) then
    begin
      if Assigned(FMsg) then
        FMsg.Write
          ('Section %s has less raw data than header declares: 0x%x instead of 0x%x.',
          [FName, cnt, ARawSize]);
      ReallocMem(FMem, cnt);
      ARawSize := cnt;
      if Assigned(FMsg) then
        FMsg.Write('Actual raw size was loaded.');
    end;
    exit(true);
  end;
  exit(false);
end;

function TPESection.SaveDataToStream(AStream: TStream): boolean;
begin
  Result := false;
  if (FMem = nil) or (FRawSize = 0) then
  begin
    if Assigned(FMsg) then
      FMsg.Write('No data to save.');
    exit;
  end;
  Result := AStream.Write(FMem^, FRawSize) = FRawSize;
end;

function TPESection.LoadHeaderFromStream(AStream: TStream;
  AId: integer): boolean;
var
  sh: TImageSectionHeader;
begin
  if StreamRead(AStream, sh, sizeof(sh)) then
  begin
    SetHeader(sh, nil);
    if sh.Name = '' then
      FName := Format('#%3.3d', [AId]);
    exit(true);
  end;
  exit(false);
end;

end.
