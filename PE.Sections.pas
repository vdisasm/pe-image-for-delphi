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

    function FindByName(const AName: AnsiString; IgnoreCase: boolean = True): TPESection;

  end;

implementation

uses
  PE.Image,
  PE.Utils;

{ TPESections }

function TPESections.Add(const Sec: TPESection): TPESection;
var
  PE: TPEImage;
begin
  inherited Add(Sec);
  PE := TPEImage(FPE);
  inc(PE.FileHeader^.NumberOfSections);
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
end;

function TPESections.FindByName(const AName: AnsiString;
  IgnoreCase: boolean): TPESection;
var
  a, b: AnsiString;
begin
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
      exit;
  end;
  exit(nil);
end;

procedure TPESections.Resize(Sec: TPESection; NewSize: UInt32);
var
  h: TImageSectionHeader;
  NewVirtualSize: UInt32;
begin
  NewVirtualSize := AlignUp(NewSize, TPEImage(FPE).SectionAlignment);
  // Last section can be changed freely, other sections must be checked.
  if Sec <> self.Last then
  begin
    if NewVirtualSize > Sec.VirtualSize then
      raise Exception.Create('Cannot resize section: size is too big');
  end;
  h := Sec.ImageSectionHeader;
  h.SizeOfRawData := NewSize;
  h.Misc.VirtualSize := NewVirtualSize;
  Sec.SetHeader(h, nil, False);
end;

function TPESections.SizeOfAllHeaders: UInt32;
begin
  Result := Count * sizeof(TImageSectionHeader)
end;

end.
