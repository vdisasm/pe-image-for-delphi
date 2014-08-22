unit PE.Types.Sections;

interface

{$i 'PE.Types.Sections.inc'}

type
  TISHMisc = packed record
  public
    case Integer of
      0: (PhysicalAddress: uint32);
      1: (VirtualSize: uint32);
  end;

  TImageSectionHeader = packed record
  public
    Name: packed array [0 .. IMAGE_SIZEOF_SHORT_NAME - 1] of AnsiChar;
    Misc: TISHMisc;
    VirtualAddress: uint32;
    SizeOfRawData: uint32;
    PointerToRawData: uint32;
    PointerToRelocations: uint32;
    PointerToLinenumbers: uint32;
    NumberOfRelocations: uint16;
    NumberOfLinenumbers: uint16;
    Characteristics: uint32;
    function GetName: string;
  end;

  PImageSectionHeader = ^TImageSectionHeader;

implementation

{ TImageSectionHeader }

function TImageSectionHeader.GetName: string;
begin
  Result := string(PAnsiChar(@self.Name[0]));
end;

end.
