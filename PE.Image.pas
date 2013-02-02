unit PE.Image;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,

  PE.Common,
  PE.Headers,
  PE.DataDirectories,

  PE.Msg,
  PE.Utils,

  PE.Image.Defaults,
  PE.Image.Saving,

  PE.Types,
  PE.Types.DOSHeader,
  PE.Types.Directories,
  PE.Types.FileHeader,
  PE.Types.NTHeaders,
  PE.Types.Sections,
  PE.Types.Relocations,
  PE.Types.Imports,
  PE.Types.Export,

  PE.ExportSym,

  PE.TLS,
  PE.Section,
  PE.Sections,
  PE.Imports,
  PE.Resources,

  PE.Parser.Headers,
  PE.Parser.Export,
  PE.Parser.Import,
  PE.Parser.Relocs,
  PE.Parser.TLS,
  PE.Parser.Resources,

  PE.COFF,
  PE.COFF.Types;

type

  TPEImageKind = (PEIMAGE_KIND_DISK, PEIMAGE_KIND_MEMORY);

  { TPEImage }

  TPEImage = class
  private
    FImageKind: TPEImageKind;
    FFileName: string;
    FFileSize: UInt64;
    FDefaults: TPEDefaults;

    FCOFF: TCOFF;

    FDosHeader: TImageDOSHeader; // DOS header.
    FLFANew: uint32;             // Address of new header next after DOS.
    FDosBlock: TBytes;           // Bytes between DOS header and next header.

    FSecHdrGap: TBytes; // Gap after section headers.

    // FNtHeaders: TImageNTHeaders;
    FFileHeader: TImageFileHeader;
    FOptionalHeader: TPEOptionalHeader;

    FSections: TPESections;
    FRelocs: TRelocs;
    FImports: TPEImports;
    FExports: TPEExportSyms;
    FExportedName: AnsiString;
    FTLS: TTLS;
    FResourceTree: TResourceTree;
    FOverlay: TOverlay;
    FEndianness: TEndianness;

    FParsers: array [TParserFlag] of TPEParserClass;
    FMsg: TMsgMgr;

    { Streaming }
    FPositionRVA: TRVA; // Current RVA.

    FDataDirectories: TDataDirectories;

    { Notifiers }
    procedure DoNotifySections(Sender: TObject; const Item: TPESection;
      Action: TCollectionNotification);
    procedure DoNotifyImports(Sender: TObject; const Item: TPEImportLibrary;
      Action: TCollectionNotification);
    procedure DoReadError;

    { Parsers }
    procedure InitParsers;

    { Load base }
    function LoadSectionHeaders(AStream: TStream): UInt16;
    function LoadSectionData(AStream: TStream): UInt16;

    // Replace /%num% to name from COFF string table.
    procedure ResolveSectionNames;

    function GetImageBase: TRVA; inline;
    procedure SetImageBase(Value: TRVA); inline;

    function GetSizeOfImage: UInt64; inline;
    procedure SetSizeOfImage(Value: UInt64); inline;

    function EntryPointRVAGet: TRVA; inline;
    procedure EntryPointRVASet(Value: TRVA); inline;

    function FileAlignmentGet: uint32; inline;
    procedure FileAlignmentSet(const Value: uint32); inline;

    function SectionAlignmentGet: uint32; inline;
    procedure SectionAlignmentSet(const Value: uint32); inline;

    function GetFileHeader: PImageFileHeader; inline;
    function GetImageDOSHeader: PImageDOSHeader; inline;
    function GetOptionalHeader: PPEOptionalHeader; inline;
    function GetPositionVA: TVA;
    procedure SetPositionVA(const Value: TVA);
    procedure SetPositionRVA(const Value: TRVA);

  public

    constructor Create(); overload;
    constructor Create(AMsgProc: TMsgProc); overload;

    destructor Destroy; override;

    class function IsPE(AStream: TStream; Ofs: UInt64 = 0): boolean; static;

    { Helpers }
    function Is32bit: boolean; inline;
    function Is64bit: boolean; inline;

    // Get image bitness. 32/64 or 0 if unknown.
    function GetImageBits: UInt16; inline;
    procedure SetImageBits(Value: UInt16);

    { PE Streaming }
    function SeekRVA(RVA: TRVA): boolean;
    function SeekVA(VA: TVA): boolean;

    // function Read(var Buffer; Count: cardinal): UInt32; overload;
    // function ReadEx(var Buffer; Count: cardinal): boolean; overload; inline;

    function Read(Buffer: Pointer; Count: cardinal): uint32; overload;
    function ReadEx(Buffer: Pointer; Count: cardinal): boolean; overload; inline;
    procedure Skip(Count: integer);

    function ReadANSIString: RawByteString;
    function ReadUnicodeString: UnicodeString;

    // These functions should be Endianness-aware.
    // Sad but Delphi can't inline that simple functions.
    function ReadUInt8: UInt8; overload; {$IFDEF FPC}inline; {$ENDIF} // just to be in group.
    function ReadUInt16: UInt16; overload; {$IFDEF FPC}inline; {$ENDIF}
    function ReadUInt32: uint32; overload; {$IFDEF FPC}inline; {$ENDIF}
    function ReadUInt64: UInt64; overload; {$IFDEF FPC}inline; {$ENDIF}
    function ReadUIntPE: UInt64; overload; {$IFDEF FPC}inline; {$ENDIF}// 64/32 depending on PE format.

    function ReadUInt8(OutData: PUInt8): boolean; overload;
{$IFDEF FPC}inline; {$ENDIF} // just to be in group.
    function ReadUInt16(OutData: PUInt16): boolean; overload;
{$IFDEF FPC}inline; {$ENDIF}
    function ReadUInt32(OutData: PUInt32): boolean; overload;
{$IFDEF FPC}inline; {$ENDIF}
    function ReadUInt64(OutData: PUInt64): boolean; overload;
{$IFDEF FPC}inline; {$ENDIF}
    function ReadUIntPE(OutData: PUInt64): boolean; overload;
{$IFDEF FPC}inline; {$ENDIF}// 64/32 depending on PE format.

    function Write(Buffer: Pointer; Count: cardinal): uint32; overload;

    { Addr conversion }
    function RVAExists(RVA: TRVA): boolean;
    function RVAToMem(RVA: TRVA): Pointer;
    function RVAToOfs(RVA: TRVA; Ofs: PDword): boolean;
    function RVAToSec(RVA: TRVA; OutSec: PPESection): boolean;
    function RVAToVA(RVA: TRVA): TVA; inline;

    function VAExists(VA: TRVA): boolean;
    function VAToMem(VA: TVA): Pointer; inline;
    function VAToOfs(VA: TVA; OutOfs: PDword): boolean; inline;
    function VAToSec(VA: TRVA; OutSec: PPESection): boolean;
    function VAToRVA(VA: TVA): TRVA; inline;

    // Clear image.
    procedure Clear;

    // Calculate not aligned size of headers.
    function CalcHeadersSizeNotAligned: uint32; inline;
    procedure FixSizeOfHeaders; inline;

    // Calculate valid aligned size of image.
    function CalcSizeOfImage: UInt64; inline;

    // Calc raw size of image (w/o overlay), or 0 if failed.
    // Can be used if image loaded from stream and exact image size is unknown.
    // Though we still don't know overlay size.
    function CalcRawSizeOfImage: UInt64; inline;

    // Set valid size of image.
    procedure FixSizeOfImage; inline;

    // Calc offset of section headers.
    function CalcSecHdrOfs: TFileOffset;

    // Calc offset of section headers end.
    function CalcSecHdrEndOfs: TFileOffset;

    // Calc size of optional header w/o directories.
    function CalcSizeOfPureOptionalHeader: uint32;

    { Loading }
    function LoadFromStream(AStream: TStream;
      AParseStages: TParserFlags = DEFAULT_PARSER_FLAGS;
      ImageKind: TPEImageKind = PEIMAGE_KIND_DISK): boolean;

    function LoadFromFile(const AFileName: string;
      AParseStages: TParserFlags = DEFAULT_PARSER_FLAGS): boolean;

    function LoadFromMappedImage(const AFileName: string;
      AParseStages: TParserFlags = DEFAULT_PARSER_FLAGS): boolean;

    { Saving }

    // Save created/modified image.
    function SaveToStream(AStream: TStream): boolean;
    function SaveToFile(const AFileName: string): boolean; inline;

    { Sections }

    // Get last section containing raw offset and size.
    // Get nil if no good section found.
    function GetLastSectionWithValidRawData: TPESection;

    { Overlay }
    function GetOverlay: POverlay;
    function SaveOverlayToFile(const AFileName: string;
      Append: boolean = false): boolean;
    function RemoveOverlayFromFile: boolean;

    { Writing to external stream }

    function StreamWrite(AStream: TStream; var Buf; Size: integer): boolean;
    // Safely write 32/64-bit RVA.
    function StreamWriteRVA(AStream: TStream; RVA: TRVA): boolean;
    procedure StreamWriteStrA(AStream: TStream; const Str: AnsiString);

    { Properties }
    property Msg: TMsgMgr read FMsg;
    property Defaults: TPEDefaults read FDefaults;

    property PositionRVA: TRVA read FPositionRVA write SetPositionRVA;
    property PositionVA: TVA read GetPositionVA write SetPositionVA;

    property ImageKind: TPEImageKind read FImageKind;
    property FileName: string read FFileName;

    // Offset of NT headers, used building new image.
    property LFANew: uint32 read FLFANew write FLFANew;
    property DosBlock: TBytes read FDosBlock;
    property SecHdrGap: TBytes read FSecHdrGap;

    property DOSHeader: PImageDOSHeader read GetImageDOSHeader;
    property FileHeader: PImageFileHeader read GetFileHeader;
    property OptionalHeader: PPEOptionalHeader read GetOptionalHeader;
    property DataDirectories: TDataDirectories read FDataDirectories;

    property Sections: TPESections read FSections;
    property Relocs: TRelocs read FRelocs;
    property Imports: TPEImports read FImports;
    property ExportSyms: TPEExportSyms read FExports;
    property ExportedName: AnsiString read FExportedName write FExportedName;
    property TLS: TTLS read FTLS;
    property ResourceTree: TResourceTree read FResourceTree;
    property ImageBase: TRVA read GetImageBase write SetImageBase;
    property SizeOfImage: UInt64 read GetSizeOfImage write SetSizeOfImage;
    property ImageBits: UInt16 read GetImageBits write SetImageBits;
    property EntryPointRVA: TRVA read EntryPointRVAGet write EntryPointRVASet;
    property FileAlignment: uint32 read FileAlignmentGet write FileAlignmentSet;
    property SectionAlignment: uint32 read SectionAlignmentGet write SectionAlignmentSet;

  end;

