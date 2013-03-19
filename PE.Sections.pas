unit PE.Sections;

interface

uses
  System.Generics.Collections,
  System.SysUtils,

  PE.Common,
  PE.Types.Sections,
  PE.Section;

type
  TPESections = class(TList<TPESection>)
  private
    FPE: TObject;
    procedure ItemNotify(Sender: TObject; const Item: TPESection;
      Action: TCollectionNotification);
  public
    constructor Create(APEImage: TObject);

    function Add(const Sec: TPESection): TPESection;
    procedure Clear;

    // Change section Raw and Virtual size.
    // Virtual size is aligned to section alignment.
    procedure Resize(Sec: TPESection; NewSize: UInt32);

    function CalcNextSectionRVA: TRVA;

    // Add new named section.
    // If Mem <> nil, data from Mem will be copied to newly allocated block.
    // If Mem = nil, block will be allocated and filled with 0s.
    function AddNew(const AName: AnsiString; ASize, AFlags: UInt32; Mem: pointer): TPESection;

    function SizeOfAllHeaders: UInt32; inline;

    function RVAToOfs(RVA: TRVA; OutOfs: PDword): boolean;
    function RVAToSec(RVA: TRVA; OutSec: PPESection): boolean;

    function FindByName(const AName: AnsiString; IgnoreCase: boolean = True): TPESection;

    // Fill section memory with specified byte and return number of bytes
    // actually written.
    function FillMemory(RVA: TRVA; Size: UInt32; FillByte: Byte = 0): UInt32;
  end;

implementation

uses
  // Expand
  PE.Types.FileHeader,
  //
  PE.Image,
  PE.Utils;

{ TPESections }

function TPESections.Add(const Sec: TPESection): TPESection;
begin
  inherited Add(Sec);
  Result := Sec;
end;

function TPESections.AddNew(const AName: AnsiString; ASize, AFlags: UInt32; Mem: pointer): TPESection;
var
  h: TImageSectionHeader;
  i: integer;
  PE: TPEImage;
begin
  PE := TPEImage(FPE);

  // Clear
  FillChar(h, sizeof(h), 0);

  // Copy name.
  if AName <> '' then
  begin
    i := max(Length(h.Name), Length(AName));
    System.Move(AName[1], h.Name[0], i);
  end;

  h.Misc.VirtualSize := AlignUp(ASize, PE.SectionAlignment);
  h.VirtualAddress := CalcNextSectionRVA;
  h.SizeOfRawData := ASize;
  // h.PointerToRawData will be calculated later during image saving.
  h.Characteristics := AFlags;
  Result := TPESection.Create(h, Mem);

  Add(Result);
end;

function TPESections.CalcNextSectionRVA: TRVA;
var
  PE: TPEImage;
begin
  PE := TPEImage(FPE);
  if Count = 0 then
    Result := AlignUp(PE.CalcHeadersSizeNotAligned, PE.SectionAlignment)
  else
    Result := AlignUp(Last.RVA + Last.VirtualSize, PE.SectionAlignment);
end;

procedure TPESections.Clear;
begin
  inherited Clear;
  TPEImage(FPE).FileHeader^.NumberOfSections := 0;
end;

constructor TPESections.Create(APEImage: TObject);
begin
  inherited Create;
  FPE := APEImage;
  self.OnNotify := ItemNotify;
end;

function TPESections.FillMemory(RVA: TRVA; Size: UInt32;
  FillByte: Byte): UInt32;
var
  Sec: TPESection;
  Ofs, CanWrite: UInt32;
  p: PByte;
begin
  Result := 0;
  if not RVAToSec(RVA, @Sec) then
    Exit;
  Ofs := RVA - Sec.RVA;                   // offset of RVA in section
  CanWrite := Sec.GetAllocatedSize - Ofs; // max we can write to section end
  if CanWrite < Size then
    Result := CanWrite
  else
    Result := Size;
  p := Sec.Mem + Ofs;
  System.FillChar(p^, Result, FillByte);
end;

function TPESections.FindByName(const AName: AnsiString;
  IgnoreCase: boolean): TPESection;
var
  a, b: AnsiString;
begin
{$WARN IMPLICIT_STRING_CAST OFF}
{$WARN IMPLICIT_STRING_CAST_LOSS OFF}
  if IgnoreCase then
    a := LowerCase(AName)
  else
    a := AName;
  for Result in self do
  begin
    if IgnoreCase then
      b := LowerCase(Result.Name)
    else
      b := Result.Name;
    if a = b then
      Exit;
  end;
  Exit(nil);
{$WARN IMPLICIT_STRING_CAST ON}
{$WARN IMPLICIT_STRING_CAST_LOSS ON}
end;

procedure TPESections.ItemNotify(Sender: TObject; const Item: TPESection;
  Action: TCollectionNotification);
begin
  case Action of
    cnAdded:
      inc(TPEImage(FPE).FileHeader^.NumberOfSections);
    cnRemoved:
      begin
        dec(TPEImage(FPE).FileHeader^.NumberOfSections);
        if Item <> nil then
          Item.Free;
      end;
    cnExtracted:
      dec(TPEImage(FPE).FileHeader^.NumberOfSections);
  end;
end;

procedure TPESections.Resize(Sec: TPESection; NewSize: UInt32);
var
  NewVirtualSize: UInt32;
  EndRVA: TRVA;
begin
  // Last section can be changed freely, other sections must be checked.
  if Sec <> self.Last then
  begin
    if NewSize = 0 then
    begin
      Remove(Sec);
    end
    else
    begin
      // Get new size and rva for this section.
      NewVirtualSize := AlignUp(NewSize, TPEImage(FPE).SectionAlignment);
      EndRVA := Sec.RVA + NewVirtualSize;
      // Check if new section end would be already occupied.
      if RVAToSec(EndRVA + NewVirtualSize, nil) then
        raise Exception.Create('Cannot resize section: size is too big');
    end;
  end;
  Sec.Resize(NewSize);
end;

function TPESections.RVAToOfs(RVA: TRVA; OutOfs: PDword): boolean;
var
  Sec: TPESection;
begin
  for Sec in self do
  begin
    if Sec.ContainRVA(RVA) then
    begin
      if Assigned(OutOfs) then
        OutOfs^ := (RVA - Sec.RVA) + Sec.RawOffset;
      Exit(True);
    end;
  end;
  Exit(False);
end;

function TPESections.RVAToSec(RVA: TRVA; OutSec: PPESection): boolean;
var
  Sec: TPESection;
begin
  for Sec in self do
    if Sec.ContainRVA(RVA) then
    begin
      if OutSec <> nil then
        OutSec^ := Sec;
      Exit(True);
    end;
  Result := False;
end;

function TPESections.SizeOfAllHeaders: UInt32;
begin
  Result := Count * sizeof(TImageSectionHeader)
end;

end.
