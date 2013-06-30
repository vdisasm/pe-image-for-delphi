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
    FName: AnsiString;  // Section name.
    FVSize: uint32;     // Virtual Size.
    FRVA: TRVA;         // Relative Virtual Address.
    FRawSize: uint32;   // Raw size.
    FRawOffset: uint32; // Raw offset.
    FFlags: uint32;     // Section flags.
    FMem: TBytes;       // Memory allocated for section, size = raw size
    function GetImageSectionHeader: TImageSectionHeader;
    function GetMemPtr: PByte;

    procedure SetAllocatedSize(Value: uint32);
  public

    constructor Create(const ASecHdr: TImageSectionHeader; AMem: pointer;
      AMsg: PMsgMgr = nil); overload;

    destructor Destroy; override;

    function GetAllocatedSize: uint32;

    // Set section values from Section Header.
    // Allocate memory for section data.
    // If ChangeData is True memory will be overwritten.
    procedure SetHeader(ASecHdr: TImageSectionHeader; ASrcData: pointer;
      ChangeData: boolean = True);

    // Load Section Header from stream.
    // Allocate memory for section data.
    function LoadHeaderFromStream(AStream: TStream; AId: integer): boolean;

    // Can be used to load mapped section.
    // SetHeader must be called first.
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

    procedure Resize(NewSize: uint32);

    function ContainRVA(RVA: TRVA): boolean; inline;
    function GetEndRVA: TRVA; inline;
    function GetEndRawOffset: uint32; inline;

    function IsNameSafe: boolean;

    property Name: AnsiString read FName write FName;
    property VirtualSize: uint32 read FVSize;
    property RVA: TRVA read FRVA;
    property RawSize: uint32 read FRawSize;
    property RawOffset: uint32 read FRawOffset write FRawOffset;
    property Flags: uint32 read FFlags write FFlags;
    property Mem: PByte read GetMemPtr;
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
      fs.Write(Self.Mem^, Self.FVSize);
      Result := True;
    finally
      FreeAndNil(fs);
    end;
  except
    Result := false;
  end;
end;

procedure TPESection.SetAllocatedSize(Value: uint32);
begin
  SetLength(FMem, Value);
end;

procedure TPESection.SetHeader(ASecHdr: TImageSectionHeader; ASrcData: pointer;
  ChangeData: boolean);
var
  SizeToAlloc: uint32;
begin
  FName := ASecHdr.Name;
  FVSize := ASecHdr.Misc.VirtualSize;
  FRVA := ASecHdr.VirtualAddress;
  FRawSize := ASecHdr.SizeOfRawData;
  FRawOffset := ASecHdr.PointerToRawData;
  FFlags := ASecHdr.Characteristics;

  if ChangeData then
  begin
    SizeToAlloc := FVSize;

    if SizeToAlloc = 0 then
      raise Exception.Create('Section data size = 0.');

    // If no source mem specified, alloc empty block.
    // If have source mem, copy it.
    if ASrcData = nil then
    begin
      SetAllocatedSize(0);
      SetAllocatedSize(SizeToAlloc);
    end
    else
    begin
      SetAllocatedSize(SizeToAlloc);
      Move(ASrcData^, Mem^, SizeToAlloc);
    end;
  end;
end;

procedure TPESection.ClearData;
begin
  SetAllocatedSize(0);
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

function TPESection.GetMemPtr: PByte;
begin
  Result := @FMem[0];
end;

function TPESection.GetAllocatedSize: uint32;
begin
  Result := Length(FMem);
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
  if (ARawOffset = 0) or (ARawSize = 0) then
    Exit(false); // Bad args.

  if not StreamSeek(AStream, ARawOffset) then
    Exit(false); // Can't find position in file.

  if ARawSize > GetAllocatedSize then
    ARawSize := GetAllocatedSize;

  cnt := AStream.Read(Mem^, ARawSize);
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
    if Assigned(FMsg) then
      FMsg.Write('Actual raw size was loaded.');
  end;
  Exit(True);
end;

function TPESection.SaveDataToStream(AStream: TStream): boolean;
begin
{$WARN COMPARING_SIGNED_UNSIGNED OFF}
  Result := false;
  if (FMem = nil) or (FRawSize = 0) then
  begin
    if Assigned(FMsg) then
      FMsg.Write('No data to save.');
    Exit;
  end;
  Result := AStream.Write(Mem^, FRawSize) = FRawSize;
{$WARN COMPARING_SIGNED_UNSIGNED ON}
end;

function TPESection.LoadHeaderFromStream(AStream: TStream;
  AId: integer): boolean;
var
  sh: TImageSectionHeader;
begin
{$WARN IMPLICIT_STRING_CAST_LOSS OFF}
  if StreamRead(AStream, sh, sizeof(sh)) then
  begin
    SetHeader(sh, nil);
    if sh.Name = '' then
      FName := Format('#%3.3d', [AId]);
    Exit(True);
  end;
  Exit(false);
{$WARN IMPLICIT_STRING_CAST_LOSS ON}
end;

procedure TPESection.Resize(NewSize: uint32);
begin
  FRawSize := NewSize;
  FVSize := NewSize;
  SetAllocatedSize(NewSize);
end;

end.