implementation

{ TPEImage }

function TPEImage.EntryPointRVAGet: TRVA;
begin
  Result := FOptionalHeader.AddressOfEntryPoint;
end;

procedure TPEImage.EntryPointRVASet(Value: TRVA);
begin
  FOptionalHeader.AddressOfEntryPoint := Value;
end;

// Image Base ==================================================================
function TPEImage.GetImageBase: TRVA;
begin
  Result := FOptionalHeader.ImageBase;
end;

procedure TPEImage.SetImageBase(Value: TRVA);
begin
  FOptionalHeader.ImageBase := Value;
end;
// =============================================================================

// SizeOfImage =================================================================
function TPEImage.GetSizeOfImage: UInt64;
begin
  Result := FOptionalHeader.SizeOfImage;
end;

procedure TPEImage.SetSizeOfImage(Value: UInt64);
begin
  FOptionalHeader.SizeOfImage := Value;
end;

function TPEImage.StreamWrite(AStream: TStream; var Buf;
  Size: integer): boolean;
begin
  Result := AStream.Write(Buf, Size) = Size;
end;

function TPEImage.StreamWriteRVA(AStream: TStream; RVA: TRVA): boolean;
var
  rva32: uint32;
  rva64: UInt64;
begin
  if Is32bit then
    begin
      rva32 := RVA;
      Result := AStream.Write(rva32, 4) = 4;
      exit;
    end;
  if Is64bit then
    begin
      rva64 := RVA;
      Result := AStream.Write(rva64, 8) = 8;
      exit;
    end;
  exit(false);
