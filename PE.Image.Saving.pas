{$WARN COMBINING_SIGNED_UNSIGNED OFF}
unit PE.Image.Saving;

interface

uses
  System.Classes,
  System.SysUtils;

function SaveImageToStream(APE: TObject; AStream: TStream): boolean;

implementation

uses
  // To expand.
  PE.Headers,
  PE.Common,
  PE.DataDirectories,
  //
  PE.Types.DOSHeader,
  PE.Types.FileHeader,
  PE.Types.NTHeaders,
  PE.Types.OptionalHeader,
  PE.Types.Directories,
  PE.Types.Sections,
  PE.Image,
  PE.Section,
  PE.Sections,
  PE.Utils,

  PE.Build.Export;

{ DOS }

function DoDosHdr(PE: TPEImage; AStream: TStream): boolean;
var
  h: PImageDOSHeader;
begin
  h := PE.DOSHeader;
  h^.e_magic := MZ_SIGNATURE;
  h^.e_lfanew := PE.LFANew;

  // Write DOS header.
  Result := StreamWrite(AStream, h^, SizeOf(h^));

  // Write DOS block.
  if Length(PE.DosBlock) <> 0 then
    StreamWrite(AStream, PE.DosBlock[0], Length(PE.DosBlock));
end;

{ NT }

function DoFileHdr(PE: TPEImage; AStream: TStream): boolean;
const
  sig: uint32 = PE00_SIGNATURE;
begin
  Result := False;
  if StreamWrite(AStream, sig, SizeOf(sig)) then
    if StreamWrite(AStream, PE.FileHeader^, SizeOf(PE.FileHeader^)) then
      Result := true;
end;

{ Optional }

function DoOptHdrAndDirs(PE: TPEImage; AStream: TStream): boolean;
var
  OptHdrSize: integer;
  DDirSize: integer;
begin
  // Update # of dirs.
  PE.OptionalHeader.NumberOfRvaAndSizes := PE.DataDirectories.Count;
  // Write optional header.
  OptHdrSize := PE.OptionalHeader.WriteToStream(AStream, PE.ImageBits, -1);
  // Write dirs.
  DDirSize := PE.DataDirectories.SaveToStream(AStream);
  // Update size of opt. hdr.
  PE.FileHeader.SizeOfOptionalHeader := OptHdrSize + DDirSize;

  Result := PE.FileHeader.SizeOfOptionalHeader <> 0;
end;

{ Sec Hdr }

procedure FillSecHdrRawOfs(PE: TPEImage; ofsSecHdr: uint32);
var
  s: TPESection;
  ofs: uint64;
begin
  ofs := ofsSecHdr + PE.Sections.Count * SizeOf(TImageSectionHeader);
  for s in PE.Sections do
  begin
    ofs := AlignUp(ofs, PE.FileAlignment);
    s.RawOffset := ofs;
    inc(ofs, s.RawSize);
  end;
end;

function DoSecHdr(PE: TPEImage; AStream: TStream): boolean;
var
  Sec: TPESection;
  h: TImageSectionHeader;
begin
  for Sec in PE.Sections do
  begin
    h := Sec.ImageSectionHeader;
    if not StreamWrite(AStream, h, SizeOf(h)) then
      exit(False);
  end;
  exit(true);
end;

function DoSecHdrGap(PE: TPEImage; AStream: TStream): boolean;
var
  size: integer;
begin
  size := Length(PE.SecHdrGap);
  if size <> 0 then
    if not StreamWrite(AStream, PE.SecHdrGap[0], size) then
      exit(False);
  exit(true);
end;

procedure DoSecData(PE: TPEImage; AStream: TStream);
var
  s: TPESection;
begin
  for s in PE.Sections do
  begin
    StreamSeekWithPadding(AStream, s.RawOffset);
    AStream.Write(s.Mem^, Min(s.RawSize, s.VirtualSize));
  end;
end;

function SaveImageToStream(APE: TObject; AStream: TStream): boolean;
var
  PE: TPEImage;
  ofsFileHdr, ofsSecHdr: uint32;
begin
  Result := False;

  PE := TPEImage(APE);

  // Ensure we have all needed values set.
  PE.Defaults.SetAll;

  // save dos
  if not DoDosHdr(PE, AStream) then
    exit;
  ofsFileHdr := PE.DOSHeader.e_lfanew;

  // skip file header now
  if not StreamSeek(AStream, ofsFileHdr + SizeOf(TImageFileHeader) + 4) then
    exit;

  // update size of image header
  PE.FixSizeOfImage;

  // update size of headers
  PE.FixSizeOfHeaders;

  // save optional
  if not DoOptHdrAndDirs(PE, AStream) then
    exit;

  ofsSecHdr := AStream.Position;

  // now write file header
  if not StreamSeek(AStream, ofsFileHdr) then
    exit;
  if not DoFileHdr(PE, AStream) then
    exit;

  // go back to sec hdr
  if not StreamSeek(AStream, ofsSecHdr) then
    exit;

  // Fill RawData offsets for Section Headers.
  FillSecHdrRawOfs(PE, ofsSecHdr);

  // write sec hdr
  if not DoSecHdr(PE, AStream) then
    exit;

  // write sec hdr gap
  DoSecHdrGap(PE, AStream);

  // write sec data
  DoSecData(PE, AStream);

  Result := true;
end;

end.
