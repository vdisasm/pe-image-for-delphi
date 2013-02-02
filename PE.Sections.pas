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

    function Add(const Item: TPESection): TPESection;
    procedure Clear;

    function CalcNextSectionRVA: TRVA;

    // Add new named section.
    // If Mem <> nil, data from Mem will be copied to newly allocated block.
    // If Mem = nil, block will be allocated and filled with 0s.
    function AddNew(const AName: AnsiString; ASize, AFlags: uint32; Mem: pointer): TPESection;

    function SizeOfAllHeaders: uint32; inline;

    function FindByName(const AName: AnsiString; IgnoreCase: boolean): TPESection;

  end;

implementation

uses
  PE.Image,
  PE.Utils;

{ TPESections }

function TPESections.Add(const Item: TPESection): TPESection;
var
  PE: TPEImage;
begin
  inherited Add(Item);
  PE := TPEImage(FPE);
  inc(PE.FileHeader^.NumberOfSections);
  Result := Item;
end;

function TPESections.AddNew(const AName: AnsiString; ASize, AFlags: uint32; Mem: pointer): TPESection;
var
  h: TImageSectionHeader;
  i: integer;
  PE: TPEImage;
begin
  PE := TPEImage(FPE);

  PE.Defaults.SetAll;

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

  // h.PointerToRawData will be calculated later.

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

function TPESections.SizeOfAllHeaders: uint32;
begin
  Result := Count * sizeof(TImageSectionHeader)
end;

end.