end;

procedure TPEImage.StreamWriteStrA(AStream: TStream; const Str: AnsiString);
const
  zero: byte = 0;
begin
  if Str <> '' then
    AStream.Write(Str[1], Length(Str));
  AStream.Write(zero, 1);
end;

// =============================================================================

{$REGION 'Constructor/Destructor'}


constructor TPEImage.Create;
begin
  Create(nil);
end;

constructor TPEImage.Create(AMsgProc: TMsgProc);
begin
  FMsg := TMsgMgr.Create(AMsgProc);
  FDefaults := TPEDefaults.Create(self);

  FDataDirectories := TDataDirectories.Create(self);

  FSections := TPESections.Create(self);
  FSections.OnNotify := DoNotifySections;

  FRelocs := TRelocs.Create;

  FImports := TPEImports.Create;
  FImports.OnNotify := DoNotifyImports;

  FExports := TPEExportSyms.Create;

  FTLS := TTLS.Create;

  FResourceTree := TResourceTree.Create;

  FCOFF := TCOFF.Create(self);

  InitParsers;

end;

procedure TPEImage.Clear;
begin
  FLFANew := 0;
  SetLength(FDosBlock, 0);
  SetLength(FSecHdrGap, 0);

  FCOFF.Clear;
  FDataDirectories.Clear;
  FSections.Clear;
  FImports.Clear;
  FExports.Clear;
  FTLS.Clear;
  FResourceTree.Clear;
