unit PE.Types.NTHeaders;

interface

uses
  PE.Types.FileHeader,
  PE.Types.OptionalHeader;

const
  PE00_SIGNATURE = $00004550;

type
  TImageNTHeaders32 = packed record
    Signature:      uint32;
    FileHeader:     TImageFileHeader;
    OptionalHeader: TImageOptionalHeader32;
  end;
  PImageNTHeaders32 = ^TImageNTHeaders32;

  TImageNTHeaders64 = packed record
    Signature:      uint32;
    FileHeader:     TImageFileHeader;
    OptionalHeader: TImageOptionalHeader64;
  end;
  PImageNTHeaders64 = ^TImageNTHeaders64;

  TImageNTHeaders = packed record
    Signature:      uint32;
    FileHeader:     TImageFileHeader;
    OptionalHeader: TImageOptionalHeader;
  end;
  PImageNTHeaders = ^TImageNTHeaders;

implementation

end.
