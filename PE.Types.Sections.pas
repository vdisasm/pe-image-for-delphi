unit PE.Types.Sections;

interface

{$i 'PE.Types.Sections.inc'}

type
  TISHMisc = packed record
    case Integer of
      0: (PhysicalAddress: uint32);
      1: (VirtualSize: uint32);
  end;

  TImageSectionHeader = packed record
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
  end;

  PImageSectionHeader = ^TImageSectionHeader;

implementation

end.