end;

destructor TPEImage.Destroy;
begin
  Clear;

  FResourceTree.Free;
  FTLS.Free;
  FExports.Free;
  FImports.Free;
  FRelocs.Free;
  FSections.Free;
  FDataDirectories.Free;
  FCOFF.Free;

  inherited Destroy;
end;

procedure TPEImage.DoNotifyImports(Sender: TObject;
  const Item: TPEImportLibrary; Action: TCollectionNotification);
begin
  if Assigned(Item) then
    if Action = cnRemoved then
      Item.Free;
end;

procedure TPEImage.DoNotifySections(Sender: TObject; const Item: TPESection;
  Action: TCollectionNotification);
begin
  if Assigned(Item) then
    if Action = cnRemoved then
      Item.Free;
end;

procedure TPEImage.DoReadError;
begin
  raise Exception.Create('Read Error.');
end;

{$ENDREGION 'Constructor/Destructor'}
{$REGION 'InitParsers'}


procedure TPEImage.InitParsers;
begin
  FParsers[PF_EXPORT] := TPEExportParser;
  FParsers[PF_IMPORT] := TPEImportParser;
  FParsers[PF_RELOCS] := TPERelocParser;
  FParsers[PF_TLS] := TPETLSParser;
  FParsers[PF_RESOURCES] := TPEResourcesParser;
end;
{$ENDREGION 'InitParsers'}
{$REGION 'Sections'}


function TPEImage.CalcHeadersSizeNotAligned: uint32;
begin
  Result := $400; // todo: do not hardcode
end;

procedure TPEImage.FixSizeOfHeaders;
begin
  FOptionalHeader.SizeOfHeaders := AlignUp(CalcHeadersSizeNotAligned,
    FileAlignment);
end;

function TPEImage.CalcSizeOfImage: UInt64;
begin
  with FSections do
    begin
      if Count <> 0 then
        Result := AlignUp(Last.RVA + Last.VirtualSize, SectionAlignment)
      else
        Result := AlignUp(CalcHeadersSizeNotAligned, SectionAlignment);
    end;
end;

function TPEImage.CalcRawSizeOfImage: UInt64;
var
  Last: TPESection;
begin
  Last := GetLastSectionWithValidRawData;
  if (Last <> nil) then
    Result := Last.GetEndRawOffset
  else
    Result := 0;
end;

procedure TPEImage.FixSizeOfImage;
begin
  SizeOfImage := CalcSizeOfImage;
end;

function TPEImage.CalcSecHdrOfs: TFileOffset;
begin
  Result := FLFANew + 4 + SizeOf(TImageFileHeader) +
    CalcSizeOfPureOptionalHeader + FDataDirectories.Count *
    SizeOf(TImageDataDirectory);
end;

function TPEImage.CalcSecHdrEndOfs: TFileOffset;
begin
  Result := CalcSecHdrOfs + FSections.Count * SizeOf(TImageSectionHeader);
end;

function TPEImage.CalcSizeOfPureOptionalHeader: uint32;
begin
  Result := FOptionalHeader.CalcSize(ImageBits);
end;

function TPEImage.GetFileHeader: PImageFileHeader;
begin
  Result := @self.FFileHeader;
end;

function TPEImage.LoadSectionHeaders(AStream: TStream): UInt16;
var
  Sec: TPESection;
  Cnt: integer;
begin
  Result := 0;

  Cnt := FFileHeader.NumberOfSections;

  FSections.Clear;

  while Result < Cnt do
    begin
      Sec := TPESection.Create;
      if not Sec.LoadHeaderFromStream(AStream, Result) then
        begin
          Sec.Free;
          break;
        end;

      if not Sec.IsNameSafe then
        begin
          Sec.Name := format('sec_%4.4x', [Result]);
          Msg.Write('Section has not safe name. Overriding to %s', [Sec.Name]);
        end;

      FSections.Add(Sec);
      inc(Result);
    end;

  // Check section count.
  if FSections.Count <> FFileHeader.NumberOfSections then
    FMsg.Write('Found %d of %d section headers.',
      [FSections.Count, FFileHeader.NumberOfSections]);

end;

function TPEImage.LoadSectionData(AStream: TStream): UInt16;
var
  i: integer;
  Sec: TPESection;
begin
  Result := 0;
  // todo: check if section overlaps existing sections.
  for i := 0 to FSections.Count - 1 do
    begin
      Sec := FSections[i];

      if FImageKind = PEIMAGE_KIND_DISK then
        begin
          if Sec.LoadDataFromStream(AStream) then
            inc(Result);
        end
      else
        begin
          if Sec.LoadDataFromStreamEx(AStream, Sec.RVA, Sec.VirtualSize) then
            inc(Result);
        end;
    end;
end;

procedure TPEImage.ResolveSectionNames;
var
  i, StringOfs, err: integer;
  Sec: TPESection;
  t: RawByteString;
begin
  for i := 0 to FSections.Count - 1 do
    begin
      Sec := FSections[i];
      if (Sec.Name <> '') then
        if (Sec.Name[1] = '/') then
          begin
            t := Sec.Name;
            delete(t, 1, 1);
            val(t, StringOfs, err);
            if err = 0 then
              if FCOFF.GetString(StringOfs, t) then
                if t <> '' then
                  begin
                    Sec.Name := t; // long name from COFF strings
                  end;
          end;
    end;
end;

{$ENDREGION 'Sections'}
{$REGION 'Helpers'}


function TPEImage.Is32bit: boolean;
begin
  Result := FOptionalHeader.Magic = PE_MAGIC_PE32;
end;

function TPEImage.Is64bit: boolean;
begin
  Result := FOptionalHeader.Magic = PE_MAGIC_PE32PLUS;
end;

class function TPEImage.IsPE(AStream: TStream; Ofs: UInt64): boolean;
var
  dos: TImageDOSHeader;
  pe00: uint32;
begin
  if AStream.Seek(Ofs, soFromBeginning) <> Ofs then
    exit(false);

  if (AStream.Read(dos, SizeOf(dos)) = SizeOf(dos)) then
    if (dos.e_magic = MZ_SIGNATURE) then
      begin
        Ofs := Ofs + dos.e_lfanew;
        if Ofs >= AStream.Size then
          exit(false);
        if AStream.Seek(Ofs, soFromBeginning) = Ofs then
          if AStream.Read(pe00, SizeOf(pe00)) = SizeOf(pe00) then
            if pe00 = PE00_SIGNATURE then
              exit(true);
      end;
  exit(false);
end;

// Image Bitness ===============================================================
function TPEImage.GetImageBits: UInt16;
begin
  case FOptionalHeader.Magic of
    PE_MAGIC_PE32:
      Result := 32;
    PE_MAGIC_PE32PLUS:
      Result := 64;
    else
      Result := 0;
  end;
end;

function TPEImage.GetImageDOSHeader: PImageDOSHeader;
begin
  Result := @self.FDosHeader;
end;

procedure TPEImage.SetImageBits(Value: UInt16);
begin
  case Value of
    32:
      FOptionalHeader.Magic := PE_MAGIC_PE32;
    64:
      FOptionalHeader.Magic := PE_MAGIC_PE32PLUS;
    else
      begin
        FOptionalHeader.Magic := 0;
        raise Exception.Create('Value unsupported.');
      end;
  end;
end;

procedure TPEImage.SetPositionRVA(const Value: TRVA);
begin
  FPositionRVA := Value;
end;

procedure TPEImage.SetPositionVA(const Value: TVA);
begin
  FPositionRVA := Value - FOptionalHeader.ImageBase;
end;

// =============================================================================

{$ENDREGION 'Helpers'}
{$REGION 'Stream'}
// File/Section alignment Get/Set ==============================================

function TPEImage.FileAlignmentGet: uint32;
begin
  Result := FOptionalHeader.FileAlignment;
end;

procedure TPEImage.FileAlignmentSet(const Value: uint32);
begin
  FOptionalHeader.FileAlignment := Value;
end;

function TPEImage.SectionAlignmentGet: uint32;
begin
  Result := FOptionalHeader.SectionAlignment;
end;

procedure TPEImage.SectionAlignmentSet(const Value: uint32);
begin
  FOptionalHeader.SectionAlignment := Value;
end;

// =============================================================================

function TPEImage.SeekRVA(RVA: TRVA): boolean;
begin
  Result := RVAToOfs(RVA, nil);
  if Result then
    FPositionRVA := RVA;
end;

function TPEImage.SeekVA(VA: TVA): boolean;
begin
  Result := SeekRVA(VAToRVA(VA));
end;

function TPEImage.Read(Buffer: Pointer; Count: cardinal): uint32;
var
  Mem: Pointer;
begin
  if Count = 0 then
    exit(0);
  Mem := RVAToMem(FPositionRVA);
  if Mem <> nil then
    begin
      if Buffer <> nil then
        move(Mem^, Buffer^, Count);
      inc(FPositionRVA, Count);
      exit(Count);
    end;
  exit(0);
end;

function TPEImage.ReadEx(Buffer: Pointer; Count: cardinal): boolean;
begin
  Result := Read(Buffer, Count) = Count;
end;

procedure TPEImage.Skip(Count: integer);
begin
  inc(FPositionRVA, Count);
end;

function TPEImage.ReadUnicodeString: UnicodeString;
var
  Len, i: UInt16;
begin
  Read(@Len, 2);
  SetLength(Result, Len);
  for i := 1 to Len do
    Read(@Result[i], 2);
end;

function TPEImage.ReadANSIString: RawByteString;
var
  B: byte;
begin
  Result := '';
  while ReadEx(@B, 1) and (B <> 0) do
    Result := Result + ansichar(B);
end;

// todo: Endianness-aware
function TPEImage.ReadUInt8: UInt8;
begin
  if not ReadUInt8(@Result) then
    DoReadError;
end;

function TPEImage.ReadUInt16: UInt16;
begin
  if not ReadUInt16(@Result) then
    DoReadError;
end;

function TPEImage.ReadUInt32: uint32;
begin
  if not ReadUInt32(@Result) then
    DoReadError;
end;

function TPEImage.ReadUInt64: UInt64;
begin
  if not ReadUInt64(@Result) then
    DoReadError;
end;

function TPEImage.ReadUIntPE: UInt64; // 64/32 depending on PE format.
begin
  if not ReadUIntPE(@Result) then
    DoReadError;
end;

{ Read implementation }

function TPEImage.ReadUInt8(OutData: PUInt8): boolean;
begin
  Result := ReadEx(OutData, 1);
end;

function TPEImage.ReadUInt16(OutData: PUInt16): boolean;
begin
  Result := ReadEx(OutData, 2);
end;

function TPEImage.ReadUInt32(OutData: PUInt32): boolean;
begin
  Result := ReadEx(OutData, 4);
end;

function TPEImage.ReadUInt64(OutData: PUInt64): boolean;
begin
  Result := ReadEx(OutData, 8);
end;

function TPEImage.ReadUIntPE(OutData: PUInt64): boolean;
begin
  if OutData <> nil then
    OutData^ := 0;

  case ImageBits of
    32:
      Result := ReadEx(OutData, 4);
    64:
      Result := ReadEx(OutData, 8);
    else
      DoReadError;
  end;
end;

function TPEImage.Write(Buffer: Pointer; Count: cardinal): uint32;
var
  Mem: Pointer;
begin
  Mem := RVAToMem(FPositionRVA);
  if Mem <> nil then
    begin
      if Buffer <> nil then
        move(Buffer^, Mem^, Count);
      inc(FPositionRVA, Count);
      exit(Count);
    end;
  exit(0);
end;

{$ENDREGION 'Stream'}
{$REGION 'AddrConv'}


function TPEImage.RVAToMem(RVA: TRVA): Pointer;
var
  Ofs: integer;
  s: TPESection;
begin
  if RVAToSec(RVA, @s) and (s.Mem <> nil) then
    begin
      Ofs := RVA - s.RVA;
      exit(@s.Mem[Ofs]);
    end;
  exit(nil);
end;

function TPEImage.RVAExists(RVA: TRVA): boolean;
begin
  Result := RVAToSec(RVA, nil);
end;

function TPEImage.RVAToOfs(RVA: TRVA; Ofs: PDword): boolean;
var
  i: integer;
  rva0, rva1: dword;
begin
  for i := 0 to FSections.Count - 1 do
    begin
      rva0 := FSections[i].RVA;
      rva1 := rva0 + FSections[i].VirtualSize;
      if (RVA >= rva0) and (RVA < rva1) then
        begin
          if Assigned(Ofs) then
            Ofs^ := (RVA - rva0) + FSections[i].RawOffset;
          exit(true);
        end;
    end;
  exit(false);
end;

function TPEImage.RVAToSec(RVA: TRVA; OutSec: PPESection): boolean;
var
  Sec: TPESection;
begin
  for Sec in FSections do
    if Sec.ContainRVA(RVA) then
      begin
        if OutSec <> nil then
          OutSec^ := Sec;
        exit(true);
      end;
  Result := false;
end;

function TPEImage.RVAToVA(RVA: TRVA): UInt64;
begin
  Result := RVA + ImageBase;
end;

function TPEImage.VAExists(VA: TRVA): boolean;
begin
  Result := RVAToSec(VA - FOptionalHeader.ImageBase, nil);
end;

function TPEImage.VAToMem(VA: TVA): Pointer;
begin
  Result := RVAToMem(VAToRVA(VA));
end;

function TPEImage.VAToOfs(VA: TVA; OutOfs: PDword): boolean;
begin
  Result := RVAToOfs(VAToRVA(VA), OutOfs);
end;

function TPEImage.VAToSec(VA: TRVA; OutSec: PPESection): boolean;
begin
  Result := RVAToSec(VAToRVA(VA), OutSec);
end;

function TPEImage.VAToRVA(VA: TVA): TRVA;
begin
  Result := VA - FOptionalHeader.ImageBase;
end;
{$ENDREGION 'AddrConv'}
{$REGION 'Load'}


function TPEImage.LoadFromFile(const AFileName: string;
  AParseStages: TParserFlags): boolean;
var
  fs: TFileStream;
begin
  if not FileExists(AFileName) then
    begin
      FMsg.Write('File not found.');
      exit(false);
    end;

  fs := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    FFileName := AFileName;
    fs.Position := 0;
    Result := LoadFromStream(fs, AParseStages);
  finally
    fs.Free;
  end;
end;

function TPEImage.LoadFromMappedImage(const AFileName: string;
  AParseStages: TParserFlags): boolean;
begin
  raise Exception.Create('ToDo: LoadFromMappedImage');
end;

function TPEImage.LoadFromStream(AStream: TStream; AParseStages: TParserFlags;
  ImageKind: TPEImageKind): boolean;
var
  OptHdrOfs, SecHdrOfs, SecHdrEndOfs, SecDataOfs: TFileOffset;
  SecHdrGapSize: integer;
  OptHdrSizeRead: int32; // w/o directories
  Stage: TParserFlag;
  Parser: TPEParser;
  Signature: uint32;
  DOSBlockSize: uint32;
begin
  Result := false;
  // StreamSeek(AStream, 0);

  FImageKind := ImageKind;
  FFileSize := AStream.Size;

  // DOS header.
  if not LoadDosHeader(AStream, FDosHeader) then
    exit; // dos header failed

  // Check if e_lfanew is ok
  if not StreamSeek(AStream, FDosHeader.e_lfanew) then
    exit; // e_lfanew is wrong

  // @ e_lfanew

  // Store offset of NT headers.
  FLFANew := FDosHeader.e_lfanew;

  // Read DOS Block
  DOSBlockSize := FDosHeader.e_lfanew - SizeOf(FDosHeader);
  SetLength(self.FDosBlock, DOSBlockSize);
  if (DOSBlockSize <> 0) then
    if StreamSeek(AStream, SizeOf(FDosHeader)) then
      begin
        if not StreamRead(AStream, self.FDosBlock[0], DOSBlockSize) then
          SetLength(self.FDosBlock, 0);
      end;

  // Go back to new header.
  if not StreamSeek(AStream, FDosHeader.e_lfanew) then
    exit; // e_lfanew is wrong

  // Load signature.
  if not StreamRead(AStream, Signature, SizeOf(Signature)) then
    exit;
  // Check signature.
  if Signature <> PE00_SIGNATURE then
    exit; // not PE file

  // Load File Header.
  if not LoadFileHeader(AStream, FFileHeader) then
    exit; // File Header failed.

  // Get offsets of Optional Header and Section Headers.
  OptHdrOfs := AStream.Position;
  SecHdrOfs := OptHdrOfs + FFileHeader.SizeOfOptionalHeader;
  SecHdrEndOfs := SecHdrOfs + SizeOf(TImageSectionHeader) *
    FFileHeader.NumberOfSections;

  // Read COFF.
  FCOFF.LoadFromStream(AStream);

  // Load Section Headers first.
  AStream.Position := SecHdrOfs;
  LoadSectionHeaders(AStream);

  // Convert /%num% section names to long names if possible.
  ResolveSectionNames;

  // Read Gap after Section Header.
  if FSections.Count <> 0 then
    begin
      SecDataOfs := FSections.First.RawOffset;
      if SecDataOfs >= SecHdrEndOfs then
        begin
          SecHdrGapSize := SecDataOfs - SecHdrEndOfs;
          SetLength(self.FSecHdrGap, SecHdrGapSize);
          if SecHdrGapSize <> 0 then
            begin
              AStream.Position := SecHdrEndOfs;
              AStream.Read(self.FSecHdrGap[0], SecHdrGapSize);
            end;
        end;
    end;

  // Read opt.hdr. magic to know if image is 32 or 64 bit.
  AStream.Position := OptHdrOfs;
  if not StreamPeek(AStream, FOptionalHeader.Magic,
    SizeOf(FOptionalHeader.Magic)) then
    exit;

  // Safe read optional header.
  OptHdrSizeRead := FOptionalHeader.ReadFromStream(AStream, ImageBits, -1);

  if OptHdrSizeRead <> 0 then
    begin
      // Read data directories from current pos top SecHdrOfs.
      FDataDirectories.LoadFromStream(AStream, Msg, AStream.Position, SecHdrOfs,
        FOptionalHeader.NumberOfRvaAndSizes);
    end;

  Result := true;

  // Load section data.
  LoadSectionData(AStream);

  // Execute parsers.
  for Stage in AParseStages do
    if Assigned(FParsers[Stage]) then
      begin
        Parser := FParsers[Stage].Create(self);
        try
          // Todo: print status of parsing.
          case Parser.Parse of
            // PR_OK:
            // Msg.Write('[%s] Parser returned ok.', [Parser.ToString]);
            PR_ERROR:
              Msg.Write('[%s] Parser returned error.', [Parser.ToString]);
            PR_SUSPICIOUS:
              Msg.Write('[%s] Parser returned status SUSPICIOUS.',
                [Parser.ToString]);
          end;
        finally
          Parser.Free;
        end;
      end;

end;
{$ENDREGION 'Load'}


function TPEImage.SaveToStream(AStream: TStream): boolean;
begin
  Result := PE.Image.Saving.SaveImageToStream(self, AStream);
end;

function TPEImage.SaveToFile(const AFileName: string): boolean;
var
  fs: TFileStream;
begin
  fs := TFileStream.Create(AFileName, fmCreate);
  try
    Result := SaveToStream(fs);
  finally
    fs.Free;
  end;
end;

{$REGION 'Overlay'}


function TPEImage.GetOptionalHeader: PPEOptionalHeader;
begin
  Result := @self.FOptionalHeader;
end;

function TPEImage.GetOverlay: POverlay;
var
  lastSec: TPESection;
begin
  lastSec := GetLastSectionWithValidRawData;

  if (lastSec <> nil) then
    begin
      FOverlay.Offset := lastSec.GetEndRawOffset; // overlay offset

      // Check overlay offet present in file.
      if FOverlay.Offset < FFileSize then
        begin
          FOverlay.Size := FFileSize - FOverlay.Offset;
          exit(@FOverlay);
        end;
    end;

  exit(nil);
end;

function TPEImage.GetPositionVA: TVA;
begin
  Result := FPositionRVA + FOptionalHeader.ImageBase;
end;

function TPEImage.GetLastSectionWithValidRawData: TPESection;
var
  i: integer;
begin
  for i := FSections.Count - 1 downto 0 do
    if (FSections[i].RawOffset <> 0) and (FSections[i].RawSize <> 0) then
      exit(FSections[i]);
  exit(nil);
end;

function TPEImage.SaveOverlayToFile(const AFileName: string;
  Append: boolean = false): boolean;
var
  src, dst: TFileStream;
  ovr: POverlay;
begin
  Result := false;
  ovr := GetOverlay;
  if Assigned(ovr) then
    begin
      // If no overlay, we're done.
      if ovr^.Size = 0 then
        exit(true);
      try
        src := TFileStream.Create(self.FFileName, fmOpenRead or fmShareDenyWrite);

        if Append and FileExists(AFileName) then
          begin
            dst := TFileStream.Create(AFileName, fmOpenReadWrite or
              fmShareDenyWrite);
            dst.Seek(0, soFromEnd);
          end
        else
          dst := TFileStream.Create(AFileName, fmCreate);

        try
          src.Seek(ovr^.Offset, soFromBeginning);
          dst.CopyFrom(src, ovr^.Size);
          Result := true;
        finally
          src.Free;
          dst.Free;
        end;
      except
      end;
    end;
end;

function TPEImage.RemoveOverlayFromFile: boolean;
var
  ovr: POverlay;
  fs: TFileStream;
begin
  Result := false;
  ovr := GetOverlay;
  if (ovr <> nil) and (ovr^.Size <> 0) then
    begin
      try
        fs := TFileStream.Create(FFileName, fmOpenWrite or fmShareDenyWrite);
        try
          fs.Size := fs.Size - ovr^.Size; // Trim file.
          self.FFileSize := fs.Size;      // Update filesize.
          Result := true;
        finally
          fs.Free;
        end;
      except
      end;
    end;
end;

{$ENDREGION 'Overlay'}

end.
